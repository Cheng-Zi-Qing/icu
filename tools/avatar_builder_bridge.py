#!/usr/bin/env python3
import argparse
from contextlib import redirect_stdout
import json
import os
import sys
from pathlib import Path

BUILDER_DIR = str(Path(__file__).resolve().parent.parent / "builder")


def _default_image_models():
    return [
        {
            "name": "Stable Diffusion XL",
            "url": "stabilityai/stable-diffusion-xl-base-1.0",
            "token": "",
        }
    ]


def _load_settings(repo_root: str | None):
    candidate_roots = []

    app_support_root = os.getenv("ICU_APP_SUPPORT_ROOT", "").strip()
    if app_support_root:
        candidate_roots.append(Path(app_support_root))

    if repo_root:
        candidate_roots.append(Path(repo_root))

    for root in candidate_roots:
        settings_file = root / "config" / "settings.json"
        if settings_file.exists():
            with settings_file.open("r", encoding="utf-8") as handle:
                return json.load(handle)

    return {}


def _load_local_api_url(repo_root: str | None) -> str:
    settings = _load_settings(repo_root)
    return (
        settings.get("ai", {})
        .get("local_api", {})
        .get("url", "http://localhost:11434")
        .rstrip("/")
    )


def _load_image_models(repo_root: str | None):
    settings = _load_settings(repo_root)
    models = settings.get("ai", {}).get("image_models", [])
    return models or _default_image_models()


def _resolve_image_token(repo_root: str | None, model_url: str, explicit_token: str) -> str:
    if explicit_token:
        return explicit_token

    for model in _load_image_models(repo_root):
        if model.get("url") == model_url and model.get("token"):
            return model["token"]

    return os.getenv("HF_TOKEN", "")


def _session_dir(session_id: str) -> Path:
    root = Path("/tmp/icu_avatar_bridge") / session_id
    root.mkdir(parents=True, exist_ok=True)
    return root


def cmd_list_image_models(args):
    print(json.dumps({"models": _load_image_models(args.repo_root)}, ensure_ascii=False))


def cmd_optimize_prompt(args):
    sys.path.insert(0, BUILDER_DIR)
    from prompt_optimizer import PromptOptimizer

    optimizer = PromptOptimizer(ollama_url=_load_local_api_url(args.repo_root))
    prompt = optimizer.optimize(args.text)
    if not prompt:
        raise RuntimeError("failed to optimize prompt")

    print(json.dumps({"prompt": prompt}, ensure_ascii=False))


def cmd_generate_image(args):
    sys.path.insert(0, BUILDER_DIR)
    from vision_generator import VisionGenerator

    token = _resolve_image_token(args.repo_root, args.model_url, args.token)
    generator = VisionGenerator(
        checkpoint_dir=str(_session_dir(args.session_id)),
        hf_token=token,
        model=args.model_url or None,
    )
    with redirect_stdout(sys.stderr):
        image_path = generator.generate(args.prompt, force=True)
    if not image_path:
        raise RuntimeError("failed to generate image")

    print(json.dumps({"path": image_path}, ensure_ascii=False))


def cmd_generate_persona(args):
    sys.path.insert(0, BUILDER_DIR)
    from ollama_http import get_json, post_json

    ollama_url = _load_local_api_url(args.repo_root)
    models = [model["name"] for model in get_json(f"{ollama_url}/api/tags").get("models", [])]
    if "qwen3.5:35b" in models:
        model = "qwen3.5:35b"
    elif "qwen2.5:27b" in models:
        model = "qwen2.5:27b"
    else:
        raise RuntimeError("no supported qwen model found")

    response = post_json(
        f"{ollama_url}/api/chat",
        {
            "model": model,
            "messages": [
                {
                    "role": "system",
                    "content": "你是桌宠人设生成助手。根据用户描述生成简短的人设描述（2-3句话）。",
                },
                {
                    "role": "user",
                    "content": f"用户描述：{args.text}\n\n请生成人设描述：",
                },
            ],
            "options": {"temperature": 0.7},
            "stream": False,
        },
    )

    print(json.dumps({"persona": response["message"]["content"]}, ensure_ascii=False))


def build_parser():
    parser = argparse.ArgumentParser(description="ICU avatar builder bridge")
    subparsers = parser.add_subparsers(dest="command", required=True)

    optimize = subparsers.add_parser("optimize-prompt")
    optimize.add_argument("--text", required=True)
    optimize.add_argument("--repo-root")
    optimize.set_defaults(func=cmd_optimize_prompt)

    list_models = subparsers.add_parser("list-image-models")
    list_models.add_argument("--repo-root")
    list_models.set_defaults(func=cmd_list_image_models)

    generate_image = subparsers.add_parser("generate-image")
    generate_image.add_argument("--prompt", required=True)
    generate_image.add_argument("--model-url", default="")
    generate_image.add_argument("--token", default="")
    generate_image.add_argument("--session-id", required=True)
    generate_image.add_argument("--repo-root")
    generate_image.set_defaults(func=cmd_generate_image)

    generate_persona = subparsers.add_parser("generate-persona")
    generate_persona.add_argument("--text", required=True)
    generate_persona.add_argument("--repo-root")
    generate_persona.set_defaults(func=cmd_generate_persona)

    return parser


def main():
    parser = build_parser()
    args = parser.parse_args()
    try:
        args.func(args)
    except Exception as error:  # pragma: no cover - CLI error path
        print(str(error), file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()

"""第二层：躯体铸造 (Vision Generation)"""
import json
import time
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.parse import quote
from urllib.request import Request, urlopen


class VisionGenerator:
    def __init__(self, checkpoint_dir="/tmp/icu_build", hf_token=None, model=None):
        self.checkpoint_dir = Path(checkpoint_dir)
        self.checkpoint_file = self.checkpoint_dir / "step2_raw_sheet.png"
        self.hf_token = hf_token
        self.model = model or "stabilityai/stable-diffusion-xl-base-1.0"
        self.max_retries = 3
        self.request_timeout = 90

    def generate(self, prompt, force=False):
        """生成图像"""
        if not force and self.checkpoint_file.exists():
            print("📦 使用缓存的图像")
            return str(self.checkpoint_file)

        print("🎨 正在生成图像...")

        for attempt in range(self.max_retries):
            try:
                image_bytes = self._text_to_image(prompt)
                if not image_bytes:
                    raise ValueError("生成的图片内容为空")

                self.checkpoint_dir.mkdir(parents=True, exist_ok=True)
                self.checkpoint_file.write_bytes(image_bytes)
                print(f"✅ 图像生成完成")
                return str(self.checkpoint_file)

            except Exception as e:
                print(f"⚠️ 第 {attempt + 1} 次尝试失败：{e}")
                if attempt < self.max_retries - 1:
                    wait_time = 5 * (2 ** attempt)
                    print(f"  等待 {wait_time} 秒后重试...")
                    time.sleep(wait_time)

        return None

    def _text_to_image(self, prompt):
        payload = json.dumps(
            {
                "inputs": prompt,
                "options": {"wait_for_model": True},
            }
        ).encode("utf-8")
        request = Request(
            self._model_endpoint(),
            data=payload,
            headers=_request_headers(self.hf_token),
            method="POST",
        )

        try:
            with urlopen(request, timeout=self.request_timeout) as response:
                content_type = response.headers.get("Content-Type", "").split(";", 1)[0]
                body = response.read()
        except HTTPError as error:
            detail = error.read().decode("utf-8", errors="replace")
            if error.code == 401 and not self.hf_token:
                raise RuntimeError("当前图像模型需要 Hugging Face Token，请在第 2 步填写后重试") from error
            raise RuntimeError(_extract_error_message(detail) or str(error)) from error
        except URLError as error:
            raise RuntimeError(str(error.reason)) from error

        if content_type == "application/json":
            detail = body.decode("utf-8", errors="replace")
            raise RuntimeError(
                _extract_error_message(detail) or "image inference returned JSON instead of image"
            )

        return body

    def _model_endpoint(self):
        if self.model.startswith("http://") or self.model.startswith("https://"):
            return self.model
        return f"https://api-inference.huggingface.co/models/{quote(self.model, safe='/')}"


def _extract_error_message(body):
    if not body:
        return ""

    try:
        payload = json.loads(body)
    except json.JSONDecodeError:
        return body.strip()

    if isinstance(payload, dict):
        error = payload.get("error")
        if error:
            return str(error)
    return body.strip()


def _request_headers(token):
    headers = {
        "Content-Type": "application/json",
        "Accept": "image/png",
    }
    if token:
        headers["Authorization"] = f"Bearer {token}"
    return headers

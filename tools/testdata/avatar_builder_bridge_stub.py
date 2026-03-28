#!/usr/bin/env python3
import json
import sys


def main():
    command = sys.argv[1]

    if command == "optimize-prompt":
        print(json.dumps({"prompt": "pixel art calm capybara"}))
        return

    if command == "generate-persona":
        text = sys.argv[sys.argv.index("--text") + 1]
        if text == "fail":
            print("stub persona failure", file=sys.stderr)
            sys.exit(1)

        print(json.dumps({"persona": "stub persona"}))
        return

    if command == "list-image-models":
        print(json.dumps({"models": [{"name": "Stub", "url": "stub/model", "token": ""}]}))
        return

    if command == "generate-image":
        print(json.dumps({"path": "/tmp/stub.png"}))
        return

    print(f"unsupported command: {command}", file=sys.stderr)
    sys.exit(1)


if __name__ == "__main__":
    main()

"""Minimal stdlib HTTP helpers for Ollama JSON APIs."""
import json
import os
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

MODEL_DISCOVERY_TIMEOUT_SECONDS = float(os.getenv("ICU_OLLAMA_DISCOVERY_TIMEOUT_SECONDS", "10"))
CHAT_REQUEST_TIMEOUT_SECONDS = float(os.getenv("ICU_OLLAMA_CHAT_TIMEOUT_SECONDS", "120"))


def get_json(url, timeout=MODEL_DISCOVERY_TIMEOUT_SECONDS):
    request = Request(url, method="GET")
    return _read_json(request, timeout=timeout)


def post_json(url, payload, timeout=CHAT_REQUEST_TIMEOUT_SECONDS):
    data = json.dumps(payload).encode("utf-8")
    request = Request(
        url,
        data=data,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    return _read_json(request, timeout=timeout)


def _read_json(request, timeout):
    try:
        with urlopen(request, timeout=timeout) as response:
            return json.load(response)
    except HTTPError as error:
        detail = error.read().decode("utf-8", errors="replace")
        raise RuntimeError(detail or str(error)) from error
    except URLError as error:
        raise RuntimeError(str(error.reason)) from error

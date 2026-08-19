import time

from fastapi import Request

_windows: dict[str, tuple[float, int]] = {}


def check_rate_limit(key: str, max_requests: int = 10, window_seconds: int = 60) -> bool:
    now = time.time()
    window_start, count = _windows.get(key, (now, 0))

    if now - window_start > window_seconds:
        window_start, count = now, 0

    count += 1
    _windows[key] = (window_start, count)

    return count <= max_requests


def client_ip(request: Request) -> str:
    return request.client.host if request.client else "unknown"

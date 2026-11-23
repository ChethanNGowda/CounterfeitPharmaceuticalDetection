"""Small ASGI request-size guard for image and sync endpoints."""

from __future__ import annotations

import json
from collections.abc import Awaitable, Callable
from typing import Any

ASGIApp = Callable[[dict[str, Any], Callable[..., Awaitable[Any]], Callable[..., Awaitable[Any]]], Awaitable[None]]


class _BodyLimitExceeded(Exception):
    pass


class RequestSizeLimitMiddleware:
    """Rejects oversized bodies before multipart/base64 parsing buffers them."""

    def __init__(self, app: ASGIApp, *, limits: dict[str, int]):
        self.app = app
        self.limits = limits

    async def __call__(self, scope, receive, send) -> None:
        if scope.get("type") != "http" or scope.get("method") != "POST":
            await self.app(scope, receive, send)
            return

        limit = self.limits.get(scope.get("path", ""))
        if limit is None:
            await self.app(scope, receive, send)
            return

        headers = {key.lower(): value for key, value in scope.get("headers", [])}
        raw_length = headers.get(b"content-length")
        if raw_length is not None:
            try:
                if int(raw_length) > limit:
                    await self._respond_too_large(scope, receive, send)
                    return
            except ValueError:
                pass  # The HTTP server/framework will reject malformed framing.

        received = 0
        response_started = False

        async def limited_receive():
            nonlocal received
            message = await receive()
            if message.get("type") == "http.request":
                received += len(message.get("body", b""))
                if received > limit:
                    raise _BodyLimitExceeded
            return message

        async def tracked_send(message):
            nonlocal response_started
            if message.get("type") == "http.response.start":
                response_started = True
            await send(message)

        try:
            await self.app(scope, limited_receive, tracked_send)
        except _BodyLimitExceeded:
            if not response_started:
                await self._respond_too_large(scope, receive, send)

    @staticmethod
    async def _respond_too_large(scope, receive, send) -> None:
        body = json.dumps(
            {"detail": "Request body exceeds the endpoint size limit."}
        ).encode("utf-8")
        await send(
            {
                "type": "http.response.start",
                "status": 413,
                "headers": [
                    (b"content-type", b"application/json"),
                    (b"content-length", str(len(body)).encode("ascii")),
                ],
            }
        )
        await send({"type": "http.response.body", "body": body})

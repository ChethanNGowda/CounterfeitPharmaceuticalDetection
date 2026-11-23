import asyncio

from backend.app.middleware import RequestSizeLimitMiddleware


def test_chunked_request_body_is_stopped_at_configured_limit():
    responses = []
    chunks = iter(
        [
            {"type": "http.request", "body": b"123", "more_body": True},
            {"type": "http.request", "body": b"456", "more_body": False},
        ]
    )

    async def receive():
        return next(chunks)

    async def send(message):
        responses.append(message)

    async def downstream(scope, receive, send):
        while True:
            message = await receive()
            if message.get("type") == "http.disconnect":
                return
            if not message.get("more_body", False):
                break
        await send({"type": "http.response.start", "status": 200, "headers": []})
        await send({"type": "http.response.body", "body": b"ok"})

    middleware = RequestSizeLimitMiddleware(
        downstream,
        limits={"/sync/records": 5},
    )
    asyncio.run(
        middleware(
            {
                "type": "http",
                "method": "POST",
                "path": "/sync/records",
                "headers": [],
            },
            receive,
            send,
        )
    )

    assert responses[0]["status"] == 413
    assert b"size limit" in responses[1]["body"]


def test_non_limited_paths_pass_through():
    responses = []

    async def receive():
        return {"type": "http.request", "body": b"123456", "more_body": False}

    async def send(message):
        responses.append(message)

    async def downstream(scope, receive, send):
        await receive()
        await send({"type": "http.response.start", "status": 200, "headers": []})
        await send({"type": "http.response.body", "body": b"ok"})

    middleware = RequestSizeLimitMiddleware(
        downstream,
        limits={"/sync/records": 5},
    )
    asyncio.run(
        middleware(
            {"type": "http", "method": "POST", "path": "/predict", "headers": []},
            receive,
            send,
        )
    )

    assert responses[0]["status"] == 200


def test_declared_oversized_request_is_rejected_without_reading_body():
    responses = []

    async def receive():
        raise AssertionError("middleware should reject from Content-Length first")

    async def send(message):
        responses.append(message)

    async def downstream(scope, receive, send):
        raise AssertionError("oversized body must not reach the endpoint")

    middleware = RequestSizeLimitMiddleware(
        downstream,
        limits={"/sync/records": 5},
    )
    asyncio.run(
        middleware(
            {
                "type": "http",
                "method": "POST",
                "path": "/sync/records",
                "headers": [(b"content-length", b"6")],
            },
            receive,
            send,
        )
    )
    assert responses[0]["status"] == 413

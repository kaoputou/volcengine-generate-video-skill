#!/usr/bin/env python3
"""Create and poll Volcengine Ark Seedance video generation tasks."""

from __future__ import annotations

import argparse
import base64
import json
import mimetypes
import os
import pathlib
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

API_BASE = "https://ark.cn-beijing.volces.com/api/v3"
CREATE_PATH = "/contents/generations/tasks"
TERMINAL_STATUSES = {"succeeded", "failed", "expired", "cancelled"}
MODELS_WITH_AUDIO = {
    "doubao-seedance-2-0-260128",
    "doubao-seedance-2-0-fast-250228",
    "doubao-seedance-1-5-pro-251215",
}


class SeedanceError(RuntimeError):
    """Raised when the API request or response is invalid."""


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Submit a Seedance video generation task and wait for completion."
    )
    parser.add_argument("--prompt", help="Text prompt for the video.")
    parser.add_argument(
        "--first-frame",
        help="First-frame image source: URL, data URI, or local file path.",
    )
    parser.add_argument(
        "--last-frame",
        help="Last-frame image source: URL, data URI, or local file path.",
    )
    parser.add_argument(
        "--reference-image",
        action="append",
        default=[],
        help="Reference image source. Repeat for multiple images.",
    )
    parser.add_argument(
        "--model",
        default="doubao-seedance-2-0-260128",
        help="Seedance model ID.",
    )
    parser.add_argument(
        "--ratio",
        choices=["16:9", "9:16", "1:1", "4:3", "adaptive"],
        help="Aspect ratio. Defaults to adaptive when image inputs are provided.",
    )
    parser.add_argument(
        "--resolution",
        choices=["480p", "720p", "1080p"],
        default="720p",
        help="Output resolution.",
    )
    parser.add_argument(
        "--duration",
        type=int,
        default=5,
        help="Duration in seconds.",
    )
    parser.add_argument(
        "--generate-audio",
        action=argparse.BooleanOptionalAction,
        default=None,
        help="Override automatic audio behavior.",
    )
    parser.add_argument(
        "--seed",
        type=int,
        default=-1,
        help="Random seed. Use -1 for random.",
    )
    parser.add_argument(
        "--watermark",
        action="store_true",
        help="Request a watermarked output.",
    )
    parser.add_argument(
        "--poll-interval",
        type=float,
        default=10.0,
        help="Polling interval in seconds.",
    )
    parser.add_argument(
        "--timeout",
        type=float,
        default=1800.0,
        help="Maximum wait time in seconds.",
    )
    parser.add_argument(
        "--download",
        help="Optional output path for downloading the final video.",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Print the final result as JSON.",
    )
    return parser.parse_args()


def build_headers(api_key: str) -> dict[str, str]:
    return {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    }


def looks_like_url(value: str) -> bool:
    parsed = urllib.parse.urlparse(value)
    return parsed.scheme in {"http", "https"}


def to_data_uri(path_str: str) -> str:
    path = pathlib.Path(path_str).expanduser()
    if not path.is_file():
        raise SeedanceError(f"Image file not found: {path}")
    mime_type, _ = mimetypes.guess_type(path.name)
    if not mime_type:
        mime_type = "application/octet-stream"
    encoded = base64.b64encode(path.read_bytes()).decode("ascii")
    return f"data:{mime_type};base64,{encoded}"


def normalize_image_source(value: str) -> str:
    if value.startswith("data:") or looks_like_url(value):
        return value
    return to_data_uri(value)


def image_content(role: str, source: str) -> dict[str, object]:
    return {
        "type": "image_url",
        "image_url": {"url": normalize_image_source(source)},
        "role": role,
    }


def default_ratio(args: argparse.Namespace) -> str:
    has_images = bool(args.first_frame or args.last_frame or args.reference_image)
    if args.ratio:
        return args.ratio
    return "adaptive" if has_images else "16:9"


def default_audio(model: str) -> bool:
    return model in MODELS_WITH_AUDIO


def build_payload(args: argparse.Namespace) -> dict[str, object]:
    content: list[dict[str, object]] = []
    if args.prompt:
        content.append({"type": "text", "text": args.prompt})
    if args.first_frame:
        content.append(image_content("first_frame", args.first_frame))
    if args.last_frame:
        content.append(image_content("last_frame", args.last_frame))
    for source in args.reference_image:
        content.append(image_content("reference_image", source))

    if not content:
        raise SeedanceError(
            "Provide at least --prompt or one image input such as --first-frame."
        )

    has_non_text = any(item["type"] != "text" for item in content)
    if not args.prompt and not has_non_text:
        raise SeedanceError(
            "Text-to-video requires --prompt unless you provide image inputs."
        )

    generate_audio = (
        args.generate_audio
        if args.generate_audio is not None
        else default_audio(args.model)
    )

    return {
        "model": args.model,
        "content": content,
        "ratio": default_ratio(args),
        "resolution": args.resolution,
        "duration": args.duration,
        "generate_audio": generate_audio,
        "seed": args.seed,
        "watermark": args.watermark,
    }


def api_request(
    method: str,
    path: str,
    headers: dict[str, str],
    payload: dict[str, object] | None = None,
) -> dict[str, object]:
    data = None
    if payload is not None:
        data = json.dumps(payload).encode("utf-8")
    request = urllib.request.Request(
        url=f"{API_BASE}{path}",
        method=method,
        headers=headers,
        data=data,
    )
    try:
        with urllib.request.urlopen(request, timeout=120) as response:
            raw = response.read().decode("utf-8")
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        raise SeedanceError(f"HTTP {exc.code}: {body}") from exc
    except urllib.error.URLError as exc:
        raise SeedanceError(f"Request failed: {exc.reason}") from exc

    try:
        parsed = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise SeedanceError(f"Invalid JSON response: {raw}") from exc
    if not isinstance(parsed, dict):
        raise SeedanceError("Unexpected API response shape.")
    return parsed


def poll_task(
    task_id: str,
    headers: dict[str, str],
    interval: float,
    timeout: float,
) -> dict[str, object]:
    start = time.monotonic()
    while True:
        result = api_request("GET", f"{CREATE_PATH}/{task_id}", headers)
        status = str(result.get("status", ""))
        print(f"Task {task_id}: {status}", file=sys.stderr)
        if status in TERMINAL_STATUSES:
            return result
        if time.monotonic() - start > timeout:
            raise SeedanceError(
                f"Timed out after {timeout} seconds waiting for task {task_id}."
            )
        time.sleep(interval)


def maybe_download(url: str, output_path: str) -> str:
    path = pathlib.Path(output_path).expanduser()
    path.parent.mkdir(parents=True, exist_ok=True)
    with urllib.request.urlopen(url, timeout=300) as response:
        path.write_bytes(response.read())
    return str(path)


def summarize(result: dict[str, object], download_path: str | None) -> str:
    content = result.get("content") if isinstance(result.get("content"), dict) else {}
    error = result.get("error") if isinstance(result.get("error"), dict) else {}
    lines = [
        f"task_id: {result.get('id', '')}",
        f"status: {result.get('status', '')}",
    ]
    if content:
        video_url = content.get("video_url", "")
        if video_url:
            lines.append(f"video_url: {video_url}")
        for key in ("resolution", "ratio", "duration", "fps", "has_audio"):
            if key in content:
                lines.append(f"{key}: {content.get(key)}")
    if download_path:
        lines.append(f"downloaded_to: {download_path}")
    if error:
        code = error.get("code", "")
        message = error.get("message", "")
        lines.append(f"error_code: {code}")
        lines.append(f"error_message: {message}")
    return "\n".join(lines)


def main() -> int:
    args = parse_args()
    api_key = os.environ.get("ARK_API_KEY")
    if not api_key:
        print("ARK_API_KEY is not set.", file=sys.stderr)
        return 2

    try:
        payload = build_payload(args)
        headers = build_headers(api_key)
        created = api_request("POST", CREATE_PATH, headers, payload)
        task_id = created.get("id")
        if not isinstance(task_id, str) or not task_id:
            raise SeedanceError(f"Task ID missing from create response: {created}")
        result = poll_task(task_id, headers, args.poll_interval, args.timeout)

        status = result.get("status")
        download_path = None
        content = result.get("content")
        if (
            status == "succeeded"
            and isinstance(content, dict)
            and isinstance(content.get("video_url"), str)
            and args.download
        ):
            download_path = maybe_download(content["video_url"], args.download)

        if args.json:
            output = {
                "request": payload,
                "result": result,
                "download_path": download_path,
            }
            print(json.dumps(output, ensure_ascii=False, indent=2))
        else:
            print(summarize(result, download_path))

        return 0 if status == "succeeded" else 1
    except SeedanceError as exc:
        print(str(exc), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())

---
name: volcengine-generate-video
description: Generate videos with Volcengine Ark Seedance via API, including text-to-video and image-to-video workflows. Use when a user asks for "生成视频", "文生视频", "图生视频", Seedance, Volcengine Ark, text-to-video, or image-to-video tasks, especially when you need to submit a task, poll for completion, and return the final video URL.
---

# Volcengine Generate Video

## Overview

Use this skill to create Volcengine Ark Seedance video generation tasks and wait for the final result.
Prefer the bundled script `scripts/seedance_video.py` over handwritten `curl` commands so the request payload, polling, local image handling, and result formatting stay consistent.

## Workflow

1. Confirm the generation mode:
   - Text-to-video: the user provides a prompt.
   - Image-to-video: the user provides at least one image for `first_frame`, `last_frame`, or `reference_image`; a prompt is optional but usually helpful.
2. Check `ARK_API_KEY` in the environment.
   - If missing, ask the user to set it.
   - The API key comes from the Volcengine Ark console: `https://console.volcengine.com/ark/region:ark+cn-beijing/apiKey`
3. Collect or confirm the main parameters:
   - `model`
   - `ratio`
   - `resolution`
   - `duration`
   - whether to generate audio
4. Run the bundled script.
5. Return the final `video_url` plus key metadata.
6. Remind the user that the returned video URL expires after 24 hours.

## Defaults

- Default model: `doubao-seedance-2-0-260128`
- Default ratio:
  - `16:9` for text-only generation
  - `adaptive` when a frame image is provided
- Default resolution: `720p`
- Default duration: `5`
- Default audio behavior:
  - enabled for Seedance 2.0 and 1.5 Pro models
  - disabled for lite and older models unless the user explicitly requests otherwise

## Commands

Run from the skill directory when convenient.

Text-to-video:

```bash
python3 scripts/seedance_video.py \
  --prompt "A cinematic tracking shot of a red fox running through snowy woods at sunrise"
```

Image-to-video with a first frame URL:

```bash
python3 scripts/seedance_video.py \
  --prompt "Slow camera push-in, soft morning light" \
  --first-frame https://example.com/frame.jpg
```

Image-to-video with a local file and direct download:

```bash
python3 scripts/seedance_video.py \
  --prompt "The character turns and smiles at the camera" \
  --first-frame /absolute/path/to/frame.png \
  --download /absolute/path/to/output.mp4
```

Useful flags:

- `--model <model-id>`
- `--ratio 16:9|9:16|1:1|4:3|adaptive`
- `--resolution 480p|720p|1080p`
- `--duration <seconds>`
- `--generate-audio` or `--no-generate-audio`
- `--seed <int>`
- `--watermark`
- `--download <path>`
- `--json`

## Output Expectations

When the task succeeds, report:

- the final video URL
- model used
- ratio
- resolution
- duration
- whether audio is present
- any saved download path, if one was requested

When the task fails, include:

- task status
- error code and message when present

## Reference

Read `references/openapi.yaml` only when you need the raw API schema, supported enums, or request/response details that are not obvious from the script interface.

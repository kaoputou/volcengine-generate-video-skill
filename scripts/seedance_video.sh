#!/usr/bin/env bash
set -euo pipefail

API_BASE="https://ark.cn-beijing.volces.com/api/v3"
CREATE_PATH="/contents/generations/tasks"
MODEL="doubao-seedance-2-0-260128"
RATIO=""
RESOLUTION="720p"
DURATION="5"
GENERATE_AUDIO=""
SEED="-1"
WATERMARK="false"
POLL_INTERVAL="10"
TIMEOUT="1800"
DOWNLOAD_PATH=""
OUTPUT_JSON="false"
PROMPT=""
FIRST_FRAME=""
LAST_FRAME=""
REFERENCE_IMAGES=()

usage() {
  cat <<'EOF'
usage: seedance_video.sh [options]

Submit a Seedance video generation task and wait for completion.

options:
  --prompt TEXT                 Text prompt for the video.
  --first-frame SRC             First-frame image source: URL, data URI, or local file path.
  --last-frame SRC              Last-frame image source: URL, data URI, or local file path.
  --reference-image SRC         Reference image source. Repeat for multiple images.
  --model MODEL_ID              Seedance model ID. Default: doubao-seedance-2-0-260128
  --ratio VALUE                 16:9, 9:16, 1:1, 4:3, adaptive
  --resolution VALUE            480p, 720p, 1080p
  --duration SECONDS            Video duration. Default: 5
  --generate-audio              Force audio generation on
  --no-generate-audio           Force audio generation off
  --seed INTEGER                Random seed. Default: -1
  --watermark                   Request a watermarked output
  --poll-interval SECONDS       Polling interval. Default: 10
  --timeout SECONDS             Max wait time. Default: 1800
  --download PATH               Download the final video to PATH
  --json                        Print final result as JSON
  -h, --help                    Show this help
EOF
}

die() {
  echo "$*" >&2
  exit 1
}

json_escape() {
  local input="$1"
  input=${input//\\/\\\\}
  input=${input//\"/\\\"}
  input=${input//$'\n'/\\n}
  input=${input//$'\r'/\\r}
  input=${input//$'\t'/\\t}
  printf '%s' "$input"
}

looks_like_url() {
  case "$1" in
    http://*|https://*) return 0 ;;
    *) return 1 ;;
  esac
}

mime_type_for_file() {
  local path="$1"
  local mime_type
  mime_type="$(file -b --mime-type "$path" 2>/dev/null || true)"
  if [[ -z "$mime_type" || "$mime_type" == "application/octet-stream" ]]; then
    case "${path##*.}" in
      png|PNG) mime_type="image/png" ;;
      jpg|JPG|jpeg|JPEG) mime_type="image/jpeg" ;;
      webp|WEBP) mime_type="image/webp" ;;
      gif|GIF) mime_type="image/gif" ;;
      *) mime_type="application/octet-stream" ;;
    esac
  fi
  printf '%s' "$mime_type"
}

to_data_uri() {
  local path="$1"
  [[ -f "$path" ]] || die "Image file not found: $path"
  local mime_type encoded
  mime_type="$(mime_type_for_file "$path")"
  encoded="$(base64 <"$path" | tr -d '\n')"
  printf 'data:%s;base64,%s' "$mime_type" "$encoded"
}

normalize_image_source() {
  local value="$1"
  if [[ "$value" == data:* ]] || looks_like_url "$value"; then
    printf '%s' "$value"
  else
    to_data_uri "$value"
  fi
}

default_ratio() {
  if [[ -n "$RATIO" ]]; then
    printf '%s' "$RATIO"
  elif [[ -n "$FIRST_FRAME" || -n "$LAST_FRAME" || ${#REFERENCE_IMAGES[@]} -gt 0 ]]; then
    printf 'adaptive'
  else
    printf '16:9'
  fi
}

default_audio() {
  case "$MODEL" in
    doubao-seedance-2-0-260128|doubao-seedance-2-0-fast-250228|doubao-seedance-1-5-pro-251215)
      printf 'true'
      ;;
    *)
      printf 'false'
      ;;
  esac
}

json_extract_raw() {
  local keypath="$1"
  local input="$2"
  printf '%s' "$input" | plutil -extract "$keypath" raw -o - - 2>/dev/null || true
}

build_payload() {
  local content_parts=()
  if [[ -n "$PROMPT" ]]; then
    content_parts+=("{\"type\":\"text\",\"text\":\"$(json_escape "$PROMPT")\"}")
  fi
  if [[ -n "$FIRST_FRAME" ]]; then
    content_parts+=("{\"type\":\"image_url\",\"image_url\":{\"url\":\"$(json_escape "$(normalize_image_source "$FIRST_FRAME")")\"},\"role\":\"first_frame\"}")
  fi
  if [[ -n "$LAST_FRAME" ]]; then
    content_parts+=("{\"type\":\"image_url\",\"image_url\":{\"url\":\"$(json_escape "$(normalize_image_source "$LAST_FRAME")")\"},\"role\":\"last_frame\"}")
  fi
  if [[ ${#REFERENCE_IMAGES[@]} -gt 0 ]]; then
    local ref
    for ref in "${REFERENCE_IMAGES[@]}"; do
      content_parts+=("{\"type\":\"image_url\",\"image_url\":{\"url\":\"$(json_escape "$(normalize_image_source "$ref")")\"},\"role\":\"reference_image\"}")
    done
  fi

  [[ ${#content_parts[@]} -gt 0 ]] || die "Provide at least --prompt or one image input such as --first-frame."

  local audio
  if [[ -n "$GENERATE_AUDIO" ]]; then
    audio="$GENERATE_AUDIO"
  else
    audio="$(default_audio)"
  fi

  local content_json
  content_json="$(printf '%s\n' "${content_parts[@]}" | paste -sd, -)"

  printf '{"model":"%s","content":[%s],"ratio":"%s","resolution":"%s","duration":%s,"generate_audio":%s,"seed":%s,"watermark":%s}' \
    "$(json_escape "$MODEL")" \
    "$content_json" \
    "$(json_escape "$(default_ratio)")" \
    "$(json_escape "$RESOLUTION")" \
    "$DURATION" \
    "$audio" \
    "$SEED" \
    "$WATERMARK"
}

api_request() {
  local method="$1"
  local path="$2"
  local payload="${3:-}"
  local response_file http_code body

  response_file="$(mktemp)"
  if [[ -n "$payload" ]]; then
    http_code="$(curl -sS -X "$method" \
      "${API_BASE}${path}" \
      -H "Authorization: Bearer ${ARK_API_KEY}" \
      -H "Content-Type: application/json" \
      --data "$payload" \
      -o "$response_file" \
      -w '%{http_code}')"
  else
    http_code="$(curl -sS -X "$method" \
      "${API_BASE}${path}" \
      -H "Authorization: Bearer ${ARK_API_KEY}" \
      -o "$response_file" \
      -w '%{http_code}')"
  fi

  body="$(cat "$response_file")"
  rm -f "$response_file"

  if [[ ! "$http_code" =~ ^2 ]]; then
    die "HTTP ${http_code}: ${body}"
  fi
  printf '%s' "$body"
}

poll_task() {
  local task_id="$1"
  local start_ts now_ts result status
  start_ts="$(date +%s)"
  while true; do
    result="$(api_request "GET" "${CREATE_PATH}/${task_id}")"
    status="$(json_extract_raw "status" "$result")"
    echo "Task ${task_id}: ${status}" >&2
    case "$status" in
      succeeded|failed|expired|cancelled)
        printf '%s' "$result"
        return 0
        ;;
    esac
    now_ts="$(date +%s)"
    if (( now_ts - start_ts > TIMEOUT )); then
      die "Timed out after ${TIMEOUT} seconds waiting for task ${task_id}."
    fi
    sleep "$POLL_INTERVAL"
  done
}

maybe_download() {
  local url="$1"
  local output_path="$2"
  mkdir -p "$(dirname "$output_path")"
  curl -L -sS "$url" -o "$output_path"
  printf '%s' "$output_path"
}

print_summary() {
  local result="$1"
  local download_path="$2"
  local task_id status video_url resolution ratio duration fps has_audio error_code error_message
  task_id="$(json_extract_raw "id" "$result")"
  status="$(json_extract_raw "status" "$result")"
  video_url="$(json_extract_raw "content.video_url" "$result")"
  resolution="$(json_extract_raw "content.resolution" "$result")"
  ratio="$(json_extract_raw "content.ratio" "$result")"
  duration="$(json_extract_raw "content.duration" "$result")"
  fps="$(json_extract_raw "content.fps" "$result")"
  has_audio="$(json_extract_raw "content.has_audio" "$result")"
  error_code="$(json_extract_raw "error.code" "$result")"
  error_message="$(json_extract_raw "error.message" "$result")"

  echo "task_id: ${task_id}"
  echo "status: ${status}"
  [[ -n "$video_url" ]] && echo "video_url: ${video_url}"
  [[ -n "$resolution" ]] && echo "resolution: ${resolution}"
  [[ -n "$ratio" ]] && echo "ratio: ${ratio}"
  [[ -n "$duration" ]] && echo "duration: ${duration}"
  [[ -n "$fps" ]] && echo "fps: ${fps}"
  [[ -n "$has_audio" ]] && echo "has_audio: ${has_audio}"
  [[ -n "$download_path" ]] && echo "downloaded_to: ${download_path}"
  [[ -n "$error_code" ]] && echo "error_code: ${error_code}"
  [[ -n "$error_message" ]] && echo "error_message: ${error_message}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prompt)
      [[ $# -ge 2 ]] || die "Missing value for --prompt"
      PROMPT="$2"
      shift 2
      ;;
    --first-frame)
      [[ $# -ge 2 ]] || die "Missing value for --first-frame"
      FIRST_FRAME="$2"
      shift 2
      ;;
    --last-frame)
      [[ $# -ge 2 ]] || die "Missing value for --last-frame"
      LAST_FRAME="$2"
      shift 2
      ;;
    --reference-image)
      [[ $# -ge 2 ]] || die "Missing value for --reference-image"
      REFERENCE_IMAGES+=("$2")
      shift 2
      ;;
    --model)
      [[ $# -ge 2 ]] || die "Missing value for --model"
      MODEL="$2"
      shift 2
      ;;
    --ratio)
      [[ $# -ge 2 ]] || die "Missing value for --ratio"
      RATIO="$2"
      shift 2
      ;;
    --resolution)
      [[ $# -ge 2 ]] || die "Missing value for --resolution"
      RESOLUTION="$2"
      shift 2
      ;;
    --duration)
      [[ $# -ge 2 ]] || die "Missing value for --duration"
      DURATION="$2"
      shift 2
      ;;
    --generate-audio)
      GENERATE_AUDIO="true"
      shift
      ;;
    --no-generate-audio)
      GENERATE_AUDIO="false"
      shift
      ;;
    --seed)
      [[ $# -ge 2 ]] || die "Missing value for --seed"
      SEED="$2"
      shift 2
      ;;
    --watermark)
      WATERMARK="true"
      shift
      ;;
    --poll-interval)
      [[ $# -ge 2 ]] || die "Missing value for --poll-interval"
      POLL_INTERVAL="$2"
      shift 2
      ;;
    --timeout)
      [[ $# -ge 2 ]] || die "Missing value for --timeout"
      TIMEOUT="$2"
      shift 2
      ;;
    --download)
      [[ $# -ge 2 ]] || die "Missing value for --download"
      DOWNLOAD_PATH="$2"
      shift 2
      ;;
    --json)
      OUTPUT_JSON="true"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "Unknown argument: $1"
      ;;
  esac
done

[[ -n "${ARK_API_KEY:-}" ]] || die "ARK_API_KEY is not set."

payload="$(build_payload)"
created="$(api_request "POST" "${CREATE_PATH}" "$payload")"
task_id="$(json_extract_raw "id" "$created")"
[[ -n "$task_id" ]] || die "Task ID missing from create response: ${created}"
result="$(poll_task "$task_id")"
status="$(json_extract_raw "status" "$result")"
downloaded_to=""

if [[ "$status" == "succeeded" && -n "$DOWNLOAD_PATH" ]]; then
  video_url="$(json_extract_raw "content.video_url" "$result")"
  [[ -n "$video_url" ]] || die "Succeeded task is missing content.video_url"
  downloaded_to="$(maybe_download "$video_url" "$DOWNLOAD_PATH")"
fi

if [[ "$OUTPUT_JSON" == "true" ]]; then
  if [[ -n "$downloaded_to" ]]; then
    printf '{"request":%s,"result":%s,"download_path":"%s"}\n' \
      "$payload" \
      "$result" \
      "$(json_escape "$downloaded_to")"
  else
    printf '{"request":%s,"result":%s,"download_path":null}\n' \
      "$payload" \
      "$result"
  fi
else
  print_summary "$result" "$downloaded_to"
fi

[[ "$status" == "succeeded" ]]

#!/usr/bin/env bash
# Robust streamer: re-encodes input to stable H.264/AAC profile and streams to RTMP
# Usage: ./stream.sh PLAYLIST RTMP_URL

set -euo pipefail
PLAYLIST="${1:-}"
RTMP_URL="${2:-}"
LOG="/var/log/ffmpeg-stream.log"

if [ -z "$PLAYLIST" ] || [ -z "$RTMP_URL" ]; then
  echo "Usage: $0 PLAYLIST RTMP_URL" >&2
  exit 1
fi

trap 'echo "$(date) - terminating" >> "$LOG"; exit 0' SIGINT SIGTERM

echo "$(date) - starting streamer with playlist=$PLAYLIST to $RTMP_URL" >> "$LOG"

while true; do
  if [ ! -f "$PLAYLIST" ]; then
    echo "$(date) - playlist not found: $PLAYLIST" >> "$LOG"
    sleep 10
    continue
  fi

  while IFS= read -r FILE || [ -n "$FILE" ]; do
    # strip comments after # and trim
    FILE="${FILE%%#*}"
    FILE="${FILE## }"
    [ -z "$FILE" ] && continue

    if [ ! -f "$FILE" ]; then
      echo "$(date) - file not found: $FILE" >> "$LOG"
      continue
    fi

    echo "$(date) - streaming file: $FILE" >> "$LOG"

    ffmpeg -re -hide_banner -loglevel warning -i "$FILE" \
      -c:v libx264 -preset veryfast -profile:v main -level 3.1 -pix_fmt yuv420p \
      -b:v 1500k -maxrate 1800k -bufsize 3000k -vf "scale='min(1280,iw)':'-2'" \
      -c:a aac -b:a 128k -ar 44100 \
      -f flv "$RTMP_URL" >> "$LOG" 2>&1 || {
        echo "$(date) - ffmpeg exited for $FILE, sleeping 3s and continuing" >> "$LOG"
        sleep 3
      }
  done < "$PLAYLIST"

  echo "$(date) - playlist finished, looping after 2s" >> "$LOG"
  sleep 2
done

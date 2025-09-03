#!/bin/bash
# Emite en bucle una lista de videos hacia un servidor RTMP.
# Uso: ./stream.sh PLAYLIST RTMP_URL

set -e
PLAYLIST="$1"
RTMP_URL="$2"

if [ -z "$PLAYLIST" ] || [ -z "$RTMP_URL" ]; then
  echo "Uso: $0 PLAYLIST RTMP_URL" >&2
  exit 1
fi

while true; do
  while IFS= read -r FILE; do
    [ -z "$FILE" ] && continue
    ffmpeg -re -i "$FILE" -c copy -f flv "$RTMP_URL"
  done < "$PLAYLIST"
  sleep 1
done

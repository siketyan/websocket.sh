#!/usr/bin/env sh

HOSTNAME="echo.websocket.org"
PORT="443"
ENDPOINT="/"
ON_MESSAGE="on_message"
ON_CONNECT="on_connect"
MESSAGE="Hello WebSocket!"

. ./websocket.sh

on_message() {
  echo "< $1"
}

on_connect() {
  echo "! Connected"
  echo "> $MESSAGE"
  ws_write "$MESSAGE" 2>/dev/null
}

HANDLE="$(ws_create)"

trap 'ws_close' 2
ws_connect "$HANDLE" "$HOSTNAME" "$PORT" "$ENDPOINT" "$ON_MESSAGE" "$ON_CONNECT" 2>/dev/null

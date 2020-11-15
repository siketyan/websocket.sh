#!/usr/bin/env bash

SRC="./src"
ENTRYPOINT="$SRC/websocket.sh"
DISTRIBUTION="./websocket.sh"
HASHBANG='#!/usr/bin/env bash'

wsm_interpret() {
  while IFS="" read -r LINE; do
    PREFIX="$(echo "$LINE" | cut -c1-2)"

    if [ "$PREFIX" == ". " ]; then
      wsm_interpret "$SRC/$(echo "$LINE" | cut -c3-)"
    elif [ "$PREFIX" == "#!" ]; then
      continue
    else
      echo "$LINE"
    fi
  done < "$1"
}

wsm_make() {
  echo "$HASHBANG"
  wsm_interpret "$ENTRYPOINT"
}

wsm_make > "$DISTRIBUTION"

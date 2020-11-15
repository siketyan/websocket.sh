#!/usr/bin/env bash

wsi_ord() {
  od -An -tuC
}

wsi_chr() {
  # shellcheck disable=SC2059
  printf "\\$(printf '%03o' "$1")"
}

wsi_to_bin() {
  BIN=$(xargs printf "obase=2;%s\n" | bc)
  LENGTH=$(echo -n "$BIN" | wc -c)

  for i in $(seq "$(expr "$1" - "$LENGTH")"); do
    echo -ne "0"
  done

  echo "$BIN"
}

wsi_to_dec() {
  xargs printf "ibase=2;%s\n" | bc
}

wsi_to_hex() {
  xargs printf "obase=16;%s\n" | bc
}

wsi_to_uppercase() {
  # shellcheck disable=SC2021
  tr '[a-z]' '[A-Z]'
}

wsi_bin_to_hex() {
  xargs printf "ibase=2;obase=16;%s\n" | bc
}

wsi_hex_to_dec() {
  xargs printf "ibase=16;%s\n" | bc
}

wsi_hex_to_chr() {
  wsi_hex_to_dec | xargs printf "%c"
}

wsi_str_to_hex() {
  od -A n -t x1 | tr -d ' \n'
}

wsi_hex_to_str() {
  LENGTH=$(echo -ne "$1" | wc -c)

  for i in $(seq 1 2 "$(expr "$LENGTH" - 1)"); do
    wsi_chr "$(echo -ne "$1" | wsi_substr "$i" "$(expr "$i" + 1)" | wsi_to_uppercase | wsi_hex_to_dec)"
  done
}

wsi_substr() {
  cut "-c$1-$2"
}

wsi_char_at() {
  cut "-c$1"
}

wsi_print() {
  echo -ne "$1\r\n"
  wsi_log "# > $1"
}

wsi_log() {
  echo "$1" >&2
}

wsi_random_bytes() {
  LC_ALL=C awk "
    BEGIN {
        srand();
        seed = 1024 * rand();
        for (i = 0; i < $1; ++i) {
            srand(seed * i);
            printf(\"%c\", 127 * rand());
        }
    }
  "
}

wsi_getchar() {
  dd "bs=1" "count=1" 2>/dev/null
}

wsi_getchars() {
  dd "bs=1" "count=$1" 2>/dev/null
}

wsi_gets() {
  while true; do
    CHARACTER=$(wsi_getchar | wsi_ord)

    if [ "$CHARACTER" -eq 13 ]; then
      continue
    elif [ "$CHARACTER" -eq 10 ]; then
      break
    fi

    wsi_chr "$CHARACTER"
  done
}

wsi_base64_encode() {
  uuencode -m - | tail -n +2 | head -n 1
}

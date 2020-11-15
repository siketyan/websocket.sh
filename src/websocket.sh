#!/usr/bin/env bash

. ./utils.sh

ws_read() {
  HEADER_1=$(wsi_getchar | wsi_ord | wsi_to_bin 8)
  HEADER_2=$(wsi_getchar | wsi_ord | wsi_to_bin 8)
  OPCODE=$(echo "$HEADER_1" | wsi_substr 5 8)
  LENGTH=$(echo "$HEADER_2" | wsi_substr 2 8 | wsi_to_dec)

  wsi_log "# FIN: $(echo "$HEADER_1" | wsi_char_at 1)"
  wsi_log "# RSV1: $(echo "$HEADER_1" | wsi_char_at 2)"
  wsi_log "# RSV2: $(echo "$HEADER_1" | wsi_char_at 3)"
  wsi_log "# RSV3: $(echo "$HEADER_1" | wsi_char_at 4)"
  wsi_log "# Opcode: $OPCODE"
  wsi_log "# Mask: $(echo "$HEADER_2" | wsi_char_at 1)"
  wsi_log "# Payload Length: $LENGTH (0b$(echo "$HEADER_2" | wsi_substr 2 8))"

  if [ "$OPCODE" == "1000" ]; then
    for i in $(seq 2); do
      CODE_BIN="$CODE_BIN$(wsi_getchar | wsi_ord | wsi_to_bin 8)"
    done

    if [ "$LENGTH" -gt 2 ]; then
      echo -ne "< " >&2
      for i in $(seq "$(expr "$LENGTH" - 2)"); do
        wsi_getchar >&2
      done
      echo "" >&2
    fi

    echo "# Connection closed: $(echo "$CODE_BIN" | wsi_to_dec)" >&2

    return 1
  elif [ "$OPCODE" == "1001" ]; then
    # TODO: Response to ping
    true
  elif [ "$OPCODE" == "0000" ] && [ "$LENGTH" == 0 ]; then
    ws_close
  fi

  if [ "$LENGTH" -eq 126 ]; then
    for i in $(seq 2); do
      EXTENDED_LENGTH_BIN="$EXTENDED_LENGTH_BIN$(wsi_getchar | wsi_ord | wsi_to_bin 8)"
    done

    EXTENDED_LENGTH="$(echo "$EXTENDED_LENGTH_BIN" | wsi_to_dec)"
    LENGTH="$EXTENDED_LENGTH"

    echo "# Extended Length: $EXTENDED_LENGTH ($EXTENDED_LENGTH_BIN)" >&2
  fi

  if [ "$LENGTH" -eq 127 ]; then
    for i in $(seq 8); do
      EXTENDED_LENGTH_BIN="$EXTENDED_LENGTH_BIN$(wsi_getchar | wsi_ord | wsi_to_bin 8)"
    done

    EXTENDED_LENGTH="$(echo "$EXTENDED_LENGTH_BIN" | wsi_to_dec)"
    LENGTH="$EXTENDED_LENGTH"

    echo "# Extended Length: $EXTENDED_LENGTH ($EXTENDED_LENGTH_BIN)" >&2
  fi

  wsi_getchars "$LENGTH"
}

ws_write() {
  echo "$1" >&3
}

ws_close() {
  ws_write "CLOSED"
  wsi_log "# Bye"
  exec 3>&-
  exit 1
}

ws_receive() {
  exec 3>"$1"

  while true; do
    LINE="$(wsi_gets)"

    echo "# < $LINE" >&2

    if [ "$LINE" == "" ]; then
      break
    fi
  done

  eval "$3"

  while true; do
    # shellcheck disable=SC2034
    MESSAGE="$(ws_read)"
    EXIT_CODE=$?

    if [ "$EXIT_CODE" != 0 ]; then
      break
    fi

    eval "$2" '"$MESSAGE"'
  done

  ws_close
}

ws_transceive() {
  WEBSOCKET_KEY="$(wsi_random_bytes 16 | wsi_base64_encode)"

  wsi_print "GET $2 HTTP/1.1"
  wsi_print "Host: $1"
  wsi_print "Upgrade: websocket"
  wsi_print "Connection: Upgrade"
  wsi_print "Sec-WebSocket-Key: $WEBSOCKET_KEY"
  wsi_print "Sec-WebSocket-Version: 13"
  wsi_print ""

  while true; do
    read -r LINE

    if [ "$LINE" == "CLOSED" ]; then
      break
    elif [ "$LINE" != "" ]; then
      LINE_LENGTH="$(echo -ne "$LINE" | wc -c)"
      LENGTH="$LINE_LENGTH"
      wsi_log "# Payload Length: $LINE_LENGTH"

      if [ "$LENGTH" -gt 125 ]; then
          EXTENDED_LENGTH_BIN="$(echo "$LENGTH" | wsi_to_bin 16)"
          LENGTH=126
      else
          EXTENDED_LENGTH_BIN=""
      fi

      LENGTH_BIN="$(echo $LENGTH | wsi_to_bin 7)"
      HEADER_BIN="100000011$LENGTH_BIN$EXTENDED_LENGTH_BIN"
      wsi_log "# Header: $HEADER_BIN"

      # shellcheck disable=SC2000
      for i in $(seq 1 8 "$(expr "$(echo "$HEADER_BIN" | wc -c)" - 1)"); do
          BYTE_HEX=$(echo "$HEADER_BIN" | wsi_substr "$i" "$(expr "$i" + 7)")
          BYTE_DEC=$(echo "$BYTE_HEX" | wsi_to_dec)
          wsi_chr "$BYTE_DEC" | cat -
      done

      MASKING_KEY_HEX="$(wsi_random_bytes 4 | wsi_str_to_hex)"
      LINE_HEX="$(echo -ne "$LINE" | wsi_str_to_hex)"
      wsi_hex_to_str "$MASKING_KEY_HEX"

      wsi_log "# Mask: $MASKING_KEY_HEX"

      for i in $(seq 0 "$(expr "$LINE_LENGTH" - 1)"); do
          j=$(expr "$i" % 4)
          MASKING_OCTET="$(echo -ne "$MASKING_KEY_HEX" | wsi_substr "$(expr "$j" \* 2 + 1)" "$(expr "$j" \* 2 + 2)")"
          ORIGINAL_OCTET="$(echo -ne "$LINE_HEX" | wsi_substr "$(expr "$i" \* 2 + 1)" "$(expr "$i" \* 2 + 2)")"
          MASKED_OCTET="$(printf '%02x' $(( 0x$ORIGINAL_OCTET ^ 0x$MASKING_OCTET )))"
          wsi_hex_to_str "$MASKED_OCTET"
      done
    fi
  done
}

ws_connect() {
  # shellcheck disable=SC2094
  ws_transceive "$2" "$4" < "$1" | openssl s_client -verify_quiet -quiet -connect "$2:$3" | ws_receive "$1" "$5" "$6"
}

ws_create() {
  HANDLE="$(mktemp)"

  rm -f "$HANDLE"
  mkfifo "$HANDLE"
  echo "$HANDLE"
}

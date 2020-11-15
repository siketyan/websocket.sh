# websocket.sh
A simple WebSocket implementation, written only in Shell Script.

## Installation
```console
$ ./make.sh
```

## Usage
1. Load the built script.
   ```shell script
   . ./websocket.sh
   ```

1. Creating a Pipe to handle the stream.
   ```shell script
   HANDLE="$(ws_create)"
   ```

1. Prepare functions to handle events.
   ```shell script
   on_message() {
     MESSAGE="$1"
     echo "on_message: $MESSAGE"
   }
   
   on_connect() {
     echo "on_connect"
     # TODO: Start sending something...
   }
   ```

1. Connect to your server.
   ```shell script
   ws_connect "hostname.local" "80" "/connect" "on_message" "on_connect"
   # ws_connect [hostname] [port] [path] [on_message] [on_connect]
   ```

1. Send something.
   ```shell script
   ws_write "Hey!"
   ```

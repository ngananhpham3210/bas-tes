#!/bin/bash

# The `build` function runs once at deploy time to prepare the environment.
# Its job is to download dependencies and make them available for the handler.
build() {
  echo "--- Build: Downloading yt-dlp binary ---"

  # 1. Download the file into the cache and get its source location.
  local ytdlp_source_path
  ytdlp_source_path="$(import_file "https://github.com/yt-dlp/yt-dlp/releases/download/2023.12.30/yt-dlp_linux")"

  # 2. Make the downloaded file executable.
  chmod +x "$ytdlp_source_path"

  # 3. Ensure the bin directory exists inside the cache.
  mkdir -p "$IMPORT_CACHE/bin"

  # 4. Create a symlink in the `bin` directory for a predictable path.
  #    This allows us to easily find it at runtime without calling import_file again.
  ln -s "$ytdlp_source_path" "$IMPORT_CACHE/bin/yt-dlp"

  echo "--- Build: Complete. yt-dlp is ready. ---"
}

# The `handler` function runs on every incoming HTTP request.
handler() {
  # Set the content type to plain text for the response.
  http_response_header "Content-Type" "text/plain"

  # The path to our binary is now fixed and predictable because of our build step.
  local YTDLP_PATH="$IMPORT_CACHE/bin/yt-dlp"

  # Check if the file exists and is executable before trying to run it.
  if [ -x "$YTDLP_PATH" ]; then
    # Execute the binary and return its version as the HTTP response body.
    "$YTDLP_PATH" --version
  else
    # If something went wrong, send a server error response.
    http_response_code 500
    echo "Error: yt-dlp binary not found or not executable at '$YTDLP_PATH'."
  fi
}

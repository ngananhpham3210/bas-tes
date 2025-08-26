#!/bin/bash

# The `build` function runs once at deploy time.
# Its job is to download dependencies and place them in the import cache.
build() {
  echo "--- Build Phase ---"
  echo "Downloading and caching yt-dlp binary..."

  # Download the file. It will be stored in the cache.
  local ytdlp_build_path
  ytdlp_build_path="$(import_file "https://github.com/yt-dlp/yt-dlp/releases/download/2025.08.22/yt-dlp_linux")"

  # Make it executable. File permissions are preserved in the final Lambda package.
  chmod +x "$ytdlp_build_path"

  echo "Build complete. yt-dlp is cached and executable."
  echo "--- End Build Phase ---"
}

# The `handler` function runs on every request.
# Its job is to handle the request and produce a response.
handler() {
  # Let the client know we are sending back plain text
  http_response_header "Content-Type" "text/plain"

  # Get the path to the binary from the cache that was populated during build.
  # This call is instant and does NOT re-download the file.
  local YTDLP_PATH
  YTDLP_PATH="$(import_file "https://github.com/yt-dlp/yt-dlp/releases/download/2023.12.30/yt-dlp_linux")"

  # For debugging, print the path to the Vercel logs.
  echo "Handler: Found yt-dlp at: $YTDLP_PATH" >&2

  # Check if the file exists and is executable before running it
  if [ -x "$YTDLP_PATH" ]; then
    # Execute the binary. Its output is the HTTP response body.
    "$YTDLP_PATH" --version
  else
    # If something went wrong, send an error response.
    http_response_code 500
    echo "Error: yt-dlp binary not found or not executable at runtime."
  fi
}

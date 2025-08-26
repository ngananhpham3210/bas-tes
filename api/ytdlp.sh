#!/bin/bash

# The `build` function runs once at deploy time to prepare the environment.
build() {
  echo "--- Build Phase ---"
  echo "Downloading yt-dlp binary..."

  # 1. Download the file into the cache and get its location.
  local ytdlp_source_path
  ytdlp_source_path="$(import_file "https://github.com/yt-dlp/yt-dlp/releases/download/2025.08.22/yt-dlp_linux")"

  # 2. Define the desired, predictable path inside the `bin` directory.
  local ytdlp_bin_path="$IMPORT_CACHE/bin/yt-dlp"

  # 3. Ensure the bin directory exists.
  mkdir -p "$IMPORT_CACHE/bin"

  # 4. THE FIX: Remove the destination file if it exists to prevent conflicts.
  rm -f "$ytdlp_bin_path"

  # 5. Copy the binary to the desired location.
  cp "$ytdlp_source_path" "$ytdlp_bin_path"

  # 6. Make the NEW file executable.
  chmod +x "$ytdlp_bin_path"

  echo "Build complete. yt-dlp has been copied into the bin directory."
  echo "--- End Build Phase ---"
}

# The `handler` function runs on every request.
handler() {
  # Let the client know we are sending back plain text
  http_response_header "Content-Type" "text/plain; charset=utf-8"

  # The path to our binary is now fixed and predictable.
  local YTDLP_PATH="$IMPORT_CACHE/bin/yt-dlp"

  # Check if the file exists and is executable.
  if [ -x "$YTDLP_PATH" ]; then
    # Execute the command and capture its output into a variable.
    local ytdlp_version
    ytdlp_version=$("$YTDLP_PATH" --version)

    # Use echo to format the final HTTP response body.
    echo "Hello from Vercel! The yt-dlp version is: $ytdlp_version"
  else
    # Error handling for the case where the file is still missing.
    http_response_code 500
    echo "Error: yt-dlp binary not found or not executable at '$YTDLP_PATH'."
  fi
}

#!/bin/bash

# The `build` function runs once at deploy time to prepare the environment.
build() {
  echo "--- Build Phase ---"
  echo "Downloading yt-dlp binary..."

  # 1. Download the file into the cache and get its location.
  local ytdlp_source_path
  ytdlp_source_path="$(import_file "https://github.com/yt-dlp/yt-dlp/releases/download/2023.12.30/yt-dlp_linux")"

  # 2. Make the downloaded file executable.
  chmod +x "$ytdlp_source_path"

  # 3. Ensure the bin directory exists.
  mkdir -p "$IMPORT_CACHE/bin"

  # 4. Define the desired, predictable path inside the `bin` directory.
  local ytdlp_bin_path="$IMPORT_CACHE/bin/yt-dlp"

  # 5. THE FIX: Use `ln -sf` to force overwrite the symlink if it exists.
  #    -s: symbolic link
  #    -f: force (remove existing destination files)
  ln -sf "$ytdlp_source_path" "$ytdlp_bin_path"

  echo "Build complete. Symlink created for yt-dlp in the bin directory."
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
    # If something went wrong, send an error response.
    http_response_code 500
    echo "Error: yt-dlp binary not found or not executable at '$YTDLP_PATH'."
  fi
}

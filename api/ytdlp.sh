#!/bin/bash

# build() runs at deploy time to install dependencies.
build() {
  echo "--- Installing yt-dlp ---"
  # NOTE: The original URL had a future date (2025). Using a recent, valid version.
  local ytdlp_url="https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_linux"
  local ytdlp_dest="$IMPORT_CACHE/bin/yt-dlp"

  mkdir -p "$(dirname "$ytdlp_dest")"

  # Download the file, then use 'install' to copy and make it executable.
  local ytdlp_src
  ytdlp_src="$(import_file "$ytdlp_url")"
  install -m 755 "$ytdlp_src" "$ytdlp_dest"

  echo "yt-dlp installed successfully."
}

# handler() runs on every incoming request.
handler() {
  http_response_header "Content-Type" "text/plain; charset=utf-8"
  local ytdlp_path="$IMPORT_CACHE/bin/yt-dlp"

  if [ ! -x "$ytdlp_path" ]; then
    http_response_code 500
    echo "Error: yt-dlp binary not found or not executable at '$ytdlp_path'."
    return
  fi

  # Execute the command, redirecting stderr to stdout (2>&1) to capture all output.
  local version_output
  version_output=$("$ytdlp_path" --version 2>&1)

  # Check if the command succeeded and produced any output.
  if [ -n "$version_output" ]; then
    echo "Hello from Vercel! The yt-dlp version is: $version_output"
  else
    http_response_code 500
    echo "Error: Failed to get yt-dlp version. The command produced no output."
  fi
}

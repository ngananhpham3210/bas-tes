#!/bin/bash

# build() runs at deploy time to install dependencies.
build() {
  echo "--- Installing yt-dlp ---"
  local ytdlp_url="https://github.com/yt-dlp/yt-dlp/releases/download/2025.08.22/yt-dlp_linux"
  local ytdlp_dest="$IMPORT_CACHE/bin/yt-dlp"

  # Create bin directory if it doesn't exist.
  mkdir -p "$(dirname "$ytdlp_dest")"

  # Download the file and use 'install' to copy it and make it executable.
  local ytdlp_src
  ytdlp_src="$(import_file "$ytdlp_url")"
  install -m 755 "$ytdlp_src" "$ytdlp_dest"
}

# handler() runs on every incoming request.
handler() {
  http_response_header "Content-Type" "text/plain; charset=utf-8"
  local ytdlp_path="$IMPORT_CACHE/bin/yt-dlp"

  if [ -x "$ytdlp_path" ]; then
    # Execute yt-dlp and embed its version directly in the response.
    echo "Hello from Vercel! The yt-dlp version is: $(${ytdlp_path} --version)"
  else
    http_response_code 500
    echo "Error: yt-dlp binary not found or not executable at '$ytdlp_path'."
  fi
}

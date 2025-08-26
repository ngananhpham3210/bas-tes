#!/bin/bash

# build() runs at deploy time to bundle dependencies.
build() {
  echo "--- Build Phase: Bundling a self-contained Python & yt-dlp ---"

  # 1. Define a single local directory for our entire environment.
  local INSTALL_DIR="./.local"
  mkdir -p "$INSTALL_DIR"

  # 2. Download and extract a portable Python directly into our directory.
  echo "Downloading and extracting standalone Python..."
  local python_url="https://github.com/astral-sh/python-build-standalone/releases/download/20250818/cpython-3.12.11+20250818-x86_64_v4-unknown-linux-gnu-install_only_stripped.tar.gz"
  local python_tarball
  python_tarball="$(import_file "$python_url")"
  tar -xzf "$python_tarball" -C "$INSTALL_DIR" --strip-components=1

  # 3. Use the newly extracted Python to install yt-dlp.
  # pip will place the 'yt-dlp' executable inside ./local/bin/
  echo "Installing yt-dlp..."
  "$INSTALL_DIR/bin/python3" -m pip install yt-dlp

  echo "--- Build complete. Environment is bundled in '$INSTALL_DIR'. ---"
}

# handler() runs on every incoming request.
handler() {
  http_response_header "Content-Type" "text/plain; charset=utf-8"

  # The path to the yt-dlp executable is now simple and predictable.
  local YTDLP_EXE="./.local/bin/yt-dlp"

  if [ ! -x "$YTDLP_EXE" ]; then
    http_response_code 500
    echo "Error: Bundled yt-dlp executable not found at '$YTDLP_EXE'."
    return
  fi

  # Execute the script directly and capture its version.
  local version_output
  version_output=$("$YTDLP_EXE" --version 2>&1)

  if [ -n "$version_output" ]; then
    echo "Hello from Vercel! The yt-dlp version is: $version_output"
  else
    http_response_code 500
    echo "Error: Failed to get yt-dlp version using the bundled executable."
  fi
}

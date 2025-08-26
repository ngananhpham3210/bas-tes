#!/bin/bash

# build() runs at deploy time to bundle dependencies.
build() {
  echo "--- Build Phase: Bundling a self-contained Python & yt-dlp ---"

  local INSTALL_DIR="./.local"
  mkdir -p "$INSTALL_DIR"

  # 1. Download the correct x86_64 portable Python binary.
  echo "Downloading and extracting x86_64 standalone Python..."
  local python_url="https://github.com/indygreg/python-build-standalone/releases/download/20240107/cpython-3.11.7+20240107-x86_64-unknown-linux-gnu-install_only.tar.gz"
  
  local python_tarball
  python_tarball="$(import_file "$python_url")"
  tar -xzf "$python_tarball" -C "$INSTALL_DIR" --strip-components=1

  # 2. Use the new Python to install yt-dlp.
  echo "Installing yt-dlp..."
  "$INSTALL_DIR/bin/python3" -m pip install yt-dlp

  # 3. THE FIX: Remove unnecessary config symlinks that cause packaging errors.
  echo "Removing problematic config scripts..."
  rm -f "$INSTALL_DIR/bin/python*-config"

  echo "--- Build complete. Environment is bundled and cleaned. ---"
}

# handler() runs on every incoming request.
handler() {
  http_response_header "Content-Type" "text/plain; charset=utf-8"

  local YTDLP_EXE="./.local/bin/yt-dlp"

  if [ ! -x "$YTDLP_EXE" ]; then
    http_response_code 500
    echo "Error: Bundled yt-dlp executable not found at '$YTDLP_EXE'."
    return
  fi

  local version_output
  version_output=$("$YTDLP_EXE" --version 2>&1)

  if [ -n "$version_output" ]; then
    echo "Hello from Vercel! The yt-dlp version is: $version_output"
  else
    http_response_code 500
    echo "Error: Failed to get yt-dlp version using the bundled executable."
  fi
}

#!/bin/bash

# build() runs at deploy time to prepare the environment.
build() {
  echo "--- Build Phase: Setting up a self-contained Python environment ---"

  # Define paths for our custom Python installation within the Vercel cache.
  local PYTHON_INSTALL_DIR="$IMPORT_CACHE/python_standalone"
  local BIN_DIR="$IMPORT_CACHE/bin"
  local PYTHON_EXE="$BIN_DIR/python"

  # 1. Download the most suitable pre-compiled Python binary.
  # This version is x86_64, for Linux with GNU libc, and is stripped for minimal size.
  # NOTE: The date in the filename is just a build timestamp from the list you provided.
  local python_url="https://github.com/astral-sh/python-build-standalone/releases/download/20250818/cpython-3.12.11+20250818-x86_64_v4-unknown-linux-gnu-install_only_stripped.tar.gz"

  echo "Downloading standalone Python from $python_url..."
  local python_tarball
  python_tarball="$(import_file "$python_url")"

  # 2. Extract Python into its dedicated directory.
  echo "Extracting Python..."
  mkdir -p "$PYTHON_INSTALL_DIR"
  tar -xzf "$python_tarball" -C "$PYTHON_INSTALL_DIR" --strip-components=1

  # 3. Create symlinks in a common 'bin' directory for easy access.
  echo "Creating symlinks for python and pip..."
  mkdir -p "$BIN_DIR"
  ln -sf "$PYTHON_INSTALL_DIR/bin/python3" "$PYTHON_EXE"
  ln -sf "$PYTHON_INSTALL_DIR/bin/pip3" "$BIN_DIR/pip"

  # 4. Use our new, cached Python to install yt-dlp.
  echo "Installing yt-dlp using the cached Python..."
  "$PYTHON_EXE" -m pip install --upgrade pip yt-dlp

  echo "--- Build complete. Standalone Python and yt-dlp are installed. ---"
}

# handler() runs on every incoming request.
handler() {
  http_response_header "Content-Type" "text/plain; charset=utf-8"

  # Define the path to our cached, self-contained Python executable.
  local PYTHON_EXE="$IMPORT_CACHE/bin/python"

  if [ ! -x "$PYTHON_EXE" ]; then
    http_response_code 500
    echo "Error: Standalone Python not found at '$PYTHON_EXE'."
    return
  fi

  # Use our cached Python to run the yt-dlp module. Redirect stderr to stdout.
  local version_output
  version_output=$("$PYTHON_EXE" -m yt_dlp --version 2>&1)

  if [ -n "$version_output" ]; then
    echo "Hello from Vercel! The yt-dlp version is: $version_output"
  else
    http_response_code 500
    echo "Error: Failed to get yt-dlp version using the cached Python."
  fi
}

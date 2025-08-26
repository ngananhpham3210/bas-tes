#!/bin/bash

# build() runs at deploy time. We install dependencies into the project directory
# so they are included in the final runtime package.
build() {
  echo "--- Build Phase: Installing a self-contained Python ---"

  # Define local paths relative to the project root.
  # These directories will be created and bundled with the function.
  local PYTHON_INSTALL_DIR="./.python-standalone"
  local BIN_DIR="./.bin"
  local PYTHON_EXE="$BIN_DIR/python"

  # 1. Download a portable, pre-compiled Python binary.
  local python_url="https://github.com/astral-sh/python-build-standalone/releases/download/20250818/cpython-3.12.11+20250818-x86_64_v4-unknown-linux-gnu-install_only_stripped.tar.gz"
  echo "Downloading standalone Python..."
  local python_tarball
  python_tarball="$(import_file "$python_url")"

  # 2. Extract Python into our local directory.
  echo "Extracting Python to $PYTHON_INSTALL_DIR..."
  mkdir -p "$PYTHON_INSTALL_DIR"
  tar -xzf "$python_tarball" -C "$PYTHON_INSTALL_DIR" --strip-components=1

  # 3. Create a local 'bin' directory and symlink the python executable.
  echo "Creating symlinks for python and pip..."
  mkdir -p "$BIN_DIR"
  # Use a relative path for the symlink target so it works in any environment.
  ln -sf "../$PYTHON_INSTALL_DIR/bin/python3" "$PYTHON_EXE"
  ln -sf "../$PYTHON_INSTALL_DIR/bin/pip3" "$BIN_DIR/pip"

  # 4. Use our new, local Python to install yt-dlp.
  echo "Installing yt-dlp using the local Python..."
  "$PYTHON_EXE" -m pip install --upgrade pip
  "$PYTHON_EXE" -m pip install yt-dlp

  echo "--- Build complete. Python and yt-dlp are bundled. ---"
}

# handler() runs on every incoming request.
handler() {
  http_response_header "Content-Type" "text/plain; charset=utf-8"

  # The path is now relative to the project root (/var/task).
  local PYTHON_EXE="./.bin/python"

  # Check if our bundled Python executable exists.
  if [ ! -x "$PYTHON_EXE" ]; then
    http_response_code 500
    echo "Error: Bundled Python not found at '$PYTHON_EXE'."
    return
  fi

  # Use our bundled Python to run the yt-dlp module.
  local version_output
  version_output=$("$PYTHON_EXE" -m yt_dlp --version 2>&1)

  if [ -n "$version_output" ]; then
    echo "Hello from Vercel! The yt-dlp version is: $version_output"
  else
    http_response_code 500
    echo "Error: Failed to get yt-dlp version using the bundled Python."
  fi
}

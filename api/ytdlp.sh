#!/bin/bash

# build() runs at deploy time to prepare the environment.
build() {
  echo "--- Installing yt-dlp using pip ---"

  # We install yt-dlp as a Python package instead of downloading a binary.
  # This avoids system library (glibc/libz) incompatibilities.
  # The --target flag installs the package into the current directory,
  # which becomes part of the serverless function's deployment package.
  python3 -m pip install --upgrade pip
  python3 -m pip install yt-dlp --target .

  echo "yt-dlp Python package installed successfully."
}

# handler() runs on every incoming request.
handler() {
  http_response_header "Content-Type" "text/plain; charset=utf-8"

  # We now execute yt-dlp as a Python module. This is the correct way
  # to run it when installed into a local directory.
  # We still redirect stderr to stdout (2>&1) to capture all output.
  local version_output
  version_output=$(python3 -m yt_dlp --version 2>&1)

  # Check if the command produced any output.
  if [ -n "$version_output" ]; then
    echo "Hello from Vercel! The yt-dlp version is: $version_output"
  else
    # This might happen if python3 isn't in the PATH or the module is not found.
    http_response_code 500
    echo "Error: Failed to execute 'python3 -m yt_dlp --version'."
  fi
}

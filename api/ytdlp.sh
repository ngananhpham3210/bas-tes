#!/bin/bash
set -euo pipefail

# This function runs during the Vercel build process.
function build() {
  echo "--- Python Build Step ---"

  PYTHON_URL="https://github.com/astral-sh/python-build-standalone/releases/download/20250818/cpython-3.13.7+20250818-aarch64-unknown-linux-gnu-install_only_stripped.tar.gz"
  FILENAME=$(basename "$PYTHON_URL")

  echo "Downloading Python from $PYTHON_URL..."
  curl --retry 3 -L -o "$FILENAME" "$PYTHON_URL"
  echo "Download complete."

  # Step 1: Extract the archive.
  echo "Extracting $FILENAME..."
  tar -xzf "$FILENAME"

  # Step 2: Create a new, clean directory.
  mkdir python_final

  # Step 3: Copy from the extracted dir to the final dir, resolving all symlinks.
  echo "Copying and resolving symlinks to create a clean build output..."
  cp -RL python/* python_final/

  # Step 4: Clean up the intermediate files.
  echo "Cleaning up intermediate files..."
  rm -rf python
  rm "$FILENAME"
# This function runs during the Vercel build process.
function build() {
  echo "--- Python Build Step ---"

  # --- FIX: Changed URL to the aarch64 (ARM) version ---
  PYTHON_URL="https://github.com/astral-sh/python-build-standalone/releases/download/20250818/cpython-3.12.11+20250818-aarch64-unknown-linux-gnu-install_only_stripped.tar.gz"
  # --------------------------------------------------------
  FILENAME=$(basename "$PYTHON_URL")

  echo "Downloading Python for ARM64 from $PYTHON_URL..."
  curl --retry 3 -L -o "$FILENAME" "$PYTHON_URL"
  echo "Download complete."

  # The rest of the build process remains the same
  echo "Extracting $FILENAME..."
  tar -xzf "$FILENAME"
  mkdir python_final
  echo "Copying and resolving symlinks..."
  cp -RL python/* python_final/
  echo "Cleaning up..."
  rm -rf python
  rm "$FILENAME"
  mv python_final python
  echo "Setting execute permissions..."
  chmod -R +x python/bin

  echo "--- Python Build Step Finished ---"
}

# This function runs for every incoming request.
# No changes are needed here.
function handler() {
  # Add the `python/bin` directory to the PATH.
  export PATH="$PWD/python/bin:$PATH"

  # Example: Check the Python version
  echo "Checking Python version:"
  python3 --version
  echo

  # Example: Run an inline Python script
  echo "Running an inline Python script:"
  python3 -c '
import sys
import platform

print(f"Hello from Python {sys.version}!")
print(f"Running on platform: {platform.system()} {platform.machine()}")
'
}

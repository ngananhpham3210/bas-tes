# FILE: api/index.sh
#!/bin/bash
set -euo pipefail

# This is your regular handler function.
# It can now use the Python binary installed during the build step.
function handler() {
  # Add the custom Python installation to the PATH
  export PATH="/var/task/.import-cache/python/bin:$PATH"
  
  echo "--- Running Python from standalone build ---"
  python --version
  
  echo "--- Executing an inline Python script ---"
  python -c 'import sys; print(f"Hello from Python {sys.version}!")'
}

# This `build` function is automatically called by the Vercel Runtime during the build process.
function build() {
  echo "----> Installing standalone Python 3.12..."
  
  # 1. Define the URL and the output filename
  PYTHON_URL="https://github.com/astral-sh/python-build-standalone/releases/download/20250818/cpython-3.12.11+20250818-x86_64_v4-unknown-linux-gnu-install_only_stripped.tar.gz"
  ARCHIVE_NAME="python.tar.gz"

  # 2. Download the archive
  #    -L follows redirects
  #    -o specifies the output file
  echo "      Downloading from $PYTHON_URL"
  curl -fLo "$ARCHIVE_NAME" "$PYTHON_URL"

  # 3. Create the destination directory inside the build output
  #    This will become /var/task/.import-cache/ at runtime.
  mkdir -p .import-cache

  # 4. Extract the archive into the target directory
  #    -C specifies the output directory
  echo "      Extracting archive to ./.import-cache/"
  tar -xzf "$ARCHIVE_NAME" -C ./.import-cache

  # 5. Clean up the downloaded archive to keep the Lambda small
  rm "$ARCHIVE_NAME"
  
  echo "----> Python installation complete."
}

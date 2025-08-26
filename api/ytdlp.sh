# api/python.sh

# build function remains the same
function build() {
  # ... (previous build logic) ...
  echo "--- Python Build Step ---"
  PYTHON_URL="https://github.com/astral-sh/python-build-standalone/releases/download/20250818/cpython-3.12.11+20250818-x86_64_v4-unknown-linux-gnu-install_only_stripped.tar.gz"
  FILENAME=$(basename "$PYTHON_URL")
  echo "Downloading Python from $PYTHON_URL..."
  curl --retry 3 -L -o "$FILENAME" "$PYTHON_URL"
  echo "Extracting $FILENAME..."
  tar -xzf "$FILENAME"
  mkdir python_final
  echo "Copying and resolving symlinks..."
  cp -RL python/* python_final/
  rm -rf python
  rm "$FILENAME"
  mv python_final python
  echo "--- Python Build Step Finished ---"
}

function handler() {
  # Add our Python to the PATH
  export PATH="$PWD/python/bin:$PATH"

  # Parse the request path from the event file
  local event_file="$1"
  local path
  path=$(jq -r '.path' < "$event_file")

  # Simple routing logic
  if [[ "$path" == "/api/python/version" ]]; then
    # Set the content type to JSON
    http_response_json

    # Get the python version and format it as JSON
    local version
    version=$(python3 --version)
    jq -n --arg ver "$version" '{"python_version": $ver}'

  elif [[ "$path" == "/api/python" ]]; then
    # Set the content type to plain text
    http_response_header "Content-Type" "text/plain"
    echo "Hello! Try visiting /api/python/version"

  else
    # Handle not found
    http_response_code 404
    echo "Not Found"
  fi
}

#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
INPUT_FILE="$REPO_ROOT/MANUSCRIPT.md"
COVER_FILE="$REPO_ROOT/cover.png"
OUTPUT_FILE="$REPO_ROOT/What It Feels Like To Be You.epub"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Required command not found: $1" >&2
    exit 1
  fi
}

require_file() {
  if [[ ! -f "$1" ]]; then
    echo "Required file not found: $1" >&2
    exit 1
  fi
}

require_command pandoc
require_file "$SCRIPT_DIR/create_manuscript.sh"
require_file "$COVER_FILE"

"$SCRIPT_DIR/create_manuscript.sh"
require_file "$INPUT_FILE"

pandoc "$INPUT_FILE" \
  --from gfm \
  --to epub3 \
  --toc \
  --toc-depth=2 \
  --split-level=2 \
  --metadata title="What It Feels Like to Be You" \
  --metadata author="Joshua Szepietowski" \
  --metadata lang="en-US" \
  --resource-path="$REPO_ROOT" \
  --epub-cover-image="$COVER_FILE" \
  --output "$OUTPUT_FILE"

echo "Wrote $OUTPUT_FILE"

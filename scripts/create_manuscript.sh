#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
CHAPTERS_DIR="$REPO_ROOT/chapters"
OUTPUT_FILE="$REPO_ROOT/MANUSCRIPT.md"
TEMP_FILE="$(mktemp "$REPO_ROOT/.manuscript.XXXXXX")"

trap 'rm -f "$TEMP_FILE"' EXIT

if [[ ! -d "$CHAPTERS_DIR" ]]; then
  echo "Chapters directory not found: $CHAPTERS_DIR" >&2
  exit 1
fi

shopt -s nullglob

act_dirs=("$CHAPTERS_DIR"/Act\ *)
if [[ ${#act_dirs[@]} -eq 0 ]]; then
  echo "No act directories found in $CHAPTERS_DIR" >&2
  exit 1
fi

{
  printf '# What It Feels Like to Be You\n\n'
  printf 'A Novel by Joshua Szepietowski\n'
} > "$TEMP_FILE"

chapter_count=0

for act_dir in "${act_dirs[@]}"; do
  chapter_files=("$act_dir"/Chapter\ *.md)
  if [[ ${#chapter_files[@]} -eq 0 ]]; then
    continue
  fi

  printf '\n## %s\n' "$(basename "$act_dir")" >> "$TEMP_FILE"

  for chapter_file in "${chapter_files[@]}"; do
    chapter_name="${chapter_file##*/}"
    chapter_name="${chapter_name%.md}"

    printf '\n### %s\n\n' "$chapter_name" >> "$TEMP_FILE"
    awk '
      NR == 1 && /^# / {
        skip_leading_blank = 1
        next
      }
      skip_leading_blank && $0 == "" {
        next
      }
      {
        skip_leading_blank = 0
        print
      }
    ' "$chapter_file" >> "$TEMP_FILE"

    chapter_count=$((chapter_count + 1))
  done
done

if [[ $chapter_count -eq 0 ]]; then
  echo "No chapter files found in $CHAPTERS_DIR" >&2
  exit 1
fi

printf '\n' >> "$TEMP_FILE"
mv "$TEMP_FILE" "$OUTPUT_FILE"
trap - EXIT

echo "Wrote $OUTPUT_FILE"
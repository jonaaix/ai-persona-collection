#!/usr/bin/env bash
# This script does NOT depend on git.
#
# ============
# USAGE:
# ============
# alias ai-copy="~/concat-copy.sh"
#
# ============
# COPY TO CLIPBOARD
# ============
# ai-copy
#
# ============
# CONCAT TO FILE in ~/Downloads
# ============
# ai-copy --to-file
# ai-copy --to-file my_component
#


set -euo pipefail

# Array of additional exclude patterns (regex, case-insensitive)
EXTRA_EXCLUDES=(
  ".env"
  "composer.lock"
  "package-lock.json"
  ".editorconfig"
  ".prettierrc"
  ".gitignore"
  "build-rembg"
  "resources"
  "release"
  "dist"
  "public"
  "assets"
  ".angular"
  "docs"
  "supervisord.log"
  ".sass-cache"
  "builds"
  "database.sqlite"
  "bootstrap/cache"
  # image files
  ".png"
  ".jpe?g"
  ".gif"
  ".bmp"
  ".svg"
  ".webp"
  ".tiff?"
  ".ico"
  # video files
  ".mp4"
  ".mov"
  ".avi"
  ".mkv"
  ".flv"
  ".wmv"
  ".webm"
  ".mpeg?"
  ".3gp"
)

# Common gitignore directories/patterns to exclude
COMMON_IGNORES=(
  ".git"
  "node_modules"
  "vendor"
  ".svn"
  ".hg"
  ".DS_Store"
  ".idea"
  ".vscode"
  "storage"
)

# Combine patterns into a single regex
EXCLUDE_PATTERN="$(printf "|%s" "${EXTRA_EXCLUDES[@]}" "${COMMON_IGNORES[@]}")"
EXCLUDE_PATTERN="${EXCLUDE_PATTERN:1}"

# Choose date command & format
if command -v gdate >/dev/null 2>&1; then
  DATE_CMD=gdate
  DATE_FMT='--iso-8601=seconds'
else
  DATE_CMD=date
  DATE_FMT='-u +%Y-%m-%dT%H:%M:%SZ'
fi

# Check arguments
OUTPUT_TO_FILE=false
OUTPUT_PATH=""

if [[ "${1:-}" == "--to-file" ]]; then
  OUTPUT_TO_FILE=true
  CUSTOM_NAME="${2:-}"
  if [[ -n "$CUSTOM_NAME" ]]; then
    OUTPUT_PATH="${HOME}/Downloads/${CUSTOM_NAME}.txt"
  else
    OUTPUT_PATH="${HOME}/Downloads/ai-copy-context.txt"
  fi

  if [[ -f "$OUTPUT_PATH" ]]; then
    rm -f "$OUTPUT_PATH"
  fi
else
  # Ensure pbcopy is available (macOS only)
  if ! command -v pbcopy >/dev/null; then
    echo "Error: pbcopy not found. This script requires macOS." >&2
    exit 1
  fi
fi

# Collect output
OUTPUT_CONTENT=$(
  {
    echo "Project snapshot: $(basename "$PWD")"
    echo "Generated on: $($DATE_CMD $DATE_FMT)"
    echo

    echo "== Directory Tree =="
    tree -I "$(IFS="|"; echo "${COMMON_IGNORES[*]}")" . | sed "1s|\.|$(basename "$PWD")|"
    echo

    echo "== File Contents =="
    find . -type f \
      | grep -Eiv "${EXCLUDE_PATTERN}" \
      | sort \
      | while IFS= read -r file; do
          echo
          echo "----- ${file#./} -----"
          cat "$file"
        done
  }
)

# Conditional output
if $OUTPUT_TO_FILE; then
  echo "$OUTPUT_CONTENT" > "$OUTPUT_PATH"
  echo "✅ Project snapshot saved to: $OUTPUT_PATH"
else
  echo "$OUTPUT_CONTENT" | pbcopy
  echo "✅ Project snapshot copied to clipboard"
fi

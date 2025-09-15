#!/usr/bin/env bash
# This script does NOT depend on git.
#
# ============
# USAGE:
# ============
# alias ai-copy="~/concat-copy.sh"
#
# Copy to clipboard (default):
#   ai-copy
#
# Concatenate to file in ~/Downloads:
#   ai-copy -f
#   ai-copy -f my_component
#   ai-copy --to-file
#   ai-copy --to-file my_component
#
# Tree only (clipboard or file with -f):
#   ai-copy -t
#   ai-copy --tree
#   ai-copy -t -f proj_dir
#

set -euo pipefail

# -----------------------------
# Config: excludes
# -----------------------------
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

EXCLUDE_PATTERN="$(printf "|%s" "${EXTRA_EXCLUDES[@]}" "${COMMON_IGNORES[@]}")"
EXCLUDE_PATTERN="${EXCLUDE_PATTERN:1}"

# -----------------------------
# Helpers
# -----------------------------
usage() {
  cat <<'EOF'
ai-copy [-t|--tree] [-f|--to-file [NAME]]

Options:
  -t, --tree          Output only the directory tree (no file contents).
  -f, --to-file NAME  Write output to ~/Downloads/NAME.txt (NAME optional).
  -h, --help          Show this help.

Examples:
  ai-copy
  ai-copy -f
  ai-copy -f my_component
  ai-copy -t
  ai-copy -t -f my_project_src
EOF
}

# Choose date command & format
if command -v gdate >/dev/null 2>&1; then
  DATE_CMD=gdate
  DATE_FMT='--iso-8601=seconds'
else
  DATE_CMD=date
  DATE_FMT='-u +%Y-%m-%dT%H:%M:%SZ'
fi

# -----------------------------
# Parse options
# -----------------------------
OUTPUT_TO_FILE=false
CUSTOM_NAME=""
TREE_ONLY=false

while [[ $# -gt 0 ]]; do
  case "${1:-}" in
    -f|--to-file)
      OUTPUT_TO_FILE=true
      if [[ -n "${2:-}" && ! "${2:-}" =~ ^- ]]; then
        CUSTOM_NAME="$2"
        shift
      fi
      ;;
    -t|--tree)
      TREE_ONLY=true
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    -*)
      echo "Error: Unknown option '$1'" >&2
      usage
      exit 2
      ;;
    *)
      echo "Error: Unexpected argument '$1'" >&2
      usage
      exit 2
      ;;
  esac
  shift
done

# -----------------------------
# Output target setup
# -----------------------------
OUTPUT_PATH=""
if $OUTPUT_TO_FILE; then
  if [[ -n "$CUSTOM_NAME" ]]; then
    OUTPUT_PATH="${HOME}/Downloads/${CUSTOM_NAME}.txt"
  else
    OUTPUT_PATH="${HOME}/Downloads/ai-copy-context.txt"
  fi
  if [[ -f "$OUTPUT_PATH" ]]; then
    rm -f "$OUTPUT_PATH"
  fi
else
  # Clipboard mode requires pbcopy (macOS)
  if ! command -v pbcopy >/dev/null; then
    echo "Error: pbcopy not found. This script requires macOS for clipboard mode." >&2
    echo "Tip: Use -f/--to-file to write to a file instead." >&2
    exit 1
  fi
fi

# -----------------------------
# Preconditions
# -----------------------------
if ! command -v tree >/dev/null 2>&1; then
  echo "Error: 'tree' command not found. Please install it (e.g., 'brew install tree')." >&2
  exit 1
fi

# -----------------------------
# Build output
# -----------------------------
PROJECT_NAME="$(basename "$PWD")"

make_tree() {
  # Use COMMON_IGNORES for tree's -I pattern
  local ignore
  ignore="$(IFS="|"; echo "${COMMON_IGNORES[*]}")"
  tree -I "$ignore" . | sed "1s|\.|$PROJECT_NAME|"
}

make_full() {
  # Full snapshot (tree + filtered file contents)
  {
    echo "Project snapshot: $PROJECT_NAME"
    echo "Generated on: $($DATE_CMD $DATE_FMT)"
    echo

    echo "== Directory Tree =="
    make_tree
    echo

    echo "== File Contents =="
    # shellcheck disable=SC2016
    find . -type f \
      | grep -Eiv "${EXCLUDE_PATTERN}" \
      | sort \
      | while IFS= read -r file; do
          echo
          echo "----- ${file#./} -----"
          cat "$file"
        done
  }
}

make_tree_only() {
  {
    echo "Project snapshot: $PROJECT_NAME"
    echo "Generated on: $($DATE_CMD $DATE_FMT)"
    echo
    echo "== Directory Tree =="
    make_tree
  }
}

if $TREE_ONLY; then
  OUTPUT_CONTENT="$(make_tree_only)"
else
  OUTPUT_CONTENT="$(make_full)"
fi

# -----------------------------
# Emit
# -----------------------------
if $OUTPUT_TO_FILE; then
  echo "$OUTPUT_CONTENT" > "$OUTPUT_PATH"
  echo "✅ Output saved to: $OUTPUT_PATH"
else
  echo "$OUTPUT_CONTENT" | pbcopy
  echo "✅ Output copied to clipboard"
fi

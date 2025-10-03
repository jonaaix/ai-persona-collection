#!/usr/bin/env bash
# This script does NOT depend on git.
#
# ============
# USAGE:
# ============
# alias ai-copy="~/concat-copy.sh"
# OR
# ln -s <PATH TO SCRIPT> /usr/local/bin/ai-copy
#
# Copy to clipboard (default):
#   ai-copy
#
# Concatenate to file in ~/Downloads:
#   ai-copy -f
#   ai-copy -f my_component
#
# Concatenate to file in a specific directory:
#   ai-copy -f my_api_context -p /tmp
#   ai-copy -f web_component -p .
#
# Output to console (stdout):
#   ai-copy -o | less
#   ai-copy -t -o
#
# Tree only (clipboard, file, or stdout):
#   ai-copy -t
#   ai-copy -t -f proj_dir
#   ai-copy -t -o
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
  # Ignore only top-level resources/ directory
  "^resources$"
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
  # Output usage information to stderr.
  cat <<'EOF' >&2
ai-copy [-t] [-o | -f [NAME] [-p DIR]]

Options:
  -t, --tree          Output only the directory tree.
  -f, --to-file NAME  Write output to a file (NAME optional).
  -p, --path DIR      Set output directory for -f (default: ~/Downloads).
  -o, --stdout        Write output to standard output.
  -h, --help          Show this help.

Examples:
  ai-copy
  ai-copy -f my_component
  ai-copy -f my_api -p /tmp
  ai-copy -t -o
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
OUTPUT_TO_STDOUT=false
CUSTOM_NAME=""
OUTPUT_DIR=""
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
    -p|--path)
      if [[ -n "${2:-}" && ! "${2:-}" =~ ^- ]]; then
        OUTPUT_DIR="$2"
        shift
      else
        echo "Error: --path requires a directory argument." >&2
        usage
        exit 2
      fi
      ;;
    -o|--stdout)
      OUTPUT_TO_STDOUT=true
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
      # This case is not expected to be reached with current logic
      echo "Error: Unexpected argument '$1'" >&2
      usage
      exit 2
      ;;
  esac
  shift
done

# -----------------------------
# Validate options
# -----------------------------
if $OUTPUT_TO_FILE && $OUTPUT_TO_STDOUT; then
  echo "Error: --to-file (-f) and --stdout (-o) cannot be used together." >&2
  usage
  exit 2
fi

if [[ -n "$OUTPUT_DIR" ]] && ! $OUTPUT_TO_FILE; then
    echo "Warning: --path (-p) is only used with --to-file (-f)." >&2
fi


# -----------------------------
# Output target setup
# -----------------------------
sanitize_filename() {
  local name="$1"
  # Replace slashes and spaces with underscore
  name="${name//\//_}"
  name="${name// /_}"
  # Replace any remaining illegal chars with underscore
  name="${name//[^a-zA-Z0-9._-]/_}"
  echo "$name"
}

OUTPUT_PATH=""
if $OUTPUT_TO_FILE; then
  TARGET_DIR="${OUTPUT_DIR:-${HOME}/Downloads}"
  mkdir -p "$TARGET_DIR"

  if [[ -n "$CUSTOM_NAME" ]]; then
    SAFE_NAME="$(sanitize_filename "$CUSTOM_NAME")"
    FILENAME="ai-copy-${SAFE_NAME}.txt"
  else
    FILENAME="ai-copy-context.txt"
  fi

  OUTPUT_PATH="${TARGET_DIR}/${FILENAME}"

  if [[ -f "$OUTPUT_PATH" ]]; then
    rm -f "$OUTPUT_PATH"
  fi
elif ! $OUTPUT_TO_STDOUT; then
  # Default is clipboard mode, requires pbcopy (macOS)
  if ! command -v pbcopy >/dev/null; then
    echo "Error: pbcopy not found. This script requires macOS for clipboard mode." >&2
    echo "Tip: Use -f/--to-file or -o/--stdout to output elsewhere." >&2
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
  # Version 3: Added explicit section markers for maximum parsing robustness.
  {
    echo "Project snapshot: $PROJECT_NAME"
    echo "Generated on: $($DATE_CMD $DATE_FMT)"
    echo

    # --- Directory Tree Section ---
    echo "########## START SECTION: Directory Tree ##########"
    make_tree
    echo
    echo "########## END SECTION: Directory Tree ##########"
    echo

    # --- File Contents Section ---
    echo "########## START SECTION: File Contents ##########"
    # shellcheck disable=SC2016
    find . -type f \
      | sed 's|^\./||' \
      | grep -Eiv -- "${EXCLUDE_PATTERN}" \
      | sort \
      | while IFS= read -r file; do
          # Use distinct, unambiguous markers for file start and end
          echo
          echo "########## START FILE: ${file#./} ##########"
          cat -- "$file"
          echo # Ensures a newline exists before the end marker
          echo "########## END FILE: ${file#./} ##########"
        done
    echo # Ensures a final newline before the section end
    echo "########## END SECTION: File Contents ##########"
  }
}

make_tree_only() {
  {
    echo "Project snapshot: $PROJECT_NAME"
    echo "Generated on: $($DATE_CMD $DATE_FMT)"
    echo
    # --- Directory Tree Section ---
    echo "########## START SECTION: Directory Tree ##########"
    echo
    make_tree
    echo
    echo "########## END SECTION: Directory Tree ##########"
    echo
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
if $OUTPUT_TO_STDOUT; then
  echo "$OUTPUT_CONTENT"
elif $OUTPUT_TO_FILE; then
  echo "$OUTPUT_CONTENT" > "$OUTPUT_PATH"
  echo "✅ Output saved to: $OUTPUT_PATH" >&2
else
  # Default to clipboard
  echo "$OUTPUT_CONTENT" | pbcopy
  echo "✅ Output copied to clipboard" >&2
fi
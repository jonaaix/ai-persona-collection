#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# AI Copy Wrapper
# Delegates logic to ai-copy.py located in the same directory.
#
# USAGE:
#   ai-copy
#   ai-copy -f [NAME] [-p DIR]
#   ai-copy -t
#   ai-copy -o
# ==============================================================================

# 1. Resolve the absolute directory of this script.
#    We use Python here because 'readlink -f' is not available on standard macOS,
#    and we need to resolve symlinks if the user linked this script to /usr/local/bin.
SCRIPT_DIR="$(python3 -c 'import os, sys; print(os.path.dirname(os.path.realpath(sys.argv[1])))' "${BASH_SOURCE[0]}")"

PYTHON_SCRIPT="${SCRIPT_DIR}/ai-copy.py"

# 2. Verify core logic existence
if [[ ! -f "$PYTHON_SCRIPT" ]]; then
  echo "Error: Core logic file 'ai-copy.py' not found." >&2
  echo "Expected location: $PYTHON_SCRIPT" >&2
  exit 1
fi

# 3. Hand over execution to Python
#    Using 'exec' replaces the shell process with the python process.
exec python3 "$PYTHON_SCRIPT" "$@"
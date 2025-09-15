#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
AI Companion Output Interpreter (Interactive & Secure)
Version 2.0

This script runs continuously, waiting for structured command blocks to be
pasted into the terminal. It applies file operations safely within the project
directory, preventing any changes outside of it or within the .git folder.

Usage:
1. Run this script from the root of your project: `python apply_changes_interactive.py`
2. The script will prompt you to paste content.
3. Copy the entire multi-line output from the AI Companion.
4. Paste it into the terminal.
5. Press Ctrl+D (on macOS/Linux) or Ctrl+Z then Enter (on Windows) to submit.
6. The script will process the commands and wait for the next input.
"""

import re
import subprocess
import sys
from pathlib import Path


def is_path_safe(path_to_check: Path, project_root: Path) -> bool:
    """
    Ensures that the path is safely within the project root and not in .git.
    This is a critical security sandbox.
    """
    try:
        # Resolve the path to its absolute, canonical form.
        # This prevents tricks with symlinks or ".." components.
        resolved_path = (project_root / path_to_check).resolve()
        
        # 1. THE CRITICAL CHECK: Is the resolved path still inside the project root?
        # Python 3.9+ has `is_relative_to`, which is perfect for this.
        if not resolved_path.is_relative_to(project_root):
            return False
            
        # 2. THE .GIT CHECK: Is '.git' a component of the path?
        if '.git' in resolved_path.parts:
            return False
            
    except Exception:
        # Any resolution error means the path is suspicious or invalid.
        return False
        
    return True


def handle_create_or_replace(file_path: Path, content: str, operation: str) -> None:
    """Handles file creation or replacement."""
    print(f"[{operation.upper()}] Processing '{file_path}'...")
    try:
        file_path.parent.mkdir(parents=True, exist_ok=True)
        file_path.write_text(content, encoding='utf-8')
        print(f"  -> SUCCESS: Wrote {len(content.encode('utf-8'))} bytes.")
    except IOError as e:
        print(f"  -> ERROR: Could not write to file: {e}", file=sys.stderr)


def handle_delete(file_path: Path) -> None:
    """Handles file deletion."""
    print(f"[DELETE] Processing '{file_path}'...")
    if not file_path.exists():
        print(f"  -> INFO: File not found, skipping.")
        return
    try:
        file_path.unlink()
        print(f"  -> SUCCESS: File deleted.")
    except IOError as e:
        print(f"  -> ERROR: Could not delete file: {e}", file=sys.stderr)


def handle_patch(file_path: Path, patch_content: str) -> None:
    """Handles applying a patch to an existing file."""
    print(f"[PATCH] Processing '{file_path}'...")
    if not file_path.exists():
        print(f"  -> ERROR: Cannot patch non-existent file.", file=sys.stderr)
        return

    try:
        result = subprocess.run(
            ['patch', '--no-backup-if-mismatch', str(file_path)],
            input=patch_content, text=True, check=True, capture_output=True
        )
        print(f"  -> SUCCESS: Patch applied.")
        if result.stdout:
            print("     " + result.stdout.strip().replace('\n', '\n     '))
    except FileNotFoundError:
        print("  -> ERROR: The 'patch' command was not found.", file=sys.stderr)
    except subprocess.CalledProcessError as e:
        print(f"  -> ERROR: Patch could not be applied cleanly.", file=sys.stderr)
        print("     Reason: The local file has likely changed.", file=sys.stderr)
        print("     Details: " + e.stderr.strip().replace('\n', '\n     '), file=sys.stderr)


def process_input(content: str, project_root: Path) -> None:
    """Parses and executes commands from the input string."""
    command_pattern = re.compile(
        r"--- (START-FILE|START-PATCH|START-REPLACE-FILE|DELETE-FILE): (.+?) ---\n?"
        r"((?:.|\n)*?(?=--- END-))?"
        r"(?:--- END-(?:FILE|PATCH|REPLACE-FILE): \2 ---\n?)?",
        re.MULTILINE
    )

    matches = list(command_pattern.finditer(content))
    if not matches:
        print("No valid command blocks found in the provided input.")
        return

    print(f"\nFound {len(matches)} command(s). Starting processing...")
    for match in matches:
        command, path_str, content = match.groups()
        file_path_relative = Path(path_str.strip())

        # --- SECURITY SANDBOX CHECK ---
        if not is_path_safe(file_path_relative, project_root):
            print(f"[SECURITY] DANGEROUS PATH DETECTED! Skipping operation for '{file_path_relative}'.", file=sys.stderr)
            print(f"           Reason: Path is outside the project directory or targets the .git folder.", file=sys.stderr)
            continue
        
        content = content.strip() if content else ""
        
        if command == 'START-FILE':
            handle_create_or_replace(file_path_relative, content, "CREATE")
        elif command == 'START-REPLACE-FILE':
            handle_create_or_replace(file_path_relative, content, "REPLACE")
        elif command == 'START-PATCH':
            handle_patch(file_path_relative, content)
        elif command == 'DELETE-FILE':
            handle_delete(file_path_relative)
    
    print(f"\nProcessing complete.")


def main() -> None:
    """Main execution loop."""
    print("--- AI Companion Output Interpreter (Interactive & Secure) v2.0 ---")
    project_root = Path.cwd().resolve()
    print(f"Project root locked to: {project_root}")
    print("-" * 60)

    while True:
        print("\nReady for input. Paste content below, then press Ctrl+D (or Ctrl+Z+Enter).")
        try:
            input_content = sys.stdin.read()
            if input_content:
                process_input(input_content, project_root)
        except KeyboardInterrupt:
            print("\nExiting.")
            break
        except EOFError:
            print("\nExiting.")
            break


if __name__ == "__main__":
    main()
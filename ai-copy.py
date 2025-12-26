#!/usr/bin/env python3
"""
AI Context Exporter (Core Logic)
Handles file traversing, filtering, and content aggregation.
"""

import os
import sys
import argparse
import subprocess
import shutil
import re
from datetime import datetime, timezone
from pathlib import Path

# --- CONFIGURATION -----------------------------------------------------------

# Extensions to ignore strictly at the end of the filename
IGNORED_EXTENSIONS = {
    ".log", ".env", ".lock", ".zip", ".tar", ".gz", ".rar",
    ".png", ".jpg", ".jpeg", ".gif", ".bmp", ".svg", ".webp", ".tiff", ".tif", ".ico",
    ".mp4", ".mov", ".avi", ".mkv", ".flv", ".wmv", ".webm", ".3gp",
    ".pyc", ".sqlite", ".sass-cache", ".map", ".min.js", ".min.css"
}

# Exact directory names to skip (prevents traversing)
IGNORED_DIRS = {
    ".git", "node_modules", "__pycache__", "vendor", ".svn", ".hg",
    ".DS_Store", ".idea", ".vscode", "storage", "dist", "build",
    "public", "tmp", "assets", ".angular", "docs", "builds",
    "bootstrap/cache", "release", "coverage", ".pytest_cache"
}

# Exact filenames to ignore
IGNORED_FILENAMES = {
    "composer.lock", "package-lock.json", "yarn.lock", "pnpm-lock.yaml",
    ".editorconfig", ".prettierrc", ".gitignore", ".gitattributes",
    "supervisord.log", "database.sqlite", ".DS_Store"
}

# Regex patterns for special cases
IGNORED_PATTERNS = [
    re.compile(r"^resources$"),   # Matches top-level resources folder if needed
    re.compile(r"^build-rembg"),
]

# --- LOGIC -------------------------------------------------------------------

class ContextExporter:
    def __init__(self, tree_only, output_stdout, to_file, custom_name, output_path):
        self.tree_only = tree_only
        self.output_stdout = output_stdout
        self.to_file = to_file
        self.custom_name = custom_name
        self.output_dir = output_path if output_path else str(Path.home() / "Downloads")
        self.project_name = Path.cwd().name
        self._check_dependencies()

    def _check_dependencies(self):
        if not shutil.which("tree"):
            print("Error: 'tree' command not found. Please install it (e.g., 'brew install tree').", file=sys.stderr)
            sys.exit(1)

    def _sanitize_filename(self, name):
        name = name.replace("/", "_").replace(" ", "_")
        return re.sub(r"[^a-zA-Z0-9._-]", "_", name)

    def _should_ignore(self, path):
        # 1. Check directories in path
        for part in path.parts:
            if part in IGNORED_DIRS:
                return True

        name = path.name

        # 2. Check exact filename
        if name in IGNORED_FILENAMES:
            return True

        # 3. Check extension (robust logic: ends_with)
        if any(name.lower().endswith(ext) for ext in IGNORED_EXTENSIONS):
            return True

        # 4. Regex fallback
        for pattern in IGNORED_PATTERNS:
            if pattern.search(name):
                return True
        return False

    def _get_tree_output(self):
        ignore_pattern = "|".join(IGNORED_DIRS.union({".git"}))
        try:
            # -I pattern excludes directories from tree view
            result = subprocess.run(
                ["tree", "-I", ignore_pattern, "."],
                capture_output=True, text=True, check=True
            )
            output = result.stdout
            lines = output.splitlines()
            if lines and lines[0] == ".":
                lines[0] = self.project_name
            return "\n".join(lines)
        except subprocess.CalledProcessError as e:
            return f"Error running tree: {e}"

    def _generate_content(self):
        now = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
        buffer = []
        buffer.append(f"Project snapshot: {self.project_name}")
        buffer.append(f"Generated on: {now}")
        buffer.append("")
        
        # Directory Tree
        buffer.append("########## START SECTION: Directory Tree ##########")
        buffer.append(self._get_tree_output())
        buffer.append("")
        buffer.append("########## END SECTION: Directory Tree ##########")
        buffer.append("")

        if self.tree_only:
            return "\n".join(buffer)

        # File Contents
        buffer.append("########## START SECTION: File Contents ##########")
        
        file_paths = []
        for root, dirs, files in os.walk("."):
            # Prune ignored directories in-place
            dirs[:] = [d for d in dirs if d not in IGNORED_DIRS and not d.startswith(".")]
            
            for file in files:
                path = Path(root) / file
                if not self._should_ignore(path):
                    file_paths.append(path)

        # Sort for deterministic output
        file_paths.sort(key=lambda p: str(p))

        for path in file_paths:
            clean_path = str(path).lstrip("./")
            try:
                # errors='ignore' skips binary chars instead of crashing
                with open(path, 'r', encoding='utf-8', errors='ignore') as f:
                    content = f.read()
                
                buffer.append("")
                buffer.append(f"########## START FILE: {clean_path} ##########")
                buffer.append(content)
                buffer.append("")
                buffer.append(f"########## END FILE: {clean_path} ##########")
            except Exception:
                continue # Skip files we can't read

        buffer.append("")
        buffer.append("########## END SECTION: File Contents ##########")
        return "\n".join(buffer)

    def execute(self):
        content = self._generate_content()

        if self.output_stdout:
            print(content)
        elif self.to_file:
            safe_name = "context"
            if self.custom_name:
                safe_name = self._sanitize_filename(self.custom_name)
            
            filename = f"ai-copy-{safe_name}.txt"
            target_path = Path(self.output_dir) / filename
            target_path.parent.mkdir(parents=True, exist_ok=True)
            
            with open(target_path, "w", encoding="utf-8") as f:
                f.write(content)
            print(f"✅ Output saved to: {target_path}", file=sys.stderr)
        else:
            # Clipboard (macOS check)
            if not shutil.which("pbcopy"):
                print("Error: pbcopy not found. Use -f or -o on non-macOS systems.", file=sys.stderr)
                sys.exit(1)
            
            process = subprocess.Popen(['pbcopy'], stdin=subprocess.PIPE)
            process.communicate(input=content.encode('utf-8'))
            print("✅ Output copied to clipboard", file=sys.stderr)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument("-t", "--tree", action="store_true")
    parser.add_argument("-f", "--to-file", nargs="?", const="", metavar="NAME")
    parser.add_argument("-p", "--path", metavar="DIR")
    parser.add_argument("-o", "--stdout", action="store_true")
    parser.add_argument("-h", "--help", action="store_true")

    args, unknown = parser.parse_known_args()

    if args.help:
        print("""
ai-copy [-t] [-o | -f [NAME] [-p DIR]]

Options:
  -t, --tree          Output only the directory tree.
  -f, --to-file NAME  Write output to a file (NAME optional).
  -p, --path DIR      Set output directory for -f (default: ~/Downloads).
  -o, --stdout        Write output to standard output.
  -h, --help          Show this help.
        """, file=sys.stderr)
        sys.exit(0)

    # Basic Validation logic
    if args.to_file is not None and args.stdout:
        print("Error: --to-file (-f) and --stdout (-o) cannot be used together.", file=sys.stderr)
        sys.exit(2)

    exporter = ContextExporter(
        tree_only=args.tree,
        output_stdout=args.stdout,
        to_file=(args.to_file is not None),
        custom_name=args.to_file,
        output_path=args.path
    )
    exporter.execute()
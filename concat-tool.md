### Tool Specification: `ai-copy`

This document provides instructions on how to use the `ai-copy` tool for code and project analysis.

**Purpose of the Tool**
The `ai-copy` tool captures the directory structure and relevant file contents of a project and outputs them as a single, consolidated text stream.

**Rules of Engagement**

1.  **Use Standard Output**: You must **always** use the `-o` (`--stdout`) option. This ensures that all analysis is streamed directly to you as text and that no files are created on the system. This is a mandatory requirement.

2.  **Adjust Analysis Scope**: Execute the command in the relevant directory.

    -   For a **full project analysis**, run it in the project's root directory.
    -   To focus on a **specific part** (e.g., a component or module), first change into the corresponding subdirectory.

3.  **Structure-Only Analysis (Optional)**: If you only need a quick overview of the directory structure without seeing any file contents, you can additionally use the `-t` (`--tree`) option.

**Command Examples**

-   **Full analysis of the current directory:**
    ```shell
    ai-copy -o
    ```
-   **Display only the tree structure of the current directory:**
    ```shell
    ai-copy -t -o
    ```
-   **Analysis of a specific subdirectory (e.g., `src/api`):**
    ```shell
    cd src/api && ai-copy -o
    ```

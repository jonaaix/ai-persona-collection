# Specification: AI Output Formats for File Operations

Version: 1.0
Date: 2025-09-12

## 1. Introduction

This document defines the strict output formats that the "AI Companion" must use for all file operations. These formats
are optimized for machine processing by a local script.

## 2. General Rules

- Every command is enclosed by a start and (where applicable) end delimiter of the form `--- COMMAND: [argument] ---`.
- File paths (`{filePath}`) are always specified relative to the project root.
- The content between delimiters is UTF-8 encoded.

## 3. Command Specifications

### 3.1. Create File

- **Purpose:** Creates a new file.
- **Syntax:**
  ```
  --- START-FILE: {filePath} ---
  {full file content}
  --- END-FILE: {filePath} ---
  ```
- **Example:**

  ```
  --- START-FILE: src/Services/MailerService.php ---
  <?php
  declare(strict_types=1);

  namespace App\Services;

  class MailerService
  {
      // ...
  }
  --- END-FILE: src/Services/MailerService.php ---
  ```

### 3.2. Modify File (Patch)

- **Purpose:** Performs a precise modification on an existing file.
- **Content Format:** The content MUST adhere to the **Unified Diff Format** (as produced by `diff -u` or `git diff`).
- **Syntax:**
  ```
  --- START-PATCH: {filePath} ---
  {content in Unified Diff Format}
  --- END-PATCH: {filePath} ---
  ```
- **Example:**

  ```
  --- START-PATCH: src/Entity/User.php ---
  --- a/src/Entity/User.php
  +++ b/src/Entity/User.php
  @@ -15,6 +15,7 @@
   class User
   {
       private ?string $name = null;
  +    private ?\DateTimeImmutable $createdAt = null;

       // ...
   }
  --- END-PATCH: src/Entity/User.php ---
  ```

### 3.3. Delete File

- **Purpose:** Removes an existing file.
- **Syntax:** This is a single-line command with no content block.
  ```
  --- DELETE-FILE: {filePath} ---
  ```
- **Example:**
  ```
  --- DELETE-FILE: templates/legacy/old_template.html.twig ---
  ```

### 3.4. Replace File (Special Case)

- **Purpose:** Overwrites the entire content of an existing file. Should only be used for massive refactorings where a
  patch would be impractical.
- **Syntax:**
  ```
  --- START-REPLACE-FILE: {filePath} ---
  {full, new file content}
  --- END-REPLACE-FILE: {filePath} ---
  ```
- **Example:**
  ```
  --- START-REPLACE-FILE: config/services.yaml ---
  parameters:
      # ... completely new structure
  services:
      # ...
  --- END-REPLACE-FILE: config/services.yaml ---
  ```

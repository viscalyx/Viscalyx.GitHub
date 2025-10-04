---
description: Guidelines for writing and maintaining Markdown documentation.
applyTo: "**/*.md"
---

# Markdown Style Guidelines

- Wrap lines at word boundaries when over 80 characters (except tables/code blocks)
  - For tables/code blocks exceeding 80 characters, disable `MD013` rule using inline-comment
- Use 2 spaces for indentation
- Use '1.' for all items in ordered lists (1/1/1 numbering style)
- Empty lines required before/after code blocks and headings (except before line 1)
- Escape backslashes in file paths only (not in code blocks)
- Code blocks must specify language identifiers

## Text Formatting

- Parameters: **bold**
- Values/literals: `inline code`
- Resource/module/product names: _italic_
- Commands/files/paths: `inline code`

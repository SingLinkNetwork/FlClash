# Backup ZIP Path Traversal Design

## Goal

Prevent a backup archive from creating or overwriting files outside FlClash's
temporary restore directory, while preserving restoration of valid backups.

## Decision

Validate every archive entry before creating the restore directory or opening
an output stream. An entry is rejected when its ZIP name is empty, absolute,
uses a Windows drive prefix or backslash separator, resolves to the restore
directory itself, or resolves outside that directory after normalization.

The validator returns the final absolute output path only for a safe relative
file. `restoreBackupArchive` first validates the complete archive, then writes
the already-validated entries. A single unsafe entry therefore fails the whole
restore before any archive entry is written.

## Error Handling

Unsafe archive names raise `FileSystemException` naming the invalid entry. The
input ZIP stream is still closed in `finally`; callers retain their existing
restore-directory cleanup. Ordinary write failures retain the existing error
behaviour and also close each output stream.

## Compatibility

Normal relative entries such as `database.sqlite`, `config.json`,
`profiles/123.yaml`, and `scripts/456.js` remain valid. No backup format,
database migration, UI, or platform-specific code changes.

## Verification

Regression tests create ZIP archives in a temporary directory and prove that:

1. a `../escaped.txt` entry fails without creating the sibling file;
2. an absolute entry fails without writing any valid entry that appears before
   it in the archive;
3. a nested valid entry restores with its original content; and
4. the existing stream-release test continues to pass.

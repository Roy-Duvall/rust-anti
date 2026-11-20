# Symbolic Link Creator Rust Conversion Design

**Status:** Proposed

## Intent and why

Replace `scripts/SymbolicLinker_V2_8.ps1` with a native Windows Rust application that preserves the V2.8 user workflow and safety behavior while removing the PowerShell/WinForms runtime.

## Goals

- Provide a native GUI for selecting one source file or source directory and a destination directory.
- Preserve the nine editable path templates and `%APPDATA%\SymbolicLinkCreator\templates.json` persistence.
- Support top-level file linking, recursive file and directory linking, overwrite of existing symbolic links, and skipping of regular files or existing links when overwrite is disabled.
- Keep source contents unchanged and never replace a regular file or directory at the destination.
- Return explicit success, skipped, and failure counts/results.
- Handle paths with spaces and Windows separators.
- Add automated tests for path mapping, existing-link detection, template serialization, and operation planning.

## Non-goals

- No Linux or macOS port.
- No hard links, junctions, directory mounts, or batch file from a file list.
- No automatic elevation or silent overwriting.
- No removal of existing PowerShell scripts or binaries during the first conversion.
- No changes to the destination directory unless the operation explicitly creates links or mirror directories.

## Anti-goals

The app must not claim success for partial or failed operations, overwrite a regular file/directory, remove a destination before confirming that it is a reparse point, or leave template data corrupt after a JSON read/write failure.

## Constraints

- Target platform: Windows 11.
- User interface: native Rust desktop GUI.
- Framework: `eframe`/`egui`.
- Native dialogs: `rfd`.
- JSON: `serde` and `serde_json`.
- Symlinks: Rust `std::os::windows::fs::symlink_file` / `symlink_dir`, with destination reparse-point checks through the Windows filesystem APIs.
- App state location: `%APPDATA%\SymbolicLinkCreator\templates.json`, with UTF-8 JSON and exactly nine template entries.
- Startup behavior: the app may create symbolic links only when Windows elevation or Developer Mode permits it. It must report permission failure without claiming success.
- Existing destination parent/recursive directories must be handled within the destination tree; the app must not traverse symlinks unexpectedly.
- Source and destination trees must not overlap. In particular, reject a destination inside the source tree and reject source/destination mappings that can mutate the source contents.

## Approaches considered

1. **Native eframe/egui GUI (selected).** This is a Rust-native Windows application with a compact dependency footprint and direct access to Rust Windows filesystem APIs. It is the smallest fit for the existing script's behavior.
2. **Tauri GUI.** This would provide web-native layout and tooling but requires a separate frontend stack and a larger packaging/runtime surface. It does not materially improve this utility.
3. **CLI core only.** This would reduce UI work but would lose the V2.8 GUI and template workflow requested by the conversion.

## Architecture

Create a Cargo package with one clear GUI entry point and a platform-independent core module:

- `src/main.rs`: application entry point, startup privilege check, egui app state, controls, previews, dialogs, and user feedback.
- `src/config.rs`: load/save exactly nine templates at `%APPDATA%\SymbolicLinkCreator\templates.json`; malformed JSON falls back to nine empty templates and reports a load error.
- `src/linker.rs`: validation and operation planning/execution for file and directory sources.
- `src/tests` (inline unit tests or `tests/` integration tests): filesystem and planning tests.

The GUI owns UI state and calls a linker API rather than embedding filesystem mutations in event handlers. A planning step maps source-relative paths to destination paths and identifies collisions before mutation. Execution uses an operation plan so preview text and the final summary match the operation.

## Core API

The implementation will expose these Rust interfaces:

- `pub fn templates_path() -> Result<PathBuf, AppError>`
- `pub fn load_templates() -> Result<[String; 9], AppError>`
- `pub fn save_templates(templates: &[String; 9]) -> Result<(), AppError>`
- `pub fn plan_links(source: &Path, destination: &Path, mode: LinkMode, overwrite: bool) -> Result<LinkPlan, AppError>`
- `pub fn execute_plan(plan: &LinkPlan) -> LinkSummary`
- `pub fn validate_source(source: &Path, mode: LinkMode) -> Result<(), AppError>`
- `pub fn validate_destination(destination: &Path) -> Result<(), AppError>`

`LinkMode` is `File` or `Directory { recursive: bool }`. `LinkPlan` contains ordered `CreateDirectory`, `CreateFileLink`, and `CreateDirectoryLink` actions only for the selected source/destination mapping. `LinkSummary` contains created directory, created file-link, skipped, and failed counts plus per-action error text.

Plan entries must include `Create`, `Skip`, and `Conflict` states where a planned destination collision is known. A conflict must not be executed as an overwrite.

## GUI behavior

- Default source mode: Directory.
- Source controls: file/directory dropdown, editable path, browse button.
- Destination controls: editable directory path and browse button.
- Nine template rows: editable path, folder browse, copy source/destination, and send to source/destination.
- Options: recurse checkbox enabled for directory mode, overwrite checkbox disabled for file/destination conflicts as a safety rule.
- Preview: explains the current mode and source/destination mapping; updates on source, destination, mode, or recurse changes.
- Create: plans and validates first, then executes and shows a summary.
- Close: save templates once; save failures produce a visible error without creating any links.
- Existing regular destination items: always skip and report a conflict.
- Existing reparse points: replace only when overwrite is enabled and only after confirming it is a symbolic link, never a junction or other reparse point.
- Recheck destination state immediately before every mutation to reduce regular-file deletion and link replacement races.

## Link operation behavior

For file mode, the destination name is `source.file_name()` and a file symlink is created.

For directory top-level mode, only immediate files under the source are linked into the destination using their file names.

For directory recursive mode, source directories are mirrored under the destination. Each source file becomes a file symlink at the matching relative destination path. The app does not create symlinks for source directories unless a separate directory-link action is required; mirroring directories is the V2.8 behavior.

Directory creation in a recursive operation is limited to missing destination directories. Existing regular directories are reused. Existing files where a directory would be needed are conflicts, not overwritten.

An existing reparse point where a mirrored directory is required is a conflict. Recursive traversal must not follow source-directory reparse points.

## Permission and error behavior

The app will detect the current Windows identity at startup and show a blocking "Administrator rights required" message when not elevated, matching V2.8. If Windows Developer Mode is intended to supersede elevation, that is a separate confirmation and is not included in this design. Symlink creation failures are collected as failures rather than counted as success.

The app will not run a PowerShell script or call `cmd.exe` for filesystem operations.

Template writes will be atomic: write the UTF-8 JSON payload to a sibling temporary file, flush it, and rename it over `templates.json`. A failed write will leave the prior template file intact when the filesystem allows it and will show a save error.

## Packaging

Add a `Cargo.toml`, `Cargo.lock`, Rust source under `src/`, tests under `tests/`, and Rust entries in `.gitignore` (`/target/`). Keep the existing PowerShell files and `bin/` executable intact until parity verification.

Add a Windows build command in the README:

```powers
cargo build --release
```

The initial executable will be emitted at `target\release\symbolic-link-maker.exe`.

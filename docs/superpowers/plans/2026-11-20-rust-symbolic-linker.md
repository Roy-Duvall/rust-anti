# Rust Symbolic Link Creator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert V2.8 into a native Windows Rust application while preserving its GUI workflow and link safety.

**Architecture:** Split a small egui desktop shell from a platform-independent link planner/executor. Persist nine templates as JSON in APPDATA, plan all destination mutations before execution, and report per-action failures without false success.

**Tech Stack:** Rust stable, Cargo, eframe/egui, rfd, serde/serde_json, and Windows filesystem APIs.

**Spec:** `docs/superpowers/specs/2026-11-20-symbolic-linker-rust-design.md`

## Global Constraints

- Target Windows 11 with Rust stable.
- Preserve V2.8: file mode, top-level directory mode, recursive directory mode, nine templates, overwrite checkbox, preview, and close-time save.
- The source must exist and the destination directory must already exist.
- Existing regular files/directories must never be overwritten or deleted.
- Existing symbolic links may be replaced only when overwrite is enabled.
- Never claim success for partial or failed operations.
- Keep existing PowerShell and binary files intact until parity verification.

## Review Focus

- A source/destination overlap must be rejected by `validate_paths()`; test `destination_inside_source_is_rejected`.
- A malformed or wrong-sized template file must become exactly nine empty entries and be reported; test `load_templates_rejects_malformed_json`.
- Dangling symbolic links and junctions must not be replaced as ordinary destination items; test `execute_plan_never_removes_regular_or_junction_destination`.
- A destination that changes after planning must be rechecked and skipped/conflicted; test `execute_plan_rechecks_destination`.
- Permission failures must count as failures and appear in the summary; test `execute_plan_records_permission_error`.

---

### Task 1: Add the Cargo package and template persistence

**Files:**
- Create: `Cargo.toml`
- Create: `src/main.rs`
- Create: `src/config.rs`
- Modify: `.gitignore`
- Test: `src/config.rs`

**Interfaces:**
- Consumes: `APPDATA` environment variable on Windows.
- Produces: `pub fn templates_path() -> Result<PathBuf, AppError>`, `pub fn load_templates() -> Result<[String; 9], AppError>`, `pub fn save_templates(templates: &[String; 9]) -> Result<(), AppError>`.

- [ ] **Step 1: Write failing tests in `src/config.rs`**

Add tests named `templates_path_uses_symbolic_link_creator_directory`, `load_templates_defaults_for_missing_file`, `load_templates_accepts_exactly_nine_entries`, `load_templates_rejects_wrong_size`, and `save_templates_writes_nine_utf8_entries`.

Assert `load_templates()` returns nine empty strings when the file is missing or invalid and `save_templates()` writes valid JSON containing exactly nine entries.

- [ ] **Step 2: Run `cargo test config::tests`**

Expected: FAIL because `Cargo.toml` and `src/config.rs` do not exist.

- [ ] **Step 3: Scaffold the package**

Create `Cargo.toml`, `src/main.rs`, `src/config.rs`, and add `/target/` to `.gitignore`. Add `eframe`, `rfd`, `serde`, `serde_json`, and `windows-sys` dependencies.

Do not implement GUI behavior in this task; `main.rs` must start an empty native egui window titled `Symbolic Link Creator v2.8`.

- [ ] **Step 4: Implement the template persistence API**

Use `%APPDATA%\SymbolicLinkCreator\templates.json`. For malformed JSON or a wrong entry count, log through `AppError` and return nine empty strings. For save, atomically write a sibling temporary file and rename it over the destination.

- [ ] **Step 5: Run `cargo test config::tests`**

Expected: PASS.

- [ ] **Step 6: Commit**

```powershell
git add Cargo.toml Cargo.lock src/main.rs src/config.rs .gitignore
git commit -m "feat: scaffold Rust app and template persistence"
```

### Task 2: Implement and test link planning

**Files:**
- Create: `src/linker.rs`
- Test: `src/linker.rs`

**Interfaces:**
- Consumes: `AppError` and `std::path::{Path, PathBuf}`.
- Produces: `pub enum LinkMode { File, Directory { recursive: bool } }`, `pub enum PlannedAction { CreateDirectory, CreateFileLink, CreateDirectoryLink }`, `pub struct LinkPlan`, `pub struct LinkSummary`, `pub fn validate_source(source: &Path, mode: LinkMode) -> Result<(), AppError>`, `pub fn validate_destination(destination: &Path) -> Result<(), AppError>`, `pub fn validate_paths(source: &Path, destination: &Path) -> Result<(), AppError>`, and `pub fn plan_links(source: &Path, destination: &Path, mode: LinkMode, overwrite: bool) -> Result<LinkPlan, AppError>`.

- [ ] **Step 1: Write failing planner tests**

Add tests named `file_mode_maps_source_name_to_destination`, `top_level_mode_lists_only_immediate_files`, `recursive_mode_maps_relative_paths_and_directories`, `destination_inside_source_is_rejected`, `existing_regular_destination_is_conflict`, `existing_symlink_is_create_or_skip_based_on_overwrite`, and `missing_destination_parent_is_rejected`.

Assert file mode creates one `CreateFileLink` action; top-level mode excludes directories; recursive mode includes relative directories and file links; overlap and missing destination return `AppError`; regular destination items are conflicts; symlinks follow the overwrite flag.

- [ ] **Step 2: Run `cargo test linker::tests`**

Expected: FAIL because `src/linker.rs` is not linked or its API is not implemented.

- [ ] **Step 3: Add and implement `src/linker.rs`**

Add `mod linker;` and `mod config;` to `main.rs`. Implement path validation, source/destination overlap checks, directory walking, and destination collision classification using `symlink_metadata`.

- [ ] **Step 4: Run `cargo test linker::tests`**

Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add src/main.rs src/linker.rs
git commit -m "feat: add symbolic-link operation planning"
```

### Task 3: Implement and test Windows link execution

**Files:**
- Create: `src/executor.rs`
- Modify: `src/main.rs`
- Test: `src/executor.rs`

**Interfaces:**
- Consumes: `LinkPlan`, `PlannedAction`, and `LinkSummary`.
- Produces: `pub fn execute_plan(plan: &LinkPlan) -> LinkSummary`.

- [ ] **Step 1: Write failing executor tests**

Add Windows-only tests named `execute_plan_creates_file_symlink`, `execute_plan_creates_directory_mirror`, `execute_plan_skips_existing_regular_file`, `execute_plan_replaces_only_existing_symlink_when_overwrite`, `execute_plan_rechecks_destination`, `execute_plan_never_removes_regular_or_junction_destination`, and `execute_plan_records_permission_error`.

Assert created counts and skip/failure counts match the operation. Assert regular files and junctions remain unchanged and permission-denied operations appear in the failure list.

- [ ] **Step 2: Run `cargo test executor::tests`**

Expected: FAIL because `src/executor.rs` does not exist.

- [ ] **Step 3: Implement `src/executor.rs`**

Create destination directories, file symlinks, and directory symlinks using Rust Windows filesystem APIs. Recheck every destination with `symlink_metadata` immediately before mutation. Remove only confirmed symbolic links for overwrite. Collect each error in `LinkSummary.failures` and never convert failures to success.

- [ ] **Step 4: Run `cargo test executor::tests`**

Expected: PASS on elevated Windows or an environment with Developer Mode enabled.

- [ ] **Step 5: Commit**

```powershell
git add src/main.rs src/executor.rs
git commit -m "feat: execute safe Windows symbolic links"
```

### Task 4: Build the egui GUI and templates workflow

**Files:**
- Create: `src/app.rs`
- Modify: `src/main.rs`
- Test: `src/app.rs`

**Interfaces:**
- Consumes: `config::load_templates`, `config::save_templates`, `linker::{LinkMode, plan_links}`, and `executor::execute_plan`.
- Produces: `pub struct SymbolicLinkApp`, implementing `eframe::App`.

- [ ] **Step 1: Write failing app-state tests**

Add tests named `default_source_mode_is_directory`, `file_mode_disables_recursive_option`, `preview_describes_recursive_directory`, `template_send_actions_update_fields`, and `close_save_failure_is_reported`.

Assert source starts as Directory, file mode resets recurse to false, preview text names the source/destination and mode, template transfers update the correct field, and save failures produce a visible result instead of a silent success.

- [ ] **Step 2: Run `cargo test app::tests`**

Expected: FAIL because `src/app.rs` does not exist.

- [ ] **Step 3: Implement `src/app.rs`**

Build the V2.8 layout: source controls, destination controls, nine template rows, options, preview, create, and close. Use `rfd` for file/folder dialogs. Add source/destination text-change updates to the preview.

- [ ] **Step 4: Wire create and close behavior**

Create calls `validate_source`, `validate_destination`, `validate_paths`, `plan_links`, and `execute_plan`, then show exact created/skip/failure counts. Close saves all nine templates and shows a save error if persistence fails.

- [ ] **Step 5: Run `cargo test app::tests` and `cargo build --release`**

Expected: tests pass; a Windows executable is emitted at `target\release\symbolic-link-maker.exe`.

- [ ] **Step 6: Commit**

```powershell
git add src/app.rs src/main.rs
git commit -m "feat: add native symbolic-linker GUI"
```

### Task 5: Add startup elevation feedback and packaging details

**Files:**
- Modify: `src/main.rs`
- Modify: `README.md`
- Modify: `.gitignore`

**Interfaces:**
- Consumes: Windows identity and principal APIs.
- Produces: blocking startup error for non-administrator runs and no mutation before elevation is confirmed.

- [ ] **Step 1: Write the startup check test**

Add a unit test named `elevation_error_text_matches_admin_requirement` asserting the text says Administrator rights are required and explains that PowerShell or the executable must be opened with elevated privileges.

- [ ] **Step 2: Run `cargo test elevation_error_text_matches_admin_requirement`**

Expected: FAIL because the startup check text/function is not implemented.

- [ ] **Step 3: Implement startup elevation check**

At startup, check the Windows administrator role. If it is false, show a modal blocking error and exit before opening the GUI or performing filesystem mutations.

- [ ] **Step 4: Update README and `.gitignore`**

Document `cargo build --release`, executable location, Windows elevation requirement, file/directory modes, overwrite behavior, template location, and the existing PowerShell scripts being retained for reference.

- [ ] **Step 5: Run verification commands**

Run `cargo fmt --check`, `cargo test`, and `cargo build --release`.

Expected: formatting passes, tests pass, and release build succeeds.

- [ ] **Step 6: Commit**

```powershell
git add src/main.rs README.md .gitignore
git commit -m "docs: package the Rust symbolic-link creator"
```

### Task 6: Perform Windows parity verification

**Files:**
- No source changes unless verification exposes a bug.
- Test: manual checklist plus automated suite from Tasks 1-5.

- [ ] **Step 1: Run automated verification**

Run `cargo fmt --check`, `cargo test`, and `cargo build --release`.

Expected: zero formatting failures, zero test failures, and a release executable.

- [ ] **Step 2: Verify file mode**

Launch `target\release\symbolic-link-maker.exe` as Administrator. Select a source file and existing destination, create the link, and confirm it resolves to the source. Repeat with overwrite off and on.

- [ ] **Step 3: Verify top-level and recursive directory modes**

Create top-level file links and confirm subdirectories are not traversed. Enable recurse and confirm matching relative directories and file links are created without changing source contents.

- [ ] **Step 4: Verify templates and safety**

Populate all nine templates, save, close, reopen, and confirm each value loads. Place a regular file at a destination link path and confirm it remains untouched. Place a junction at a destination path and confirm it is not removed.

- [ ] **Step 5: Commit any parity fixes**

Create a separate commit for each independently reviewed parity fix and include `Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>` in the commit message.

# Task 2: Implement and test link planning

Read this task as the requirements.

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

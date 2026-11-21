# Task 3: Implement and test Windows link execution

Read this task as the requirements.

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

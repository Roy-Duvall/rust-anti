# Task 4: Build the egui GUI and templates workflow

Read this task as the requirements.

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

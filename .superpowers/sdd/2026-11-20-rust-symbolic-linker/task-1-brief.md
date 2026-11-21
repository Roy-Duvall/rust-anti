# Task 1: Add the Cargo package and template persistence

Read this task as the requirements.

## Plan text

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

# Task 5: Add startup elevation feedback and packaging details

Read this task as the requirements.

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

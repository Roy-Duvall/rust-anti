# Task 6: Perform Windows parity verification

Read this task as the requirements.

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

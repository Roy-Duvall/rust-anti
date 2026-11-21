# SymbolicLinker_v3r_1

High-performance native Rust conversion of `SymbolicLinker_V2_8.ps1`.

## Features
- **Native Classic Windows GUI**: Powered by `native-windows-gui`, with genuine Win32 controls (GroupBoxes, Buttons, ComboBoxes, TextInputs, and TextBoxes).
- **Embedded Application Manifest**: Includes `<requestedExecutionLevel level="requireAdministrator" />` to automatically request UAC elevation when executed, plus a programmatic fallback check.
- **Embedded Icon**: Incorporates `symlnk1.ico` directly into the `.exe`.
- **Saved Path Templates (1 - 9)**: Compatible with `%APPDATA%\SymbolicLinkCreator\templates.json`, allowing seamless template sharing between PowerShell and Rust versions.
- **Full Parity with PowerShell v2.8**:
  - Source Type selection (`File` or `Directory`).
  - Native Windows Folder and File browser dialogs (`IFileDialog`).
  - Fast directory traversal using `walkdir`.
  - Safe Reparse Point detection (`FILE_ATTRIBUTE_REPARSE_POINT`) to avoid overwriting non-symlink destination files.
  - Live preview updating on any field change.
  - Automatic template saving on close.

## Building and Running

### Build Release Binary
```powershell
cargo build --release
```

The resulting executable will be at:
`target\release\SymbolicLinker_v3r_1.exe`

### Run
Right-click `SymbolicLinker_v3r_1.exe` and run as Administrator (or let Windows UAC elevate automatically).

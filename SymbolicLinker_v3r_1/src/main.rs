#![windows_subsystem = "windows"]

use native_windows_gui as nwg;
use std::cell::RefCell;
use std::path::{Path, PathBuf};
use std::rc::Rc;
use walkdir::WalkDir;
use winapi::shared::ntdef::PWSTR;
use winapi::shared::winerror::S_OK;
use winapi::shared::wtypesbase::CLSCTX_INPROC_SERVER;
use winapi::um::combaseapi::{CoCreateInstance, CoTaskMemFree};
use winapi::um::shobjidl::{
    FOS_FILEMUSTEXIST, FOS_PATHMUSTEXIST, FOS_PICKFOLDERS, FOS_SHAREAWARE,
    IFileOpenDialog,
};
use winapi::um::shobjidl_core::{
    CLSID_FileOpenDialog, IShellItem, SIGDN_DESKTOPABSOLUTEPARSING, SIGDN_FILESYSPATH,
};
use winapi::Interface;
use windows_sys::Win32::UI::WindowsAndMessaging::{
    MB_ICONERROR, MB_ICONINFORMATION, MB_ICONWARNING,
};

extern "system" {
    fn SHCreateItemFromParsingName(
        pszPath: winapi::shared::ntdef::PCWSTR,
        pbc: *mut winapi::um::objidl::IBindCtx,
        riid: winapi::shared::guiddef::REFIID,
        ppv: *mut *mut winapi::ctypes::c_void,
    ) -> winapi::shared::ntdef::HRESULT;
}

// Check if running with elevated Administrator privileges
fn is_elevated() -> bool {
    use windows_sys::Win32::Foundation::{CloseHandle, HANDLE};
    use windows_sys::Win32::Security::{
        GetTokenInformation, TokenElevation, TOKEN_ELEVATION, TOKEN_QUERY,
    };
    use windows_sys::Win32::System::Threading::{GetCurrentProcess, OpenProcessToken};

    unsafe {
        let mut token: HANDLE = std::ptr::null_mut();
        if OpenProcessToken(GetCurrentProcess(), TOKEN_QUERY, &mut token) == 0 {
            return false;
        }

        let mut elevation = TOKEN_ELEVATION {
            TokenIsElevated: 0,
        };
        let mut return_length = 0;
        let success = GetTokenInformation(
            token,
            TokenElevation,
            &mut elevation as *mut _ as *mut _,
            std::mem::size_of::<TOKEN_ELEVATION>() as u32,
            &mut return_length,
        );

        CloseHandle(token);
        success != 0 && elevation.TokenIsElevated != 0
    }
}

// Display native Win32 MessageBox
fn show_message(parent: Option<&nwg::ControlHandle>, title: &str, message: &str, icon: u32) {
    use windows_sys::Win32::UI::WindowsAndMessaging::*;
    let hwnd = match parent {
        Some(nwg::ControlHandle::Hwnd(h)) => *h as windows_sys::Win32::Foundation::HWND,
        _ => std::ptr::null_mut(),
    };
    let title_wide: Vec<u16> = title.encode_utf16().chain(std::iter::once(0)).collect();
    let msg_wide: Vec<u16> = message.encode_utf16().chain(std::iter::once(0)).collect();
    unsafe {
        MessageBoxW(hwnd, msg_wide.as_ptr(), title_wide.as_ptr(), MB_OK | icon);
    }
}

// Configuration persistence for templates (%APPDATA%\SymbolicLinkCreator\templates.json)
fn get_config_path() -> Option<(PathBuf, PathBuf)> {
    if let Ok(appdata) = std::env::var("APPDATA") {
        let dir = PathBuf::from(appdata).join("SymbolicLinkCreator");
        let file = dir.join("templates.json");
        Some((dir, file))
    } else {
        None
    }
}

fn load_saved_templates() -> [String; 9] {
    let mut defaults: [String; 9] = Default::default();
    if let Some((_, file)) = get_config_path() {
        if file.exists() {
            if let Ok(content) = std::fs::read_to_string(&file) {
                if let Ok(arr) = serde_json::from_str::<Vec<String>>(&content) {
                    for (i, val) in arr.into_iter().take(9).enumerate() {
                        defaults[i] = val;
                    }
                }
            }
        }
    }
    defaults
}

fn save_saved_templates(templates: &[String; 9]) -> Result<(), String> {
    if let Some((dir, file)) = get_config_path() {
        if !dir.exists() {
            std::fs::create_dir_all(&dir).map_err(|e| e.to_string())?;
        }
        let json = serde_json::to_string_pretty(templates).map_err(|e| e.to_string())?;
        std::fs::write(&file, json).map_err(|e| e.to_string())?;
        Ok(())
    } else {
        Err("Could not determine %APPDATA% directory".to_string())
    }
}

// Check if a path is a Windows Reparse Point (symlink / junction)
fn is_reparse_point(path: &Path) -> bool {
    use std::os::windows::fs::MetadataExt;
    if let Ok(meta) = std::fs::symlink_metadata(path) {
        (meta.file_attributes() & 0x400) != 0
    } else {
        false
    }
}

fn is_symlink_or_exists(path: &Path) -> bool {
    std::fs::symlink_metadata(path).is_ok()
}

// Win32 GroupBox creation helper
fn create_group_box(
    parent: &nwg::Window,
    text: &str,
    x: i32,
    y: i32,
    w: i32,
    h: i32,
    font: Option<&nwg::Font>,
) -> windows_sys::Win32::Foundation::HWND {
    use windows_sys::Win32::UI::WindowsAndMessaging::*;
    let parent_hwnd = match parent.handle {
        nwg::ControlHandle::Hwnd(h) => h as windows_sys::Win32::Foundation::HWND,
        _ => return std::ptr::null_mut(),
    };
    let class_name: Vec<u16> = "BUTTON\0".encode_utf16().collect();
    let text_wide: Vec<u16> = text.encode_utf16().chain(std::iter::once(0)).collect();
    unsafe {
        let hwnd = CreateWindowExW(
            0,
            class_name.as_ptr(),
            text_wide.as_ptr(),
            WS_CHILD | WS_VISIBLE | (BS_GROUPBOX as u32) | WS_CLIPSIBLINGS,
            x,
            y,
            w,
            h,
            parent_hwnd,
            std::ptr::null_mut(),
            std::ptr::null_mut(),
            std::ptr::null(),
        );
        if !hwnd.is_null() {
            if let Some(f) = font {
                SendMessageW(hwnd, WM_SETFONT, f.handle as usize, 1);
            }
        }
        hwnd
    }
}

// Native Windows folder browser that fully supports browsing and selecting network connected PCs & shares
fn pick_folder(parent: &nwg::Window, title: &str, current_path: &str) -> Option<String> {
    unsafe {
        let mut dialog: *mut IFileOpenDialog = std::ptr::null_mut();
        if CoCreateInstance(
            &CLSID_FileOpenDialog,
            std::ptr::null_mut(),
            CLSCTX_INPROC_SERVER,
            &IFileOpenDialog::uuidof(),
            std::mem::transmute(&mut dialog),
        ) != S_OK
        {
            return None;
        }

        let fd = &mut *dialog;

        // FOS_SHAREAWARE | FOS_PICKFOLDERS | FOS_PATHMUSTEXIST
        // Notice: We intentionally DO NOT set FOS_FORCEFILESYSTEM so network connected PCs can be browsed
        let flags = FOS_PICKFOLDERS | FOS_PATHMUSTEXIST | FOS_SHAREAWARE;
        let _ = fd.SetOptions(flags);

        let title_w: Vec<u16> = title.encode_utf16().chain(std::iter::once(0)).collect();
        let _ = fd.SetTitle(title_w.as_ptr());

        // Default to "This PC" (contains local drives, mapped drives, and Network PCs)
        let folder_to_set = if !current_path.trim().is_empty() {
            let p = Path::new(current_path.trim());
            if p.exists() {
                current_path.trim().to_string()
            } else {
                ":::{20D04FE0-3AEA-1069-A2D8-08002B30309D}".to_string()
            }
        } else {
            ":::{20D04FE0-3AEA-1069-A2D8-08002B30309D}".to_string()
        };

        let path_w: Vec<u16> = folder_to_set
            .encode_utf16()
            .chain(std::iter::once(0))
            .collect();
        let mut shellitem: *mut IShellItem = std::ptr::null_mut();

        if SHCreateItemFromParsingName(
            path_w.as_ptr(),
            std::ptr::null_mut(),
            &IShellItem::uuidof(),
            std::mem::transmute(&mut shellitem),
        ) == S_OK
        {
            let _ = fd.SetFolder(&mut *shellitem);
            let _ = fd.SetDefaultFolder(&mut *shellitem);
            (&mut *shellitem).Release();
        }

        let parent_hwnd = match parent.handle {
            nwg::ControlHandle::Hwnd(h) => h as winapi::shared::windef::HWND,
            _ => std::ptr::null_mut(),
        };

        let mut result = None;
        if fd.Show(parent_hwnd) == S_OK {
            let mut result_item: *mut IShellItem = std::ptr::null_mut();
            if fd.GetResult(&mut result_item) == S_OK {
                let mut path_ptr: PWSTR = std::ptr::null_mut();
                let hr = (&mut *result_item).GetDisplayName(SIGDN_FILESYSPATH, &mut path_ptr);
                let hr = if hr != S_OK {
                    (&mut *result_item)
                        .GetDisplayName(SIGDN_DESKTOPABSOLUTEPARSING, &mut path_ptr)
                } else {
                    hr
                };

                if hr == S_OK && !path_ptr.is_null() {
                    let len = (0..).take_while(|&i| *path_ptr.offset(i) != 0).count();
                    let slice = std::slice::from_raw_parts(path_ptr, len);
                    result = Some(String::from_utf16_lossy(slice));
                    CoTaskMemFree(path_ptr as *mut _);
                }
                (&mut *result_item).Release();
            }
        }

        fd.Release();
        result
    }
}

// Native Windows file browser that supports browsing and selecting network files
fn pick_file(parent: &nwg::Window, title: &str, current_path: &str) -> Option<String> {
    unsafe {
        let mut dialog: *mut IFileOpenDialog = std::ptr::null_mut();
        if CoCreateInstance(
            &CLSID_FileOpenDialog,
            std::ptr::null_mut(),
            CLSCTX_INPROC_SERVER,
            &IFileOpenDialog::uuidof(),
            std::mem::transmute(&mut dialog),
        ) != S_OK
        {
            return None;
        }

        let fd = &mut *dialog;

        // FOS_FILEMUSTEXIST | FOS_PATHMUSTEXIST | FOS_SHAREAWARE
        let flags = FOS_FILEMUSTEXIST | FOS_PATHMUSTEXIST | FOS_SHAREAWARE;
        let _ = fd.SetOptions(flags);

        let title_w: Vec<u16> = title.encode_utf16().chain(std::iter::once(0)).collect();
        let _ = fd.SetTitle(title_w.as_ptr());

        let folder_to_set = if !current_path.trim().is_empty() {
            let p = Path::new(current_path.trim());
            if p.is_file() {
                p.parent().map(|parent| parent.to_string_lossy().to_string())
            } else if p.is_dir() {
                Some(current_path.trim().to_string())
            } else {
                None
            }
        } else {
            None
        }
        .unwrap_or_else(|| ":::{20D04FE0-3AEA-1069-A2D8-08002B30309D}".to_string());

        let path_w: Vec<u16> = folder_to_set
            .encode_utf16()
            .chain(std::iter::once(0))
            .collect();
        let mut shellitem: *mut IShellItem = std::ptr::null_mut();

        if SHCreateItemFromParsingName(
            path_w.as_ptr(),
            std::ptr::null_mut(),
            &IShellItem::uuidof(),
            std::mem::transmute(&mut shellitem),
        ) == S_OK
        {
            let _ = fd.SetFolder(&mut *shellitem);
            let _ = fd.SetDefaultFolder(&mut *shellitem);
            (&mut *shellitem).Release();
        }

        let parent_hwnd = match parent.handle {
            nwg::ControlHandle::Hwnd(h) => h as winapi::shared::windef::HWND,
            _ => std::ptr::null_mut(),
        };

        let mut result = None;
        if fd.Show(parent_hwnd) == S_OK {
            let mut result_item: *mut IShellItem = std::ptr::null_mut();
            if fd.GetResult(&mut result_item) == S_OK {
                let mut path_ptr: PWSTR = std::ptr::null_mut();
                let hr = (&mut *result_item).GetDisplayName(SIGDN_FILESYSPATH, &mut path_ptr);
                let hr = if hr != S_OK {
                    (&mut *result_item)
                        .GetDisplayName(SIGDN_DESKTOPABSOLUTEPARSING, &mut path_ptr)
                } else {
                    hr
                };

                if hr == S_OK && !path_ptr.is_null() {
                    let len = (0..).take_while(|&i| *path_ptr.offset(i) != 0).count();
                    let slice = std::slice::from_raw_parts(path_ptr, len);
                    result = Some(String::from_utf16_lossy(slice));
                    CoTaskMemFree(path_ptr as *mut _);
                }
                (&mut *result_item).Release();
            }
        }

        fd.Release();
        result
    }
}

struct TemplateRow {
    _label: nwg::Label,
    input: nwg::TextInput,
    btn_browse: nwg::Button,
    btn_from_src: nwg::Button,
    btn_from_dst: nwg::Button,
    btn_to_src: nwg::Button,
    btn_to_dst: nwg::Button,
}

struct App {
    window: nwg::Window,
    source_type_cb: nwg::ComboBox<String>,
    source_input: nwg::TextInput,
    source_browse_btn: nwg::Button,

    dest_input: nwg::TextInput,
    dest_browse_btn: nwg::Button,

    template_rows: Vec<TemplateRow>,
    save_templates_btn: nwg::Button,

    recurse_cb: nwg::CheckBox,
    overwrite_cb: nwg::CheckBox,
    _help_label: nwg::Label,

    preview_box: nwg::TextBox,

    create_btn: nwg::Button,
    close_btn: nwg::Button,
}

impl App {
    fn update_preview(&self) {
        let src = self.source_input.text();
        let src = src.trim();
        let dst = self.dest_input.text();
        let dst = dst.trim();

        if !src.is_empty() && !dst.is_empty() {
            let is_directory = self.source_type_cb.selection() == Some(1);
            let is_recursive = self.recurse_cb.check_state() == nwg::CheckBoxState::Checked;

            if is_directory {
                if is_recursive {
                    self.preview_box.set_text(&format!(
                        "Mode: Recursive Directory\r\nWill create symbolic links for ALL files in:\r\n{}\r\nInto: {}",
                        src, dst
                    ));
                } else {
                    self.preview_box.set_text(&format!(
                        "Mode: Top-Level Files Only\r\nWill create symbolic links for files in:\r\n{}\r\nInto: {}",
                        src, dst
                    ));
                }
            } else {
                self.preview_box.set_text(&format!(
                    "Mode: Single File\r\nWill create symbolic link for:\r\n{}\r\nInto: {}",
                    src, dst
                ));
            }
        } else {
            self.preview_box
                .set_text("Please select both a Source and a Destination directory/file.");
        }
    }

    fn save_all_templates(&self, show_dialog: bool) {
        let mut tpls: [String; 9] = Default::default();
        for (i, row) in self.template_rows.iter().enumerate() {
            tpls[i] = row.input.text().trim().to_string();
        }

        match save_saved_templates(&tpls) {
            Ok(_) => {
                if show_dialog {
                    show_message(
                        Some(&self.window.handle),
                        "Templates Saved",
                        "All 9 template paths saved successfully!",
                        MB_ICONINFORMATION,
                    );
                }
            }
            Err(e) => {
                show_message(
                    Some(&self.window.handle),
                    "Save Error",
                    &format!("Error saving templates: {}", e),
                    MB_ICONERROR,
                );
            }
        }
    }

    fn create_symbolic_links(&self) {
        let src = self
            .source_input
            .text()
            .trim_end_matches(['\\', '/'])
            .to_string();
        let dst = self
            .dest_input
            .text()
            .trim_end_matches(['\\', '/'])
            .to_string();
        let overwrite = self.overwrite_cb.check_state() == nwg::CheckBoxState::Checked;

        let src_path = Path::new(&src);
        let dst_path = Path::new(&dst);

        if src.is_empty() || !src_path.exists() {
            show_message(
                Some(&self.window.handle),
                "Error",
                "Source path does not exist.",
                MB_ICONERROR,
            );
            return;
        }

        if dst.is_empty() || !dst_path.exists() {
            show_message(
                Some(&self.window.handle),
                "Error",
                "Destination directory does not exist.",
                MB_ICONERROR,
            );
            return;
        }

        let is_directory = self.source_type_cb.selection() == Some(1);
        let is_recursive = self.recurse_cb.check_state() == nwg::CheckBoxState::Checked;

        let mut file_count = 0;
        let mut dir_count = 0;
        let mut skipped_count = 0;

        if is_directory {
            if is_recursive {
                for entry in WalkDir::new(src_path).min_depth(1) {
                    let entry = match entry {
                        Ok(e) => e,
                        Err(e) => {
                            eprintln!("Walk error: {}", e);
                            continue;
                        }
                    };

                    let entry_path = entry.path();
                    let relative = match entry_path.strip_prefix(src_path) {
                        Ok(r) => r,
                        Err(_) => continue,
                    };
                    let target = dst_path.join(relative);

                    if entry.file_type().is_dir() {
                        if !target.exists() {
                            if std::fs::create_dir_all(&target).is_ok() {
                                dir_count += 1;
                            }
                        }
                    } else {
                        // Ensure parent folder exists
                        if let Some(parent) = target.parent() {
                            if !parent.exists() {
                                let _ = std::fs::create_dir_all(parent);
                            }
                        }

                        if is_symlink_or_exists(&target) {
                            if is_reparse_point(&target) {
                                if overwrite {
                                    let _ = std::fs::remove_file(&target);
                                    if std::os::windows::fs::symlink_file(entry_path, &target).is_ok()
                                    {
                                        file_count += 1;
                                    } else {
                                        skipped_count += 1;
                                    }
                                } else {
                                    skipped_count += 1;
                                }
                            } else {
                                skipped_count += 1;
                            }
                        } else {
                            if std::os::windows::fs::symlink_file(entry_path, &target).is_ok() {
                                file_count += 1;
                            } else {
                                skipped_count += 1;
                            }
                        }
                    }
                }

                show_message(
                    Some(&self.window.handle),
                    "Success",
                    &format!(
                        "Recursive symbolic links operation completed!\n\nDirectories created: {}\nFile symlinks created: {}\nSkipped: {}",
                        dir_count, file_count, skipped_count
                    ),
                    MB_ICONINFORMATION,
                );
            } else {
                // Top-level files only
                if let Ok(entries) = std::fs::read_dir(src_path) {
                    for entry in entries.flatten() {
                        let path = entry.path();
                        if path.is_file() {
                            let file_name = entry.file_name();
                            let target = dst_path.join(file_name);

                            if is_symlink_or_exists(&target) {
                                if is_reparse_point(&target) {
                                    if overwrite {
                                        let _ = std::fs::remove_file(&target);
                                        if std::os::windows::fs::symlink_file(&path, &target).is_ok()
                                        {
                                            file_count += 1;
                                        } else {
                                            skipped_count += 1;
                                        }
                                    } else {
                                        skipped_count += 1;
                                    }
                                } else {
                                    skipped_count += 1;
                                }
                            } else {
                                if std::os::windows::fs::symlink_file(&path, &target).is_ok() {
                                    file_count += 1;
                                } else {
                                    skipped_count += 1;
                                }
                            }
                        }
                    }
                }

                show_message(
                    Some(&self.window.handle),
                    "Success",
                    &format!(
                        "Top-level file symbolic links operation completed!\n\nFile symlinks created: {}\nSkipped: {}",
                        file_count, skipped_count
                    ),
                    MB_ICONINFORMATION,
                );
            }
        } else {
            // Single file
            let file_name = match src_path.file_name() {
                Some(f) => f,
                None => {
                    show_message(
                        Some(&self.window.handle),
                        "Error",
                        "Invalid source file path.",
                        MB_ICONERROR,
                    );
                    return;
                }
            };
            let target = dst_path.join(file_name);

            if is_symlink_or_exists(&target) {
                if is_reparse_point(&target) {
                    if overwrite {
                        let _ = std::fs::remove_file(&target);
                        match std::os::windows::fs::symlink_file(src_path, &target) {
                            Ok(_) => {
                                show_message(
                                    Some(&self.window.handle),
                                    "Success",
                                    "Symbolic link replaced successfully!",
                                    MB_ICONINFORMATION,
                                );
                            }
                            Err(e) => {
                                show_message(
                                    Some(&self.window.handle),
                                    "Operation Failed",
                                    &format!("Error creating symbolic link:\n\n{}", e),
                                    MB_ICONERROR,
                                );
                            }
                        }
                    } else {
                        show_message(
                            Some(&self.window.handle),
                            "Skipped",
                            "Symbolic link already exists and overwrite is disabled.",
                            MB_ICONINFORMATION,
                        );
                    }
                } else {
                    show_message(
                        Some(&self.window.handle),
                        "Error",
                        "A regular file already exists at destination.\nCannot overwrite regular files.",
                        MB_ICONWARNING,
                    );
                }
            } else {
                match std::os::windows::fs::symlink_file(src_path, &target) {
                    Ok(_) => {
                        show_message(
                            Some(&self.window.handle),
                            "Success",
                            "Symbolic link created successfully!",
                            MB_ICONINFORMATION,
                        );
                    }
                    Err(e) => {
                        show_message(
                            Some(&self.window.handle),
                            "Operation Failed",
                            &format!("Error creating symbolic link:\n\n{}", e),
                            MB_ICONERROR,
                        );
                    }
                }
            }
        }
    }
}

fn main() {
    // Elevation check - Administrator rights required for symlinks
    if !is_elevated() {
        show_message(
            None,
            "Admin Rights Required",
            "This application must be run as Administrator to create symbolic links.\n\nPlease right-click and select 'Run as administrator'.",
            MB_ICONERROR,
        );
        return;
    }

    nwg::init().expect("Failed to initialize Native Windows GUI");

    // Configure system fonts
    let mut default_font = Default::default();
    nwg::Font::builder()
        .size(15)
        .family("Segoe UI")
        .build(&mut default_font)
        .expect("Failed to create UI font");
    nwg::Font::set_global_default(Some(default_font));

    let mut bold_font = Default::default();
    nwg::Font::builder()
        .size(15)
        .family("Segoe UI")
        .weight(700)
        .build(&mut bold_font)
        .expect("Failed to create bold font");

    // Center the window on screen
    let (pos_x, pos_y) = unsafe {
        use windows_sys::Win32::UI::WindowsAndMessaging::*;
        let screen_w = GetSystemMetrics(SM_CXSCREEN);
        let screen_h = GetSystemMetrics(SM_CYSCREEN);
        let win_w = 750;
        let win_h = 830;
        ((screen_w - win_w) / 2, (screen_h - win_h) / 2)
    };

    // Main window
    let mut window = Default::default();
    nwg::Window::builder()
        .size((750, 830))
        .position((pos_x, pos_y))
        .title("Symbolic Link Creator v3r.1 - with Editable Templates")
        .flags(nwg::WindowFlags::WINDOW | nwg::WindowFlags::VISIBLE | nwg::WindowFlags::MINIMIZE_BOX)
        .build(&mut window)
        .expect("Failed to create main window");

    // Win32 GroupBoxes
    create_group_box(
        &window,
        "Source Selection",
        20,
        15,
        700,
        95,
        Some(&bold_font),
    );
    create_group_box(
        &window,
        "Destination Selection",
        20,
        120,
        700,
        80,
        Some(&bold_font),
    );
    create_group_box(
        &window,
        "Saved Path Templates (1 - 9)",
        20,
        210,
        700,
        335,
        Some(&bold_font),
    );
    create_group_box(&window, "Options", 20, 555, 700, 105, Some(&bold_font));
    create_group_box(&window, "Preview", 20, 670, 700, 80, Some(&bold_font));

    // Group 1: Source Selection Controls
    let mut source_type_label = Default::default();
    nwg::Label::builder()
        .text("Source Type:")
        .size((100, 20))
        .position((35, 38))
        .parent(&window)
        .build(&mut source_type_label)
        .unwrap();

    let mut source_type_cb = Default::default();
    nwg::ComboBox::builder()
        .size((120, 25))
        .position((35, 62))
        .collection(vec!["File".to_string(), "Directory".to_string()])
        .selected_index(Some(1))
        .parent(&window)
        .build(&mut source_type_cb)
        .unwrap();

    let mut source_input = Default::default();
    nwg::TextInput::builder()
        .size((470, 25))
        .position((165, 62))
        .parent(&window)
        .build(&mut source_input)
        .unwrap();

    let mut source_browse_btn = Default::default();
    nwg::Button::builder()
        .text("...")
        .size((60, 27))
        .position((645, 61))
        .parent(&window)
        .build(&mut source_browse_btn)
        .unwrap();

    // Group 2: Destination Selection Controls
    let mut dest_label = Default::default();
    nwg::Label::builder()
        .text("Destination Folder:")
        .size((150, 20))
        .position((35, 140))
        .parent(&window)
        .build(&mut dest_label)
        .unwrap();

    let mut dest_input = Default::default();
    nwg::TextInput::builder()
        .size((600, 25))
        .position((35, 162))
        .parent(&window)
        .build(&mut dest_input)
        .unwrap();

    let mut dest_browse_btn = Default::default();
    nwg::Button::builder()
        .text("Browse")
        .size((60, 27))
        .position((645, 161))
        .parent(&window)
        .build(&mut dest_browse_btn)
        .unwrap();

    // Group 3: Saved Path Templates (1 - 9)
    let saved_templates = load_saved_templates();
    let mut template_rows = Vec::with_capacity(9);

    for i in 0..9 {
        let y = 235 + (i as i32 * 30);

        let mut lbl = Default::default();
        nwg::Label::builder()
            .text(&format!("#{}:", i + 1))
            .font(Some(&bold_font))
            .size((28, 20))
            .position((32, y + 3))
            .parent(&window)
            .build(&mut lbl)
            .unwrap();

        let mut txt = Default::default();
        nwg::TextInput::builder()
            .text(&saved_templates[i])
            .size((310, 25))
            .position((62, y))
            .parent(&window)
            .build(&mut txt)
            .unwrap();

        let mut btn_browse = Default::default();
        nwg::Button::builder()
            .text("...")
            .size((35, 25))
            .position((380, y - 1))
            .parent(&window)
            .build(&mut btn_browse)
            .unwrap();

        let mut btn_from_src = Default::default();
        nwg::Button::builder()
            .text("+ From Src")
            .size((70, 25))
            .position((420, y - 1))
            .parent(&window)
            .build(&mut btn_from_src)
            .unwrap();

        let mut btn_from_dst = Default::default();
        nwg::Button::builder()
            .text("+ From Dst")
            .size((70, 25))
            .position((495, y - 1))
            .parent(&window)
            .build(&mut btn_from_dst)
            .unwrap();

        let mut btn_to_src = Default::default();
        nwg::Button::builder()
            .text("-> Source")
            .size((68, 25))
            .position((570, y - 1))
            .parent(&window)
            .build(&mut btn_to_src)
            .unwrap();

        let mut btn_to_dst = Default::default();
        nwg::Button::builder()
            .text("-> Dest")
            .size((60, 25))
            .position((645, y - 1))
            .parent(&window)
            .build(&mut btn_to_dst)
            .unwrap();

        template_rows.push(TemplateRow {
            _label: lbl,
            input: txt,
            btn_browse,
            btn_from_src,
            btn_from_dst,
            btn_to_src,
            btn_to_dst,
        });
    }

    let mut save_templates_btn = Default::default();
    nwg::Button::builder()
        .text("Save All Templates")
        .font(Some(&bold_font))
        .size((160, 28))
        .position((545, 508))
        .parent(&window)
        .build(&mut save_templates_btn)
        .unwrap();

    // Group 4: Options Controls
    let mut recurse_cb = Default::default();
    nwg::CheckBox::builder()
        .text("Recurse: Include all subdirectories and their files")
        .size((650, 22))
        .position((35, 577))
        .parent(&window)
        .build(&mut recurse_cb)
        .unwrap();

    let mut overwrite_cb = Default::default();
    nwg::CheckBox::builder()
        .text("Overwrite existing symbolic links (if unchecked, existing links will be skipped)")
        .size((650, 22))
        .position((35, 602))
        .parent(&window)
        .build(&mut overwrite_cb)
        .unwrap();

    let mut help_label = Default::default();
    nwg::Label::builder()
        .text("Recurse OFF: Links top-level files | Recurse ON: Links all nested files | Overwrite: Replaces existing symlinks")
        .size((660, 20))
        .position((35, 630))
        .parent(&window)
        .build(&mut help_label)
        .unwrap();

    // Group 5: Preview Controls
    let mut preview_box = Default::default();
    nwg::TextBox::builder()
        .text("Please select both a Source and a Destination directory/file.")
        .readonly(true)
        .flags(
            nwg::TextBoxFlags::VISIBLE
                | nwg::TextBoxFlags::AUTOVSCROLL
                | nwg::TextBoxFlags::VSCROLL,
        )
        .size((670, 50))
        .position((35, 692))
        .parent(&window)
        .build(&mut preview_box)
        .unwrap();

    // Action Buttons
    let mut create_btn = Default::default();
    nwg::Button::builder()
        .text("Create Symbolic Link(s)")
        .font(Some(&bold_font))
        .size((220, 36))
        .position((20, 765))
        .parent(&window)
        .build(&mut create_btn)
        .unwrap();

    let mut close_btn = Default::default();
    nwg::Button::builder()
        .text("Close")
        .size((220, 36))
        .position((500, 765))
        .parent(&window)
        .build(&mut close_btn)
        .unwrap();

    let app = Rc::new(RefCell::new(App {
        window,
        source_type_cb,
        source_input,
        source_browse_btn,
        dest_input,
        dest_browse_btn,
        template_rows,
        save_templates_btn,
        recurse_cb,
        overwrite_cb,
        _help_label: help_label,
        preview_box,
        create_btn,
        close_btn,
    }));

    // Event binding
    let app_ref = app.clone();
    let handler = nwg::full_bind_event_handler(
        &app.borrow().window.handle,
        move |evt, _evt_data, handle| {
            let app = app_ref.borrow();

            // Window close
            if evt == nwg::Event::OnWindowClose && handle == app.window.handle {
                app.save_all_templates(false);
                nwg::stop_thread_dispatch();
                return;
            }

            // Text input updates
            if evt == nwg::Event::OnTextInput {
                if handle == app.source_input.handle || handle == app.dest_input.handle {
                    app.update_preview();
                }
            }

            // ComboBox selection change
            if evt == nwg::Event::OnComboxBoxSelection && handle == app.source_type_cb.handle {
                let is_directory = app.source_type_cb.selection() == Some(1);
                if is_directory {
                    app.recurse_cb.set_enabled(true);
                } else {
                    app.recurse_cb.set_enabled(false);
                    app.recurse_cb.set_check_state(nwg::CheckBoxState::Unchecked);
                }
                app.update_preview();
            }

            // Button clicks
            if evt == nwg::Event::OnButtonClick {
                // Checkbox clicked
                if handle == app.recurse_cb.handle {
                    app.update_preview();
                    return;
                }

                // Close button
                if handle == app.close_btn.handle {
                    app.save_all_templates(false);
                    nwg::stop_thread_dispatch();
                    return;
                }

                // Create button
                if handle == app.create_btn.handle {
                    app.create_symbolic_links();
                    return;
                }

                // Save templates button
                if handle == app.save_templates_btn.handle {
                    app.save_all_templates(true);
                    return;
                }

                // Source browse button
                if handle == app.source_browse_btn.handle {
                    let is_file = app.source_type_cb.selection() == Some(0);
                    let curr_text = app.source_input.text();

                    let selected = if is_file {
                        pick_file(&app.window, "Select Source File", &curr_text)
                    } else {
                        pick_folder(&app.window, "Select Source Directory", &curr_text)
                    };

                    if let Some(path) = selected {
                        app.source_input.set_text(&path);
                        app.update_preview();
                    }
                    return;
                }

                // Destination browse button
                if handle == app.dest_browse_btn.handle {
                    let curr_text = app.dest_input.text();
                    if let Some(path) =
                        pick_folder(&app.window, "Select Destination Directory", &curr_text)
                    {
                        app.dest_input.set_text(&path);
                        app.update_preview();
                    }
                    return;
                }

                // Template row buttons
                for row in &app.template_rows {
                    if handle == row.btn_browse.handle {
                        let curr_text = row.input.text();
                        if let Some(path) =
                            pick_folder(&app.window, "Select Folder for Template", &curr_text)
                        {
                            row.input.set_text(&path);
                        }
                        return;
                    }

                    if handle == row.btn_from_src.handle {
                        let src_text = app.source_input.text();
                        if src_text.trim().is_empty() {
                            show_message(
                                Some(&app.window.handle),
                                "Notice",
                                "Source field is currently empty.",
                                MB_ICONINFORMATION,
                            );
                        } else {
                            row.input.set_text(&src_text);
                        }
                        return;
                    }

                    if handle == row.btn_from_dst.handle {
                        let dst_text = app.dest_input.text();
                        if dst_text.trim().is_empty() {
                            show_message(
                                Some(&app.window.handle),
                                "Notice",
                                "Destination field is currently empty.",
                                MB_ICONINFORMATION,
                            );
                        } else {
                            row.input.set_text(&dst_text);
                        }
                        return;
                    }

                    if handle == row.btn_to_src.handle {
                        let path_val = row.input.text();
                        if !path_val.trim().is_empty() {
                            app.source_input.set_text(&path_val);
                            let path = Path::new(&path_val);
                            if path.is_dir() {
                                app.source_type_cb.set_selection(Some(1)); // Directory
                                app.recurse_cb.set_enabled(true);
                            } else if path.is_file() {
                                app.source_type_cb.set_selection(Some(0)); // File
                                app.recurse_cb.set_enabled(false);
                                app.recurse_cb.set_check_state(nwg::CheckBoxState::Unchecked);
                            }
                            app.update_preview();
                        }
                        return;
                    }

                    if handle == row.btn_to_dst.handle {
                        let path_val = row.input.text();
                        if !path_val.trim().is_empty() {
                            app.dest_input.set_text(&path_val);
                            app.update_preview();
                        }
                        return;
                    }
                }
            }
        },
    );

    nwg::dispatch_thread_events();
    nwg::unbind_event_handler(&handler);
}

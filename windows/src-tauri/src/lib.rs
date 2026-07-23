mod model;
mod scanner;

use model::{AppInfo, PortScanResult, TerminateResult, UpdateStatus};
use serde::Deserialize;
use std::io::Write;
use std::process::{Command, Stdio};
use std::sync::atomic::{AtomicBool, Ordering};
use tauri::menu::MenuBuilder;
use tauri::tray::{MouseButton, MouseButtonState, TrayIconBuilder, TrayIconEvent};
use tauri::{Emitter, Manager, PhysicalPosition, WindowEvent};

#[derive(Default)]
struct AppState {
    quitting: AtomicBool,
}

/// Runs the Windows backend against a known listener. This is used by the
/// Windows CI smoke test and is intentionally kept out of the bundled app.
#[doc(hidden)]
pub fn run_backend_smoke_test(port: u16, terminate: bool) -> Result<(), String> {
    let result = scanner::scan_ports()?;
    let usages: Vec<_> = result
        .ports
        .iter()
        .filter(|usage| {
            usage.port == port && usage.protocol_name == "TCP" && usage.state == "LISTEN"
        })
        .collect();

    if usages.is_empty() {
        return Err(format!("没有发现测试 TCP 监听端口 {port}"));
    }
    if usages.iter().any(|usage| usage.pid == 0) {
        return Err(format!("测试端口 {port} 未解析到有效 PID"));
    }
    if usages.iter().any(|usage| usage.command.trim().is_empty()) {
        return Err(format!("测试端口 {port} 未解析到进程名"));
    }
    let project_usages = usages
        .iter()
        .filter(|usage| usage.is_project_service)
        .copied()
        .collect::<Vec<_>>();
    if project_usages.is_empty() {
        let details = usages
            .iter()
            .map(|usage| {
                format!(
                    "PID {} user='{}' exe='{}' cwd='{}'",
                    usage.pid, usage.user, usage.executable_path, usage.working_directory
                )
            })
            .collect::<Vec<_>>()
            .join(", ");
        return Err(format!("测试端口 {port} 未被识别为项目服务：{details}"));
    }
    if project_usages
        .iter()
        .any(|usage| usage.user.trim().is_empty())
    {
        return Err(format!("测试端口 {port} 未解析到进程用户"));
    }
    if project_usages
        .iter()
        .any(|usage| usage.executable_path.trim().is_empty())
    {
        return Err(format!("测试端口 {port} 未解析到可执行路径"));
    }
    if project_usages
        .iter()
        .any(|usage| usage.working_directory.trim().is_empty())
    {
        return Err(format!("测试端口 {port} 未解析到工作目录"));
    }
    if project_usages
        .iter()
        .any(|usage| usage.parent_command.trim().is_empty())
    {
        return Err(format!("测试端口 {port} 未解析到父进程"));
    }

    let pids = project_usages
        .iter()
        .map(|usage| usage.pid)
        .collect::<Vec<_>>();
    let parents = project_usages
        .iter()
        .map(|usage| usage.parent_command.as_str())
        .collect::<Vec<_>>();
    println!(
        "DevPilot backend smoke test: port={port}, pids={pids:?}, parents={parents:?}, project_service=true"
    );

    if terminate {
        let terminated = scanner::terminate_processes(pids)?;
        if terminated.terminated_pids.is_empty() {
            return Err(format!("测试端口 {port} 的进程没有被关闭"));
        }
        println!(
            "DevPilot backend smoke test: terminated={:?}",
            terminated.terminated_pids
        );
    }

    Ok(())
}

#[tauri::command]
async fn scan_ports() -> Result<PortScanResult, String> {
    tauri::async_runtime::spawn_blocking(scanner::scan_ports)
        .await
        .map_err(|error| format!("端口扫描任务失败：{error}"))?
}

#[tauri::command]
async fn terminate_processes(pids: Vec<u32>) -> Result<TerminateResult, String> {
    tauri::async_runtime::spawn_blocking(move || scanner::terminate_processes(pids))
        .await
        .map_err(|error| format!("关闭进程任务失败：{error}"))?
}

#[tauri::command]
fn get_app_info(app: tauri::AppHandle) -> AppInfo {
    let version = app.package_info().version.to_string();
    AppInfo {
        build: version.clone(),
        version,
        platform: "Windows",
    }
}

#[tauri::command]
fn show_main_window(app: tauri::AppHandle) -> Result<(), String> {
    show_main(&app)
}

#[tauri::command]
fn reveal_in_explorer(path: String) -> Result<(), String> {
    if path.trim().is_empty() {
        return Err("项目路径为空".into());
    }

    #[cfg(target_os = "windows")]
    {
        let mut command = Command::new("explorer.exe");
        if std::path::Path::new(&path).is_dir() {
            command.arg(&path);
        } else {
            command.args(["/select,", &path]);
        }
        command
            .spawn()
            .map(|_| ())
            .map_err(|error| format!("无法在资源管理器中打开路径：{error}"))
    }

    #[cfg(not(target_os = "windows"))]
    {
        Command::new("open")
            .arg(&path)
            .spawn()
            .map(|_| ())
            .map_err(|error| format!("无法打开路径：{error}"))
    }
}

#[tauri::command]
fn copy_text(text: String) -> Result<(), String> {
    #[cfg(target_os = "windows")]
    let mut child = Command::new("powershell.exe")
        .args([
            "-NoProfile",
            "-NonInteractive",
            "-Command",
            "Set-Clipboard -Value ([Console]::In.ReadToEnd())",
        ])
        .stdin(Stdio::piped())
        .spawn()
        .map_err(|error| format!("无法访问剪贴板：{error}"))?;

    #[cfg(not(target_os = "windows"))]
    let mut child = Command::new("pbcopy")
        .stdin(Stdio::piped())
        .spawn()
        .map_err(|error| format!("无法访问剪贴板：{error}"))?;

    child
        .stdin
        .as_mut()
        .ok_or_else(|| "无法写入剪贴板".to_owned())?
        .write_all(text.as_bytes())
        .map_err(|error| format!("无法写入剪贴板：{error}"))?;
    let status = child
        .wait()
        .map_err(|error| format!("剪贴板命令失败：{error}"))?;
    status
        .success()
        .then_some(())
        .ok_or_else(|| "剪贴板命令执行失败".to_owned())
}

#[derive(Deserialize)]
struct GitHubRelease {
    tag_name: String,
    html_url: String,
}

#[tauri::command]
async fn check_for_updates(app: tauri::AppHandle) -> Result<UpdateStatus, String> {
    let current_version = app.package_info().version.to_string();
    tauri::async_runtime::spawn_blocking(move || fetch_update_status(current_version))
        .await
        .map_err(|error| format!("更新检查任务失败：{error}"))?
}

fn fetch_update_status(current_version: String) -> Result<UpdateStatus, String> {
    #[cfg(not(target_os = "windows"))]
    const RELEASE_API: &str = "https://api.github.com/repos/pkc918/DevPilot/releases/latest";

    #[cfg(target_os = "windows")]
    let output = Command::new("powershell.exe")
        .args([
            "-NoProfile",
            "-NonInteractive",
            "-Command",
            "[Console]::OutputEncoding=[Text.Encoding]::UTF8; $ProgressPreference='SilentlyContinue'; Invoke-RestMethod -Headers @{'User-Agent'='DevPilot-Windows'} -Uri 'https://api.github.com/repos/pkc918/DevPilot/releases/latest' | Select-Object tag_name,html_url | ConvertTo-Json -Compress",
        ])
        .output()
        .map_err(|error| format!("无法启动更新检查：{error}"))?;

    #[cfg(not(target_os = "windows"))]
    let output = Command::new("curl")
        .args(["-fsSL", "-H", "User-Agent: DevPilot-Windows", RELEASE_API])
        .output()
        .map_err(|error| format!("无法启动更新检查：{error}"))?;

    if !output.status.success() {
        let message = String::from_utf8_lossy(&output.stderr).trim().to_owned();
        return Err(if message.is_empty() {
            "无法连接 GitHub 检查更新".into()
        } else {
            format!("检查更新失败：{message}")
        });
    }

    let body = String::from_utf8_lossy(&output.stdout)
        .trim_start_matches('\u{feff}')
        .trim()
        .to_owned();
    let release: GitHubRelease =
        serde_json::from_str(&body).map_err(|error| format!("无法解析更新信息：{error}"))?;
    let latest_version = release.tag_name.trim_start_matches(['v', 'V']).to_owned();

    Ok(UpdateStatus {
        has_update: version_parts(&latest_version) > version_parts(&current_version),
        current_version,
        latest_version,
        release_url: release.html_url,
    })
}

fn version_parts(version: &str) -> Vec<u64> {
    version
        .trim_start_matches(['v', 'V'])
        .split('.')
        .map(|part| {
            part.chars()
                .take_while(char::is_ascii_digit)
                .collect::<String>()
                .parse::<u64>()
                .unwrap_or(0)
        })
        .collect()
}

#[tauri::command]
fn open_release_url(url: String) -> Result<(), String> {
    if !url.starts_with("https://github.com/pkc918/DevPilot/") {
        return Err("拒绝打开非 DevPilot GitHub 地址".into());
    }

    #[cfg(target_os = "windows")]
    let result = Command::new("explorer.exe").arg(&url).spawn();
    #[cfg(target_os = "macos")]
    let result = Command::new("open").arg(&url).spawn();
    #[cfg(all(not(target_os = "windows"), not(target_os = "macos")))]
    let result = Command::new("xdg-open").arg(&url).spawn();

    result
        .map(|_| ())
        .map_err(|error| format!("无法打开发布页面：{error}"))
}

fn show_main(app: &tauri::AppHandle) -> Result<(), String> {
    let window = app
        .get_webview_window("main")
        .ok_or_else(|| "找不到主窗口".to_owned())?;
    let _ = window.unminimize();
    window.show().map_err(|error| error.to_string())?;
    window.set_focus().map_err(|error| error.to_string())
}

fn toggle_tray_window(app: &tauri::AppHandle, click: PhysicalPosition<f64>) {
    let Some(window) = app.get_webview_window("tray") else {
        return;
    };
    if window.is_visible().unwrap_or(false) {
        let _ = window.hide();
        return;
    }

    if let Ok(size) = window.outer_size() {
        let width = f64::from(size.width);
        let height = f64::from(size.height);
        let x = if click.x >= width {
            click.x - width + 24.0
        } else {
            click.x
        };
        let y = if click.y >= height + 32.0 {
            click.y - height - 8.0
        } else {
            click.y + 28.0
        };
        let _ = window.set_position(PhysicalPosition::new(x.round() as i32, y.round() as i32));
    }

    let _ = window.show();
    let _ = window.set_focus();
    let _ = window.emit("refresh-ports", ());
}

pub fn run() {
    tauri::Builder::default()
        .manage(AppState::default())
        .setup(|app| {
            let menu = MenuBuilder::new(app)
                .text("show", "打开 DevPilot")
                .text("refresh", "刷新端口")
                .separator()
                .text("settings", "设置")
                .separator()
                .text("quit", "退出")
                .build()?;

            let mut tray = TrayIconBuilder::with_id("devpilot-tray")
                .tooltip("DevPilot · 本地开发服务端口")
                .menu(&menu)
                .show_menu_on_left_click(false)
                .on_menu_event(|app, event| match event.id().as_ref() {
                    "show" => {
                        let _ = show_main(app);
                    }
                    "refresh" => {
                        let _ = app.emit("refresh-ports", ());
                    }
                    "settings" => {
                        let _ = show_main(app);
                        let _ = app.emit_to("main", "open-settings", ());
                    }
                    "quit" => {
                        app.state::<AppState>()
                            .quitting
                            .store(true, Ordering::SeqCst);
                        app.exit(0);
                    }
                    _ => {}
                })
                .on_tray_icon_event(|tray, event| {
                    if let TrayIconEvent::Click {
                        button: MouseButton::Left,
                        button_state: MouseButtonState::Up,
                        position,
                        ..
                    } = event
                    {
                        toggle_tray_window(tray.app_handle(), position);
                    }
                });

            if let Some(icon) = app.default_window_icon() {
                tray = tray.icon(icon.clone());
            }
            tray.build(app)?;
            Ok(())
        })
        .on_window_event(|window, event| match event {
            WindowEvent::CloseRequested { api, .. }
                if matches!(window.label(), "main" | "tray")
                    && !window
                        .app_handle()
                        .state::<AppState>()
                        .quitting
                        .load(Ordering::SeqCst) =>
            {
                api.prevent_close();
                let _ = window.hide();
            }
            WindowEvent::Focused(false) if window.label() == "tray" => {
                let _ = window.hide();
            }
            _ => {}
        })
        .invoke_handler(tauri::generate_handler![
            scan_ports,
            terminate_processes,
            get_app_info,
            show_main_window,
            reveal_in_explorer,
            copy_text,
            check_for_updates,
            open_release_url
        ])
        .run(tauri::generate_context!())
        .expect("error while running DevPilot");
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn semantic_versions_compare_numerically() {
        assert!(version_parts("1.10.0") > version_parts("1.9.9"));
        assert_eq!(version_parts("v2.4.1"), vec![2, 4, 1]);
        assert_eq!(version_parts("2.0.0-beta.1"), vec![2, 0, 0, 1]);
    }
}

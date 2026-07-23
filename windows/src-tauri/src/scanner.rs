use crate::model::{PortScanResult, PortUsage, TerminateResult};
use netstat2::{
    iterate_sockets_info, AddressFamilyFlags, ProtocolFlags, ProtocolSocketInfo, TcpState,
};
use std::collections::HashSet;
use std::env;
use std::path::Path;
use std::process::Command;
use sysinfo::{Pid, System, Users};

pub fn scan_ports() -> Result<PortScanResult, String> {
    let address_families = AddressFamilyFlags::IPV4 | AddressFamilyFlags::IPV6;
    let protocols = ProtocolFlags::TCP | ProtocolFlags::UDP;
    let sockets = iterate_sockets_info(address_families, protocols)
        .map_err(|error| format!("无法读取 Windows 网络端点：{error}"))?;

    // A full process refresh is intentional: Windows process CWD, executable, owner and
    // parent data are all needed to reproduce the macOS project-service classification.
    let system = System::new_all();
    let users = Users::new_with_refreshed_list();
    let mut ports = Vec::new();
    let mut raw_socket_count = 0usize;
    let mut seen = HashSet::new();

    for socket in sockets {
        let socket = socket.map_err(|error| format!("读取网络端点失败：{error}"))?;
        raw_socket_count += 1;

        let (protocol_name, address, port, state) = match socket.protocol_socket_info {
            ProtocolSocketInfo::Tcp(tcp) if tcp.state == TcpState::Listen => {
                ("TCP", tcp.local_addr.to_string(), tcp.local_port, "LISTEN")
            }
            ProtocolSocketInfo::Tcp(_) => continue,
            ProtocolSocketInfo::Udp(udp) => ("UDP", udp.local_addr.to_string(), udp.local_port, ""),
        };

        let pids: Vec<u32> = if socket.associated_pids.is_empty() {
            vec![0]
        } else {
            socket.associated_pids
        };

        for pid in pids {
            let identity = (protocol_name, address.clone(), port, pid);
            if !seen.insert(identity) {
                continue;
            }
            ports.push(build_port_usage(
                protocol_name,
                address.clone(),
                port,
                state,
                pid,
                &system,
                &users,
            ));
        }
    }

    ports.sort_by(|left, right| {
        left.port
            .cmp(&right.port)
            .then_with(|| {
                left.command
                    .to_lowercase()
                    .cmp(&right.command.to_lowercase())
            })
            .then_with(|| left.pid.cmp(&right.pid))
    });

    Ok(PortScanResult {
        diagnostic_text: format!(
            "raw {raw_socket_count} sockets, parsed {} ports",
            ports.len()
        ),
        ports,
        raw_socket_count,
    })
}

fn build_port_usage(
    protocol_name: &str,
    address: String,
    port: u16,
    state: &str,
    pid: u32,
    system: &System,
    users: &Users,
) -> PortUsage {
    let process = system.process(Pid::from_u32(pid));
    let command = process
        .map(|process| clean_process_name(process.name().to_string_lossy().as_ref()))
        .unwrap_or_else(|| {
            if pid == 0 {
                "System".into()
            } else {
                "未知进程".into()
            }
        });
    let executable_path = process
        .and_then(|process| process.exe())
        .map(path_to_string)
        .unwrap_or_default();
    let working_directory = process
        .and_then(|process| process.cwd())
        .map(path_to_string)
        .unwrap_or_default();
    let user = process
        .and_then(|process| process.user_id())
        .and_then(|user_id| users.get_user_by_id(user_id))
        .map(|user| user.name().to_owned())
        .unwrap_or_default();
    let parent_command = process
        .and_then(|process| process.parent())
        .and_then(|parent_pid| system.process(parent_pid))
        .map(|parent| clean_process_name(parent.name().to_string_lossy().as_ref()))
        .unwrap_or_default();

    let is_project_service = is_project_service(
        protocol_name,
        state,
        &address,
        pid,
        &user,
        &executable_path,
        &working_directory,
    );

    PortUsage {
        id: format!("{protocol_name}-{port}-{pid}-{address}"),
        command,
        pid,
        user,
        protocol_name: protocol_name.to_owned(),
        address,
        port,
        state: state.to_owned(),
        executable_path,
        working_directory,
        parent_command,
        is_project_service,
    }
}

fn clean_process_name(name: &str) -> String {
    let trimmed = name.trim();
    trimmed
        .strip_suffix(".exe")
        .or_else(|| trimmed.strip_suffix(".EXE"))
        .unwrap_or(trimmed)
        .to_owned()
}

fn path_to_string(path: &Path) -> String {
    path.to_string_lossy().into_owned()
}

fn is_project_service(
    protocol_name: &str,
    state: &str,
    address: &str,
    pid: u32,
    user: &str,
    executable_path: &str,
    working_directory: &str,
) -> bool {
    protocol_name == "TCP"
        && state == "LISTEN"
        && is_local_address(address)
        && pid > 0
        && is_owned_by_current_user(user, working_directory)
        && is_user_executable(executable_path, working_directory)
}

fn is_local_address(address: &str) -> bool {
    matches!(address, "0.0.0.0" | "::" | "::1")
        || address.starts_with("127.")
        || address.eq_ignore_ascii_case("localhost")
}

fn is_owned_by_current_user(user: &str, working_directory: &str) -> bool {
    let current_user = env::var("USERNAME")
        .or_else(|_| env::var("USER"))
        .unwrap_or_default();
    let normalized_owner = normalize_user(user);
    let normalized_current = normalize_user(&current_user);

    if !normalized_owner.is_empty() && normalized_owner == normalized_current {
        return true;
    }

    // Some protected-process metadata lacks an owner. A CWD under USERPROFILE is
    // still strong evidence that a listener belongs to the interactive user.
    let user_profile = env::var("USERPROFILE").unwrap_or_default();
    user.is_empty()
        && !user_profile.is_empty()
        && working_directory
            .to_lowercase()
            .starts_with(&user_profile.to_lowercase())
}

fn normalize_user(user: &str) -> String {
    user.rsplit(['\\', '/'])
        .next()
        .unwrap_or(user)
        .to_lowercase()
}

fn is_user_executable(executable_path: &str, working_directory: &str) -> bool {
    if !working_directory.is_empty() {
        return is_development_directory(working_directory);
    }

    if executable_path.is_empty() {
        return true;
    }

    let executable = normalize_path(executable_path);
    let windows_dir = normalize_path(&env::var("WINDIR").unwrap_or_else(|_| "C:\\Windows".into()));
    let program_data =
        normalize_path(&env::var("PROGRAMDATA").unwrap_or_else(|_| "C:\\ProgramData".into()));
    let program_files =
        normalize_path(&env::var("PROGRAMFILES").unwrap_or_else(|_| "C:\\Program Files".into()));
    let program_files_x86 = normalize_path(
        &env::var("PROGRAMFILES(X86)").unwrap_or_else(|_| "C:\\Program Files (x86)".into()),
    );

    !starts_with_dir(&executable, &windows_dir)
        && !starts_with_dir(&executable, &program_data)
        && !starts_with_dir(&executable, &program_files)
        && !starts_with_dir(&executable, &program_files_x86)
}

fn is_development_directory(path: &str) -> bool {
    let path = normalize_path(path);
    let windows_dir = normalize_path(&env::var("WINDIR").unwrap_or_else(|_| "C:\\Windows".into()));
    let program_data =
        normalize_path(&env::var("PROGRAMDATA").unwrap_or_else(|_| "C:\\ProgramData".into()));
    let program_files =
        normalize_path(&env::var("PROGRAMFILES").unwrap_or_else(|_| "C:\\Program Files".into()));
    let program_files_x86 = normalize_path(
        &env::var("PROGRAMFILES(X86)").unwrap_or_else(|_| "C:\\Program Files (x86)".into()),
    );

    !starts_with_dir(&path, &windows_dir)
        && !starts_with_dir(&path, &program_data)
        && !starts_with_dir(&path, &program_files)
        && !starts_with_dir(&path, &program_files_x86)
        && !path.contains("\\appdata\\")
}

fn normalize_path(path: &str) -> String {
    path.trim_end_matches(['\\', '/'])
        .replace('/', "\\")
        .to_lowercase()
}

fn starts_with_dir(path: &str, parent: &str) -> bool {
    path == parent || path.starts_with(&format!("{parent}\\"))
}

pub fn terminate_processes(pids: Vec<u32>) -> Result<TerminateResult, String> {
    let current_pid = std::process::id();
    let unique_pids: Vec<u32> = pids
        .into_iter()
        .filter(|pid| *pid > 0 && *pid != current_pid)
        .collect::<HashSet<_>>()
        .into_iter()
        .collect();

    let mut terminated = Vec::new();
    let mut errors = Vec::new();
    for pid in unique_pids {
        match terminate_process(pid) {
            Ok(()) => terminated.push(pid),
            Err(error) => errors.push(error),
        }
    }
    terminated.sort_unstable();

    if errors.is_empty() {
        Ok(TerminateResult {
            terminated_pids: terminated,
        })
    } else {
        Err(errors.join("；"))
    }
}

#[cfg(target_os = "windows")]
fn terminate_process(pid: u32) -> Result<(), String> {
    let pid_text = pid.to_string();
    let graceful = Command::new("taskkill.exe")
        .args(["/PID", &pid_text, "/T"])
        .output()
        .map_err(|error| format!("无法关闭 PID {pid}：{error}"))?;
    if graceful.status.success() {
        return Ok(());
    }

    let forced = Command::new("taskkill.exe")
        .args(["/PID", &pid_text, "/T", "/F"])
        .output()
        .map_err(|error| format!("无法关闭 PID {pid}：{error}"))?;
    if forced.status.success() {
        Ok(())
    } else {
        let message = String::from_utf8_lossy(&forced.stderr).trim().to_owned();
        Err(if message.is_empty() {
            format!("关闭 PID {pid} 失败，可能需要管理员权限")
        } else {
            format!("关闭 PID {pid} 失败：{message}")
        })
    }
}

#[cfg(not(target_os = "windows"))]
fn terminate_process(pid: u32) -> Result<(), String> {
    let status = Command::new("kill")
        .args(["-TERM", &pid.to_string()])
        .status()
        .map_err(|error| format!("无法关闭 PID {pid}：{error}"))?;
    status
        .success()
        .then_some(())
        .ok_or_else(|| format!("关闭 PID {pid} 失败"))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn local_addresses_match_windows_listeners() {
        assert!(is_local_address("0.0.0.0"));
        assert!(is_local_address("::"));
        assert!(is_local_address("::1"));
        assert!(is_local_address("127.0.0.1"));
        assert!(!is_local_address("192.168.1.20"));
    }

    #[test]
    fn development_directory_excludes_windows_roots() {
        env::set_var("WINDIR", r"C:\Windows");
        env::set_var("PROGRAMFILES", r"C:\Program Files");
        env::set_var("PROGRAMFILES(X86)", r"C:\Program Files (x86)");
        env::set_var("PROGRAMDATA", r"C:\ProgramData");

        assert!(is_development_directory(r"C:\Users\rose\code\DevPilot"));
        assert!(!is_development_directory(r"C:\Windows\System32"));
        assert!(!is_development_directory(r"C:\Program Files\Docker"));
        assert!(!is_development_directory(
            r"C:\Users\rose\AppData\Local\Programs"
        ));
    }

    #[test]
    fn executable_from_program_files_is_allowed_when_cwd_is_project() {
        env::set_var("USERNAME", "rose");
        assert!(is_project_service(
            "TCP",
            "LISTEN",
            "127.0.0.1",
            42,
            "DESKTOP\\rose",
            r"C:\Program Files\nodejs\node.exe",
            r"C:\Users\rose\code\site",
        ));
    }

    #[test]
    fn udp_never_counts_as_project_service() {
        env::set_var("USERNAME", "rose");
        assert!(!is_project_service(
            "UDP",
            "",
            "0.0.0.0",
            42,
            "rose",
            r"C:\Users\rose\bin\server.exe",
            r"C:\Users\rose\code\site",
        ));
    }
}

use serde::Serialize;

#[derive(Clone, Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct PortUsage {
    pub id: String,
    pub command: String,
    pub pid: u32,
    pub user: String,
    pub protocol_name: String,
    pub address: String,
    pub port: u16,
    pub state: String,
    pub executable_path: String,
    pub working_directory: String,
    pub parent_command: String,
    pub is_project_service: bool,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct PortScanResult {
    pub ports: Vec<PortUsage>,
    pub raw_socket_count: usize,
    pub diagnostic_text: String,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct TerminateResult {
    pub terminated_pids: Vec<u32>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct AppInfo {
    pub version: String,
    pub build: String,
    pub platform: &'static str,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct UpdateStatus {
    pub current_version: String,
    pub latest_version: String,
    pub has_update: bool,
    pub release_url: String,
}

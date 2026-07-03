import SwiftUI

struct SettingsView: View {
    @AppStorage("portAutoRefresh") private var portAutoRefresh = true
    let checkForUpdates: () -> Void

    init(checkForUpdates: @escaping () -> Void = {}) {
        self.checkForUpdates = checkForUpdates
    }

    var body: some View {
        TabView {
            Form {
                Section("Port") {
                    Toggle("自动刷新端口状态", isOn: $portAutoRefresh)
                    Text("关闭后仍可通过主窗口工具栏手动刷新。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Updates") {
                    LabeledContent("当前版本", value: AppVersionInfo.versionText)
                    LabeledContent("构建版本", value: AppVersionInfo.buildText)

                    Button("检查更新...") {
                        checkForUpdates()
                    }
                }
            }
            .formStyle(.grouped)
            .tabItem {
                Label("General", systemImage: "gearshape")
            }
        }
        .frame(width: 460, height: 260)
        .scenePadding()
    }
}

import SwiftUI

struct SettingsView: View {
    @AppStorage("portAutoRefresh") private var portAutoRefresh = true

    var body: some View {
        TabView {
            Form {
                Section("Port") {
                    Toggle("自动刷新端口状态", isOn: $portAutoRefresh)
                    Text("关闭后仍可通过主窗口工具栏手动刷新。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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

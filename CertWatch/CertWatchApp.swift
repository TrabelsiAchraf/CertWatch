import SwiftUI

// MARK: - CertWatch App
@main
struct CertWatchApp: App {

    @StateObject private var viewModel = CertWatchViewModel()

    var body: some Scene {
        MenuBarExtra {
            PopoverRootView(viewModel: viewModel)
        } label: {
            MenuBarLabel(alertCount: viewModel.alertCount, status: viewModel.overallStatus)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(viewModel: viewModel)
        }
    }

    init() {
        if !UserDefaults.standard.bool(forKey: "hasRequestedNotifications") {
            UserDefaults.standard.set(true, forKey: "hasRequestedNotifications")
            NotificationService.shared.requestAuthorization { granted in
                DispatchQueue.main.async {
                    UserDefaults.standard.set(granted, forKey: "notificationsEnabled")
                }
            }
        }
    }
}

// MARK: - Menu Bar Label
struct MenuBarLabel: View {
    let alertCount: Int
    let status: CertificateStatus

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.menuBarIcon)
            if alertCount > 0 {
                Text("\(alertCount)")
                    .font(.caption2)
            }
        }
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @ObservedObject var viewModel: CertWatchViewModel

    var body: some View {
        Form {
            Section("General") {
                Toggle("Launch at Login", isOn: Binding(
                    get: { viewModel.launchAtLogin },
                    set: { viewModel.toggleLaunchAtLogin($0) }
                ))
            }

            Section("Notifications") {
                Toggle("Enable expiration alerts", isOn: Binding(
                    get: { viewModel.notificationsEnabled },
                    set: { viewModel.toggleNotifications($0) }
                ))

                Text("Alerts at 30 days, 7 days, and 1 day before expiration. Broken profiles trigger an immediate alert.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Button("Send Test Notification") {
                    viewModel.sendTestNotification()
                }
            }

            Section("Data") {
                HStack {
                    Button("Refresh Now") { viewModel.refresh() }
                    Button("Export Report") { viewModel.exportReport() }
                }
                Button("Open Developer Portal") { viewModel.openDeveloperPortal() }
            }

            Section("Keyboard Shortcut") {
                Text("To set a global hotkey: System Settings > Keyboard > Keyboard Shortcuts > App Shortcuts > add CertWatch.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("About") {
                HStack {
                    Text("CertWatch")
                        .fontWeight(.semibold)
                    Spacer()
                    Text("v1.1.0")
                        .foregroundColor(.secondary)
                }
                Text("Silently monitors your Apple Developer certificates and provisioning profiles. Alerts you before expiration.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 400)
    }
}

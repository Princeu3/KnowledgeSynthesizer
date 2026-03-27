import SwiftUI

struct SettingsView: View {
    @State private var backendStatus = "Checking..."
    @State private var isCheckingBackend = false

    var body: some View {
        NavigationStack {
            List {
                Section("Active Platforms") {
                    Label {
                        HStack {
                            Text("Instagram")
                            Spacer()
                            Text("Active")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                    } icon: {
                        Image(systemName: "camera.circle.fill")
                            .foregroundStyle(SourceType.instagram.accentColor)
                    }
                }

                Section("Coming Soon") {
                    ForEach([SourceType.youtube, .github, .website, .twitter, .linkedin], id: \.self) { source in
                        Label {
                            HStack {
                                Text(source.displayName)
                                Spacer()
                                Text("Soon")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        } icon: {
                            Image(systemName: source.iconName)
                                .foregroundStyle(source.accentColor)
                        }
                    }
                }

                Section("Backend") {
                    LabeledContent("Status") {
                        if isCheckingBackend {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(backendStatus == "Connected" ? .green : .red)
                                    .frame(width: 8, height: 8)
                                Text(backendStatus)
                                    .foregroundStyle(backendStatus == "Connected" ? .green : .red)
                            }
                            .font(.caption.weight(.medium))
                        }
                    }
                    LabeledContent("Environment", value: "Production")
                }

                Section("About") {
                    LabeledContent("Version", value: "0.1.0")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .task {
                await checkBackend()
            }
        }
    }

    private func checkBackend() async {
        isCheckingBackend = true
        defer { isCheckingBackend = false }

        do {
            let response = try await APIService.shared.healthCheck()
            backendStatus = response.status == "ok" ? "Connected" : "Error"
        } catch {
            backendStatus = "Offline"
        }
    }
}

#Preview {
    SettingsView()
}

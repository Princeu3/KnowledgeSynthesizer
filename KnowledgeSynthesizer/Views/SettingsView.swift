import SwiftUI

struct SettingsView: View {
    @State private var backendStatus: String = "Checking..."
    @State private var isCheckingBackend = false

    var body: some View {
        NavigationStack {
            List {
                Section("Active Platforms") {
                    HStack {
                        Image(systemName: "camera.circle.fill")
                            .foregroundStyle(Color(hex: "#E1306C"))
                        Text("Instagram")
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Active")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }

                Section("Coming Soon") {
                    ForEach([SourceType.youtube, .github, .website, .twitter, .linkedin], id: \.self) { source in
                        HStack {
                            Image(systemName: source.iconName)
                                .foregroundStyle(Color(hex: source.accentColorHex))
                            Text(source.displayName)
                            Spacer()
                            Text("Soon")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                Section("Backend") {
                    HStack {
                        Text("Status")
                        Spacer()
                        if isCheckingBackend {
                            ProgressView()
                        } else {
                            Text(backendStatus)
                                .font(.caption)
                                .foregroundStyle(backendStatus == "Connected" ? .green : .red)
                        }
                    }
                    LabeledContent("URL", value: "localhost:8000")
                }

                Section("About") {
                    LabeledContent("Version", value: "0.1.0")
                }
            }
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

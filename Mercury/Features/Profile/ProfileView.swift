import SwiftUI

struct ProfileView: View {
    let session: SessionModel

    @State private var trackError: String?
    @State private var isChangingTrack = false
    @State private var isSigningOut = false
    #if DEBUG
    @State private var serverOverride = UserDefaults.standard.string(forKey: AppConfig.baseURLOverrideKey) ?? ""
    #endif

    var body: some View {
        NavigationStack {
            List {
                if let me = session.me {
                    Section("Account") {
                        LabeledContent("Name", value: me.user.name)
                        LabeledContent("Email", value: me.user.email)
                    }

                    Section {
                        Menu {
                            ForEach(Track.allCases) { track in
                                Button(track.displayName) {
                                    Task { await changeTrack(track) }
                                }
                            }
                        } label: {
                            LabeledContent(
                                "Track",
                                value: me.settings?.activeTrack.displayName ?? "—"
                            )
                        }
                        .disabled(isChangingTrack)
                    } header: {
                        Text("Learning")
                    } footer: {
                        if let trackError {
                            Text(trackError).foregroundStyle(.red)
                        }
                    }
                }

                Section {
                    Button(role: .destructive) {
                        Task {
                            isSigningOut = true
                            await session.signOut()
                        }
                    } label: {
                        if isSigningOut {
                            ProgressView().frame(maxWidth: .infinity)
                        } else {
                            Text("Sign Out").frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(isSigningOut)
                }

                #if DEBUG
                Section {
                    TextField("http://localhost:3000", text: $serverOverride)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button("Apply & Sign Out") {
                        applyServerOverride()
                    }
                } header: {
                    Text("Developer: Server Override")
                } footer: {
                    Text("Empty resets to the built-in URL. Applying signs you out; relaunch the app to take effect.")
                }
                #endif

                Section {
                    LabeledContent("Version", value: appVersion)
                }
            }
            .navigationTitle("Profile")
        }
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        return version ?? "1.0"
    }

    private func changeTrack(_ track: Track) async {
        guard !isChangingTrack else { return }
        isChangingTrack = true
        defer { isChangingTrack = false }
        trackError = nil
        do {
            try await session.changeTrack(track)
        } catch {
            trackError = error.localizedDescription
        }
    }

    #if DEBUG
    private func applyServerOverride() {
        let trimmed = serverOverride.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            UserDefaults.standard.removeObject(forKey: AppConfig.baseURLOverrideKey)
        } else {
            UserDefaults.standard.set(trimmed, forKey: AppConfig.baseURLOverrideKey)
        }
        session.forceSignOut()
    }
    #endif
}

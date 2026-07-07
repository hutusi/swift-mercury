import SwiftUI

struct RootView: View {
    let deps: AppDependencies

    var body: some View {
        Group {
            switch deps.session.phase {
            case .loading:
                ProgressView()
            case .failed(let message):
                bootstrapFailure(message)
            case .signedOut:
                AuthFlowView(session: deps.session)
            case .onboardingRequired:
                OnboardingView(session: deps.session)
            case .ready:
                MainTabView(session: deps.session, api: deps.api)
            }
        }
        .task {
            await deps.session.bootstrap()
        }
    }

    private func bootstrapFailure(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Cannot Connect", systemImage: "wifi.exclamationmark")
        } description: {
            Text(message)
        } actions: {
            Button("Retry") {
                Task { await deps.session.bootstrap() }
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

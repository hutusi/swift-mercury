import SwiftUI

struct OnboardingView: View {
    let session: SessionModel

    @State private var selectedTrack: Track?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            // ScrollView, not VStack: at accessibility text sizes the cards
            // overflow the screen and become untappable otherwise.
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("What are you preparing for?")
                        .font(.title2.bold())
                    Text("You can change tracks any time from your profile.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    ForEach(Track.allCases) { track in
                        trackCard(track)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
                .padding()
            }
            .navigationTitle("Choose a Track")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func trackCard(_ track: Track) -> some View {
        Button {
            selectedTrack = track
            Task { await choose(track) }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(track.displayName)
                        .font(.headline)
                    Text(subtitle(for: track))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if selectedTrack == track {
                    ProgressView()
                } else {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.tertiary)
                }
            }
            .padding()
            .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(selectedTrack != nil)
    }

    private func subtitle(for track: Track) -> String {
        switch track {
        case .toeic: String(localized: "Score-focused prep for the TOEIC exam")
        case .ielts: String(localized: "Band-focused prep for the IELTS exam")
        case .business: String(localized: "Everyday workplace English skills")
        }
    }

    private func choose(_ track: Track) async {
        errorMessage = nil
        do {
            try await session.completeOnboarding(track: track)
        } catch {
            errorMessage = error.localizedDescription
            selectedTrack = nil
        }
    }
}

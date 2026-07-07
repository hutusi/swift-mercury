import SwiftUI

struct DashboardView: View {
    @State private var model: DashboardViewModel

    init(api: any MercuryAPI) {
        _model = State(initialValue: DashboardViewModel(api: api))
    }

    var body: some View {
        NavigationStack {
            Group {
                switch model.state {
                case .loading:
                    ProgressView()
                case .failed(let message):
                    ContentUnavailableView {
                        Label("Couldn't Load", systemImage: "wifi.exclamationmark")
                    } description: {
                        Text(message)
                    } actions: {
                        Button("Retry") {
                            Task { await model.reload() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                case .loaded(let dashboard):
                    content(dashboard)
                }
            }
            .navigationTitle("Dashboard")
        }
        .task {
            await model.load()
        }
    }

    private func content(_ dashboard: DashboardResponse) -> some View {
        List {
            Section {
                HStack(spacing: 12) {
                    statTile(
                        value: "\(dashboard.streak)",
                        label: String(localized: "Day Streak"),
                        systemImage: "flame.fill",
                        tint: .orange
                    )
                    statTile(
                        value: "\(dashboard.dueWords)",
                        label: String(localized: "Words Due"),
                        systemImage: "clock.fill",
                        tint: .blue
                    )
                    statTile(
                        value: "\(dashboard.activeMistakes)",
                        label: String(localized: "Mistakes"),
                        systemImage: "exclamationmark.triangle.fill",
                        tint: .red
                    )
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            if dashboard.isNewUser {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Welcome to Mercury!")
                            .font(.headline)
                        Text("Head to the Vocabulary tab to study your first \(dashboard.track.displayName) words.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }

            if let estimate = dashboard.lastExamEstimate {
                Section("Latest Exam Estimate") {
                    Label(estimate.displayText, systemImage: "chart.bar.fill")
                }
            }

            if !dashboard.recentScores.isEmpty {
                Section("Recent Activity") {
                    ForEach(dashboard.recentScores) { score in
                        scoreRow(score)
                    }
                }
            }
        }
        .refreshable {
            await model.load()
        }
    }

    private func statTile(value: String, label: String, systemImage: String, tint: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
            Text(value)
                .font(.title2.bold())
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 12))
    }

    private func scoreRow(_ score: RecentScore) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(score.kind.displayName)
                Text(score.at, format: .relative(presentation: .named))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(scoreText(score))
                .font(.callout.bold())
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }

    private func scoreText(_ score: RecentScore) -> String {
        if let value = score.score, let total = score.total {
            return "\(value)/\(total)"
        }
        if let label = score.scoreLabel {
            return label
        }
        if let estimate = score.estimate {
            return estimate.displayText
        }
        return "—"
    }
}

import SwiftUI

struct VocabOverviewView: View {
    private let api: any MercuryAPI
    @State private var model: VocabOverviewViewModel
    @State private var showStudy = false
    @State private var showQuiz = false

    init(api: any MercuryAPI) {
        self.api = api
        _model = State(initialValue: VocabOverviewViewModel(api: api))
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
                case .loaded(let overview):
                    content(overview)
                }
            }
            .navigationTitle("Vocabulary")
        }
        .task {
            await model.load()
        }
        .fullScreenCover(isPresented: $showStudy) {
            StudySessionView(api: api)
        }
        .fullScreenCover(isPresented: $showQuiz) {
            QuizView(api: api)
        }
        .onChange(of: showStudy) { _, isPresented in
            if !isPresented {
                Task { await model.load() }
            }
        }
        .onChange(of: showQuiz) { _, isPresented in
            if !isPresented {
                Task { await model.load() }
            }
        }
    }

    private func content(_ overview: VocabOverview) -> some View {
        List {
            Section {
                HStack(spacing: 12) {
                    countTile(count: overview.dueCount, label: String(localized: "Due"), tint: .orange)
                    countTile(count: overview.freshCount, label: String(localized: "New"), tint: .blue)
                    countTile(count: overview.learnedCount, label: String(localized: "Learned"), tint: .green)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

                Button {
                    showStudy = true
                } label: {
                    Label(
                        overview.dueCount > 0
                            ? String(localized: "Study (\(overview.dueCount) due)")
                            : String(localized: "Study New Words"),
                        systemImage: "rectangle.on.rectangle.angled"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

                Button {
                    showQuiz = true
                } label: {
                    Label("Quiz", systemImage: "checklist")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            ForEach(model.topicGroups, id: \.topic) { group in
                Section(group.topic.capitalized) {
                    ForEach(group.words) { word in
                        wordRow(word)
                    }
                }
            }
        }
        .refreshable {
            await model.load()
        }
    }

    private func countTile(count: Int, label: String, tint: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(.title3.bold())
                .monospacedDigit()
                .foregroundStyle(tint)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 12))
    }

    private func wordRow(_ entry: OverviewWord) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(entry.word.headword)
                        .font(.body.weight(.medium))
                    Text(entry.word.pos)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(entry.word.translationZh)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if entry.due {
                Text("DUE")
                    .font(.caption2.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.orange.opacity(0.2), in: Capsule())
                    .foregroundStyle(.orange)
            } else if entry.started {
                Image(systemName: "circle.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(.green)
            }
        }
    }
}

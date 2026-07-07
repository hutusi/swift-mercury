import SwiftUI

struct QuizView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var model: QuizViewModel
    @State private var confirmClose = false

    init(api: any MercuryAPI) {
        _model = State(initialValue: QuizViewModel(api: api))
    }

    var body: some View {
        NavigationStack {
            Group {
                switch model.state {
                case .loading, .submitting:
                    ProgressView()
                case .empty:
                    ContentUnavailableView {
                        Label("Not Enough Words", systemImage: "tray")
                    } description: {
                        Text("Study a few more words first, then come back for a quiz.")
                    } actions: {
                        Button("Done") { dismiss() }
                            .buttonStyle(.borderedProminent)
                    }
                case .loadFailed(let message):
                    ContentUnavailableView {
                        Label("Couldn't Load", systemImage: "wifi.exclamationmark")
                    } description: {
                        Text(message)
                    } actions: {
                        Button("Retry") {
                            Task { await model.load() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                case .submitFailed(let message):
                    ContentUnavailableView {
                        Label("Couldn't Submit", systemImage: "wifi.exclamationmark")
                    } description: {
                        Text("\(message) Your answers are saved.")
                    } actions: {
                        Button("Try Again") {
                            Task { await model.submit() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                case .active:
                    questionView
                case .result(let result):
                    resultView(result)
                }
            }
            .navigationTitle(model.state == .active ? model.progressText : "Quiz")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        if model.hasUnsavedProgress {
                            confirmClose = true
                        } else {
                            dismiss()
                        }
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
            .confirmationDialog(
                "Abandon this quiz?",
                isPresented: $confirmClose,
                titleVisibility: .visible
            ) {
                Button("Abandon Quiz", role: .destructive) { dismiss() }
                Button("Keep Going", role: .cancel) {}
            } message: {
                Text("Your answers so far will be discarded.")
            }
        }
        .task {
            await model.load()
        }
        .interactiveDismissDisabled(model.hasUnsavedProgress)
    }

    private var questionView: some View {
        VStack(spacing: 24) {
            if let question = model.currentQuestion {
                VStack(spacing: 8) {
                    Text(question.direction == .en2zh ? "Which meaning matches?" : "Which word matches?")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text(question.prompt)
                        .font(.system(size: 32, weight: .bold))
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 32)

                VStack(spacing: 12) {
                    ForEach(question.options) { option in
                        Button {
                            Task { await model.select(option) }
                        } label: {
                            Text(option.text)
                                .font(.body)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.horizontal)
            }
            Spacer()
        }
    }

    private func resultView(_ result: QuizResult) -> some View {
        List {
            Section {
                VStack(spacing: 8) {
                    Text("\(result.score) / \(result.total)")
                        .font(.system(size: 44, weight: .bold))
                        .monospacedDigit()
                    Text(result.score == result.total
                         ? "Perfect score!"
                         : "Missed words go to your mistakes notebook.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .listRowBackground(Color.clear)
            }

            Section("Review") {
                ForEach(model.questions) { question in
                    reviewRow(question, result: result)
                }
            }

            Section {
                Button {
                    Task { await model.load() }
                } label: {
                    Text("Try Another Quiz")
                        .frame(maxWidth: .infinity)
                }
                Button("Done") { dismiss() }
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func reviewRow(_ question: QuizQuestion, result: QuizResult) -> some View {
        let correct = model.isCorrect(question, in: result)
        return HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(correct ? .green : .red)
            VStack(alignment: .leading, spacing: 2) {
                Text(question.prompt)
                    .font(.body.weight(.medium))
                Text(model.correctText(for: question))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if !correct, let chosen = model.chosenText(for: question) {
                    Text("You chose: \(chosen)")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
    }
}

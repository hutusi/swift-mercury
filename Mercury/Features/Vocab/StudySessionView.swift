import SwiftUI

struct StudySessionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var model: StudySessionViewModel
    @State private var confirmClose = false

    init(api: any MercuryAPI) {
        _model = State(initialValue: StudySessionViewModel(api: api))
    }

    var body: some View {
        NavigationStack {
            Group {
                switch model.state {
                case .loading:
                    ProgressView()
                case .empty:
                    ContentUnavailableView {
                        Label("All Caught Up", systemImage: "checkmark.seal.fill")
                    } description: {
                        Text("No cards are due right now. Come back later!")
                    } actions: {
                        Button("Done") { dismiss() }
                            .buttonStyle(.borderedProminent)
                    }
                case .failed(let message):
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
                case .finished(let reviewed):
                    finishedView(reviewed: reviewed)
                case .studying:
                    studyView
                }
            }
            .navigationTitle(model.state == .studying ? model.progressText : "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        if model.state == .studying && model.hasStartedGrading {
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
                "End this study session?",
                isPresented: $confirmClose,
                titleVisibility: .visible
            ) {
                Button("End Session", role: .destructive) { dismiss() }
                Button("Keep Studying", role: .cancel) {}
            } message: {
                Text("Cards you already graded are saved.")
            }
        }
        .task {
            await model.load()
        }
        .interactiveDismissDisabled(model.state == .studying && model.hasStartedGrading)
    }

    private var studyView: some View {
        // Scrolls so the grade bar stays reachable at accessibility text sizes.
        ScrollView {
            studyContent
        }
    }

    private var studyContent: some View {
        VStack(spacing: 20) {
            if let card = model.currentCard {
                FlashcardView(card: card, isFlipped: model.isFlipped)
                    .padding(.horizontal)
                    .onTapGesture {
                        model.flip()
                    }
                    // One VoiceOver element: tap gestures alone aren't
                    // discoverable or activatable with VoiceOver.
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityHint(
                        model.isFlipped
                            ? Text("Shows the front of the card again.")
                            : Text("Reveals the meaning and examples.")
                    )
            }

            if let error = model.gradeError {
                Text("\(error) — tap a grade to retry.")
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            if model.isFlipped {
                gradeBar
            } else {
                Text("How well did you know it? Flip first.")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .padding(.top)
    }

    private var gradeBar: some View {
        HStack(spacing: 10) {
            gradeButton(.again, tint: .red)
            gradeButton(.hard, tint: .orange)
            gradeButton(.good, tint: .green)
            gradeButton(.easy, tint: .blue)
        }
        .padding(.horizontal)
        .disabled(model.isGrading)
    }

    private func gradeButton(_ grade: Grade, tint: Color) -> some View {
        Button {
            Task { await model.grade(grade) }
        } label: {
            Text(grade.displayName)
                .font(.callout.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.bordered)
        .tint(tint)
    }

    private func finishedView(reviewed: Int) -> some View {
        ContentUnavailableView {
            Label("Session Complete", systemImage: "party.popper.fill")
        } description: {
            Text("You reviewed ^[\(reviewed) word](inflect: true). Keep the streak going!")
        } actions: {
            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
        }
    }
}

import SwiftUI

struct FlashcardView: View {
    let card: StudyCard
    let isFlipped: Bool

    var body: some View {
        ZStack {
            front
                .opacity(isFlipped ? 0 : 1)
                .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
            back
                .opacity(isFlipped ? 1 : 0)
                .rotation3DEffect(.degrees(isFlipped ? 0 : -180), axis: (x: 0, y: 1, z: 0))
        }
        .animation(.spring(duration: 0.4), value: isFlipped)
    }

    private var front: some View {
        cardFace {
            VStack(spacing: 12) {
                if card.isNew {
                    Text("NEW")
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.blue.opacity(0.15), in: Capsule())
                        .foregroundStyle(.blue)
                }
                Text(card.word.headword)
                    .font(.system(size: 40, weight: .bold))
                    .multilineTextAlignment(.center)
                HStack(spacing: 8) {
                    Text(card.word.ipa)
                    Text(card.word.pos)
                }
                .font(.title3)
                .foregroundStyle(.secondary)
                Spacer().frame(height: 8)
                Text("Tap to reveal")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var back: some View {
        cardFace {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(card.word.headword)
                        .font(.title2.bold())
                    Text(card.word.translationZh)
                        .font(.title3)
                }
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    Text(card.word.definitionEn)
                        .font(.body)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(card.word.exampleEn)
                        .font(.callout.italic())
                    Text(card.word.exampleZh)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func cardFace(@ViewBuilder content: () -> some View) -> some View {
        content()
            .padding(24)
            .frame(maxWidth: .infinity, minHeight: 340)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(.quaternary, lineWidth: 1)
            )
    }
}

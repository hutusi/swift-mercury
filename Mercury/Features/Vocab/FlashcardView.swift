import SwiftUI

struct FlashcardView: View {
    let card: StudyCard
    let isFlipped: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var headwordSize = 40.0

    var body: some View {
        ZStack {
            // Both faces stay mounted for the animation, so the invisible one
            // must be explicitly hidden or VoiceOver reads both at once.
            front
                .opacity(isFlipped ? 0 : 1)
                .rotation3DEffect(.degrees(flipDegrees(front: true)), axis: (x: 0, y: 1, z: 0))
                .accessibilityHidden(isFlipped)
            back
                .opacity(isFlipped ? 1 : 0)
                .rotation3DEffect(.degrees(flipDegrees(front: false)), axis: (x: 0, y: 1, z: 0))
                .accessibilityHidden(!isFlipped)
        }
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(duration: 0.4), value: isFlipped)
    }

    /// With Reduce Motion on, the flip degrades to a plain crossfade.
    private func flipDegrees(front: Bool) -> Double {
        guard !reduceMotion else { return 0 }
        if front {
            return isFlipped ? 180 : 0
        }
        return isFlipped ? 0 : -180
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
                    .font(.system(size: headwordSize, weight: .bold))
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

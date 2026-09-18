import SwiftUI

/// A card with a front and a back. The back is reached by a tap on the Watch.
struct CardView: View {
    let card: Card
    let isStarred: Bool
    let isFlipped: Bool

    var body: some View {
        ZStack {
            front
                .opacity(isFlipped ? 0 : 1)
            back
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                .opacity(isFlipped ? 1 : 0)
        }
        .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
        .animation(.spring(duration: 0.45, bounce: 0.2), value: isFlipped)
    }

    private var front: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(card.color.gradient)
            .overlay(alignment: .topTrailing) {
                if isStarred {
                    Image(systemName: "star.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .padding(20)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .overlay(alignment: .bottomLeading) {
                Text(card.title)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(24)
            }
            .shadow(color: card.color.opacity(0.35), radius: 24, y: 12)
    }

    private var back: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(Color(.secondarySystemGroupedBackground))
            .overlay {
                VStack(alignment: .leading, spacing: 12) {
                    Text(card.title)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(card.color)
                    Text(card.note)
                        .font(.body)
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("Tap the Watch to turn back")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(card.color.opacity(0.5), lineWidth: 2)
            }
    }
}

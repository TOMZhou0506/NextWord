import SwiftUI

// BirdPrompt is the survey’s speech bubble
// Used by the learning survey and reusable on other screens later.

struct BirdPrompt: View {
    let text: String

    var body: some View {
        HStack(alignment: .center, spacing: 6) {
            BirdMascot(pose: .wave, size: 88)

            HStack(spacing: 0) {
                // Small triangle pointing at the bird.
                BubbleTail()
                    .fill(Color(.secondarySystemGroupedBackground))
                    .frame(width: 10, height: 16)
                Text(text)
                    .font(.title3.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
            }
        }
    }
}

// BubbleTail is a custom Shape.
private struct BubbleTail: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

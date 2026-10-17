import SwiftUI

// A bird with a short title and explanation, used instead of a plain empty or error message.
// Like ContentUnavailableView, but with the mascot showing the right feeling.
struct BirdMessage: View {
    let pose: BirdMascot.Pose
    let title: String
    var message: String? = nil
    var birdSize: CGFloat = 110

    var body: some View {
        VStack(spacing: 10) {
            BirdMascot(pose: pose, size: birdSize)
            Text(title)
                .font(.headline)
                .multilineTextAlignment(.center)
            if let message {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        // VoiceOver reads the title and message together as one item.
        .accessibilityElement(children: .combine)
    }
}

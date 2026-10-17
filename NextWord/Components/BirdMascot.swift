import SwiftUI

// The blue bird mascot. Each pose matches a feeling, so the bird only appears
// at moments that mean something: welcoming, celebrating, thinking or resting.
struct BirdMascot: View {
    enum Pose {
        case wave        // Welcome and questions
        case celebrate   // Finished a review or mastered a word
        case thinking    // Nothing found or something went wrong
        case sleeping    // Nothing to do right now
        case alarm       // Study reminders
        case magnifier   // Looking up a word
        case flame       // Learning streak
        case reading     // Articles
        case headphones  // Videos

        var imageName: String {
            switch self {
            case .wave: "BirdWave"
            case .celebrate: "BirdCelebrate"
            case .thinking: "BirdThinking"
            case .sleeping: "BirdSleeping"
            case .alarm: "BirdAlarm"
            case .magnifier: "BirdMagnifier"
            case .flame: "BirdFlame"
            case .reading: "BirdReading"
            case .headphones: "BirdHeadphones"
            }
        }
    }

    let pose: Pose
    var size: CGFloat = 120
    // The app's only bird animation: grow from small with a little bounce, used to celebrate.
    var popsIn = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasAppeared = false

    var body: some View {
        Image(pose.imageName)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .scaleEffect(popsIn && !hasAppeared ? 0.3 : 1)
            .opacity(popsIn && !hasAppeared ? 0 : 1)
            .onAppear {
                // Respect the iOS "Reduce Motion" setting: just show the bird without moving it.
                if reduceMotion {
                    hasAppeared = true
                } else {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.55)) { hasAppeared = true }
                }
            }
            // Decoration only; the text next to the bird says what matters.
            .accessibilityHidden(true)
    }
}

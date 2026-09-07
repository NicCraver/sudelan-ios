import Foundation
import SwiftUI

struct DeleteFeedback {
    static func trigger() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    static func triggerSuccess() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    static func triggerLight() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
}

struct DeleteAnimation {
    /// Kept for reference; PhotoSwipeCard now uses velocity springs.
    static let duration: Double = 0.38
    static let exitOffset: CGFloat = UIScreen.main.bounds.width * 1.25
    static let exitOffsetY: CGFloat = -UIScreen.main.bounds.height * 0.45
    static let throwScale: CGFloat = 0.90
}

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
    static let duration: Double = 0.3
    static let exitOffset: CGFloat = UIScreen.main.bounds.width * 1.5
    static let exitOffsetY: CGFloat = -UIScreen.main.bounds.height * 0.8
}

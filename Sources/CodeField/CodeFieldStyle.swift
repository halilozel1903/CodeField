import SwiftUI

/// How the boxes of a ``CodeField`` are drawn.
public enum CodeFieldStyle: Sendable, Hashable, CaseIterable {
    /// Outlined boxes with softly rounded corners.
    case boxed
    /// A line under each character, no box.
    case underline
    /// Filled, generously rounded tiles.
    case rounded
    /// Liquid Glass tiles on iOS 26 and macOS 26, a material fallback on earlier systems.
    case glass

    var spacing: CGFloat {
        switch self {
        case .boxed, .glass: 10
        case .underline: 14
        case .rounded: 8
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .boxed: 10
        case .underline: 0
        case .rounded: 18
        case .glass: 16
        }
    }
}

/// The validation state of a ``CodeField``.
public enum CodeFieldStatus: Sendable, Hashable {
    /// Waiting for input.
    case idle
    /// The code was rejected: the boxes turn red, shake and an error haptic plays.
    case error
    /// The code was accepted: the boxes turn green and a success haptic plays.
    case success

    var color: Color? {
        switch self {
        case .idle: nil
        case .error: .red
        case .success: .green
        }
    }

    var feedback: SensoryFeedback? {
        switch self {
        case .idle: nil
        case .error: .error
        case .success: .success
        }
    }
}

import CodeField
import SwiftUI

/// Scenes used by CI to capture the README screenshots.
/// Launch with `-screenshot <scene>`; normal launches are unaffected.
enum ScreenshotScene: String {
    /// The verification screen with a partially entered code and the caret.
    case filled
    /// A rejected code in the error state.
    case error
    /// Every style side by side.
    case styles

    static var current: ScreenshotScene? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-screenshot"), arguments.indices.contains(index + 1) else {
            return nil
        }
        return ScreenshotScene(rawValue: arguments[index + 1])
    }

    var code: String {
        switch self {
        case .filled: "482"
        case .error: "135790"
        case .styles: ""
        }
    }

    var status: CodeFieldStatus {
        self == .error ? .error : .idle
    }
}

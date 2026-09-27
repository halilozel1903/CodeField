/// The characters a code may contain.
public enum CodeCharacterSet: Sendable, Hashable, CaseIterable {
    /// `0` to `9`. Other scripts' digits (for example full-width `１` or Arabic-Indic `٣`) are converted to ASCII.
    case digits
    /// ASCII letters and digits. Letters are uppercased.
    case alphanumeric

    /// Normalizes a single character, or returns `nil` when it is not allowed.
    func normalize(_ character: Character) -> Character? {
        if character.isNumber, let value = character.wholeNumberValue, (0...9).contains(value) {
            return Character(String(value))
        }
        if self == .alphanumeric, character.isASCII, character.isLetter {
            return Character(character.uppercased())
        }
        return nil
    }
}

/// What a single box of a ``CodeField`` shows.
public enum CodeSlot: Sendable, Hashable {
    /// The box holds a character.
    case filled(Character)
    /// The next character goes here; the caret is drawn in this box.
    case active
    /// The box is waiting for earlier boxes to be filled.
    case empty
}

/// The pure, UI-free logic behind ``CodeField``: sanitizing, filtering, clamping and paste handling.
///
/// `CodeInput` is a value type with no SwiftUI dependency, so you can reuse it with UIKit,
/// AppKit or your own views, and test it without a simulator.
///
/// ```swift
/// var input = CodeInput(length: 6)
/// input.replace(with: "Your code is 482-913")   // value == "482913", isComplete == true
/// ```
public struct CodeInput: Sendable, Hashable {
    /// The supported code lengths.
    public static let lengthRange: ClosedRange<Int> = 4...8

    /// The number of characters in a complete code, clamped to ``lengthRange``.
    public let length: Int
    /// The characters the code may contain.
    public let characterSet: CodeCharacterSet
    /// The sanitized code entered so far. Never longer than ``length``.
    public private(set) var value: String

    /// Creates an input. `length` is clamped to ``lengthRange`` and `value` is sanitized and clamped.
    public init(length: Int = 6, characterSet: CodeCharacterSet = .digits, value: String = "") {
        self.length = Self.clampedLength(length)
        self.characterSet = characterSet
        self.value = ""
        self.value = clamp(Self.sanitize(value, characterSet: characterSet))
    }

    // MARK: - State

    /// The number of characters entered.
    public var count: Int { value.count }

    /// `true` when every box is filled.
    public var isComplete: Bool { value.count == length }

    /// `true` when nothing has been entered.
    public var isEmpty: Bool { value.isEmpty }

    /// The index of the box that receives the next character, or `nil` when the code is complete.
    public var activeIndex: Int? { isComplete ? nil : value.count }

    /// What the box at `index` shows.
    public func slot(at index: Int) -> CodeSlot {
        guard index >= 0, index < length else { return .empty }
        if index < value.count {
            return .filled(value[value.index(value.startIndex, offsetBy: index)])
        }
        return index == value.count ? .active : .empty
    }

    /// Every box, from first to last.
    public var slots: [CodeSlot] { (0..<length).map { slot(at: $0) } }

    /// A VoiceOver description that reveals how much was entered, never the code itself.
    /// For example `"3 of 6 digits entered"`.
    public var accessibilityValue: String {
        let unit = characterSet == .digits ? "digits" : "characters"
        return "\(value.count) of \(length) \(unit) entered"
    }

    // MARK: - Editing

    /// Applies the new contents of a text field to the code.
    ///
    /// - Typed characters are filtered and appended; anything beyond ``length`` is dropped.
    /// - Deletions (backspace) are applied as is.
    /// - When more than one character arrives at once (paste, SMS autofill) and it contains a
    ///   full-length code, that code replaces the current value, even inside a sentence such as
    ///   `"Your code is 482913."`.
    ///
    /// - Returns: `true` when this edit completed the code.
    @discardableResult
    public mutating func replace(with text: String) -> Bool {
        let wasComplete = isComplete
        let isAppend = text.hasPrefix(value)
        let inserted = isAppend ? String(text.dropFirst(value.count)) : text

        if inserted.count > 1, let code = Self.extractCode(from: inserted, length: length, characterSet: characterSet) {
            value = code
        } else if isAppend {
            value = clamp(value + Self.sanitize(inserted, characterSet: characterSet))
        } else {
            value = clamp(Self.sanitize(text, characterSet: characterSet))
        }
        return !wasComplete && isComplete
    }

    /// Pastes text: a full-length code found anywhere in `text` replaces the current value,
    /// otherwise the allowed characters are appended.
    ///
    /// - Returns: `true` when the paste completed the code.
    @discardableResult
    public mutating func paste(_ text: String) -> Bool {
        let wasComplete = isComplete
        if let code = Self.extractCode(from: text, length: length, characterSet: characterSet) {
            value = code
        } else {
            value = clamp(value + Self.sanitize(text, characterSet: characterSet))
        }
        return !wasComplete && isComplete
    }

    /// Appends one character if it is allowed and there is room.
    ///
    /// - Returns: `true` when this character completed the code.
    @discardableResult
    public mutating func append(_ character: Character) -> Bool {
        guard !isComplete, let normalized = characterSet.normalize(character) else { return false }
        value.append(normalized)
        return isComplete
    }

    /// Removes the last character, like the backspace key moving back one box.
    public mutating func deleteBackward() {
        guard !value.isEmpty else { return }
        value.removeLast()
    }

    /// Removes every character.
    public mutating func clear() {
        value = ""
    }

    // MARK: - Pure helpers

    /// Clamps a requested length to ``lengthRange``.
    public static func clampedLength(_ length: Int) -> Int {
        min(max(length, lengthRange.lowerBound), lengthRange.upperBound)
    }

    /// Keeps only the allowed characters of `text`, normalized (ASCII digits, uppercase letters).
    public static func sanitize(_ text: some StringProtocol, characterSet: CodeCharacterSet) -> String {
        var result = ""
        for character in text {
            if let normalized = characterSet.normalize(character) {
                result.append(normalized)
            }
        }
        return result
    }

    /// Finds a code of exactly `length` characters in pasted or autofilled text.
    ///
    /// Whitespace-separated words are tried first, preferring words that contain a digit and
    /// words written in capitals (`"Your code is AB12CD"` gives `"AB12CD"`). If no word fits,
    /// the whole text is tried, which joins grouped codes such as `"123 456"` or `"123-456"`.
    ///
    /// - Returns: The sanitized code, or `nil` when no full-length code was found.
    public static func extractCode(from text: some StringProtocol, length: Int, characterSet: CodeCharacterSet) -> String? {
        let length = clampedLength(length)
        var best: (code: String, score: Int)?
        for word in text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }) {
            let code = sanitize(word, characterSet: characterSet)
            guard code.count == length else { continue }
            var score = 0
            if word.contains(where: { $0.isNumber }) { score += 2 }
            if !word.contains(where: { $0.isLowercase }) { score += 1 }
            if best == nil || score > best!.score {
                best = (code, score)
            }
        }
        if let best { return best.code }

        let whole = sanitize(text, characterSet: characterSet)
        return whole.count == length ? whole : nil
    }

    private func clamp(_ text: String) -> String {
        String(text.prefix(length))
    }
}

import SwiftUI

/// A one-time-code and PIN input: a row of boxes backed by a single hidden text field.
///
/// ```swift
/// @State private var code = ""
/// @State private var status: CodeFieldStatus = .idle
///
/// CodeField($code, length: 6, status: status) { code in
///     status = await api.verify(code) ? .success : .error
/// }
/// ```
///
/// - SMS codes are offered above the keyboard (`.textContentType(.oneTimeCode)` on iOS).
/// - Pasting a whole message, such as `"Your code is 482913"`, fills every box.
/// - Backspace moves back one box at a time.
/// - Setting `status` to ``CodeFieldStatus/error`` shakes the boxes and plays an error haptic;
///   ``CodeFieldStatus/success`` turns them green with a success haptic.
/// - VoiceOver reads a single element, for example "Verification code, 3 of 6 digits entered".
public struct CodeField: View {
    @Binding private var code: String
    private let length: Int
    private let characterSet: CodeCharacterSet
    private let style: CodeFieldStyle
    private let isSecure: Bool
    private let status: CodeFieldStatus
    private let autofocus: Bool
    private let onComplete: ((String) -> Void)?

    /// Mirrors the hidden text field, including keystrokes that are rejected afterwards.
    @State private var text: String
    @State private var shakeOffset: CGFloat = 0
    @FocusState private var isFocused: Bool

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Creates a code field.
    ///
    /// - Parameters:
    ///   - code: The entered code. It only ever contains allowed characters and at most `length` of them.
    ///   - length: The number of boxes, from 4 to 8. Values outside that range are clamped.
    ///   - characterSet: Digits only (number pad) or letters and digits.
    ///   - style: How the boxes are drawn.
    ///   - isSecure: Shows dots instead of the characters, for PINs.
    ///   - status: The validation state; drive it from your verification logic.
    ///   - autofocus: Focuses the field (and shows the keyboard) when it appears.
    ///   - onComplete: Called once each time the last box is filled.
    public init(
        _ code: Binding<String>,
        length: Int = 6,
        characterSet: CodeCharacterSet = .digits,
        style: CodeFieldStyle = .boxed,
        isSecure: Bool = false,
        status: CodeFieldStatus = .idle,
        autofocus: Bool = false,
        onComplete: ((String) -> Void)? = nil
    ) {
        let input = CodeInput(length: length, characterSet: characterSet, value: code.wrappedValue)
        _code = code
        _text = State(initialValue: input.value)
        self.length = input.length
        self.characterSet = characterSet
        self.style = style
        self.isSecure = isSecure
        self.status = status
        self.autofocus = autofocus
        self.onComplete = onComplete
    }

    private var input: CodeInput {
        CodeInput(length: length, characterSet: characterSet, value: code)
    }

    public var body: some View {
        let input = self.input
        let showsCaret = isFocused && isEnabled

        ZStack {
            hiddenTextField

            HStack(spacing: style.spacing) {
                ForEach(0..<input.length, id: \.self) { index in
                    CodeSlotView(
                        slot: input.slot(at: index),
                        style: style,
                        isSecure: isSecure,
                        status: status,
                        isFocused: showsCaret
                    )
                }
            }
            .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { isFocused = true }
        .offset(x: shakeOffset)
        .animation(.spring(duration: 0.3, bounce: 0.35), value: input.value)
        .animation(.easeInOut(duration: 0.2), value: status)
        .onChange(of: text) { _, newValue in
            apply(newValue)
        }
        .onChange(of: code) { _, newValue in
            // The binding was changed from outside, for example cleared after an error.
            let normalized = CodeInput(length: length, characterSet: characterSet, value: newValue).value
            if code != normalized { code = normalized }
            if text != normalized { text = normalized }
        }
        .onChange(of: status) { _, newValue in
            if newValue == .error { shake() }
        }
        .sensoryFeedback(trigger: status) { _, newValue in
            newValue.feedback
        }
        .task {
            guard autofocus else { return }
            // Focusing during the first layout pass is ignored on some systems.
            try? await Task.sleep(for: .milliseconds(150))
            isFocused = true
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Verification code"))
        .accessibilityValue(Text(spokenValue(for: input)))
        .accessibilityHint(Text("Double-tap to enter the code."))
        .accessibilityAction { isFocused = true }
    }

    /// The real input: invisible, but it owns the keyboard, autofill and paste.
    private var hiddenTextField: some View {
        TextField("", text: $text)
            .textFieldStyle(.plain)
            .codeFieldInputTraits(characterSet)
            .focused($isFocused)
            .foregroundStyle(.clear)
            .tint(.clear)
            .focusEffectDisabled()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityHidden(true)
    }

    private func apply(_ newText: String) {
        var updated = input
        let didComplete = updated.replace(with: newText)
        if code != updated.value { code = updated.value }
        if text != updated.value { text = updated.value }
        if didComplete { onComplete?(updated.value) }
    }

    private func shake() {
        guard !reduceMotion else { return }
        Task {
            for offset in [-12, 10, -8, 6, -3, 0] as [CGFloat] {
                withAnimation(.easeInOut(duration: 0.06)) { shakeOffset = offset }
                try? await Task.sleep(for: .milliseconds(60))
            }
        }
    }

    private func spokenValue(for input: CodeInput) -> String {
        switch status {
        case .idle: input.accessibilityValue
        case .error: input.accessibilityValue + ", incorrect code"
        case .success: input.accessibilityValue + ", code accepted"
        }
    }
}

extension View {
    /// Keyboard, autofill and capitalization for the hidden text field.
    func codeFieldInputTraits(_ characterSet: CodeCharacterSet) -> some View {
        #if os(iOS)
        return self
            .keyboardType(characterSet == .digits ? UIKeyboardType.numberPad : .asciiCapable)
            .textContentType(.oneTimeCode)
            .textInputAutocapitalization(characterSet == .digits ? TextInputAutocapitalization.never : .characters)
            .autocorrectionDisabled()
        #else
        return self.autocorrectionDisabled()
        #endif
    }
}

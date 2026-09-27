import CodeField
import SwiftUI

/// A typical "enter the code we texted you" screen.
struct VerificationView: View {
    /// The code the fake backend accepts.
    static let validCode = "246810"

    @State private var code: String
    @State private var status: CodeFieldStatus
    @State private var isVerifying = false
    private let autofocus: Bool

    init(code: String = "", status: CodeFieldStatus = .idle, autofocus: Bool = true) {
        _code = State(initialValue: code)
        _status = State(initialValue: status)
        self.autofocus = autofocus
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    header

                    CodeField($code, length: 6, style: .boxed, status: status, autofocus: autofocus) { entered in
                        verify(entered)
                    }
                    .disabled(status == .success)
                    .padding(.horizontal, 8)

                    statusLine

                    Button("Resend code") {
                        code = ""
                        status = .idle
                    }
                    .font(.subheadline.weight(.semibold))
                    .disabled(isVerifying)

                    Text("Hint: the demo accepts \(Self.validCode).")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                }
                .padding(24)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Verification")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onChange(of: code) { _, newValue in
            // Start over as soon as the user edits a rejected code.
            if status == .error, newValue.count < 6 { status = .idle }
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: "message.badge.filled.fill")
                .font(.system(size: 52))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.tint)
                .padding(.top, 24)
            Text("Enter your code")
                .font(.title.bold())
            Text("We sent a 6-digit code to\n+1 (555) 010-4477")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder
    private var statusLine: some View {
        Group {
            if isVerifying {
                ProgressView()
            } else {
                switch status {
                case .idle:
                    Text("The code expires in 10 minutes.")
                        .foregroundStyle(.secondary)
                case .error:
                    Label("That code didn't match. Try again.", systemImage: "exclamationmark.circle.fill")
                        .foregroundStyle(.red)
                case .success:
                    Label("Verified. Welcome back!", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
        }
        .font(.subheadline.weight(.medium))
        .frame(minHeight: 24)
    }

    private func verify(_ entered: String) {
        isVerifying = true
        Task {
            try? await Task.sleep(for: .milliseconds(700))
            status = entered == Self.validCode ? .success : .error
            isVerifying = false
        }
    }
}

#Preview {
    VerificationView()
}

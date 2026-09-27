import CodeField
import SwiftUI

/// Every style side by side.
struct StylesView: View {
    @State private var boxed: String
    @State private var rounded: String
    @State private var underline: String
    @State private var glass: String
    @State private var success: String

    init(prefilled: Bool = false) {
        _boxed = State(initialValue: prefilled ? "1234" : "")
        _rounded = State(initialValue: prefilled ? "K7Q" : "")
        _underline = State(initialValue: prefilled ? "12" : "")
        _glass = State(initialValue: prefilled ? "90" : "")
        _success = State(initialValue: "552207")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    Demo("Boxed", detail: "6 digits") {
                        CodeField($boxed, length: 6, style: .boxed)
                    }
                    Demo("Rounded", detail: "6 letters or digits") {
                        CodeField($rounded, length: 6, characterSet: .alphanumeric, style: .rounded)
                    }
                    Demo("Underline", detail: "4-digit PIN, secure") {
                        CodeField($underline, length: 4, style: .underline, isSecure: true)
                            .frame(maxWidth: 260)
                    }
                    Demo("Liquid Glass", detail: "Material on iOS 17 and 18") {
                        CodeField($glass, length: 4, style: .glass)
                            .frame(maxWidth: 280)
                            .padding(20)
                            .frame(maxWidth: .infinity)
                            .background(
                                LinearGradient(
                                    colors: [.indigo, .purple, .pink],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                in: RoundedRectangle(cornerRadius: 24, style: .continuous)
                            )
                    }
                    Demo("Success", detail: "status: .success") {
                        CodeField($success, length: 6, style: .rounded, status: .success)
                    }
                }
                .padding(20)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Styles")
        }
    }
}

private struct Demo<Content: View>: View {
    let title: String
    let detail: String
    @ViewBuilder var content: Content

    init(_ title: String, detail: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.detail = detail
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.headline)
                Spacer()
                Text(detail).font(.footnote).foregroundStyle(.secondary)
            }
            content
                .frame(maxWidth: .infinity)
        }
    }
}

#Preview {
    StylesView(prefilled: true)
}

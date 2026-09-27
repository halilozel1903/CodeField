import CodeField
import SwiftUI

enum DemoTab: Hashable {
    case verify
    case styles
}

struct ContentView: View {
    let scene: ScreenshotScene?

    @State private var tab: DemoTab

    init(scene: ScreenshotScene? = nil) {
        self.scene = scene
        _tab = State(initialValue: scene == .styles ? .styles : .verify)
    }

    var body: some View {
        TabView(selection: $tab) {
            VerificationView(
                code: scene?.code ?? "",
                status: scene?.status ?? .idle,
                autofocus: scene == nil || scene == .filled
            )
            .tabItem { Label("Verify", systemImage: "checkmark.shield") }
            .tag(DemoTab.verify)

            StylesView(prefilled: scene == .styles)
                .tabItem { Label("Styles", systemImage: "square.grid.2x2") }
                .tag(DemoTab.styles)
        }
    }
}

#Preview {
    ContentView()
}

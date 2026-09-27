import SwiftUI

/// One box of a ``CodeField``.
struct CodeSlotView: View {
    let slot: CodeSlot
    let style: CodeFieldStyle
    let isSecure: Bool
    let status: CodeFieldStatus
    let isFocused: Bool

    private var isActive: Bool { isFocused && slot == .active }

    private var isFilled: Bool {
        if case .filled = slot { return true }
        return false
    }

    /// Draws a colored outline (or a thicker underline).
    private var isHighlighted: Bool { isActive || status != .idle }

    var body: some View {
        ZStack {
            content
        }
        .frame(maxWidth: 56)
        .frame(height: 60)
        .modifier(SlotBackground(
            style: style,
            stroke: strokeStyle,
            isHighlighted: isHighlighted,
            statusColor: status.color
        ))
        .scaleEffect(isActive ? 1.04 : 1)
        .animation(.spring(duration: 0.25, bounce: 0.3), value: isActive)
    }

    @ViewBuilder
    private var content: some View {
        switch slot {
        case let .filled(character):
            Group {
                if isSecure {
                    Circle()
                        .fill(foregroundStyle)
                        .frame(width: 12, height: 12)
                } else {
                    Text(String(character))
                        .font(.system(.title2, design: .rounded, weight: .semibold))
                        .monospacedDigit()
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .foregroundStyle(foregroundStyle)
                }
            }
            .transition(.scale(scale: 0.5).combined(with: .opacity))
        case .active:
            if isFocused {
                CaretView(color: status.color)
            }
        case .empty:
            EmptyView()
        }
    }

    private var foregroundStyle: AnyShapeStyle {
        if let color = status.color { return AnyShapeStyle(color) }
        return AnyShapeStyle(.primary)
    }

    private var strokeStyle: AnyShapeStyle {
        if let color = status.color { return AnyShapeStyle(color) }
        if isActive { return AnyShapeStyle(.tint) }
        return AnyShapeStyle(Color.secondary.opacity(isFilled ? 0.55 : 0.3))
    }
}

/// The per-style background of a box.
private struct SlotBackground: ViewModifier {
    let style: CodeFieldStyle
    let stroke: AnyShapeStyle
    let isHighlighted: Bool
    let statusColor: Color?

    @ViewBuilder
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
        let lineWidth: CGFloat = isHighlighted ? 2 : 1
        let wash = statusColor?.opacity(0.1) ?? Color.clear

        switch style {
        case .boxed:
            content
                .background(wash, in: shape)
                .overlay(shape.strokeBorder(stroke, lineWidth: lineWidth))
        case .underline:
            content
                .overlay(alignment: .bottom) {
                    Capsule()
                        .fill(stroke)
                        .frame(height: isHighlighted ? 3 : 2)
                }
        case .rounded:
            content
                .background(statusColor?.opacity(0.12) ?? Color.secondary.opacity(0.12), in: shape)
                .overlay(shape.strokeBorder(stroke, lineWidth: isHighlighted ? 2 : 0))
        case .glass:
            if #available(iOS 26.0, macOS 26.0, *) {
                content
                    .glassEffect(.regular.tint(statusColor?.opacity(0.2) ?? .clear).interactive(), in: shape)
                    .overlay(shape.strokeBorder(stroke, lineWidth: isHighlighted ? 2 : 0))
            } else {
                content
                    .background(.ultraThinMaterial, in: shape)
                    .background(wash, in: shape)
                    .overlay(shape.strokeBorder(isHighlighted ? stroke : AnyShapeStyle(Color.white.opacity(0.25)), lineWidth: isHighlighted ? 2 : 0.5))
                    .shadow(color: .black.opacity(0.1), radius: 10, y: 4)
            }
        }
    }
}

/// A blinking bar drawn in the active box.
private struct CaretView: View {
    let color: Color?

    @State private var isVisible = true

    var body: some View {
        Capsule()
            .fill(color.map { AnyShapeStyle($0) } ?? AnyShapeStyle(.tint))
            .frame(width: 2.5, height: 28)
            .opacity(isVisible ? 1 : 0)
            .task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(530))
                    withAnimation(.easeInOut(duration: 0.18)) { isVisible.toggle() }
                }
            }
    }
}

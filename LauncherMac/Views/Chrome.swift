import AppKit
import SwiftUI

struct LauncherBackground: View {
    var body: some View {
        ZStack {
            VisualEffectView(material: .underWindowBackground, blendingMode: .behindWindow)

            LinearGradient(
                stops: [
                    .init(color: Color(red: 0.05, green: 0.08, blue: 0.26), location: 0),
                    .init(color: Color(red: 0.15, green: 0.11, blue: 0.42), location: 0.55),
                    .init(color: Color(red: 0.32, green: 0.10, blue: 0.38), location: 1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .opacity(0.84)

            RadialGradient(
                colors: [Color.white.opacity(0.10), .clear],
                center: .top,
                startRadius: 10,
                endRadius: 720
            )
        }
        .ignoresSafeArea()
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

struct SearchBar: View {
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding
    var onSubmit: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.55))

            TextField("Search Applications", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .foregroundStyle(.white)
                .focused(isFocused)
                .onSubmit(onSubmit)

            if !text.isEmpty {
                Button {
                    text = ""
                    isFocused.wrappedValue = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.white.opacity(0.55))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 38)
        .background(Capsule(style: .continuous).fill(Color.white.opacity(0.14)))
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
        )
    }
}

struct PageDots: View {
    let count: Int
    let current: Int
    let onSelect: (Int) -> Void

    var body: some View {
        HStack(spacing: 9) {
            ForEach(0 ..< count, id: \.self) { index in
                Circle()
                    .fill(Color.white.opacity(index == current ? 0.9 : 0.28))
                    .frame(width: 7, height: 7)
                    .contentShape(Rectangle())
                    .onTapGesture { onSelect(index) }
            }
        }
        .padding(.vertical, 6)
    }
}

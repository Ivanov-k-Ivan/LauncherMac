import AppKit
import SwiftUI

struct LauncherBackground: View {
    let shape: RoundedRectangle

    var body: some View {
        ZStack {
            VisualEffectView(material: .fullScreenUI, blendingMode: .behindWindow)

            Color.black.opacity(0.0)
        }
        .clipShape(shape)
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
        HStack(spacing: 14) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.white.opacity(0.72))
                .frame(width: 24)

            ZStack(alignment: .leading) {
                if text.isEmpty {
                    Text("Spotlight Search")
                        .font(.system(size: 22, weight: .regular))
                        .foregroundStyle(.white.opacity(0.9))
                        .offset(x: 7)
                        .allowsHitTesting(false)
                }

                TextField("", text: $text)
                    .textFieldStyle(.plain)
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(.white)
                    .tint(.white.opacity(0.75))
                    .focused(isFocused)
                    .onSubmit(onSubmit)
                    .accessibilityLabel("Search applications")
            }

            if !text.isEmpty {
                Button {
                    text = ""
                    isFocused.wrappedValue = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.55))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(height: 40)
    }
}

struct CapsuleSearchBar: View {
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

struct CategoryChips: View {
    let categories: [AppCategory]
    @Binding var selection: AppCategory?

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(categories) { category in
                    let isSelected = selection == category
                    Button {
                        withAnimation(.easeOut(duration: 0.16)) {
                            selection = isSelected ? nil : category
                        }
                    } label: {
                        Text(category.title)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(isSelected ? 1 : 0.82))
                            .padding(.horizontal, 14)
                            .frame(height: 32)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color.white.opacity(isSelected ? 0.22 : 0.09))
                            )
                            .overlay(
                                Capsule(style: .continuous)
                                    .strokeBorder(Color.white.opacity(isSelected ? 0.32 : 0.06), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
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

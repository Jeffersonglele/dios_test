import SwiftUI

@available(iOS 17.0, *)
struct NavItem: Identifiable {
    let id: Int
    let icon: String
    let label: String
}

@available(iOS 17.0, *)
struct LiquidGlassNavBar: View {
    let items: [NavItem]
    @Binding var currentIndex: Int
    let onTap: (Int) -> Void

    @Environment(\.colorScheme) private var colorScheme

    private let accent = Color(red: 0.784, green: 0.298, blue: 0.184)

    private var inactiveColor: Color {
        colorScheme == .dark ? .white.opacity(0.55) : .black.opacity(0.42)
    }

    private var activeColor: Color {
        colorScheme == .dark ? .white : accent
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items) { item in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        currentIndex = item.id
                    }
                    onTap(item.id)
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: item.icon)
                            .font(.system(size: 20, weight: .medium))
                        Text(item.label)
                            .font(.system(
                                size: 10,
                                weight: currentIndex == item.id ? .semibold : .medium,
                                design: .rounded
                            ))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .foregroundStyle(currentIndex == item.id ? activeColor : inactiveColor)
                    .frame(maxWidth: 82)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 8)
                    .background {
                        if currentIndex == item.id {
                            activePill
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 72)
        .background { glassBackground }
        .clipShape(Capsule())
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private var glassBackground: some View {
        if #available(iOS 26.0, *) {
            Capsule()
                .glassEffect(
                    .regular.tint(
                        colorScheme == .dark
                            ? .white.opacity(0.08)
                            : accent.opacity(0.08)
                    ),
                    in: .capsule
                )
        } else {
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule().stroke(
                        colorScheme == .dark
                            ? .white.opacity(0.20)
                            : .white.opacity(0.45),
                        lineWidth: 0.8
                    )
                )
        }
    }

    @ViewBuilder
    private var activePill: some View {
        if #available(iOS 26.0, *) {
            Capsule()
                .glassEffect(.regular.tint(activeColor.opacity(0.12)), in: .capsule)
        } else {
            Capsule()
                .fill(accent.opacity(0.14))
                .overlay(Capsule().stroke(accent.opacity(0.28), lineWidth: 0.8))
        }
    }
}

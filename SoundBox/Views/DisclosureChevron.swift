import SwiftUI

struct DisclosureChevron: View {
    let isExpanded: Bool
    var size: CGFloat = 10

    var body: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(.tertiary)
            .frame(width: 14, height: 14)
            .rotationEffect(.degrees(isExpanded ? 90 : 0))
            .animation(.easeInOut(duration: 0.14), value: isExpanded)
            .accessibilityHidden(true)
    }
}

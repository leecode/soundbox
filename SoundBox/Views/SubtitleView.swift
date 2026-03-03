import SwiftUI

struct SubtitleView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 8) {
            if let subtitle = appState.playerState.currentSubtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.title3)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                    )
            } else {
                // 占位，保持布局稳定
                Text(" ")
                    .font(.title3)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .opacity(0)
            }
        }
        .frame(maxWidth: 600)
    }
}

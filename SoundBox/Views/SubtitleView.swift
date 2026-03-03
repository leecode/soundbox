import SwiftUI

struct SubtitleView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 8) {
            if let subtitle = appState.playerState.currentSubtitle {
                Text(subtitle)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.ultraThinMaterial)
                    )
            } else {
                Text("")
                    .frame(height: 60)
            }
        }
        .frame(maxWidth: 500)
    }
}

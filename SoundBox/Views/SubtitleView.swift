import SwiftUI

struct SubtitleView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            if let subtitle = appState.playerState.currentSubtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.title3)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    }
            } else {
                Text(" ")
                    .font(.title3)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .opacity(0)
            }
        }
        .frame(maxWidth: 760)
    }
}

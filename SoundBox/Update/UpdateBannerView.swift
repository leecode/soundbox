import SwiftUI

struct UpdateBannerView: View {
    @EnvironmentObject var updateManager: UpdateManager

    var body: some View {
        VStack(spacing: 0) {
            if let release = updateManager.updateAvailable {
                bannerContent(
                    icon: "arrow.triangle.2.circlepath",
                    iconColor: .accentColor,
                    text: "新版本 \(stripVPrefix(release.tagName)) 可用",
                    showDownload: true
                ) {
                    updateManager.openReleasePage()
                } dismissAction: {
                    withAnimation(.easeInOut) {
                        updateManager.dismiss()
                    }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            } else if updateManager.isUpToDate {
                bannerContent(
                    icon: "checkmark.circle",
                    iconColor: .green,
                    text: "已是最新版本",
                    showDownload: false
                ) {} dismissAction: {
                    withAnimation(.easeInOut) {
                        updateManager.dismissUpToDate()
                    }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut, value: updateManager.updateAvailable != nil)
        .animation(.easeInOut, value: updateManager.isUpToDate)
    }

    private func bannerContent(
        icon: String,
        iconColor: Color,
        text: String,
        showDownload: Bool,
        downloadAction: @escaping () -> Void,
        dismissAction: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(iconColor)
                .font(.body)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer()

            if showDownload {
                Button(action: downloadAction) {
                    Text("下载")
                        .font(.subheadline)
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("下载新版本")
            }

            Button(action: dismissAction) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("关闭")
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isStaticText)
    }

    private func stripVPrefix(_ tag: String) -> String {
        tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
    }
}

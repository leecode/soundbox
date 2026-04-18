import SwiftUI

/// 台本查看器：显示 .txt 台本内容（支持 Shift-JIS 编码）
struct ScriptView: View {
    let content: String?

    var body: some View {
        VStack(spacing: 0) {
            if let content {
                ScrollView {
                    Text(content)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .textSelection(.enabled)
                }
            } else {
                VStack(spacing: 12) {
                    Spacer()
                    VStack(spacing: 10) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 34))
                            .foregroundStyle(.tertiary)

                        Text("无台本文件")
                            .font(.body)
                            .foregroundStyle(.secondary)

                        Text("未找到与音频文件同名的 .txt 台本文件")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 220)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 18)
                    .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

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
                    Image(systemName: "doc.text")
                        .font(.system(size: 40))
                        .foregroundStyle(.tertiary)

                    Text("无台本文件")
                        .font(.body)
                        .foregroundStyle(.secondary)

                    Text("未找到与音频文件同名的 .txt 台本文件")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

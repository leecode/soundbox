import SwiftUI

struct CompanionControlView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var server: CompanionWebServer

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("手机伴侣", systemImage: "iphone")
                    .font(.headline)

                Spacer()

                Button(server.isRunning ? "停止" : "启动") {
                    if server.isRunning {
                        appState.stopCompanionServer()
                    } else {
                        appState.startCompanionServer()
                    }
                }
                .buttonStyle(.borderedProminent)
            }

            if let urlString = server.urlString {
                Text("在同一 Wi-Fi 的手机浏览器打开：")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Text(urlString)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .lineLimit(1)

                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(urlString, forType: .string)
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    .buttonStyle(.plain)
                    .help("复制地址")
                }
            } else {
                Text("启动后会生成局域网访问地址。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let errorMessage = server.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(14)
        .frame(width: 360)
    }
}

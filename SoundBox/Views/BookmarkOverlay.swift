import SwiftUI

/// 浮层：在当前播放位置添加书签
struct BookmarkOverlay: View {
    let timestamp: TimeInterval
    let onSave: (String) -> Void
    let onCancel: () -> Void

    @State private var label: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 12) {
            Text("添加书签")
                .font(.headline)

            Text(formatTime(timestamp))
                .font(.system(.title3, design: .monospaced))
                .foregroundStyle(.secondary)

            TextField("标签（可选）", text: $label)
                .textFieldStyle(.roundedBorder)
                .focused($isFocused)
                .onSubmit {
                    onSave(label)
                }

            HStack(spacing: 12) {
                Button("取消") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Button("保存") {
                    onSave(label)
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 260)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.2), radius: 12, y: 4)
        .onAppear {
            isFocused = true
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let totalSeconds = Int(time)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

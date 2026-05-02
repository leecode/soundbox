import Foundation
import Network
import AppKit

final class CompanionWebServer: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var urlString: String?
    @Published private(set) var errorMessage: String?

    private var listener: NWListener?
    private let queue = DispatchQueue(label: "com.soundbox.companion.server")
    private let encoder = JSONEncoder()
    private var stateProvider: (() -> CompanionPlaybackState)?
    private var commandHandler: ((CompanionCommand) -> Void)?
    private var accessToken = ""

    func start(
        stateProvider: @escaping () -> CompanionPlaybackState,
        commandHandler: @escaping (CompanionCommand) -> Void
    ) {
        stop()

        self.stateProvider = stateProvider
        self.commandHandler = commandHandler
        self.accessToken = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()

        do {
            let listener = try NWListener(using: .tcp, on: 0)
            self.listener = listener

            listener.stateUpdateHandler = { [weak self] state in
                self?.handleListenerState(state)
            }
            listener.newConnectionHandler = { [weak self] connection in
                self?.handleConnection(connection)
            }
            listener.start(queue: queue)
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = error.localizedDescription
                self.isRunning = false
                self.urlString = nil
            }
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
        DispatchQueue.main.async {
            self.isRunning = false
            self.urlString = nil
            self.errorMessage = nil
        }
    }

    private func handleListenerState(_ state: NWListener.State) {
        switch state {
        case .ready:
            let port = listener?.port?.rawValue ?? 0
            let host = Self.localIPAddress() ?? "127.0.0.1"
            let urlString = "http://\(host):\(port)?token=\(accessToken)"
            DispatchQueue.main.async {
                self.isRunning = true
                self.urlString = urlString
                self.errorMessage = nil
            }
        case .failed(let error):
            DispatchQueue.main.async {
                self.isRunning = false
                self.urlString = nil
                self.errorMessage = error.localizedDescription
            }
        case .cancelled:
            DispatchQueue.main.async {
                self.isRunning = false
                self.urlString = nil
            }
        default:
            break
        }
    }

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: queue)
        receive(on: connection, data: Data())
    }

    private func receive(on connection: NWConnection, data: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] chunk, _, isComplete, error in
            guard let self else { return }
            var requestData = data
            if let chunk {
                requestData.append(chunk)
            }

            if let request = HTTPRequest(data: requestData) {
                self.respond(to: request, on: connection)
                return
            }

            if isComplete || error != nil {
                self.sendResponse(.badRequest(), on: connection)
                return
            }

            self.receive(on: connection, data: requestData)
        }
    }

    private func respond(to request: HTTPRequest, on connection: NWConnection) {
        switch (request.method, request.path) {
        case ("GET", "/"), ("GET", "/index.html"):
            sendResponse(.html(Self.indexHTML), on: connection)
        case ("GET", "/api/state"):
            guard isAuthorized(request) else {
                sendResponse(.unauthorized(), on: connection)
                return
            }
            guard let stateProvider else {
                sendResponse(.json(["error": "server not ready"], status: 503), on: connection)
                return
            }
            do {
                let data = try encoder.encode(stateProvider())
                sendResponse(.data(data, contentType: "application/json; charset=utf-8"), on: connection)
            } catch {
                sendResponse(.json(["error": error.localizedDescription], status: 500), on: connection)
            }
        case ("POST", "/api/command"):
            guard isAuthorized(request) else {
                sendResponse(.unauthorized(), on: connection)
                return
            }
            do {
                let command = try JSONDecoder().decode(CompanionCommand.self, from: request.body)
                commandHandler?(command)
                sendResponse(.json(["ok": true]), on: connection)
            } catch {
                sendResponse(.json(["error": error.localizedDescription], status: 400), on: connection)
            }
        default:
            sendResponse(.notFound(), on: connection)
        }
    }

    private func isAuthorized(_ request: HTTPRequest) -> Bool {
        request.queryItems["token"] == accessToken
    }

    private func sendResponse(_ response: HTTPResponse, on connection: NWConnection) {
        connection.send(content: response.data, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private static func localIPAddress() -> String? {
        var address: String?
        var interfaces: UnsafeMutablePointer<ifaddrs>?

        guard getifaddrs(&interfaces) == 0, let first = interfaces else { return nil }
        defer { freeifaddrs(interfaces) }

        for interface in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let flags = Int32(interface.pointee.ifa_flags)
            let isUp = (flags & IFF_UP) == IFF_UP
            let isLoopback = (flags & IFF_LOOPBACK) == IFF_LOOPBACK
            let addr = interface.pointee.ifa_addr.pointee

            guard isUp, !isLoopback, addr.sa_family == UInt8(AF_INET) else { continue }

            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let result = getnameinfo(
                interface.pointee.ifa_addr,
                socklen_t(addr.sa_len),
                &hostname,
                socklen_t(hostname.count),
                nil,
                0,
                NI_NUMERICHOST
            )

            if result == 0 {
                let candidate = String(cString: hostname)
                if candidate.hasPrefix("192.168.") || candidate.hasPrefix("10.") || candidate.hasPrefix("172.") {
                    address = candidate
                    break
                }
                address = address ?? candidate
            }
        }

        return address
    }
}

private struct HTTPRequest {
    let method: String
    let path: String
    let queryItems: [String: String]
    let body: Data

    init?(data: Data) {
        guard let headerEnd = data.range(of: Data("\r\n\r\n".utf8)) else { return nil }
        let headerData = data[..<headerEnd.lowerBound]
        guard let headerText = String(data: headerData, encoding: .utf8) else { return nil }

        let lines = headerText.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else { return nil }
        let parts = requestLine.split(separator: " ", maxSplits: 2).map(String.init)
        guard parts.count >= 2 else { return nil }

        var contentLength = 0
        for line in lines.dropFirst() {
            let headerParts = line.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            if headerParts.count == 2, headerParts[0].lowercased() == "content-length" {
                contentLength = Int(headerParts[1]) ?? 0
            }
        }

        let bodyStart = headerEnd.upperBound
        guard data.count >= bodyStart + contentLength else { return nil }

        let rawPath = parts[1]
        let components = URLComponents(string: "http://soundbox.local\(rawPath)")

        self.method = parts[0]
        self.path = components?.path ?? rawPath.split(separator: "?", maxSplits: 1).first.map(String.init) ?? "/"
        var queryItems: [String: String] = [:]
        for item in components?.queryItems ?? [] {
            if let value = item.value {
                queryItems[item.name] = value
            }
        }

        self.queryItems = queryItems
        self.body = data[bodyStart..<(bodyStart + contentLength)]
    }
}

private struct HTTPResponse {
    let data: Data

    static func html(_ html: String) -> HTTPResponse {
        data(Data(html.utf8), contentType: "text/html; charset=utf-8")
    }

    static func json(_ object: [String: Any], status: Int = 200) -> HTTPResponse {
        let data = (try? JSONSerialization.data(withJSONObject: object)) ?? Data("{}".utf8)
        return response(status: status, body: data, contentType: "application/json; charset=utf-8")
    }

    static func data(_ body: Data, contentType: String, status: Int = 200) -> HTTPResponse {
        response(status: status, body: body, contentType: contentType)
    }

    static func notFound() -> HTTPResponse {
        response(status: 404, body: Data("Not Found".utf8), contentType: "text/plain; charset=utf-8")
    }

    static func badRequest() -> HTTPResponse {
        response(status: 400, body: Data("Bad Request".utf8), contentType: "text/plain; charset=utf-8")
    }

    static func unauthorized() -> HTTPResponse {
        response(status: 401, body: Data("Unauthorized".utf8), contentType: "text/plain; charset=utf-8")
    }

    private static func response(status: Int, body: Data, contentType: String) -> HTTPResponse {
        let reason = [
            200: "OK",
            400: "Bad Request",
            401: "Unauthorized",
            404: "Not Found",
            500: "Internal Server Error",
            503: "Service Unavailable"
        ][status] ?? "OK"
        let headers = [
            "HTTP/1.1 \(status) \(reason)",
            "Content-Type: \(contentType)",
            "Content-Length: \(body.count)",
            "Cache-Control: no-store",
            "Connection: close",
            "Access-Control-Allow-Origin: *",
            "",
            ""
        ].joined(separator: "\r\n")
        var response = Data(headers.utf8)
        response.append(body)
        return HTTPResponse(data: response)
    }
}

private extension CompanionWebServer {
    static let indexHTML = """
    <!doctype html>
    <html lang="zh-CN">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
      <title>SoundBox Companion</title>
      <style>
        :root {
          color-scheme: light dark;
          --accent: #007aff;
          --bookmark: #ff9500;
          --bg: Canvas;
          --fg: CanvasText;
          --muted: color-mix(in srgb, CanvasText 58%, transparent);
          --line: color-mix(in srgb, CanvasText 14%, transparent);
          --surface: color-mix(in srgb, Canvas 88%, CanvasText 4%);
        }
        * { box-sizing: border-box; }
        body {
          margin: 0;
          min-height: 100vh;
          font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", system-ui, sans-serif;
          background: var(--bg);
          color: var(--fg);
        }
        main {
          width: min(100%, 520px);
          margin: 0 auto;
          padding: max(18px, env(safe-area-inset-top)) 16px max(22px, env(safe-area-inset-bottom));
        }
        header { display: flex; align-items: center; justify-content: space-between; gap: 12px; }
        h1 { margin: 0; font-size: 15px; font-weight: 650; }
        .status { color: var(--muted); font-size: 12px; }
        .track { margin-top: 22px; }
        .title { margin: 0; font-size: 22px; font-weight: 700; line-height: 1.2; }
        .artist { margin-top: 6px; color: var(--muted); font-size: 14px; }
        .subtitle {
          min-height: 128px;
          margin: 24px 0;
          display: grid;
          place-items: center;
          text-align: center;
          font-size: 24px;
          line-height: 1.45;
          font-weight: 600;
          padding: 18px;
          border: 1px solid var(--line);
          border-radius: 12px;
          background: var(--surface);
        }
        .time { display: flex; justify-content: space-between; color: var(--muted); font-variant-numeric: tabular-nums; font-size: 12px; }
        input[type="range"] { width: 100%; accent-color: var(--accent); }
        .controls { display: grid; grid-template-columns: repeat(5, 1fr); gap: 10px; margin: 20px 0 14px; }
        button, select {
          min-height: 44px;
          border: 1px solid var(--line);
          border-radius: 10px;
          background: var(--surface);
          color: var(--fg);
          font: inherit;
        }
        button.primary { background: var(--accent); color: white; border-color: transparent; font-weight: 700; }
        .speed { width: 100%; margin-bottom: 18px; padding: 0 12px; }
        .section-title { margin: 20px 0 8px; font-size: 13px; color: var(--muted); font-weight: 650; }
        .cue {
          width: 100%;
          display: grid;
          grid-template-columns: 54px 1fr;
          gap: 10px;
          text-align: left;
          padding: 10px 0;
          min-height: 44px;
          border: 0;
          border-bottom: 1px solid var(--line);
          border-radius: 0;
          background: transparent;
        }
        .cue.active { color: var(--accent); }
        .cue time { color: var(--muted); font-size: 12px; font-variant-numeric: tabular-nums; }
        .empty { color: var(--muted); font-size: 14px; text-align: center; padding: 24px 0; }
      </style>
    </head>
    <body>
      <main>
        <header>
          <h1>SoundBox</h1>
          <div class="status" id="status">连接中</div>
        </header>

        <section class="track">
          <h2 class="title" id="title">未选择音频</h2>
          <div class="artist" id="artist"></div>
        </section>

        <section class="subtitle" id="subtitle">当前没有字幕</section>

        <div class="time">
          <span id="currentTime">0:00</span>
          <span id="duration">0:00</span>
        </div>
        <input id="progress" type="range" min="0" max="0" value="0" step="0.1">

        <section class="controls">
          <button data-command="previousTrack">上一曲</button>
          <button data-command="backward15">-15s</button>
          <button class="primary" id="playButton" data-command="togglePlayback">播放</button>
          <button data-command="forward15">+15s</button>
          <button data-command="nextTrack">下一曲</button>
        </section>

        <select class="speed" id="speed">
          <option value="0.5">0.5x</option>
          <option value="0.75">0.75x</option>
          <option value="1">1.0x</option>
          <option value="1.25">1.25x</option>
          <option value="1.5">1.5x</option>
          <option value="1.75">1.75x</option>
          <option value="2">2.0x</option>
        </select>

        <button id="bookmark" style="width:100%">添加书签</button>

        <div class="section-title">字幕</div>
        <section id="cues" class="empty">没有可用字幕</section>
      </main>

      <script>
        const $ = (id) => document.getElementById(id);
        const token = new URLSearchParams(window.location.search).get("token") || "";
        let state = null;
        let dragging = false;

        function apiPath(path) {
          return `${path}?token=${encodeURIComponent(token)}`;
        }

        function formatTime(value) {
          const total = Math.max(Math.floor(value || 0), 0);
          const h = Math.floor(total / 3600);
          const m = Math.floor((total % 3600) / 60);
          const s = total % 60;
          return h > 0 ? `${h}:${String(m).padStart(2, "0")}:${String(s).padStart(2, "0")}` : `${m}:${String(s).padStart(2, "0")}`;
        }

        async function command(payload) {
          await fetch(apiPath("/api/command"), {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify(payload)
          });
        }

        async function refresh() {
          try {
            const res = await fetch(apiPath("/api/state"), { cache: "no-store" });
            if (!res.ok) throw new Error(`HTTP ${res.status}`);
            state = await res.json();
            render();
            $("status").textContent = "已连接";
          } catch (error) {
            $("status").textContent = "已断开";
          }
        }

        function render() {
          $("title").textContent = state.trackTitle || "未选择音频";
          $("artist").textContent = state.artist || "";
          $("subtitle").textContent = state.currentSubtitle || "当前没有字幕";
          $("currentTime").textContent = formatTime(state.currentTime);
          $("duration").textContent = formatTime(state.duration);
          $("playButton").textContent = state.playbackState === "playing" ? "暂停" : "播放";
          $("speed").value = String(state.playbackRate || 1);

          const progress = $("progress");
          progress.max = state.duration || 0;
          if (!dragging) progress.value = state.currentTime || 0;

          const cues = $("cues");
          cues.className = "";
          cues.innerHTML = "";
          if (!state.subtitles || state.subtitles.length === 0) {
            cues.className = "empty";
            cues.textContent = "没有可用字幕";
            return;
          }

          for (const cue of state.subtitles) {
            const button = document.createElement("button");
            button.className = `cue${cue.isActive ? " active" : ""}`;
            button.innerHTML = `<time>${formatTime(cue.startTime)}</time><span></span>`;
            button.querySelector("span").textContent = cue.text;
            button.addEventListener("click", () => command({ name: "seek", time: cue.startTime }));
            cues.appendChild(button);
          }
        }

        document.querySelectorAll("[data-command]").forEach((button) => {
          button.addEventListener("click", () => command({ name: button.dataset.command }));
        });
        $("bookmark").addEventListener("click", () => command({ name: "addBookmark", label: "" }));
        $("speed").addEventListener("change", (event) => command({ name: "setRate", rate: Number(event.target.value) }));
        $("progress").addEventListener("pointerdown", () => dragging = true);
        $("progress").addEventListener("pointerup", async (event) => {
          dragging = false;
          await command({ name: "seek", time: Number(event.target.value) });
          refresh();
        });

        refresh();
        setInterval(refresh, 500);
      </script>
    </body>
    </html>
    """
}

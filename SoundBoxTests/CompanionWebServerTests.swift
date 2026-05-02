import XCTest
@testable import SoundBox

final class CompanionWebServerTests: XCTestCase {
    private var server: CompanionWebServer?

    override func tearDown() {
        server?.stop()
        server = nil
        super.tearDown()
    }

    func testStateEndpointRequiresToken() async throws {
        let server = CompanionWebServer()
        self.server = server

        server.start(
            stateProvider: {
                CompanionPlaybackState(
                    trackTitle: "Track A",
                    artist: "Artist",
                    playbackState: "playing",
                    currentTime: 12,
                    duration: 120,
                    playbackRate: 1.25,
                    currentSubtitle: "字幕",
                    subtitles: []
                )
            },
            commandHandler: { _ in }
        )

        let baseURL = try await waitForServerURL(server)
        let authorizedURL = try endpoint("/api/state", from: baseURL, includeToken: true)
        let unauthorizedURL = try endpoint("/api/state", from: baseURL, includeToken: false)

        let (authorizedData, authorizedResponse) = try await URLSession.shared.data(from: authorizedURL)
        XCTAssertEqual((authorizedResponse as? HTTPURLResponse)?.statusCode, 200)

        let state = try JSONDecoder().decode(CompanionPlaybackState.self, from: authorizedData)
        XCTAssertEqual(state.trackTitle, "Track A")
        XCTAssertEqual(state.playbackState, "playing")

        let (_, unauthorizedResponse) = try await URLSession.shared.data(from: unauthorizedURL)
        XCTAssertEqual((unauthorizedResponse as? HTTPURLResponse)?.statusCode, 401)

        let duplicateTokenURL = try endpoint("/api/state", from: baseURL, includeToken: true, extraQueryItems: [
            URLQueryItem(name: "token", value: "bad-token")
        ])
        let (_, duplicateTokenResponse) = try await URLSession.shared.data(from: duplicateTokenURL)
        XCTAssertEqual((duplicateTokenResponse as? HTTPURLResponse)?.statusCode, 401)
    }

    func testCommandEndpointRequiresTokenAndDispatchesCommand() async throws {
        let server = CompanionWebServer()
        self.server = server

        let commandExpectation = expectation(description: "command handled")
        server.start(
            stateProvider: {
                CompanionPlaybackState(
                    trackTitle: "Track A",
                    artist: nil,
                    playbackState: "paused",
                    currentTime: 0,
                    duration: 0,
                    playbackRate: 1,
                    currentSubtitle: nil,
                    subtitles: []
                )
            },
            commandHandler: { command in
                XCTAssertEqual(command.name, "seek")
                XCTAssertEqual(command.time, 42)
                commandExpectation.fulfill()
            }
        )

        let baseURL = try await waitForServerURL(server)
        let authorizedURL = try endpoint("/api/command", from: baseURL, includeToken: true)
        let unauthorizedURL = try endpoint("/api/command", from: baseURL, includeToken: false)
        let body = Data(#"{"name":"seek","time":42}"#.utf8)

        var unauthorizedRequest = URLRequest(url: unauthorizedURL)
        unauthorizedRequest.httpMethod = "POST"
        unauthorizedRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        unauthorizedRequest.httpBody = body
        let (_, unauthorizedResponse) = try await URLSession.shared.data(for: unauthorizedRequest)
        XCTAssertEqual((unauthorizedResponse as? HTTPURLResponse)?.statusCode, 401)

        var authorizedRequest = URLRequest(url: authorizedURL)
        authorizedRequest.httpMethod = "POST"
        authorizedRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        authorizedRequest.httpBody = body
        let (_, authorizedResponse) = try await URLSession.shared.data(for: authorizedRequest)
        XCTAssertEqual((authorizedResponse as? HTTPURLResponse)?.statusCode, 200)

        await fulfillment(of: [commandExpectation], timeout: 2)
    }

    private func waitForServerURL(_ server: CompanionWebServer) async throws -> URL {
        let deadline = Date().addingTimeInterval(2)
        while Date() < deadline {
            if let urlString = server.urlString, let url = URL(string: urlString) {
                return url
            }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTFail("Server did not publish a URL")
        throw URLError(.timedOut)
    }

    private func endpoint(
        _ path: String,
        from baseURL: URL,
        includeToken: Bool,
        extraQueryItems: [URLQueryItem] = []
    ) throws -> URL {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw URLError(.badURL)
        }
        components.path = path
        if !includeToken {
            components.queryItems = nil
        }
        if !extraQueryItems.isEmpty {
            components.queryItems = (components.queryItems ?? []) + extraQueryItems
        }
        guard let url = components.url else {
            throw URLError(.badURL)
        }
        return url
    }
}

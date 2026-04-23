import Foundation
import Testing

@testable import Tajnica_sp

struct LLMRetryPolicyTests {
    @Test
    func honoursRetryAfterHeaderInSeconds() async throws {
        let recorder = SleepRecorder()
        let client = HTTPClientStub(results: [
            .success((
                Data("rate limited".utf8),
                makeResponse(statusCode: 429, headers: ["Retry-After": "2"])
            )),
            .success((Data("ok".utf8), makeResponse(statusCode: 200)))
        ])
        let policy = LLMRetryPolicy(
            maxRetries: 2,
            backoff: { _ in .zero },
            sleep: recorder.sleepClosure
        )

        let data = try await policy.perform(
            sampleRequest(),
            using: client,
            providerLabel: "Sample"
        )

        #expect(String(data: data, encoding: .utf8) == "ok")
        #expect(recorder.recordings == [Duration.seconds(2)])
    }

    @Test
    func capsRetryAfterHeaderAt30Seconds() async throws {
        let recorder = SleepRecorder()
        let client = HTTPClientStub(results: [
            .success((
                Data("rate limited".utf8),
                makeResponse(statusCode: 503, headers: ["Retry-After": "600"])
            )),
            .success((Data("ok".utf8), makeResponse(statusCode: 200)))
        ])
        let policy = LLMRetryPolicy(
            maxRetries: 2,
            backoff: { _ in .zero },
            sleep: recorder.sleepClosure
        )

        _ = try await policy.perform(
            sampleRequest(),
            using: client,
            providerLabel: "Sample"
        )

        #expect(recorder.recordings == [Duration.seconds(30)])
    }

    @Test
    func doesNotRetry4xxClientErrors() async {
        let client = HTTPClientStub(results: [
            .success((Data("bad key".utf8), makeResponse(statusCode: 401)))
        ])
        let policy = LLMRetryPolicy(maxRetries: 5, backoff: { _ in .zero }, sleep: { _ in })

        do {
            _ = try await policy.perform(
                sampleRequest(),
                using: client,
                providerLabel: "Sample"
            )
            Issue.record("Expected a 401 to surface immediately.")
        } catch let error as PlannerServiceError {
            guard case let .api(statusCode, _) = error else {
                Issue.record("Expected API error, got \(error).")
                return
            }
            #expect(statusCode == 401)
            #expect(await client.requestCount() == 1)
        } catch {
            Issue.record("Expected PlannerServiceError, got \(error).")
        }
    }

    @Test
    func retriesNetworkTimeouts() async throws {
        let client = HTTPClientStub(results: [
            .failure(URLError(.timedOut)),
            .success((Data("ok".utf8), makeResponse(statusCode: 200)))
        ])
        let policy = LLMRetryPolicy(maxRetries: 2, backoff: { _ in .zero }, sleep: { _ in })

        let data = try await policy.perform(
            sampleRequest(),
            using: client,
            providerLabel: "Sample"
        )

        #expect(String(data: data, encoding: .utf8) == "ok")
        #expect(await client.requestCount() == 2)
    }
}

private final class SleepRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var samples: [Duration] = []

    var recordings: [Duration] {
        lock.lock()
        defer { lock.unlock() }
        return samples
    }

    var sleepClosure: @Sendable (Duration) async throws -> Void {
        { [weak self] duration in
            guard let self else { return }
            self.lock.lock()
            self.samples.append(duration)
            self.lock.unlock()
        }
    }
}

private actor HTTPClientStub: HTTPClient {
    private var results: [Result<(Data, URLResponse), Error>]
    private var requests: [URLRequest] = []

    init(results: [Result<(Data, URLResponse), Error>]) {
        self.results = results
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        guard !results.isEmpty else {
            throw URLError(.badServerResponse)
        }
        return try results.removeFirst().get()
    }

    func requestCount() -> Int {
        requests.count
    }
}

private func sampleRequest() -> URLRequest {
    URLRequest(url: URL(string: "https://example.test/llm")!)
}

private func makeResponse(statusCode: Int, headers: [String: String] = [:]) -> HTTPURLResponse {
    HTTPURLResponse(
        url: URL(string: "https://example.test/llm")!,
        statusCode: statusCode,
        httpVersion: nil,
        headerFields: headers
    )!
}

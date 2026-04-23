import Foundation

/// Retry policy shared by every LLM provider. Uses exponential backoff with
/// full-jitter and respects `Retry-After` headers (seconds or HTTP-date) so
/// transient 429/5xx responses and common network blips are recovered
/// automatically without surprise cost spikes.
nonisolated struct LLMRetryPolicy: Sendable {
    /// Nanoseconds to sleep before retry attempt `index` (0-based attempt
    /// already failed; index 0 is the first retry). Returning `nil` means
    /// stop retrying.
    typealias BackoffSchedule = @Sendable (_ attempt: Int) -> Duration?

    /// Max number of retries after the initial attempt. A value of 2 means up
    /// to three total requests.
    let maxRetries: Int

    /// Backoff generator. The default is exponential with full jitter capped
    /// at 4 seconds per sleep, starting at 250 ms.
    let backoff: BackoffSchedule

    /// Optional sleep override for tests; default awaits `Task.sleep`.
    let sleep: @Sendable (Duration) async throws -> Void

    /// Optional clock for Retry-After HTTP-date parsing.
    let now: @Sendable () -> Date

    init(
        maxRetries: Int = 2,
        backoff: BackoffSchedule? = nil,
        sleep: (@Sendable (Duration) async throws -> Void)? = nil,
        now: (@Sendable () -> Date)? = nil
    ) {
        self.maxRetries = max(0, maxRetries)
        self.backoff = backoff ?? Self.defaultExponentialBackoff
        self.sleep = sleep ?? { try await Task.sleep(for: $0) }
        self.now = now ?? { Date() }
    }

    /// Fixed schedule useful for tests (zero sleeps, deterministic attempts).
    static func fixed(_ delays: [Duration]) -> LLMRetryPolicy {
        LLMRetryPolicy(
            maxRetries: delays.count,
            backoff: { attempt in
                guard delays.indices.contains(attempt) else { return nil }
                return delays[attempt]
            },
            sleep: { _ in }
        )
    }

    /// Nanosecond-fixed schedule kept for legacy call sites.
    static func fixed(_ delaysNanoseconds: [UInt64]) -> LLMRetryPolicy {
        fixed(delaysNanoseconds.map { Duration.nanoseconds(Int64(clamping: $0)) })
    }

    /// No retries at all.
    static let disabled = LLMRetryPolicy(maxRetries: 0, backoff: { _ in nil })

    @Sendable
    private static func defaultExponentialBackoff(attempt: Int) -> Duration? {
        guard attempt < 2 else { return nil }
        let base: Double = 0.25
        let capped = min(base * pow(2.0, Double(attempt)), 4.0)
        let jittered = Double.random(in: 0...capped)
        return .milliseconds(Int(jittered * 1_000))
    }

    // MARK: - Execution

    /// Executes `request` against `httpClient` with retries and returns the
    /// body on a 2xx response. Non-2xx responses are wrapped in
    /// `PlannerServiceError.api`.
    func perform(
        _ request: URLRequest,
        using httpClient: HTTPClient,
        providerLabel: String
    ) async throws -> Data {
        var attempt = 0

        while true {
            do {
                let (data, response) = try await httpClient.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw PlannerServiceError.invalidResponse
                }

                if (200..<300).contains(httpResponse.statusCode) {
                    return data
                }

                let message = String(data: data, encoding: .utf8) ?? "Unknown \(providerLabel) error"
                let apiError = PlannerServiceError.api(statusCode: httpResponse.statusCode, message: message)

                guard shouldRetry(statusCode: httpResponse.statusCode, attempt: attempt) else {
                    throw apiError
                }

                let delay = delayForRetry(
                    attempt: attempt,
                    retryAfterHeader: httpResponse.value(forHTTPHeaderField: "Retry-After")
                )
                guard let delay else {
                    throw apiError
                }

                try await sleep(delay)
                attempt += 1
            } catch let error as PlannerServiceError {
                throw error
            } catch {
                guard shouldRetry(networkError: error, attempt: attempt),
                      let delay = backoff(attempt) else {
                    throw error
                }

                try await sleep(delay)
                attempt += 1
            }
        }
    }

    // MARK: - Decisions

    private func shouldRetry(statusCode: Int, attempt: Int) -> Bool {
        guard attempt < maxRetries else { return false }
        // 529 is Anthropic's "overloaded" status; the rest are standard
        // retry-safe codes across Gemini, Anthropic, and OpenAI.
        return [408, 425, 429, 500, 502, 503, 504, 529].contains(statusCode)
    }

    private func shouldRetry(networkError: Error, attempt: Int) -> Bool {
        guard attempt < maxRetries else { return false }
        guard let urlError = networkError as? URLError else { return false }
        return [
            .timedOut,
            .cannotFindHost,
            .cannotConnectToHost,
            .dnsLookupFailed,
            .networkConnectionLost,
            .notConnectedToInternet
        ].contains(urlError.code)
    }

    private func delayForRetry(attempt: Int, retryAfterHeader: String?) -> Duration? {
        if let retryAfterHeader, let hinted = parseRetryAfter(retryAfterHeader) {
            return hinted
        }
        return backoff(attempt)
    }

    private func parseRetryAfter(_ value: String) -> Duration? {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        if let seconds = Double(trimmed), seconds >= 0 {
            return .milliseconds(Int(min(seconds, 30.0) * 1_000))
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "GMT")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        if let date = formatter.date(from: trimmed) {
            let interval = max(0, min(date.timeIntervalSince(now()), 30.0))
            return .milliseconds(Int(interval * 1_000))
        }

        return nil
    }
}

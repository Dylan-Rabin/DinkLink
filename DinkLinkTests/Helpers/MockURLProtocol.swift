import Foundation

/// URLProtocol subclass that intercepts all requests made through a URLSession
/// configured with it. Tests register handlers before each request.
final class MockURLProtocol: URLProtocol {

    // Per-request handler: receives the URLRequest, returns (Data, HTTPURLResponse).
    static var requestHandler: ((URLRequest) async throws -> (Data, HTTPURLResponse))?

    // Captured requests for assertion in tests.
    static var capturedRequests: [URLRequest] = []

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        MockURLProtocol.capturedRequests.append(request)
        guard let handler = MockURLProtocol.requestHandler else {
            client?.urlProtocolDidFinishLoading(self)
            return
        }
        let req = request
        Task { [weak self] in
            guard let self else { return }
            do {
                let (data, response) = try await handler(req)
                self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                self.client?.urlProtocol(self, didLoad: data)
                self.client?.urlProtocolDidFinishLoading(self)
            } catch {
                self.client?.urlProtocol(self, didFailWithError: error)
            }
        }
    }

    override func stopLoading() {}
}

extension MockURLProtocol {
    /// Returns a URLSession that routes all requests through MockURLProtocol.
    static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }

    /// Register a simple success JSON response.
    static func succeed(json: String = "[]", statusCode: Int = 200) {
        requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (Data(json.utf8), response)
        }
    }

    /// Register a failure response with a given status code.
    static func fail(statusCode: Int, body: String = "") {
        requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: nil
            )!
            return (Data(body.utf8), response)
        }
    }

    /// Reset state between tests.
    static func reset() {
        requestHandler = nil
        capturedRequests = []
    }
}

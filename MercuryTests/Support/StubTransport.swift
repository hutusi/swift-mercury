import Foundation

@testable import Mercury

final class StubTransport: HTTPTransport {
    private(set) var requests: [URLRequest] = []
    var responder: (URLRequest) throws -> (Data, HTTPURLResponse)

    init(responder: @escaping (URLRequest) throws -> (Data, HTTPURLResponse)) {
        self.responder = responder
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        return try responder(request)
    }
}

func makeHTTPResponse(url: URL, status: Int, headers: [String: String] = [:]) -> HTTPURLResponse {
    HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers)!
}

extension URLRequest {
    /// Decodes the request body as a JSON object for payload assertions.
    var bodyJSON: [String: Any]? {
        httpBody.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
    }
}

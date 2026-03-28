import Foundation

protocol CommentsServiceProtocol {
    func fetchComments(for itemID: UUID) async throws -> [PublicComment]
    func fetchLikes(for commentIDs: [UUID]) async throws -> [CommentLikeRecord]
    func createComment(
        itemID: UUID,
        userID: UUID,
        authorName: String,
        accessToken: String,
        body: String
    ) async throws -> PublicComment
    func likeComment(
        commentID: UUID,
        userID: UUID,
        accessToken: String
    ) async throws
    func unlikeComment(
        commentID: UUID,
        userID: UUID,
        accessToken: String
    ) async throws
}

struct SupabaseCommentsService: CommentsServiceProtocol {
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(session: URLSession = .shared) {
        self.session = session

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)

            if let date = ISO8601DateFormatter.internetDateTimeWithFractionalSeconds.date(from: value) {
                return date
            }

            if let date = ISO8601DateFormatter.internetDateTime.date(from: value) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported date string: \(value)"
            )
        }
        self.decoder = decoder

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
    }

    func fetchComments(for itemID: UUID) async throws -> [PublicComment] {
        var components = URLComponents(
            url: SupabaseConfiguration.restURL.appending(path: "comments"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "select", value: "id,item_id,user_id,author_name,body,created_at"),
            URLQueryItem(name: "item_id", value: "eq.\(itemID.uuidString.lowercased())"),
            URLQueryItem(name: "order", value: "created_at.desc")
        ]

        guard let url = components?.url else {
            throw CommentsServiceError.invalidRequest
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        applyHeaders(to: &request)

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        return try decoder.decode([PublicComment].self, from: data)
    }

    func fetchLikes(for commentIDs: [UUID]) async throws -> [CommentLikeRecord] {
        guard !commentIDs.isEmpty else { return [] }

        let joinedIDs = commentIDs
            .map { $0.uuidString.lowercased() }
            .joined(separator: ",")

        var components = URLComponents(
            url: SupabaseConfiguration.restURL.appending(path: "comment_likes"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "select", value: "id,comment_id,user_id"),
            URLQueryItem(name: "comment_id", value: "in.(\(joinedIDs))")
        ]

        guard let url = components?.url else {
            throw CommentsServiceError.invalidRequest
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        applyHeaders(to: &request)

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        return try decoder.decode([CommentLikeRecord].self, from: data)
    }

    func createComment(
        itemID: UUID,
        userID: UUID,
        authorName: String,
        accessToken: String,
        body: String
    ) async throws -> PublicComment {
        var request = URLRequest(url: SupabaseConfiguration.restURL.appending(path: "comments"))
        request.httpMethod = "POST"
        applyHeaders(to: &request, bearerToken: accessToken)
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")

        let payload = CreateCommentRequest(
            itemID: itemID,
            userID: userID,
            authorName: authorName,
            body: body.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        request.httpBody = try encoder.encode(payload)

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)

        let comments = try decoder.decode([PublicComment].self, from: data)
        guard let createdComment = comments.first else {
            throw CommentsServiceError.emptyResponse
        }

        return createdComment
    }

    func likeComment(
        commentID: UUID,
        userID: UUID,
        accessToken: String
    ) async throws {
        var request = URLRequest(url: SupabaseConfiguration.restURL.appending(path: "comment_likes"))
        request.httpMethod = "POST"
        applyHeaders(to: &request, bearerToken: accessToken)

        let payload = CommentLikePayload(commentID: commentID, userID: userID)
        request.httpBody = try encoder.encode(payload)

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
    }

    func unlikeComment(
        commentID: UUID,
        userID: UUID,
        accessToken: String
    ) async throws {
        var components = URLComponents(
            url: SupabaseConfiguration.restURL.appending(path: "comment_likes"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "comment_id", value: "eq.\(commentID.uuidString.lowercased())"),
            URLQueryItem(name: "user_id", value: "eq.\(userID.uuidString.lowercased())")
        ]

        guard let url = components?.url else {
            throw CommentsServiceError.invalidRequest
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        applyHeaders(to: &request, bearerToken: accessToken)

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
    }

    private func applyHeaders(to request: inout URLRequest, bearerToken: String? = nil) {
        request.setValue(SupabaseConfiguration.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(bearerToken ?? SupabaseConfiguration.publishableKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CommentsServiceError.invalidResponse
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            let message = String(data: data, encoding: .utf8)
            throw CommentsServiceError.requestFailed(statusCode: httpResponse.statusCode, message: message)
        }
    }
}

private struct CommentLikePayload: Encodable {
    let commentID: UUID
    let userID: UUID

    enum CodingKeys: String, CodingKey {
        case commentID = "comment_id"
        case userID = "user_id"
    }
}

enum CommentsServiceError: LocalizedError {
    case invalidRequest
    case invalidResponse
    case emptyResponse
    case requestFailed(statusCode: Int, message: String?)

    var errorDescription: String? {
        switch self {
        case .invalidRequest:
            return "Couldn't create the comments request."
        case .invalidResponse:
            return "The comments service returned an invalid response."
        case .emptyResponse:
            return "The comments service returned no created comment."
        case let .requestFailed(statusCode, message):
            if let message, !message.isEmpty {
                return "Comments request failed (\(statusCode)): \(message)"
            }
            return "Comments request failed with status \(statusCode)."
        }
    }
}

private extension ISO8601DateFormatter {
    static let internetDateTime: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static let internetDateTimeWithFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

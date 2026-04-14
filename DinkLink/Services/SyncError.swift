import Foundation

// Shared error type used across sync services.
enum SyncError: LocalizedError {
    case invalidResponse
    case requestFailed(statusCode: Int, message: String?)
    case notAuthenticated
    case queueReplayFailed(operation: String, statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The server returned an invalid response."
        case let .requestFailed(statusCode, message):
            if let message, !message.isEmpty {
                return "Request failed (\(statusCode)): \(message)"
            }
            return "Request failed with status \(statusCode)."
        case .notAuthenticated:
            return "No active session — sync requires sign-in."
        case let .queueReplayFailed(operation, statusCode):
            return "Queued operation '\(operation)' failed with status \(statusCode)."
        }
    }
}

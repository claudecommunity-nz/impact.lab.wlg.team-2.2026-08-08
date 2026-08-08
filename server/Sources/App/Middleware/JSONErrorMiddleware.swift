// SPDX-License-Identifier: AGPL-3.0-or-later
import Vapor

/// Ensures all errors leave the service as JSON: `{"error":true,"reason":"…"}`.
struct JSONErrorMiddleware: AsyncMiddleware {
    struct ErrorBody: Content {
        let error: Bool
        let reason: String
    }

    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        do {
            return try await next.respond(to: request)
        } catch {
            let status: HTTPStatus
            let reason: String

            if let abort = error as? AbortError {
                status = abort.status
                reason = abort.reason
            } else {
                status = .internalServerError
                reason = request.application.environment.isRelease
                    ? "Something went wrong."
                    : String(describing: error)
            }

            request.logger.report(error: error)

            let body = ErrorBody(error: true, reason: reason)
            let response = Response(status: status)
            try response.content.encode(body, as: .json)
            return response
        }
    }
}

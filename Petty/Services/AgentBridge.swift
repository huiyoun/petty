import Foundation

protocol AgentBridge {
    func send(_ message: String) async throws -> String
}

enum AgentBridgeError: LocalizedError {
    case commandNotFound(String)
    case launchFailed(String)
    case invalidResponse(String)
    case agentFailed(String)

    var errorDescription: String? {
        switch self {
        case .commandNotFound(let command):
            "Agent command not found: \(command)"
        case .launchFailed(let detail):
            "Agent launch failed: \(detail)"
        case .invalidResponse(let preview):
            "Agent returned invalid JSON. \(preview)"
        case .agentFailed(let detail):
            detail
        }
    }
}

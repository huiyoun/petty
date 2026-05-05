import Foundation

struct AgentCommandResponse: Decodable {
    let ok: Bool
    let message: String?
    let error: String?
}

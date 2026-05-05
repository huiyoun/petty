import Foundation

struct ChatMessage: Identifiable, Equatable, Codable {
    enum Role: String, Codable {
        case user
        case assistant
        case system
    }

    let id: UUID
    let role: Role
    let text: String
    let createdAt: Date
    let externalID: String?

    init(
        id: UUID = UUID(),
        role: Role,
        text: String,
        createdAt: Date = Date(),
        externalID: String? = nil
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.createdAt = createdAt
        self.externalID = externalID
    }
}

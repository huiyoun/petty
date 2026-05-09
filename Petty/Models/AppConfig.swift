import Foundation

struct AppConfig: Codable {
    var agent: AgentCommandConfiguration
    var petId: String? = nil
    var chatDisplayName: String? = nil
}

struct AgentCommandConfiguration: Codable {
    var command: String
    var arguments: [String]

    init(command: String, arguments: [String] = []) {
        self.command = command
        self.arguments = arguments
    }
}

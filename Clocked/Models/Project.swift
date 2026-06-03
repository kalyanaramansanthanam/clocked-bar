import Foundation

struct TimeEntry: Codable, Identifiable, Equatable {
    var id: UUID
    var projectName: String
    var startDate: Date
    var endDate: Date
    var seconds: Int
    var note: String

    init(id: UUID = UUID(), projectName: String, startDate: Date, endDate: Date, seconds: Int, note: String = "") {
        self.id = id
        self.projectName = projectName
        self.startDate = startDate
        self.endDate = endDate
        self.seconds = seconds
        self.note = note
    }
}

struct Project: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var totalSeconds: Int
    var entries: [TimeEntry]

    init(id: UUID = UUID(), name: String, totalSeconds: Int = 0, entries: [TimeEntry] = []) {
        self.id = id
        self.name = name
        self.totalSeconds = totalSeconds
        self.entries = entries
    }
}

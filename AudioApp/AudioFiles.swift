import Foundation
import SwiftData

@Model
class RecordingSession {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var duration: Double
    var fileURL: String
    var title: String
    var transcriptionText: String

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        duration: Double,
        fileURL: String,
        title: String,
        transcriptionText: String
    ) {
        self.id = id
        self.createdAt = createdAt
        self.duration = duration
        self.fileURL = fileURL
        self.title = title
        self.transcriptionText = transcriptionText
    }
}

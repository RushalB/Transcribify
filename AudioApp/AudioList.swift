import SwiftUI
import SwiftData

struct VoiceMemoList: View {
    // Fetch all sessions, sorted by date descending
    @Query(sort: \RecordingSession.createdAt, order: .reverse)
    private var sessions: [RecordingSession]
    
    @Environment(\.modelContext) private var context
    
    var body: some View {
        NavigationStack {
            if sessions.isEmpty {
                VStack {
                    Spacer()
                    Text("Tap Record to Transcribe")
                        .font(.title3)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding()
                    Spacer()
                }
                .background(Color.black.ignoresSafeArea())
            } else {
                List {
                    ForEach(sessions) { session in
                        VStack(alignment: .leading) {
                            Text(session.title.isEmpty ? "Untitled" : session.title)
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Text(session.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundColor(.gray)
                            
                            if !session.transcriptionText.isEmpty {
                                Text(session.transcriptionText)
                                    .foregroundColor(.white)
                                    .lineLimit(3)
                            }
                        }
                        .padding()
                        .background(Color.black)
                    }
                    .onDelete(perform: deleteSessions)
                }
                .background(Color.black)
                .navigationTitle("Recordings")
            }
        }
    }
    
    //For testing purposes
    private func addSession() {
        let session = RecordingSession(
            createdAt: Date(),
            duration: 120,
            fileURL: "/path/to/file.caf",
            title: "New Recording",
            transcriptionText: "This is the transcription."
        )
        context.insert(session)
    }
    
    private func deleteSessions(at offsets: IndexSet) {
        for index in offsets {
            context.delete(sessions[index])
        }
    }
}

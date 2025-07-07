import SwiftUI
import SwiftData

struct VoiceMemoList: View {
    @Query(sort: \RecordingSession.createdAt, order: .reverse)
    private var sessions: [RecordingSession]
    
    @Environment(\.modelContext) private var context
    
    var body: some View {
        NavigationStack {
            if sessions.isEmpty {
                VStack {
                    Spacer()
                    Text("Tap Record to Transcribe")
                        .frame(maxWidth: .infinity)
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
                        NavigationLink(destination: SessionDetailView(session: session)) {
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
                                        .lineLimit(1)
                                }
                            }
                            .padding(.vertical)
//                            .frame(maxWidth: .infinity)
                        }
                        .listRowBackground(Color.black)
                    }
                    .onDelete(perform: deleteSessions)
                }
                .scrollContentBackground(.hidden)
                .background(Color.black)
                .navigationTitle("Recordings")


            }
        }
    }
    
    

    
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

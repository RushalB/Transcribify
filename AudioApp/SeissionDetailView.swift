import SwiftUI


struct SessionDetailView: View {
    let session: RecordingSession
    @StateObject private var audioPlayer = AudioPlayer()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(session.title.isEmpty ? "Untitled" : session.title)
                    .font(.largeTitle)
                    .bold()
                    .foregroundColor(.white)

                Text(session.createdAt.formatted(date: .long, time: .shortened))
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                HStack {
                    Button(action: {
                        if audioPlayer.isPlaying {
                            audioPlayer.pause()
                        } else {
                            if let url = URL(string:session.fileURL) {
                                audioPlayer.play(url: url)
                            }
                        }
                    }) {
                        Image(systemName: audioPlayer.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .resizable()
                            .frame(width: 50, height: 50)
                            .foregroundColor(.blue)
                    }

                    Button(action: {
                        audioPlayer.stop()
                    }) {
                        Image(systemName: "stop.circle.fill")
                            .resizable()
                            .frame(width: 50, height: 50)
                            .foregroundColor(.red)
                    }
                }
                .padding(.top, 20)
                
                Text(session.fileURL)
                    .font(.subheadline)
                    .foregroundColor(.gray)

                Divider()

                if session.transcriptionText.isEmpty {
                    Text("No transcription available.")
                        .foregroundColor(.gray)
                } else {
                    Text(session.transcriptionText)
                        .foregroundColor(.white)
                }

                Spacer()

            
            }
            .padding()
        }
        .background(Color.black.ignoresSafeArea())

    }
}

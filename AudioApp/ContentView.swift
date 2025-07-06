import SwiftUI
import AVFoundation
import SwiftData

struct ContentView: View {
    @StateObject private var recorder = AudioEngineRecorder()
    @StateObject private var player = AudioPlayer()
    @State private var isRecording = false
    @State private var currentTranscript: String = ""
    
    @Environment(\.modelContext) private var context

    var body: some View {
        ZStack {
            VStack {
                Text("Transcribify")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding()
                    .foregroundColor(.white)

                VoiceMemoList()

                Button(player.isPlaying ? "Stop Playback" : "Play Recording") {
                    if player.isPlaying {
                        player.stop()
                    } else {
                        player.play(url: recorder.getRecordingURL())



                    }
                }
                .disabled(!FileManager.default.fileExists(atPath: recorder.getRecordingURL().path))
                .padding()
                .foregroundColor(.white)

                Spacer()

            
                    Button(action: {
                        if isRecording {
                            recorder.stopRecording {
                                transcribe(audioFileURL: recorder.getRecordingURL())
                            }
                            
                        } else {
                            recorder.startRecording()
                        }
                        isRecording.toggle()
                    }) {
                        ZStack {
                            Rectangle()
                                .fill(Color.black.opacity(0.4))
                                .frame(height: 100)
                                .edgesIgnoringSafeArea(.all)
                                .cornerRadius(5.0)

                            Circle()
                                .fill(isRecording ? Color.red : Color.green)
                                .frame(width: 60, height: 60)

                            Circle()
                                .stroke(Color.white, lineWidth: 4)
                                .frame(width: 80, height: 80)
                        }
                        .padding(.top, 5.0)
                    }
                
            }
        }
        .background(Color.black.ignoresSafeArea())
    }

    // MARK: - Actions

    func transcribe(audioFileURL: URL) {
    
        let transcriber = Transcribe()
        
        recorder.inspectAudioFile(at: audioFileURL)

        
        
        transcriber.transcribeWithGoogle(fileURL: audioFileURL) { transcript in
            if let text = transcript {
                print("Final transcription: \(text)")
                        addSession(to: context,
                                           title: "Recording \(Date())",
                                           fileURL: audioFileURL.path,
                                           transcription: text)
            } else {
                print("Failed to get transcription")
            }
        }
        

        transcriber.transcribeWithApple(fileURL: audioFileURL ){ transcript in
//        addSession(to: context,
//                           title: "Recording \(Date())",
//                           fileURL: audioFileURL.path,
//                           transcription: transcript)
        print("Received transcript: \(transcript)")
        
        }

    }
    
    
    func addSession(
        to context: ModelContext,
        title: String,
        fileURL: String,
        transcription: String = "",
        duration: Double = 0
    ) {
        let session = RecordingSession(
            createdAt: Date(),
            duration: duration,
            fileURL: fileURL,
            title: title,
            transcriptionText: transcription
        )
        context.insert(session)
    }


}

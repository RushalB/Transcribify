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

                if isRecording {
                    GeometryReader { geo in
                        Path { path in
                            for (i, amp) in recorder.amplitudes.enumerated() {
                                let x = geo.size.width * CGFloat(i) / CGFloat(recorder.amplitudes.count)
                                let y = geo.size.height / 2 - CGFloat(amp) * geo.size.height * 5.0
                                if i == 0 {
                                    path.move(to: CGPoint(x: x, y: y))
                                } else {
                                    path.addLine(to: CGPoint(x: x, y: y))
                                }
                            }
                        }
                        .stroke(Color.white, lineWidth: 1)
                    }
                    .frame(height: 150)
                    .background(.black)
                }


//                Button(player.isPlaying ? "Stop Playback" : "Play Recording") {
//                    if player.isPlaying {
//                        player.stop()
//                    } else {
//                        player.play(url: recorder.getRecordingURL())
//                    }
//                }
//                .disabled(!FileManager.default.fileExists(atPath: recorder.getRecordingURL().path))
//                .padding()
//                .foregroundColor(.white)

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
//                if isRecording {
//                    HStack {
//                        Button(action: {
//                            recorder.pauseRecording() // implement this if needed
//                            isRecording = false
//                        }) {
//                            ZStack {
//                                Rectangle()
//                                    .fill(Color.black.opacity(0.4))
//                                    .frame(height: 100)
//                                    .cornerRadius(5.0)
//
//                                Text("Pause")
//                                    .foregroundColor(.white)
//                                    .font(.title2)
//                            }
//                        }
//
//                        Button(action: {
//                            recorder.stopRecording {
//                                transcribe(audioFileURL: recorder.getRecordingURL())
//                            }
//                            isRecording = false
//                        }) {
//                            ZStack {
//                                
//                                Rectangle()
//                                    .fill(Color.black.opacity(0.4))
//                                    .frame(height: 100)
//                                    .cornerRadius(5.0)
//
//                                Text("Stop")
//                                    .foregroundColor(.white)
//                                    .font(.title2)
//                            }
//                        }
//                        
//
//                    }
//                } else {
//                    Button(action: {
//                        recorder.startRecording()
//                        isRecording = true
//                    }) {
//                        ZStack {
//                            Rectangle()
//                                .fill(Color.black.opacity(0.4))
//                                .frame(height: 100)
//                                .cornerRadius(5.0)
//
//                            Circle()
//                                .fill(Color.green)
//                                .frame(width: 60, height: 60)
//
//                            Circle()
//                                .stroke(Color.white, lineWidth: 4)
//                                .frame(width: 80, height: 80)
//                        }
//                        .padding(.top, 5.0)
//                    }
//                }

                
            }
        }
        .background(Color.black.ignoresSafeArea())
    }



    // MARK: - Actions

    func transcribe(audioFileURL: URL) {
    
        let transcriber = Transcribe()
        
        recorder.inspectAudioFile(at: audioFileURL)

        
        
//        transcriber.transcribeWithGoogle(fileURL: audioFileURL) { transcript in
//            if let text = transcript {
//                print("Final transcription: \(text)")
//                        addSession(to: context,
//                                           title: "Recording \(Date())",
//                                           fileURL: audioFileURL.path,
//                                           transcription: text)
//            } else {
//                print("Failed to get transcription")
//            }
//        }
        

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

//}
#Preview {
    ContentView()
}

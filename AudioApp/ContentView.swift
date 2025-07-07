import SwiftUI
import AVFoundation
import SwiftData

struct ContentView: View {
    @StateObject private var recorder = AudioEngineRecorder()
    @StateObject private var player = AudioPlayer()

    @State private var isTranscribing = false

    
    @Environment(\.modelContext) private var context

    var body: some View {
        ZStack {
            VStack {
                Text("Transcribify")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding([.top, .leading, .trailing])
                    .foregroundColor(.white)
                Text("Record. Transcribe. Remember.")
                    .font(.subheadline)
                    .fontWeight(.regular)
                    .foregroundColor(.white)
                //List of Recordings
                
                VoiceMemoList()
                
                //WaveForm
                
                
                
                if recorder.isRecording {
                  WaveformView(amplitudes: recorder.amplitudes)
                }


                Spacer()
                
                //Record Button
                if !recorder.isRecording && !recorder.isPaused {
                        Button(action: {
                            recorder.startRecording()
//                            recorder.isRecording = true
//                            recorder.isPaused = false
                        }) {
                            ZStack{
                                Image(systemName: "circle.fill")
                                    .resizable()
                                    .frame(width: 60, height: 60)
                                    .foregroundColor(.red)
                                Circle()
                                                            .stroke(Color.white, lineWidth: 4)
                                                            .frame(width: 80, height: 80)
                                
                            }
                            
                        }
                        .padding()
                    } else {
                        HStack(spacing: 40) {
                            Button(action: {
                                if recorder.isPaused {
                                    // Resume recording
                                    recorder.resumeRecording()
//                                    recorder.isPaused = false
//                                    recorder.isRecording = true
                                } else {
                                    // Pause recording
                                    recorder.pauseRecording()
//                                    recorder.isPaused = true
                                }
                            }) {
                                Image(systemName: recorder.isPaused ? "play.circle.fill" : "pause.circle.fill")
                                    .resizable()
                                    .frame(width: 60, height: 60)
                                    .foregroundColor(recorder.isPaused ? .green : .orange)
                            }

                            Button(action: {
                                recorder.stopRecording {
                                    transcribe(audioFileURL: recorder.getRecordingURL())
                                }
//                                recorder.isRecording = false
//                                recorder.isPaused = false
                            }) {
                                Image(systemName: "stop.circle.fill")
                                    .resizable()
                                    .frame(width: 60, height: 60)
                                    .foregroundColor(.red)
                            }
                        }
                        .padding()
                    }

            }
            if isTranscribing {
                        Color.black.opacity(0.6)
                            .ignoresSafeArea()

                        ProgressView("Transcribing...")
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.8))
                            .cornerRadius(10)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .contentShape(Rectangle()) // to block taps below
                    }
        }
        .background(Color.black.ignoresSafeArea())
            }

    func transcribe(audioFileURL: URL) {
        
        

        let transcriber = Transcribe()
        Task {
            isTranscribing = true
            var success = false

            for attempt in 1...5 {
                print("Attempt \(attempt)")
                do {
                    let (stitched,_) = try await transcriber.transcribeAndStitchAsync(audioFileURL: audioFileURL)
                    print("Final Transcription:\n\(stitched)")
                            addSession(to: context,
                                       title: "Recording \(Date())",
                                       fileURL: audioFileURL.path,
                                        transcription: stitched)
                    success = true
                    break
                } catch {
                    print("Error: \(error)")
                }
            }

            if !success {
                transcriber.transcribeWithApple(fileURL: audioFileURL ){ transcript in
                addSession(to: context,
                                   title: "Recording \(Date())",
                                   fileURL: audioFileURL.path,
                                   transcription: "Offline Transcription:"+"\n"+transcript)
                print("Apple's transcript: \(transcript)")
                
                
                }
            }
            recorder.isRecording = false
            isTranscribing = false
        }
    }
    
    
    func addSession(
        to context: ModelContext,
        title: String,
        fileURL: String,
        transcription: String = "",
        duration: Double = 0
    ) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        let uniqueFileName = "Recording_\(timestamp).caf"

        let destinationURL = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(uniqueFileName)

        let originalURL = URL(fileURLWithPath: fileURL)

        do {
            try FileManager.default.copyItem(at: originalURL, to: destinationURL)
            print("Audio file copied to: \(destinationURL.path)")
            
            try FileManager.default.setAttributes(
                        [.protectionKey: FileProtectionType.complete],
                        ofItemAtPath: destinationURL.path
                    )
                    print("File protection set to .complete")
            
        } catch {
            print("Failed to copy file: \(error)")
        }
        let session = RecordingSession(
            createdAt: Date(),
            duration: duration,
            fileURL: destinationURL.path,
            title: title,
            transcriptionText: transcription
        )
        context.insert(session)
    }


}



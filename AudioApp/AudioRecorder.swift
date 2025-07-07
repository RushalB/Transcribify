import AVFoundation



class AudioEngineRecorder : ObservableObject {
        private var engine = AVAudioEngine()
        private var file: AVAudioFile?
        @Published var isRecording = false
        @Published var isPaused = false
        @Published var amplitudes: [Float] = []
    


    // Observers for route changes and interuptions
        init() {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleRouteChange),
                name: AVAudioSession.routeChangeNotification,
                object: nil
            )

            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleInterruption),
                name: AVAudioSession.interruptionNotification,
                object: nil
            )
        }
    
    func checkPermissionAndStart() {
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted:
            startRecording()
        case .denied:
            print("Microphone permission denied.")
        case .undetermined:
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                DispatchQueue.main.async {
                    if granted {
                        self.startRecording()
                    } else {
                        print("User denied microphone permission.")
                    }
                }
            }
        @unknown default:
            print("Unknown microphone permission status.")
        }
    }
    func isStorageAvailable(requiredSpaceMB: Double = 5.0) -> Bool {
            let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            do {
                let values = try fileURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
                if let available = values.volumeAvailableCapacityForImportantUsage {
                    let availableMB = Double(available) / (1024 * 1024)
                    if availableMB < requiredSpaceMB {
                        //send this as alert to user
                        print("Not enough storage space (\(String(format: "%.2f", availableMB)) MB available). Please free up space.")
                        return false
                    }
                    return true
                }
            } catch {
                //send this as alert to user
                print("Failed to check disk space: \(error.localizedDescription)")
            }
            return false
        }
    
        func startRecording() {
            guard isStorageAvailable() else {
                print("Insufficient storage space to start recording.")
                return
            }
            
            let session = AVAudioSession.sharedInstance()
                do {
                    try session.setCategory(.playAndRecord, mode: .default, options: [.allowBluetooth, .defaultToSpeaker])
                    try session.setActive(true)
                } catch {
                    print("Failed to set up audio session: \(error)")
                    return
                }
            
            let inputNode = engine.inputNode
            let bus = 0
            let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let fileURL = dir.appendingPathComponent("recording123.caf")
            
            do {
                guard let format = AVAudioFormat(commonFormat: .pcmFormatInt16,
                                                        sampleRate: 48000,
                                                        channels: 1,
                                                        interleaved: true) else {
                           print("Failed to create AVAudioFormat")
                           return
                       }
                
                file = try AVAudioFile(forWriting: fileURL, settings: format.settings)
            } catch {
                print("Error creating audio file: \(error.localizedDescription)")
                return
            }

            inputNode.installTap(onBus: bus, bufferSize: 4096, format: inputNode.outputFormat(forBus: bus)) { buffer, time in
                do {
                    try self.file?.write(from: buffer)
                } catch {
                    print("Error writing buffer: \(error)")
                    DispatchQueue.main.async {
                        self.stopRecording()
                    }
                }
                if let channelData = buffer.floatChannelData?[0] {
                        let frameLength = Int(buffer.frameLength)
                        var rms: Float = 0

                        for i in 0..<frameLength {
                            rms += channelData[i] * channelData[i]
                        }
                        rms = sqrt(rms / Float(frameLength))

                        DispatchQueue.main.async {
                            self.amplitudes.append(rms)
                            if self.amplitudes.count > 100 { // keep last 100 samples
                                self.amplitudes.removeFirst()
                            }
                        }
                    }
            }

            do {
                try engine.start()
                isRecording = true
                print("Recording started")
            } catch {
                print("Engine failed to start: \(error)")
            }
        }

        func stopRecording(completion: (() -> Void)? = nil) {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
            isRecording = false

            print("Recording stopped")
            print(getRecordingURL())
            amplitudes = []
            completion?()
        }
        
        func pauseRecording() {
                engine.pause()
                isPaused = true
                print("Recording paused")
            }

        func resumeRecording() {
            do {
                
                try engine.start()
                isPaused = false
                print("Recording resumed")
            } catch {
                print("Failed to resume recording: \(error)")
            }
        }


        func getRecordingURL() -> URL {
            FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("recording123.caf")
            
        }
    
    
    // ------ Handle Interuptions ---------- //
    
    
    @objc private func handleRouteChange(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }

        switch reason {
        case .oldDeviceUnavailable:
            print("Headphones unplugged, stopping or pausing if needed.")
            if isRecording && !isPaused {
                pauseRecording()
            }
        case .newDeviceAvailable:
            print("New audio device available.")
            if isRecording && isPaused {
                resumeRecording()
            }
        default:
            break
        }
    }

    @objc private func handleInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            print("Audio session interrupted — pausing.")
            if isRecording && !isPaused {
                pauseRecording()
            }
        case .ended:
            print("Interruption ended — resuming.")
            if isRecording && isPaused {
                resumeRecording()
            }
        @unknown default:
            break
        }
    }


    }

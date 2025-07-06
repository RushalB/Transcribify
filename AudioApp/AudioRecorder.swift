import AVFoundation



class AudioEngineRecorder : ObservableObject {
        private var engine = AVAudioEngine()
        private var file: AVAudioFile?
        @Published var isRecording = false
        @Published var isPaused = false

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

    //this is an ios 17.0 issue
//    func checkPermissionAndStart() {
//        switch AVAudioSession.sharedInstance().recordPermission {
//        case .granted:
//            startRecording()
//        case .denied:
//            print("Microphone permission denied.")
//            // Inform user, maybe send a delegate/closure callback
//        case .undetermined:
//            AVAudioSession.sharedInstance().requestRecordPermission { granted in
//                DispatchQueue.main.async {
//                    if granted {
//                        self.startRecording()
//                    } else {
//                        print("User denied microphone permission.")
//                        // Inform user, update UI accordingly
//                    }
//                }
//            }
//        @unknown default:
//            print("Unknown microphone permission status.")
//        }
//    }
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
                // Notify user to free up space
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
            let format = inputNode.outputFormat(forBus: bus)
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

//            let desiredSettings: [String: Any] = [
//                AVFormatIDKey: Int(kAudioFormatLinearPCM),
//                AVSampleRateKey: 16000,
//                AVNumberOfChannelsKey: 1,
//                AVLinearPCMBitDepthKey: 16,
//                AVLinearPCMIsFloatKey: false,
//                AVLinearPCMIsBigEndianKey: false
//            ]
//
//            do {
//                file = try AVAudioFile(forWriting: fileURL, settings: format.settings)
//            } catch {
//                print("Error creating audio file: \(error)")
//                return
//            }

            inputNode.installTap(onBus: bus, bufferSize: 1024, format: inputNode.outputFormat(forBus: bus)) { buffer, time in
                do {
                    try self.file?.write(from: buffer)
                } catch {
                    print("Error writing buffer: \(error)")
                    DispatchQueue.main.async {
                        self.stopRecording()
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
    func inspectAudioFile(at url: URL) {
        do {
            let audioFile = try AVAudioFile(forReading: url)
            let format = audioFile.fileFormat
            
            print("Sample Rate: \(format.sampleRate)")
            print("Channels: \(format.channelCount)")
            print("Common Format: \(format.commonFormat.rawValue)")
            print("Interleaved: \(format.isInterleaved)")
            
            switch format.commonFormat {
            case .pcmFormatInt16:
                print("✅ File is 16-bit signed PCM (LINEAR16) — good for Google.")
            case .pcmFormatInt32:
                print("⚠️ File is 32-bit integer PCM — not what Google expects.")
            case .pcmFormatFloat32:
                print("⚠️ File is 32-bit float PCM — convert to LINEAR16.")
            default:
                print("❓ Unexpected format: \(format.commonFormat)")
            }
            
        } catch {
            print("Error opening audio file: \(error)")
        }
    }
    func printAudioFileInfo(url: URL) {
        do {
            let audioFile = try AVAudioFile(forReading: url)
            let format = audioFile.processingFormat
            let sampleRate = format.sampleRate
            let channels = format.channelCount
            let commonFormat = format.commonFormat

            print("Sample Rate: \(sampleRate) Hz")
            print("Channels: \(channels)")
            print("Common Format: \(commonFormat)")


            let formatSettings = audioFile.fileFormat.settings
            if let formatID = formatSettings[AVFormatIDKey] as? UInt32 {
                switch formatID {
                case kAudioFormatLinearPCM:
                    print("Format: Linear PCM")
                case kAudioFormatULaw:
                    print("Format: µ-law")
                case kAudioFormatALaw:
                    print("Format: A-law")
                default:
                    print("Format ID: \(formatID)")
                }
            }
        } catch {
            print("Failed to read audio file: \(error)")
        }
    }
    
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
//            if isRecording && isPaused {
//                resumeRecording()
//            }
            ///FIx this pausing thingy
            ///

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

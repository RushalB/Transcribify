import Foundation
import AVFoundation
import Speech

class Transcribe {
    private let googleAPIKey = "AIzaSyCgsasLk-8nHA-i9KsPXjJsxE-HeO1XpDA"
    private var player = AudioPlayer()

    
    struct Segment {
        let startTime: CMTime
        let duration: CMTime
    }
    
    private var segmentResults: [Int: String] = [:]
    private var totalSegments = 0
    private var fullAudioURL: URL!
    private var transcriptOutputURL: URL?

    func reset() {
        segmentResults = [:]
        totalSegments = 0
    }

//    func transcribeSegmentsFromFile(fullAudioURL: URL, transcriptOutputURL: URL, completion: @escaping (String) -> Void) {
//        reset()
//        self.fullAudioURL = fullAudioURL
//        self.transcriptOutputURL = transcriptOutputURL
//        
//        split(audioFileURL: fullAudioURL, segmentDuration: 3.0) { segments, error in
//            guard let segments = segments, error == nil else {
//                print("Error splitting audio: \(error!)")
//                completion("")
//                return
//            }
//            
//            self.totalSegments = segments.count
//            let asset = AVAsset(url: fullAudioURL)
//            let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
//            
//            let group = DispatchGroup()
//            let queue = OperationQueue()
//            queue.maxConcurrentOperationCount = 3
//            
//            for (index, segment) in segments.enumerated() {
//                let outputURL = documentsDir.appendingPathComponent("segment_\(index).m4a")
//                
//                group.enter()
//                
//                self.exportSegmentAsM4A(asset: asset, segment: segment, outputURL: outputURL) { success in
//                    if success {
//                        queue.addOperation {
//                            let semaphore = DispatchSemaphore(value: 0)
//                            self.transcribeWithGoogle(fileURL: outputURL, segmentIndex: index) {
//                                group.leave()
//                                semaphore.signal()
//                            }
//                            semaphore.wait()
//                        }
//                    } else {
//                        group.leave()
//                    }
//                }
//            }
//            
//            group.notify(queue: .main) {
//                print("✅ All segment transcriptions finished.")
//                let finalTranscript = self.assembleFinalTranscript()
//                completion(finalTranscript)
//            }
//        }
//    }
//
//
    func split(audioFileURL: URL, segmentDuration: TimeInterval = 3.0, completion: @escaping ([Segment]?, Error?) -> Void) {
        let asset = AVAsset(url: audioFileURL)
        Task {
            do {
                let assetDuration = try await asset.load(.duration)
                let totalDuration = CMTimeGetSeconds(assetDuration)
                
                var segments: [Segment] = []
                
                for start in stride(from: 0.0, to: totalDuration, by: segmentDuration) {
                    let startTime = CMTime(seconds: start, preferredTimescale: 600)
                    let length = min(segmentDuration, totalDuration - start)
                    let duration = CMTime(seconds: length, preferredTimescale: 600)
                    segments.append(Segment(startTime: startTime, duration: duration))
                }
                
                completion(segments, nil)
            } catch {
                completion(nil, error)
            }
        }
    }
    
    func exportSegmentAsM4A(asset: AVAsset, segment: Segment, outputURL: URL, completion: @escaping (Bool) -> Void) {
        let timeRange = CMTimeRange(start: segment.startTime, duration: segment.duration)
        
        let folderURL = outputURL.deletingLastPathComponent()
            do {
                try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
                if FileManager.default.fileExists(atPath: outputURL.path) {
                    try FileManager.default.removeItem(at: outputURL)
                }
            } catch {
                print("Error preparing output directory: \(error)")
                completion(false)
                return
            }
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            print("Failed to create export session")
            completion(false)
            return
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a
        exportSession.timeRange = timeRange
        
        exportSession.exportAsynchronously {
            switch exportSession.status {
            case .completed:
                completion(true)
            default:
                print("Export failed: \(exportSession.error?.localizedDescription ?? "unknown error")")
                completion(false)
            }
        }
    }
    func exportAndPlaySegments(asset: AVAsset, segments: [Segment], tempDirectory: URL = FileManager.default.temporaryDirectory) {
        var exportedURLs: [URL] = []
        let group = DispatchGroup()

        for (index, segment) in segments.enumerated() {
            let outputURL = tempDirectory.appendingPathComponent("segment_\(index).m4a")
            
            group.enter()
            exportSegmentAsM4A(asset: asset, segment: segment, outputURL: outputURL) { success in
                if success {
                    exportedURLs.append(outputURL)
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            if exportedURLs.isEmpty {
                print("No segments exported.")
            } else {
                print("Exported segments:")
                exportedURLs.forEach {
                    print($0)
                }
            }
        }
    }

    
    
    func transcribeWithGoogle(fileURL: URL, completion: @escaping (String?) -> Void) {
        print("Preparing to transcribe: \(fileURL)")

        guard let audioData = try? Data(contentsOf: fileURL) else {
            print("Failed to load audio data")
            completion(nil)
            return
        }

        let base64Audio = audioData.base64EncodedString()
        let requestDict: [String: Any] = [
            "config": [
                    "encoding": "LINEAR16",
                    "sampleRateHertz": 48000,       
                    "languageCode": "en-US"
                ],
                "audio": [
                    "content": base64Audio
                ]
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestDict) else {
            print("Failed to encode JSON request")
            completion(nil)
            return
        }

        let url = URL(string: "https://speech.googleapis.com/v1/speech:recognize?key=\(googleAPIKey)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Request error: \(error)")
                completion(nil)
                return
            }

            guard let data = data else {
                print("No data in response")
                completion(nil)
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let results = json["results"] as? [[String: Any]],
                   let firstResult = results.first,
                   let alternatives = firstResult["alternatives"] as? [[String: Any]],
                   let transcript = alternatives.first?["transcript"] as? String {
                    print("📝 Transcription: \(transcript)")
                    completion(transcript)
                } else {
                    print("Unexpected response: \(String(data: data, encoding: .utf8) ?? "")")
                    completion(nil)
                }
            } catch {
                print("Failed to parse JSON: \(error)")
                completion(nil)
            }
        }.resume()
    }

//
//    func transcribeWithGoogle(fileURL: URL, segmentIndex: Int, completion: @escaping () -> Void) {
//        print("Preparing to transcribe segment \(segmentIndex): \(fileURL)")
//        guard let audioData = try? Data(contentsOf: fileURL) else {
//            print("Failed to load audio data")
//            completion()
//            return
//        }
//        let base64Audio = audioData.base64EncodedString()
//        let requestDict: [String: Any] = [
//            "config": [
//                "encoding": "MULAW",
//                "sampleRateHertz": 16000,
//                "languageCode": "en-US"
//            ],
//            "audio": [
//                "content": base64Audio
//            ]
//        ]
//        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestDict) else {
//            print("Failed to encode JSON request")
//            completion()
//            return
//        }
//        let url = URL(string: "https://speech.googleapis.com/v1/speech:recognize?key=\(googleAPIKey)")!
//        var request = URLRequest(url: url)
//        request.httpMethod = "POST"
//        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
//        request.httpBody = jsonData
//        
//        sendRequestWithRetry(request: request, segmentIndex: segmentIndex, attempt: 1, completion: completion)
//    }
//
//    private func sendRequestWithRetry(request: URLRequest, segmentIndex: Int, attempt: Int, completion: @escaping () -> Void) {
//        URLSession.shared.dataTask(with: request) { data, response, error in
//            if let error = error {
//                print("Request error: \(error)")
//                //self.retryOrFail(request: request, segmentIndex: segmentIndex, attempt: attempt, completion: completion)
//                return
//            }
//            guard let data = data else {
//                print("No data in response")
//                //self.retryOrFail(request: request, segmentIndex: segmentIndex, attempt: attempt, completion: completion)
//                return
//            }
//            do {
//                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
//                   let results = json["results"] as? [[String: Any]],
//                   let firstResult = results.first,
//                   let alternatives = firstResult["alternatives"] as? [[String: Any]],
//                   let transcript = alternatives.first?["transcript"] as? String {
//                    print("📝 Segment \(segmentIndex) transcription: \(transcript)")
//                    self.segmentResults[segmentIndex] = transcript
//                } else {
//                    print("Unexpected response: \(String(data: data, encoding: .utf8) ?? "")")
//                }
//                completion()
//            } catch {
//                print("Failed to parse JSON: \(error)")
//                //self.retryOrFail(request: request, segmentIndex: segmentIndex, attempt: attempt, completion: completion)
//            }
//        }.resume()
//    }
//
//    private func retryOrFail(request: URLRequest, segmentIndex: Int, attempt: Int, completion: @escaping () -> Void) {
//        if attempt > 5 {
//            print("All retry attempts failed for segment \(segmentIndex).")
//            DispatchQueue.main.async {
//                self.transcribeWithApple(fileURL: self.fullAudioURL) { transcript in
//                    // Handle the transcript here, e.g.:
//                    print("Received transcript: \(transcript)")
//                    // Store or update UI as needed
//                }
//
//            }
//            completion()
//            return
//        }
//        let delay = pow(2.0, Double(attempt))
//        DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
//            self.sendRequestWithRetry(request: request, segmentIndex: segmentIndex, attempt: attempt + 1, completion: completion)
//        }
//    }
//
//
//    private func assembleFinalTranscript() -> String {
//        let ordered = segmentResults.sorted(by: { $0.key < $1.key }).map { $0.value }
//        let final = ordered.joined(separator: " ")
//        print("\n🎯 Final stitched transcript:\n\(final)\n")
//        return final
//    }
//    
    
    
    
    
    //Local fallback
    
    
    func transcribeWithApple(fileURL: URL, completion: @escaping (String) -> Void) {
        let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        guard let speechRecognizer = recognizer, speechRecognizer.isAvailable else {
            print("Apple Speech Recognizer not available")
            completion("")
            return
        }

        let request = SFSpeechURLRecognitionRequest(url: fileURL)
        speechRecognizer.recognitionTask(with: request) { result, error in
            if let error = error {
                print("Apple local recognition error: \(error.localizedDescription)")
                completion("")
                return
            }
            if let result = result, result.isFinal {
                print("Apple local transcription whole file: \(result.bestTranscription.formattedString)")
                completion(result.bestTranscription.formattedString)
            }
        }
    }

}

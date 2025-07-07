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
    
    
    // Splits the audio file into 3s segment
    func splitAndExportSegments(
        audioFileURL: URL,
        segmentDuration: TimeInterval = 3.0,
        tempDirectory: URL = FileManager.default.temporaryDirectory,
        assetExportPreset: String = AVAssetExportPresetPassthrough
    ) async throws -> [URL] {
        
        let asset = AVAsset(url: audioFileURL)
        let assetDuration = try await asset.load(.duration)
        let totalDuration = CMTimeGetSeconds(assetDuration)
        
        var segments: [Segment] = []
        
        for start in stride(from: 0.0, to: totalDuration, by: segmentDuration) {
            let startTime = CMTime(seconds: start, preferredTimescale: 600)
            let length = min(segmentDuration, totalDuration - start)
            let duration = CMTime(seconds: length, preferredTimescale: 600)
            segments.append(Segment(startTime: startTime, duration: duration))
        }
        
        let exportedURLs = await exportSegments(asset: asset, segments: segments, tempDirectory: tempDirectory)
        return exportedURLs
    }
    
    // Helper function to export the segments as smaller audio files
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
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough) else {
            print("Failed to create export session")
            completion(false)
            return
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .caf
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
    
    // Exports the audio files and returns the URLs array
    func exportSegments(asset: AVAsset, segments: [Segment], tempDirectory: URL = FileManager.default.temporaryDirectory) async -> [URL] {
        var exportedURLs: [URL] = []
        
        await withTaskGroup(of: (Int, URL?).self) { group in
            for (index, segment) in segments.enumerated() {
                group.addTask {
                    let outputURL = tempDirectory.appendingPathComponent("segment_\(index).caf")
                    let success = await withCheckedContinuation { continuation in
                        self.exportSegmentAsM4A(asset: asset, segment: segment, outputURL: outputURL) { success in
                            continuation.resume(returning: success)
                        }
                    }
                    return success ? (index, outputURL) : (index, nil)
                }
            }
            
            var tempResults = Array<URL?>(repeating: nil, count: segments.count)
            
            for await (index, url) in group {
                tempResults[index] = url
            }
            
            exportedURLs = tempResults.compactMap { $0 }
        }
        
        return exportedURLs
    }
    
    
    
    
    // Sends audio file to Google for transcription and return the transcribed text
    func transcribeWithGoogle(fileURL: URL, completion: @escaping (String?) -> Void) {
        print("Preparing to transcribe: \(fileURL)")
        let googleAPIKey = "AIzaSyCgsasLk-8nHA-i9KsPXjJsxE-HeO1XpDA"
        
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
    // Wrapper function to split-transcribe-stich
    // Stich merges all the transciption chunks into one big text maintaining the order of files

    func transcribeAndStitch(
        audioFileURL: URL,
        onComplete: @escaping (_ stitched: String, _ results: [String]) -> Void,
        onError: @escaping (_ error: Error) -> Void
    )  {
        Task {
            do {
                let segmentURLs = try await self.splitAndExportSegments(audioFileURL: audioFileURL)
                
                let results = await self.transcribeSegmentsConcurrently(segmentFiles: segmentURLs)
                print(results)
                
                let stitchedTranscription = results
                    .map { $0.isEmpty ? "" : $0 }
                    .joined(separator: "\n")
                
                await MainActor.run {
                    onComplete(stitchedTranscription, results)
                }
                
            } catch {
                await MainActor.run {
                    onError(error)
                }
            }
        }
    }
    // Async wrapper for the transcribeAndStitch
    func transcribeAndStitchAsync(audioFileURL: URL) async throws -> (stitched: String, results: [String]) {
        try await withCheckedThrowingContinuation { continuation in
            transcribeAndStitch(audioFileURL: audioFileURL, onComplete: { stitched, results in
                continuation.resume(returning: (stitched, results))
            }, onError: { error in
                continuation.resume(throwing: error)
            })
        }
    }
    
    // Sends audio file to Google for transcription and return the transcribed text
    // Only accepts the entire file
    //This is the local fallback option and is used only when the Google one fails
    
    
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
    
    // Async wrapper
    
    func transcribeFileAsync(url: URL) async -> String {
        await withCheckedContinuation { continuation in
            transcribeWithGoogle(fileURL: url) { result in
                if let text = result {
                    continuation.resume(returning: text)
                } else {
                    continuation.resume(returning: "")
                }
            }
        }
    }
    
    // Concurrently sends files to Google
    func transcribeSegmentsConcurrently(segmentFiles: [URL]) async -> [String] {
        var results = Array<String>(repeating: "", count: segmentFiles.count)
        
        await withTaskGroup(of: (Int, String).self) { group in
            for (index, url) in segmentFiles.enumerated() {
                group.addTask {
                    let text = await self.transcribeFileAsync(url: url)
                    return (index, text)
                }
            }
            
            for await (index, result) in group {
                results[index] = result
            }
        }
        
        return results
    }
    
}




import XCTest
import AVFoundation
@testable import AudioApp

final class TranscribeTest: XCTestCase {

    var transcriber: Transcribe!
    var testAudioURL: URL!

    override func setUp() {
        super.setUp()
        transcriber = Transcribe()

        let bundle = Bundle(for: type(of: self))
        guard let url = bundle.url(forResource: "test_audio", withExtension: "caf") else {
            XCTFail("Missing test audio file in bundle")
            return
        }
        testAudioURL = url
    }

    override func tearDown() {
        transcriber = nil
        testAudioURL = nil
        super.tearDown()
    }

    func testSplitAndExportSegments_createsSegments() async throws {
        let segments = try await transcriber.splitAndExportSegments(audioFileURL: testAudioURL, segmentDuration: 2.0)
        XCTAssertFalse(segments.isEmpty, "Expected some exported segment URLs")
        
        for url in segments {
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), "Segment file should exist at path: \(url.path)")
        }
    }
    
    func testExportSegmentAsM4A_completesSuccessfully() {
        let asset = AVAsset(url: testAudioURL)
        let segment = Transcribe.Segment(startTime: CMTime(seconds: 0, preferredTimescale: 600), duration: CMTime(seconds: 1, preferredTimescale: 600))
        
        let expectation = self.expectation(description: "Export segment completion")
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_segment.caf")
        
        transcriber.exportSegmentAsM4A(asset: asset, segment: segment, outputURL: outputURL) { success in
            XCTAssertTrue(success, "Segment export should succeed")
            XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path), "Exported file should exist")
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 10)
    }
    
    func testTranscribeWithGoogle_completionCalled() {
        let expectation = self.expectation(description: "Google transcription completion")
        
        transcriber.transcribeWithGoogle(fileURL: testAudioURL) { transcript in
            XCTAssertNotNil(transcript, "Transcript should not be nil (may be empty string)")
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 15)
    }

    func testTranscribeWithApple_completesWithResult() {
        let expectation = self.expectation(description: "Apple transcription completion")

        transcriber.transcribeWithApple(fileURL: testAudioURL) { transcript in
            XCTAssertNotNil(transcript, "Apple transcript should not be nil")
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 15)
    }

    func testTranscribeAndStitchAsync_returnsStitchedResult() async throws {
        do {
            let result = try await transcriber.transcribeAndStitchAsync(audioFileURL: testAudioURL)
            XCTAssertNotNil(result.stitched, "Stitched transcription should not be nil")
            XCTAssertEqual(result.results.count, result.stitched.split(separator: " ").count, "Number of segment results should roughly correspond to stitched transcription word count")
        } catch {
            XCTFail("TranscribeAndStitchAsync threw error: \(error)")
        }
    }
    
    func testTranscribeFileAsync_returnsString() async {
        let result = await transcriber.transcribeFileAsync(url: testAudioURL)
        XCTAssertNotNil(result, "transcribeFileAsync should return a string (may be empty)")
    }
    
   
}


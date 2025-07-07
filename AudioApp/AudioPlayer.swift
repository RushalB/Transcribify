import Foundation
import AVFoundation
import Combine

class AudioPlayer: NSObject, ObservableObject {
    private var player: AVAudioPlayer?
    @Published var isPlaying = false

    private var queue: [URL] = []
    private var currentIndex = 0

    func play(url: URL) {
        stop() // stop any existing playback
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            player?.prepareToPlay()
            player?.play()
            isPlaying = true
            print("Playback started: \(url.lastPathComponent)")
        } catch {
            print("Playback error: \(error)")
            isPlaying = false
        }
    }

    func stop() {
        player?.stop()
        isPlaying = false
    }
    
    func pause() {
        player?.pause()
        isPlaying = false
    }

    func resume() {
        player?.play()
        isPlaying = true
    }


}

extension AudioPlayer: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
    }
}

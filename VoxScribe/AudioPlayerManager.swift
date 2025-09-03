//
//  AudioPlayerManager.swift
//  VoxScribe
//
//  Created by Turann_ on 03.09.2025.
//

import AVFoundation

class AudioPlayerManager: ObservableObject {
    @Published var isPlaying = false
    @Published var playbackProgress: Double = 0.0

    private var audioPlayer: AVAudioPlayer?

    func play(audioURL: URL) {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: audioURL)
            audioPlayer?.play()
            isPlaying = true
        } catch {
            print("Error playing audio: \(error)")
        }
    }

    func stop() {
        audioPlayer?.stop()
        isPlaying = false
    }
}

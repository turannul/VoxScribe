//
//  Transcriber.swift
//  demoapp
//
//  Created by Turann_ on 30.03.2025.
//


import SwiftUI
import WhisperKit // we need to make use of this. because Apple's Speech recognition randomly stops working.

class Transcriber: NSObject {
    private var previousTranscription = ""

    
    private var _transcribedText = ""
    var transcribedText: String {
        get { return _transcribedText }
        set {
            _transcribedText = newValue
            NotificationCenter.default.post(
                name: NSNotification.Name("TranscriberTextChanged"),
                object: newValue
            )
        }
    }
    
    override init() {
        super.init()
        setupRecognition()
    }
    
    func setupRecognition() {
    }
    
    func processAudio(buffer: AVAudioPCMBuffer) {
            processWithSpeechRecognition(buffer: buffer)
    }
    
    func processAudio(sampleBuffer: CMSampleBuffer) {
        // Implementation dependent on requirements
    }
    
    func processWithSpeechRecognition(buffer: AVAudioPCMBuffer) {

    }
    
    func finishProcessing() {
    }
}
    
    func transcribe(_ buffer: AVAudioPCMBuffer) async throws -> TranscriptionResult {
        return TranscriptionResult(text: "...")
    }

struct TranscriptionResult {
    let text: String
}

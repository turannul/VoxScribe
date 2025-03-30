//
//  Transcriber.swift
//  demoapp
//
//  Created by Turann_ on 30.03.2025.
//


import SwiftUI
import Speech

class Transcriber: NSObject {
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var previousTranscription = ""
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
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
        SFSpeechRecognizer.requestAuthorization { status in
            if status != .authorized {
                print("Speech recognition authorization denied")
            }
        }
    }
    
    func processAudio(buffer: AVAudioPCMBuffer) {
            processWithSpeechRecognition(buffer: buffer)
    }
    
    func processAudio(sampleBuffer: CMSampleBuffer) {
        // Implementation dependent on requirements
    }
    
    func processWithSpeechRecognition(buffer: AVAudioPCMBuffer) {
        if recognitionRequest == nil {
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            
            guard let recognitionRequest = recognitionRequest else { return }
            
            recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { result, error in
                if let result = result {
                    let newText = result.bestTranscription.formattedString
                    let addedText = String(newText.suffix(max(0, newText.count - self.previousTranscription.count)))
                    DispatchQueue.main.async {
                        self.transcribedText += addedText
                        self.previousTranscription = newText
                    }
                }
            }
        }
        recognitionRequest?.append(buffer)
    }
    
    func finishProcessing() {
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
    }
}
    
    func transcribe(_ buffer: AVAudioPCMBuffer) async throws -> TranscriptionResult {
        return TranscriptionResult(text: "Sample transcription text")
    }

struct TranscriptionResult {
    let text: String
}

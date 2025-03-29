//
//  Transcriber.swift
//  demoapp
//
//  Created by Turann_ on 30.03.2025.
//


import SwiftUI
import AVFoundation
import Speech
import WhisperKit
import CoreAudio

class Transcriber: NSObject {
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var previousTranscription = ""
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var whisperKit: WhisperKit?
    private var useWhisperKit = true
    
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
        if useWhisperKit {
            setupWhisperKit()
        }
    }
    
    func setupRecognition() {
        SFSpeechRecognizer.requestAuthorization { status in
            if status != .authorized {
                print("Speech recognition authorization denied")
            }
        }
    }
    
    func setupWhisperKit() {
        Task {
            do {
                whisperKit = try await WhisperKit.setup()
                print("WhisperKit initialized successfully")
            } catch {
                print("Failed to initialize WhisperKit: \(error)")
                useWhisperKit = false
            }
        }
    }
    
    func processAudio(buffer: AVAudioPCMBuffer) {
        if useWhisperKit {
            processWithWhisperKit(buffer: buffer)
        } else {
            processWithSpeechRecognition(buffer: buffer)
        }
    }
    
    func processAudio(sampleBuffer: CMSampleBuffer) {
        // Implementation dependent on requirements
    }
    
    func processWithWhisperKit(buffer: AVAudioPCMBuffer) {
        Task {
            guard let whisperKit = whisperKit else { return }
            
            do {
                let result = try await whisperKit.transcribe(buffer)
                DispatchQueue.main.async {
                    if !result.text.isEmpty {
                        self.transcribedText += result.text + " "
                    }
                }
            } catch {
                print("WhisperKit transcription error: \(error)")
            }
        }
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

extension WhisperKit {
    static func setup() async throws -> WhisperKit {
        return try await WhisperKit()
    }
    
    func transcribe(_ buffer: AVAudioPCMBuffer) async throws -> TranscriptionResult {
        return TranscriptionResult(text: "Sample transcription text")
    }
}

struct TranscriptionResult {
    let text: String
}
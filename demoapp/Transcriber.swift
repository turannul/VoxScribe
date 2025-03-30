//
//  Transcriber.swift
//  demoapp
//
//  Created by Turann_ on 30.03.2025.
//

import WhisperKit
import AudioKit // Using AudioKit for audio processing
import AVFoundation

import WhisperKit

class Transcriber: NSObject {
    private var whisperKit: WhisperKit?
    private var processingQueue = DispatchQueue(label: "transcriber.queue", qos: .userInitiated)
    private var buffers: [AVAudioPCMBuffer] = []
    private var isProcessing = false
    
    @MainActor
    func setup() async {
        do {
            whisperKit = try await WhisperKit()
            print("WhisperKit ready")
        } catch {
            print("WhisperKit init failed: \(error)")
        }
    }
    
    func processAudio(buffer: AVAudioPCMBuffer) {
        processingQueue.async { [weak self] in
            self?.buffers.append(buffer)
            self?.processBuffersIfNeeded()
        }
    }
    
    private func processBuffersIfNeeded() {
        guard !isProcessing, !buffers.isEmpty else { return }
        isProcessing = true
        
        let mergedBuffer = mergeBuffers(buffers)
        buffers.removeAll()
        
        Task {
            guard let whisperKit = self.whisperKit else {
                isProcessing = false
                return
            }
            
            do {
                let audioArray = bufferToFloatArray(mergedBuffer)
                let results = try await whisperKit.transcribe(
                    audioArray: audioArray,
                    sampleRate: Int(mergedBuffer.format.sampleRate))
                
                if let text = results.first?.text {
                    self.updateTranscription(text)
                }
            } catch {
                print("Transcription error: \(error)")
            }
            isProcessing = false
        }
    }
    
    private func bufferToFloatArray(_ buffer: AVAudioPCMBuffer) -> [Float] {
        guard let channelData = buffer.floatChannelData else { return [] }
        let count = Int(buffer.frameLength)
        return Array(UnsafeBufferPointer(start: channelData[0], count: count))
    }
    
    private func mergeBuffers(_ buffers: [AVAudioPCMBuffer]) -> AVAudioPCMBuffer {
        // Implement buffer merging logic if needed (similar to your existing code)
        return buffers.first!
    }
}
                    
func convertAudioFileToPCMArray(fileURL: URL, completionHandler: @escaping (Result<[Float], Error>) -> Void) {
    var options = FormatConverter.Options()
    options.format = .wav
    options.sampleRate = 16000
    options.bitDepth = 16
    options.channels = 1
    options.isInterleaved = false

    let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
    let converter = FormatConverter(inputURL: fileURL, outputURL: tempURL, options: options)
    converter.start { error in
        if let error {
            completionHandler(.failure(error))
            return
        }

        let data = try! Data(contentsOf: tempURL) // Handle error here

        let floats = stride(from: 44, to: data.count, by: 2).map {
            return data[$0..<$0 + 2].withUnsafeBytes {
                let short = Int16(littleEndian: $0.load(as: Int16.self))
                return max(-1.0, min(Float(short) / 32767.0, 1.0))
            }
        }

        try? FileManager.default.removeItem(at: tempURL)

        completionHandler(.success(floats))
    }
}

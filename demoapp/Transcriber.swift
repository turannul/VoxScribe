//
//  Transcriber.swift
//  demoapp
//
//  Created by Turann_ on 30.03.2025.
//


import SwiftUI
import AVFoundation
import WhisperKit

class Transcriber: NSObject {
    private var previousTranscription = ""
    private var audioChunks: [AVAudioPCMBuffer] = []
    private var processingQueue = DispatchQueue(label: "xyz.turannul.processingQueue")
    private var isProcessing = false
    private var whisperKit: WhisperKit?
    private var lastProcessingTime = Date()
    private let processingInterval: TimeInterval = 2.0 // Process chunks every 2 seconds
    private var shouldProcessFinal = false
    
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
        // Initialize WhisperKit
        Task { @MainActor in
            do {
                // Fix 2: Add type annotation for WhisperKit initialization
                whisperKit = try await WhisperKit()
                print("WhisperKit initialized successfully")
            } catch {
                print("Failed to initialize WhisperKit: \(error)")
            }
        }
    }
    
    func processAudio(buffer: AVAudioPCMBuffer) {
        // Add the buffer to our chunks
        let bufferCopy = buffer.copy() as! AVAudioPCMBuffer
        processingQueue.async { [weak self] in
            guard let self = self else { return }
            self.audioChunks.append(bufferCopy)
            
            // Check if it's time to process the accumulated audio
            if !self.isProcessing && (Date().timeIntervalSince(self.lastProcessingTime) >= self.processingInterval || self.shouldProcessFinal) {
                self.processAccumulatedAudio()
            }
        }
    }
    
    func processAudio(sampleBuffer: CMSampleBuffer) {
        // Convert CMSampleBuffer to PCM buffer if needed
        if let pcmBuffer = self.convertToPCMBuffer(from: sampleBuffer) {
            self.processAudio(buffer: pcmBuffer)
        }
    }
    
    private func convertToPCMBuffer(from sampleBuffer: CMSampleBuffer) -> AVAudioPCMBuffer? {
        guard let audioBufferList = try? sampleBuffer.audioBufferList else { return nil }
        
        // Get format description from sample buffer
        guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) else { return nil }
        guard let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription) else { return nil }
        
        // Create an AVAudioFormat with the same parameters
        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: asbd.pointee.mSampleRate,
            channels: AVAudioChannelCount(asbd.pointee.mChannelsPerFrame),
            interleaved: ((asbd.pointee.mFormatFlags & kAudioFormatFlagIsNonInterleaved) == 0)
        )
        
        guard let format = format else { return nil }
        
        // Create a new PCM buffer
        let frameCapacity = UInt32(CMSampleBufferGetNumSamples(sampleBuffer))
        guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCapacity) else { return nil }
        pcmBuffer.frameLength = frameCapacity
        
        // Copy audio data to PCM buffer
        let bufferListPointer = UnsafeMutableAudioBufferListPointer(&audioBufferList.pointee)
        for (i, audioBuffer) in bufferListPointer.enumerated() {
            guard let dest = pcmBuffer.floatChannelData?[i], let src = audioBuffer.mData else { continue }
            memcpy(dest, src, Int(audioBuffer.mDataByteSize))
        }
        
        return pcmBuffer
    }
    
    private func processAccumulatedAudio() {
        guard !audioChunks.isEmpty, let _ = whisperKit, !isProcessing else { return }
        
        isProcessing = true
        lastProcessingTime = Date()
        
        // Make a copy of the current chunks and clear the array for new incoming audio
        let chunksToProcess = audioChunks
        audioChunks.removeAll()
        
        Task { @MainActor in
            do {
                // Merge audio chunks if there are multiple
                let mergedBuffer: AVAudioPCMBuffer
                if chunksToProcess.count > 1 {
                    mergedBuffer = try mergeAudioBuffers(chunksToProcess)
                } else {
                    mergedBuffer = chunksToProcess[0]
                }
                
                // Transcribe the audio
                let result = try await transcribe(mergedBuffer)
                
                // Update the transcribed text
                if !result.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let newText = self.previousTranscription + " " + result.text
                    self.previousTranscription = newText
                    self.transcribedText = newText.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                self.isProcessing = false
            } catch {
                print("Error during transcription: \(error)")
                self.isProcessing = false
            }
        }
    }
    
    private func mergeAudioBuffers(_ buffers: [AVAudioPCMBuffer]) throws -> AVAudioPCMBuffer {
        guard let firstBuffer = buffers.first else {
            throw NSError(domain: "Transcriber", code: 1, userInfo: [NSLocalizedDescriptionKey: "No buffers to merge"])
        }
        
        let format = firstBuffer.format
        
        // Calculate the total number of frames
        let totalFrames = buffers.reduce(0) { $0 + $1.frameLength }
        
        // Create a new buffer with enough capacity
        guard let mergedBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: totalFrames) else {
            throw NSError(domain: "Transcriber", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create merged buffer"])
        }
        
        var frameOffset: UInt32 = 0
        
        // Copy each buffer's data into the merged buffer
        for buffer in buffers {
            guard let mergedChannelData = mergedBuffer.floatChannelData, let sourceChannelData = buffer.floatChannelData else { continue }
            
            for channel in 0..<Int(format.channelCount) {
                // Copy the channel data
                memcpy(
                    mergedChannelData[channel] + Int(frameOffset),
                    sourceChannelData[channel],
                    Int(buffer.frameLength) * MemoryLayout<Float>.size
                )
            }
            
            frameOffset += buffer.frameLength
        }
        
        // Set the frame length of the merged buffer
        mergedBuffer.frameLength = totalFrames
        
        return mergedBuffer
    }
    
    func transcribe(_ buffer: AVAudioPCMBuffer) async throws -> TranscriptionResult {
        guard let whisperKit = whisperKit else {
            throw NSError(domain: "Transcriber", code: 3, userInfo: [NSLocalizedDescriptionKey: "WhisperKit not initialized"])
        }
        
        // Convert the audio buffer to the format expected by WhisperKit
        let audioArray = convertBufferToArray(buffer)
        
        // Fix 1: Handle the array of results correctly
        let transcriptionResults = try await whisperKit.transcribe(audioArray: audioArray)
        
        // Extract text from the results - assuming WhisperKit returns an array
        // and we're concatenating all the text or taking the first result
        if let firstResult = transcriptionResults.first {
            return TranscriptionResult(text: firstResult.text)
        } else {
            // If the array is empty, return empty text
            return TranscriptionResult(text: "")
        }
    }
    
    private func convertBufferToArray(_ buffer: AVAudioPCMBuffer) -> [Float] {
        let channelCount = Int(buffer.format.channelCount)
        let frameCount = Int(buffer.frameLength)
        var result: [Float] = []
        
        // If stereo, average the channels. If mono, just use the single channel.
        if channelCount > 1 {
            // For multi-channel, we'll average all channels
            result = Array(repeating: 0.0, count: frameCount)
            guard let channelData = buffer.floatChannelData else { return [] }
            
            for frame in 0..<frameCount {
                var sum: Float = 0.0
                for channel in 0..<channelCount {
                    sum += channelData[channel][frame]
                }
                result[frame] = sum / Float(channelCount)
            }
        } else {
            // For mono, just copy the samples
            guard let channelData = buffer.floatChannelData else { return [] }
            result = Array(UnsafeBufferPointer(start: channelData[0], count: frameCount))
        }
        
        return result
    }
    
    func finishProcessing() {
        // Process any remaining audio when recording stops
        shouldProcessFinal = true
        processingQueue.async { [weak self] in
            guard let self = self else { return }
            if !self.audioChunks.isEmpty && !self.isProcessing {
                self.processAccumulatedAudio()
            }
            self.shouldProcessFinal = false
        }
    }
}

struct TranscriptionResult {
    let text: String
}
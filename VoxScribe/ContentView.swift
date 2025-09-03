//
//  ContentView.swift
//  VoxScribe
//
//  Created by Turann_ on 30.03.2025.
//

import SwiftUI
import AVFoundation

// MARK: - Main App View
struct VoxScribeAppView: View {
    @StateObject private var viewModel = ContentViewModel()
    @State private var selection: RecordingFile? = nil

    var body: some View {
        NavigationSplitView {
            SidebarView(viewModel: viewModel, selection: $selection)
        } content: {
            ContentAreaView(viewModel: viewModel, selection: $selection)
        } detail: {
            DetailView(selection: $selection, viewModel: viewModel)
        }
    }
}

// MARK: - Sidebar
struct SidebarView: View {
    @ObservedObject var viewModel: ContentViewModel
    @Binding var selection: RecordingFile?

    var body: some View {
        VStack {
            if !viewModel.audioManager.audioPermissionGranted {
                PermissionView(viewModel: viewModel)
            } else {
                RecordingControlsView(viewModel: viewModel)
                if viewModel.audioManager.isRecording {
                    AudioWaveformView(audioLevels: viewModel.audioLevels)
                        .frame(height: 60)
                        .padding()
                }
            }
            Spacer()
            RecordingsListView(viewModel: viewModel, selection: $selection)
        }
        .frame(minWidth: 300)
    }
}

// MARK: - Content Area
struct ContentAreaView: View {
    @ObservedObject var viewModel: ContentViewModel
    @Binding var selection: RecordingFile?

    var body: some View {
        if viewModel.audioManager.isRecording {
            LiveTranscriptionView(viewModel: viewModel)
        } else {
            if let sel = selection {
                RecordingDetailView(recording: sel, onExport: { viewModel.exportRecording(sel) }, onToggleStar: { viewModel.toggleStar(for: sel) })
            } else {
                Text("Select a recording or start a new one")
                    .foregroundColor(.gray)
            }
        }
    }
}

// MARK: - Detail View
struct DetailView: View {
    @Binding var selection: RecordingFile?
    @ObservedObject var viewModel: ContentViewModel

    var body: some View {
        if let sel = selection {
            RecordingDetailView(recording: sel, onExport: { viewModel.exportRecording(sel) }, onToggleStar: { viewModel.toggleStar(for: sel) })
        } else {
            Text("Select a recording")
                .foregroundColor(.gray)
        }
    }
}

// MARK: - Permission View
struct PermissionView: View {
    @ObservedObject var viewModel: ContentViewModel

    var body: some View {
        VStack {
            Text("Microphone access is required")
                .foregroundColor(.red)
                .padding()
            Button("Request Permission") {
                viewModel.audioManager.checkPermissions()
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
    }
}

// MARK: - Recording Controls
struct RecordingControlsView: View {
    @ObservedObject var viewModel: ContentViewModel

    var body: some View {
        VStack {
            Picker("Select Source", selection: $viewModel.audioManager.selectedMicrophone) {
                ForEach(viewModel.audioManager.availableMicrophones, id: \.uniqueID) { device in
                    Text(device.localizedName).tag(device as AVCaptureDevice?)
                }
            }.padding()

            Picker("Language", selection: $viewModel.languageManager.selectedLanguage) {
                ForEach(viewModel.languageManager.availableLanguages, id: \.id) { language in
                    Text(language.name).tag(language)
                }
            }
            .onChange(of: viewModel.languageManager.selectedLanguage) { newValue in
                viewModel.audioManager.setTranscriberLanguage(languageCode: newValue.code)
            }
            .disabled(viewModel.audioManager.isRecording)
            .padding()

            Button(viewModel.audioManager.isRecording ? "Stop Recording" : "Start Recording") {
                viewModel.toggleRecording()
            }
            .buttonStyle(.borderedProminent)
            .tint(viewModel.audioManager.isRecording ? .red : .green)
            .foregroundColor(.white)
            .padding()
        }
    }
}

// MARK: - Live Transcription View
struct LiveTranscriptionView: View {
    @ObservedObject var viewModel: ContentViewModel

    var body: some View {
        VStack {
            Text("Live Transcription")
                .font(.title)
                .padding()
            Text("Language: \(viewModel.languageManager.selectedLanguage.name)")
                .font(.subheadline)
                .foregroundColor(.gray)
                .padding(.bottom)

            ScrollView {
                VStack(alignment: .leading) {
                    HStack(spacing: 0) {
                        Text(viewModel.displayText.isEmpty ? "Start speaking..." : viewModel.displayText)
                            .animation(.easeInOut, value: viewModel.displayText)
                        if viewModel.audioManager.isRecording {
                            Rectangle()
                                .frame(width: 2, height: 20)
                                .foregroundColor(.white)
                                .opacity(1)
                                .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack {
                Button("Copy") {
                    viewModel.copyToClipboard()
                }
                .disabled(viewModel.transcribedText.isEmpty)

                Button("Clear") {
                    viewModel.resetTranscription()
                }
                .disabled(viewModel.transcribedText.isEmpty)
            }
            .buttonStyle(.bordered)
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}

// MARK: - Recordings List View
struct RecordingsListView: View {
    @ObservedObject var viewModel: ContentViewModel
    @Binding var selection: RecordingFile?

    var body: some View {
        VStack {
            Text("Saved Recordings")
                .font(.title)
                .padding()

            List(selection: $selection) {
                if viewModel.savedRecordings.isEmpty {
                    Text("Nothing recorded yet.")
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .padding()
                }
                ForEach(viewModel.savedRecordings) { recording in
                    RecordingCard(recording: recording, 
                                  onDelete: { viewModel.deleteRecording(recording) }, 
                                  onToggleStar: { viewModel.toggleStar(for: recording) }, 
                                  onExport: { viewModel.exportRecording(recording) })
                        .tag(recording)
                }
            }
        }
        .background(Color.black)
    }
}


// MARK: - Recording Card View
struct RecordingCard: View {
    let recording: RecordingFile
    let onDelete: () -> Void
    let onToggleStar: () -> Void
    let onExport: () -> Void
    
    @State private var isExpanded: Bool = false
    @State private var isHovered: Bool = false
    
    private var dateFormatter: DateFormatter {
        let formatter: DateFormatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text(recording.date).font(.headline)
                    Text(isExpanded ? recording.fullText : recording.preview).font(.subheadline).lineLimit(isExpanded ? nil : 2)
                }
                
                Spacer()
                
                if isHovered {
                    HStack(spacing: 12) {
                        Button(action: onToggleStar) {Image(systemName: recording.isStarred ? "star.fill" : "star").foregroundColor(recording.isStarred ? .yellow : .gray)}
                        Button(action: onExport) {Image(systemName: "square.and.arrow.up").foregroundColor(.blue)}
                        Button(action: onDelete) {Image(systemName: "trash").foregroundColor(.red)}
                        if recording.fullText.count > 100 {Button(action: {withAnimation {isExpanded.toggle()}}) {Image(systemName: isExpanded ? "chevron.up" : "chevron.down").foregroundColor(.white)}}
                    }.transition(.opacity)
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(recording.isStarred ? Color.yellow.opacity(0.1) : Color(.darkGray)).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.2), lineWidth: 1)))
        .onHover { hovering in withAnimation(.easeInOut(duration: 0.1)) {isHovered = hovering}}
    }
}

// MARK: - Audio Waveform View
struct AudioWaveformView: View {
    var audioLevels: [CGFloat]
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<audioLevels.count, id: \.self) { index in RoundedRectangle(cornerRadius: 2).fill(Color.accentColor.opacity(0.65)).frame(width: 4, height: 6 + audioLevels[index] * 54).animation(.interactiveSpring(response: 0.15, dampingFraction: 0.5), value: audioLevels[index])}
        }
    }
}

// MARK: - Recording Detail View
struct RecordingDetailView: View {
    let recording: RecordingFile
    let onExport: () -> Void
    let onToggleStar: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(recording.date)
                        .font(.title)
                    
                    Spacer()
                    
                    Button(action: onToggleStar) {
                        Image(systemName: recording.isStarred ? "star.fill" : "star")
                            .foregroundColor(recording.isStarred ? .yellow : .gray)
                    }
                    
                    Button(action: onExport) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.blue)
                    }
                }
                .padding()
                
                Divider()
                
                Text(recording.fullText)
                    .font(.body)
                    .padding()
            }
            .padding()
        }
        .background(Color.black)
        .navigationTitle("Transcription")
    }
}

#Preview { VoxScribeAppView() }
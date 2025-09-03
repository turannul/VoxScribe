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
    @StateObject private var colorSchemeManager = ColorSchemeManager()
    @State private var selection: RecordingFile? = nil

    var body: some View {
        NavigationSplitView {
            SidebarView(viewModel: viewModel, selection: $selection)
        } content: {
            ContentAreaView(viewModel: viewModel, selection: $selection)
        } detail: {
            DetailView(selection: $selection, viewModel: viewModel)
        }
        .preferredColorScheme(colorSchemeManager.colorSchemeOption.colorScheme)
    }
}

// MARK: - Sidebar
struct SidebarView: View {
    @ObservedObject var viewModel: ContentViewModel
    @Binding var selection: RecordingFile?
    @State private var isShowingSettings = false

    var body: some View {
        VStack {
            if !viewModel.audioManager.audioPermissionGranted {
                PermissionView(viewModel: viewModel)
            } else {
                HStack {
                    Spacer()
                    Button(action: { isShowingSettings.toggle() }) {
                        Image(systemName: "gear")
                    }
                    .padding()
                }
                Button(viewModel.audioManager.isRecording ? "Stop Recording" : "Start Recording") {
                    viewModel.toggleRecording()
                }
                .buttonStyle(.borderedProminent)
                .tint(viewModel.audioManager.isRecording ? .red : .green)
                .foregroundColor(.white)
                .padding()

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
        .sheet(isPresented: $isShowingSettings) {
            SettingsView(viewModel: viewModel)
        }
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
                RecordingDetailView(viewModel: viewModel, recording: sel, onExport: { viewModel.exportRecording(sel) }, onToggleStar: { viewModel.toggleStar(for: sel) })
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
            RecordingDetailView(viewModel: viewModel, recording: sel, onExport: { viewModel.exportRecording(sel) }, onToggleStar: { viewModel.toggleStar(for: sel) })
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
                                .foregroundColor(.accentColor)
                                .opacity(1)
                                .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
            }
            .background(.regularMaterial)
            .cornerRadius(12)
            .padding()

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
    }
}


// MARK: - Recording Card View
struct RecordingCard: View {
    let recording: RecordingFile
    let onDelete: () -> Void
    let onToggleStar: () -> Void
    let onExport: () -> Void
    
    @State private var isHovered: Bool = false

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading) {
                        Text(recording.date).font(.headline)
                        Text(recording.preview).font(.subheadline).lineLimit(2)
                    }
                    Spacer()
                    if recording.isStarred {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                    }
                }
                if isHovered {
                    HStack {
                        Spacer()
                        Button(action: onToggleStar) { Image(systemName: "star").foregroundColor(.yellow) }
                        Button(action: onExport) { Image(systemName: "square.and.arrow.up").foregroundColor(.blue) }
                        Button(action: onDelete) { Image(systemName: "trash").foregroundColor(.red) }
                    }
                }
            }
        }
        .onHover { hovering in
            withAnimation {
                isHovered = hovering
            }
        }
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
    @ObservedObject var viewModel: ContentViewModel
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
                
                HStack {
                    Button(action: { 
                        if viewModel.audioPlayer.isPlaying {
                            viewModel.stopPlayback() 
                        } else {
                            viewModel.playRecording(recording)
                        }
                    }) {
                        Image(systemName: viewModel.audioPlayer.isPlaying ? "stop.fill" : "play.fill")
                    }
                    ProgressView(value: viewModel.audioPlayer.playbackProgress)
                }
                .padding()

                Text(recording.fullText)
                    .font(.body)
                    .padding()
            }
            .padding()
        }
        .background(.regularMaterial)
        .cornerRadius(12)
        .padding()
        .navigationTitle("Transcription")
    }
}

#Preview { VoxScribeAppView() }
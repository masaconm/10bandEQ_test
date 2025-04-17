<<<<<<< HEAD
//
//  PlaylistView.swift
//  10bandEQ_test
//
//  Created by 中静暢子 on 2025/03/22.
//

// MARK: - PlaylistView

=======
>>>>>>> 225a73d (20250417 Recodeing Modeへ遷移後のモニタリングモードと録音機能、録音音声のwavとmp3でのDL機能を追加、関連するUI調整をしました)
import SwiftUI
import AVFoundation

struct PlaylistView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var viewModel: AudioEngineViewModel
<<<<<<< HEAD
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                //  カスタムヘッダー（左：タイトル／右：Done）
                HStack {
                    Text("Playlist")
                        .font(.headline)
=======

    @State private var selectedExportItem: PlaylistItem?
    @State private var selectedFormat: ExportFormat = .wav
    @State private var showExporter = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // ヘッダー
                HStack {
                    Text("Playlist")
                        .font(.system(size: 16, weight: .bold))
>>>>>>> 225a73d (20250417 Recodeing Modeへ遷移後のモニタリングモードと録音機能、録音音声のwavとmp3でのDL機能を追加、関連するUI調整をしました)
                        .foregroundColor(.white)
                    Spacer()
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.white)
                }
                .padding(.horizontal)
                .padding(.top)
<<<<<<< HEAD
                
                List {
                    ForEach(viewModel.playlistItems) { item in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text(String(format: "Duration: %.2f sec", item.duration))
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            .onTapGesture {
                                viewModel.loadPlaylistItem(item)
                                presentationMode.wrappedValue.dismiss()
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                if let index = viewModel.playlistItems.firstIndex(where: { $0.id == item.id }) {
                                    viewModel.playlistItems.remove(at: index)
                                    viewModel.savePlaylistToDefaults()
                                    if viewModel.currentPlaylistItem?.id == item.id {
                                        viewModel.currentPlaylistItem = nil
                                    }
                                }
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                                    .padding(.leading, 20)
                            }
                        }
                        .padding()
                        .background(Color(hex: "#393d40"))
                        .cornerRadius(6)
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(PlainListStyle())
                
                Spacer()
            }
            .background(Color(hex: "#393d40"))
            .navigationBarHidden(true) //  ナビバーを非表示にしてカスタムヘッダー使用
        }
    }
}
=======
                .padding(.bottom, 20)

                // 見出し行
                HStack {
                    Text("Name")
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text("Duration")
                        .frame(width: 100, alignment: .leading)

                    Text("DL")
                        .frame(width: 40)

                    Text("Delete")
                        .frame(width: 60, alignment: .center)
                }
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .padding(.vertical, 6)
                .padding(.horizontal)
                .background(Color(hex: "#2a2e2f"))

                // プレイリスト一覧
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(Array(viewModel.playlistItems.enumerated()), id: \.element.id) { index, item in
                            HStack {
                                Text(item.title)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .foregroundColor(.white)

                                Text(String(format: "%.2f sec", item.duration))
                                    .frame(width: 100, alignment: .leading)
                                    .foregroundColor(.white)

                                // 各ファイルごとのDLボタン（形式選択メニュー）
                                Menu {
                                    Button("Export as WAV") {
                                        selectedExportItem = item
                                        selectedFormat = .wav
                                        showExporter = true
                                    }
                                    Button("Export as MP3 320kbps") {
                                        selectedExportItem = item
                                        selectedFormat = .mp3_320
                                        showExporter = true
                                    }
                                    Button("Export as MP3 192kbps") {
                                        selectedExportItem = item
                                        selectedFormat = .mp3_192
                                        showExporter = true
                                    }
                                } label: {
                                    Image(systemName: "arrow.down.circle")
                                        .foregroundColor(.cyan)
                                }
                                .frame(width: 40)

                                Button(action: {
                                    if let i = viewModel.playlistItems.firstIndex(where: { $0.id == item.id }) {
                                        viewModel.playlistItems.remove(at: i)
                                        viewModel.savePlaylistToDefaults()
                                        if viewModel.currentPlaylistItem?.id == item.id {
                                            viewModel.currentPlaylistItem = nil
                                        }
                                    }
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                                .frame(width: 60)
                            }
                            .font(.system(size: 14))
                            .padding(.vertical, 6)
                            .padding(.horizontal)
                            .background(Color(hex: "#46484a"))
                            .cornerRadius(6)
                            .onTapGesture {
                                viewModel.loadPlaylistItem(item)
                            }
                        }
                    }
                }
                .background(Color(hex: "#393d40"))

                Spacer()
            }
            .background(Color(hex: "#393d40"))
            .navigationBarHidden(true)
        }
        // Exporterは共通で持つ（非表示で動作）
        .fileExporter(
            isPresented: $showExporter,
            document: ExportedAudioFile(
                url: selectedExportItem?.url ?? URL(fileURLWithPath: ""),
                format: selectedFormat
            ),
            contentType: .audio,
            defaultFilename: ExportedAudioFile(
                url: selectedExportItem?.url ?? URL(fileURLWithPath: ""),
                format: selectedFormat
            ).suggestedFilename
        ) { result in
            switch result {
            case .success(let url):
                print("✅ Exported to: \(url.path)")
            case .failure(let error):
                print("❌ Export failed: \(error.localizedDescription)")
            }
        }

        }

    }


>>>>>>> 225a73d (20250417 Recodeing Modeへ遷移後のモニタリングモードと録音機能、録音音声のwavとmp3でのDL機能を追加、関連するUI調整をしました)

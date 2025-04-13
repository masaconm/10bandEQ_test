//
//  PlaylistView.swift
//  10bandEQ_test
//
//  Created by 中静暢子 on 2025/03/22.
//

// MARK: - PlaylistView

import SwiftUI
import AVFoundation

struct PlaylistView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var viewModel: AudioEngineViewModel
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                //  カスタムヘッダー（左：タイトル／右：Done）
                HStack {
                    Text("Playlist")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.white)
                }
                .padding(.horizontal)
                .padding(.top)
                
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

//
//  PlaylistView.swift
//  10bandEQ_test
//
//  Created by 中静暢子 on 2025/03/22.
//

// MARK: - PlaylistView

import SwiftUI
import AVFoundation

///// プレイリスト画面。各音声ファイル項目を表示し、タップで再生切り替え、ゴミ箱ボタンで削除できる
struct PlaylistView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var viewModel: AudioEngineViewModel

    var body: some View {
        NavigationView {
            List {
                ForEach(viewModel.playlistItems) { item in
                    HStack {
                        // 左側：タップで音声を選択してシートを閉じる
                        VStack(alignment: .leading) {
                            Text(item.title)
                                .font(.headline)
                            Text(String(format: "Duration: %.2f sec", item.duration))
                                .font(.subheadline)
                        }
                        .onTapGesture {
                            viewModel.loadPlaylistItem(item)
                            presentationMode.wrappedValue.dismiss()
                        }
                        Spacer()
                        // 右側：削除ボタン。タップしてもシートは閉じない
                        Button(action: {
                            if let index = viewModel.playlistItems.firstIndex(where: { $0.id == item.id }) {
                                viewModel.playlistItems.remove(at: index)
                                viewModel.savePlaylistToDefaults()
                                // 現在再生中の項目が削除された場合、クリアする
                                if viewModel.currentPlaylistItem?.id == item.id {
                                    viewModel.currentPlaylistItem = nil
                                }
                            }
                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Playlist")
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

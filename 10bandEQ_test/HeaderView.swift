//HeaderView.swift

import SwiftUI

struct HeaderView: View {
    // Settings ボタンタップ時のアクション
    let settingsAction: () -> Void

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topTrailing) {
                // 左側にロゴを表示
                HStack {
                    Image("logo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 60, height: 60)
                        .padding(.leading, 10)
                    Spacer()
                }
                // 右上に歯車アイコンの Settings ボタンを配置
                Button(action: settingsAction) {
                    Image(systemName: "gearshape.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                        .foregroundColor(.white)
                        .padding(.trailing, 20)
                        // 安全領域を考慮して上部に余白を追加
                        .padding(.top, geo.safeAreaInsets.top + 20)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .frame(height: 60)
        .background(Color(hex: "#242529"))
        // 上部の安全領域を無視して背景を伸ばす場合
        .ignoresSafeArea(edges: .top)
    }
}

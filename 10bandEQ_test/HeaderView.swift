import SwiftUI

/// ヘッダー：ロゴ、言語選択メニュー、（横向きの場合は）プリセットボタンと Audio Settings ボタンを表示する
struct HeaderView: View {
    @Binding var currentLanguage: String
    // Audio Settings ボタンをタップしたときのアクションをクロージャで受け取る
    let audioSettingsAction: () -> Void

    var body: some View {
        GeometryReader { geo in
            HStack {
                Image("logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 40, height: 40)
                    .padding(.leading, 10)
                Spacer()
                Menu {
                    Button("English") { currentLanguage = "English" }
                    Button("日本語") { currentLanguage = "日本語" }
                } label: {
                    Text(currentLanguage)
                        .frame(width: 120, height: 30)
                        .background(Color.white)
                        .cornerRadius(5)
                }
                Spacer()
                if geo.size.width > geo.size.height {
                    Button("Audio Settings") {
                        audioSettingsAction()
                    }
                    .frame(width: 120, height: 30)
                    .background(Color.white)
                    .cornerRadius(5)
                    
                    Button("Presets") {
                        // Presets のアクション（必要に応じて実装）
                    }
                    .frame(width: 120, height: 30)
                    .background(Color.white)
                    .cornerRadius(5)
                    .padding(.trailing, 10)
                }
            }
        }
        .frame(height: 60)
        .background(Color.gray)
    }
}


import SwiftUI

struct HeaderView: View {
    let settingsAction: () -> Void
    let midiMappingAction: () -> Void
    
    var body: some View {
        let topPadding = safeAreaTopInset()
        
        ZStack(alignment: .bottom) {
            Color(hex: "#1A1A1A")
            
            HStack(alignment: .bottom) {
                Image("logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 40)
                    .padding(.leading, 10)
                
                Spacer()
                
                Button("MIDI Mapping", action: midiMappingAction)
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 200, height: 30)
                    .background(Color(hex: "#333333"))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .padding(.trailing, 12)
                
                Button(action: settingsAction) {
                    Image(systemName: "gearshape.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 30, height: 30)
                        .foregroundColor(Color(hex: "#ccffff"))
                }
                .padding(.trailing, 10)
            }
            .padding(.top, topPadding) //  SafeArea分をここで吸収
            .padding(.bottom, 5)       //  不要な余白を入れない
        }
    }
    
    // SafeAreaTopInset
    private func safeAreaTopInset() -> CGFloat {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            return window.safeAreaInsets.top
        }
        return 20
    }
}

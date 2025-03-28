//CombinedSettingsView.swift

import SwiftUI

struct CombinedSettingsView: View {
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        AudioInterfaceSettingsView()
    }
}

struct CombinedSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        CombinedSettingsView()
    }
}

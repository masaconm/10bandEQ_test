//
//  ContentView.swift
//  10bandEQ_test
//
//  Created by 中静暢子 on 2025/02/24.
//

import SwiftUI

struct ContentView: View {
    @State private var isRecordingViewPresented = false

    var body: some View {
        ZStack {
            AudioEqualizerContentView() // 既存のイコライザー画面を維持

        }

    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .previewInterfaceOrientation(.landscapeLeft)
    }
}



//
//  ContentView.swift
//  10bandEQ_test
//
//  Created by 中静暢子 on 2025/02/24.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        AudioEqualizerContentView()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .previewInterfaceOrientation(.landscapeLeft)
    }
}

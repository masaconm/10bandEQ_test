//
//  MyApp.swift
//  10bandEQ_test
//
//  Created by 中静暢子 on 2025/02/24.
//

import SwiftUI

@main
struct MyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate // UIKit の AppDelegate を SwiftUI に統合
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .statusBar(hidden: true) // ステータスバーを非表示
            //                .previewInterfaceOrientation(.landscapeLeft) // プレビューも横向き
        }
    }
}

//
//  AppDelegate.swift
//  10bandEQ_test
//
//  Created by 中静暢子 on 2025/03/19.
//
import UIKit

class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return .landscape // iPad は横向きのみ許可
        } else {
            return .all // 念のため、他のデバイスは全向き許可
        }
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        return true
    }
}





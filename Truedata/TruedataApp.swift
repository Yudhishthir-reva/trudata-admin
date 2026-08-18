//
//  TruedataApp.swift
//  Truedata
//

import SwiftUI

@main
struct TruedataApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            SplashScreen()
                .handleNoInternet()
        }
    }
}

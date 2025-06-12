//
//  fitnessAppApp.swift
//  fitnessApp
//
//  Created by Ranbir Khaira on 2025-05-28.
//

import SwiftUI
import Firebase
import FirebaseCore

@main
struct fitnessAppApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            RootView()
            
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        
        return true
    }
}


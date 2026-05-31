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

struct RootView: View {
    @State private var showSignInView: Bool = true

    var body: some View {
        Group {
            if showSignInView {
                LoginView(showSignInView: $showSignInView)
            } else {
                RootTabView(showSignInView: $showSignInView)
            }
        }
        .onAppear {
            let authUser = try? AuthenticationManager.shared.getAuthenticatedUser()
            showSignInView = (authUser == nil)
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


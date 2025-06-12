//
//  SettingsView.swift
//  fitnessApp
//
//  Created by Ranbir Khaira on 2025-06-09.
//

import SwiftUI

@MainActor
final class SettingsViewModel: ObservableObject {
    func signOut() throws {
        try AuthenticationManager.shared.signOut()
        
    }
}

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    
    @Binding var showSignInView: Bool
    
    
    var body: some View {
        List {
            Button("Log out") {
                Task {
                    do {
                        try viewModel.signOut()
                        showSignInView = true
                    } catch {
                        print(error)
                        
                    }
                }
                
            }
        }
        .navigationBarTitle("Settings - ")
    }
}

#Preview {
    NavigationStack{
        SettingsView(showSignInView: .constant(false))
    }
    
}

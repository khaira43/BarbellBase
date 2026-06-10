//
//  LogBodyweightSheet.swift
//  fitnessApp
//

import SwiftUI
import FirebaseAuth

struct LogBodyweightSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var goalsVM: GoalsViewModel

    @State private var weightText: String = ""
    @State private var loggedAt: Date = Date()
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var canSave: Bool {
        guard let v = Double(weightText), v > 0 else { return false }
        return true
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#081f3a").ignoresSafeArea()
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Weight (lb)").font(.caption).foregroundColor(.white.opacity(0.8))
                        TextField("", text: $weightText)
                            .keyboardType(.decimalPad)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(10)
                    }
                    DatePicker("Date", selection: $loggedAt, in: ...Date(), displayedComponents: .date)
                        .colorScheme(.dark)
                        .padding()
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(10)
                    if let errorMessage {
                        Text(errorMessage).foregroundColor(.red).font(.caption)
                    }
                    Button { Task { await save() } } label: {
                        HStack {
                            if isSaving { ProgressView() }
                            Text("Save").bold()
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canSave ? Color.yellow : Color.white.opacity(0.2))
                        .foregroundColor(canSave ? .black : .white.opacity(0.5))
                        .cornerRadius(12)
                    }
                    .disabled(!canSave || isSaving)
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Log Weight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: "#081f3a"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }.foregroundColor(.red)
                }
            }
        }
    }

    private func save() async {
        guard let userId = Auth.auth().currentUser?.uid, let weight = Double(weightText) else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            try await GoalsManager.shared.logBodyweight(userId: userId, weightLb: weight, at: loggedAt)
            await goalsVM.load()
            dismiss()
        } catch {
            errorMessage = "Couldn't save weight."
        }
    }
}

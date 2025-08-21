//
//  UserManager.swift
//  fitnessApp
//
//  Created by Ranbir Khaira on 2025-07-23.
//

import Foundation
import FirebaseFirestore

final class UserManager {
    
    static let shared = UserManager()
    private init(){}
    
    func createNewUser(auth: AuthDataResultModel) async throws{
//        let db = Firestore.firestore()
//        let docRef = db.collection("users").document(auth.uid)
//        
//        let snapshot = try await docRef.getDocument()
//        if snapshot.exists {
//            print("User doc already exists: \(auth.uid). Skipping create.")
//            return
//        }
        var userData: [String: Any] = [
            "user_id" : auth.uid,
            "is_anonymous" : auth.isAnonymous,
            "date_created" : Timestamp(),
        ]
        if let email = auth.email{
            userData["email"] = email
        }
        if let photoUrl = auth.photoUrl{
            userData["photo_url"] = photoUrl
        }
//        try await docRef.setData(userData, merge: true)
        try await Firestore.firestore().collection("users").document(auth.uid).setData(userData, merge: false)
        
    }
    
    
}

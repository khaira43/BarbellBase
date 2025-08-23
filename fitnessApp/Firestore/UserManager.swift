//
//  UserManager.swift
//  fitnessApp
//
//  Created by Ranbir Khaira on 2025-07-23.
//

import Foundation
import FirebaseFirestore

struct DBUser {
    let userId: String
    let isAnonymous: Bool?
    let email: String?
    let photoUrl: String?
    let dateCreated: Date?
}

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
    
    func getUser(userId: String) async throws -> DBUser {
        let snapshot = try await Firestore.firestore().collection("users").document(userId).getDocument()
        guard let data = snapshot.data(), let userId = data["user_id"] as? String else {
            throw URLError(.badServerResponse)
        }
        
        
        let isAnonymous = data["is_anonymous"] as? Bool
        let email = data["email"] as? String
        let photoUrl = data["photo_url"] as? String
        let dateCreated = data["date_created"] as? Date
        
        return DBUser(userId: userId, isAnonymous: isAnonymous, email: email, photoUrl: photoUrl, dateCreated: dateCreated)
    }
    
    
}

//
//  JuntosAppApp.swift
//  JuntosApp
//
//  Created by JuntosApp Team on 2024.
//

import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore

@main
struct JuntosAppApp: App {
    @StateObject private var authManager = AuthenticationManager()
    @StateObject private var userManager = UserManager()
    @StateObject private var coupleManager = CoupleManager()
    
    init() {
        FirebaseApp.configure()
        
        // Configurar Firestore para persistencia offline
        let settings = FirestoreSettings()
        settings.isPersistenceEnabled = true
        settings.cacheSizeBytes = FirestoreCacheSizeUnlimited
        Firestore.firestore().settings = settings
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .environmentObject(userManager)
                .environmentObject(coupleManager)
                .onAppear {
                    authManager.checkAuthenticationState()
                }
        }
    }
}

// MARK: - Authentication Manager
class AuthenticationManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = true
    
    private var authStateListener: AuthStateDidChangeListenerHandle?
    
    init() {
        setupAuthStateListener()
    }
    
    deinit {
        if let listener = authStateListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }
    
    private func setupAuthStateListener() {
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                self?.currentUser = user
                self?.isAuthenticated = user != nil
                self?.isLoading = false
            }
        }
    }
    
    func checkAuthenticationState() {
        if let user = Auth.auth().currentUser {
            self.currentUser = user
            self.isAuthenticated = true
        }
        self.isLoading = false
    }
    
    func signOut() {
        do {
            try Auth.auth().signOut()
        } catch {
            print("Error signing out: \(error.localizedDescription)")
        }
    }
}

// MARK: - User Manager
class UserManager: ObservableObject {
    @Published var userProfile: UserProfile?
    @Published var isLoadingProfile = false
    
    private let db = Firestore.firestore()
    
    func loadUserProfile(userId: String) {
        isLoadingProfile = true
        
        db.collection("users").document(userId).getDocument { [weak self] document, error in
            DispatchQueue.main.async {
                self?.isLoadingProfile = false
                
                if let error = error {
                    print("Error loading user profile: \(error.localizedDescription)")
                    return
                }
                
                if let document = document, document.exists {
                    do {
                        self?.userProfile = try document.data(as: UserProfile.self)
                    } catch {
                        print("Error decoding user profile: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    func saveUserProfile(_ profile: UserProfile) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        do {
            try db.collection("users").document(userId).setData(from: profile)
            self.userProfile = profile
        } catch {
            print("Error saving user profile: \(error.localizedDescription)")
        }
    }
}

// MARK: - Couple Manager
class CoupleManager: ObservableObject {
    @Published var coupleData: CoupleData?
    @Published var isLoadingCouple = false
    
    private let db = Firestore.firestore()
    
    func loadCoupleData(coupleId: String) {
        isLoadingCouple = true
        
        db.collection("couples").document(coupleId).getDocument { [weak self] document, error in
            DispatchQueue.main.async {
                self?.isLoadingCouple = false
                
                if let error = error {
                    print("Error loading couple data: \(error.localizedDescription)")
                    return
                }
                
                if let document = document, document.exists {
                    do {
                        self?.coupleData = try document.data(as: CoupleData.self)
                    } catch {
                        print("Error decoding couple data: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    func createCouple(user1Id: String, user2Id: String) -> String {
        let coupleId = UUID().uuidString
        let coupleData = CoupleData(
            id: coupleId,
            user1Id: user1Id,
            user2Id: user2Id,
            createdAt: Date(),
            inviteCode: generateInviteCode()
        )
        
        do {
            try db.collection("couples").document(coupleId).setData(from: coupleData)
            self.coupleData = coupleData
            return coupleId
        } catch {
            print("Error creating couple: \(error.localizedDescription)")
            return ""
        }
    }
    
    private func generateInviteCode() -> String {
        let characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<6).map { _ in characters.randomElement()! })
    }
}
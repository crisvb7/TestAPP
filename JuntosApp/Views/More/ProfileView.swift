//
//  ProfileView.swift
//  JuntosApp
//
//  Created by JuntosApp Team on 2024.
//

import SwiftUI
import PhotosUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    
    @EnvironmentObject var userManager: UserManager
    @EnvironmentObject var coupleManager: CoupleManager
    
    @State private var name = ""
    @State private var selectedColor = "PrimaryColor"
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var profileImage: UIImage?
    @State private var isLoading = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingImagePicker = false
    @State private var showingCoupleDisconnectAlert = false
    
    private let availableColors = [
        "PrimaryColor", "blue", "green", "orange", "purple", "pink", "red", "indigo", "teal", "mint"
    ]
    
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    
    var body: some View {
        NavigationView {
            Form {
                // Profile Image Section
                Section {
                    profileImageSection
                } header: {
                    Text("Foto de Perfil")
                }
                
                // Personal Information
                Section {
                    TextField("Nombre", text: $name)
                        .textInputAutocapitalization(.words)
                } header: {
                    Text("Información Personal")
                }
                
                // Color Selection
                Section {
                    colorSelectionGrid
                } header: {
                    Text("Color Identificativo")
                } footer: {
                    Text("Este color te identificará en las actividades compartidas con tu pareja.")
                }
                
                // Couple Information
                if let coupleData = coupleManager.coupleData {
                    Section {
                        coupleInfoSection(coupleData)
                    } header: {
                        Text("Información de Pareja")
                    }
                }
                
                // Account Information
                Section {
                    accountInfoSection
                } header: {
                    Text("Cuenta")
                }
            }
            .navigationTitle("Mi Perfil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") {
                        dismiss()
                    }
                    .disabled(isLoading)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Guardar") {
                        saveProfile()
                    }
                    .disabled(isLoading || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .fontWeight(.semibold)
                }
            }
        }
        .disabled(isLoading)
        .overlay {
            if isLoading {
                loadingOverlay
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .alert("Desconectar Pareja", isPresented: $showingCoupleDisconnectAlert) {
            Button("Cancelar", role: .cancel) { }
            Button("Desconectar", role: .destructive) {
                disconnectCouple()
            }
        } message: {
            Text("¿Estás seguro de que quieres desconectarte de tu pareja? Esta acción no se puede deshacer y perderás acceso a todos los datos compartidos.")
        }
        .onAppear {
            loadCurrentUserData()
        }
    }
    
    // MARK: - Profile Image Section
    
    private var profileImageSection: some View {
        VStack(spacing: 16) {
            // Current Profile Image
            Group {
                if let profileImage = profileImage {
                    Image(uiImage: profileImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else if let photoURL = userManager.currentUser?.photoURL,
                          !photoURL.isEmpty {
                    AsyncImage(url: URL(string: photoURL)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle()
                            .fill(Color(selectedColor))
                            .overlay(
                                Text(name.prefix(1).uppercased())
                                    .font(.largeTitle)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                            )
                    }
                } else {
                    Circle()
                        .fill(Color(selectedColor))
                        .overlay(
                            Text(name.prefix(1).uppercased())
                                .font(.largeTitle)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                        )
                }
            }
            .frame(width: 120, height: 120)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
            
            // Change Photo Button
            PhotosPicker(
                selection: $selectedPhoto,
                matching: .images,
                photoLibrary: .shared()
            ) {
                Text("Cambiar Foto")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(Color("PrimaryColor"))
            }
            .onChange(of: selectedPhoto) { newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        await MainActor.run {
                            profileImage = image
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical)
    }
    
    // MARK: - Color Selection Grid
    
    private var colorSelectionGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 16) {
            ForEach(availableColors, id: \.self) { colorName in
                Button {
                    selectedColor = colorName
                } label: {
                    Circle()
                        .fill(Color(colorName))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Circle()
                                .stroke(selectedColor == colorName ? Color.primary : Color.clear, lineWidth: 3)
                        )
                        .overlay(
                            Image(systemName: "checkmark")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .opacity(selectedColor == colorName ? 1 : 0)
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Couple Info Section
    
    private func coupleInfoSection(_ coupleData: CoupleData) -> some View {
        VStack(spacing: 12) {
            InfoRow(title: "Nombre de Pareja", value: coupleData.name)
            InfoRow(title: "Fecha de Creación", value: DateFormatter.shortDate.string(from: coupleData.createdAt))
            InfoRow(title: "Código de Invitación", value: coupleData.inviteCode)
            
            Button("Desconectar Pareja") {
                showingCoupleDisconnectAlert = true
            }
            .foregroundColor(.red)
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
        }
    }
    
    // MARK: - Account Info Section
    
    private var accountInfoSection: some View {
        VStack(spacing: 12) {
            if let user = Auth.auth().currentUser {
                InfoRow(title: "Email", value: user.email ?? "No disponible")
                
                if let creationDate = user.metadata.creationDate {
                    InfoRow(title: "Miembro desde", value: DateFormatter.shortDate.string(from: creationDate))
                }
                
                InfoRow(title: "Proveedor", value: getAuthProvider(user))
            }
        }
    }
    
    // MARK: - Loading Overlay
    
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(1.2)
                
                Text("Guardando perfil...")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .padding(30)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
            )
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadCurrentUserData() {
        if let currentUser = userManager.currentUser {
            name = currentUser.name
            selectedColor = currentUser.color
        }
    }
    
    private func getAuthProvider(_ user: User) -> String {
        guard let providerData = user.providerData.first else {
            return "Email"
        }
        
        switch providerData.providerID {
        case "google.com":
            return "Google"
        case "apple.com":
            return "Apple"
        case "password":
            return "Email"
        default:
            return "Desconocido"
        }
    }
    
    // MARK: - Save Profile
    
    private func saveProfile() {
        guard let currentUser = Auth.auth().currentUser else { return }
        
        isLoading = true
        
        // Upload profile image if changed
        if let profileImage = profileImage {
            uploadProfileImage(profileImage, userId: currentUser.uid) { imageURL in
                updateUserProfile(userId: currentUser.uid, photoURL: imageURL)
            }
        } else {
            updateUserProfile(userId: currentUser.uid, photoURL: nil)
        }
    }
    
    private func uploadProfileImage(_ image: UIImage, userId: String, completion: @escaping (String?) -> Void) {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            completion(nil)
            return
        }
        
        let storageRef = storage.reference().child("profile_images/\(userId).jpg")
        
        storageRef.putData(imageData, metadata: nil) { metadata, error in
            if let error = error {
                print("Error uploading profile image: \(error)")
                completion(nil)
                return
            }
            
            storageRef.downloadURL { url, error in
                if let error = error {
                    print("Error getting download URL: \(error)")
                    completion(nil)
                } else {
                    completion(url?.absoluteString)
                }
            }
        }
    }
    
    private func updateUserProfile(userId: String, photoURL: String?) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        var updateData: [String: Any] = [
            "name": trimmedName,
            "color": selectedColor,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        
        if let photoURL = photoURL {
            updateData["photoURL"] = photoURL
        }
        
        db.collection("users").document(userId).updateData(updateData) { error in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = "Error al actualizar el perfil: \(error.localizedDescription)"
                    self.showingError = true
                } else {
                    // Update local user data
                    if var currentUser = self.userManager.currentUser {
                        currentUser.name = trimmedName
                        currentUser.color = self.selectedColor
                        if let photoURL = photoURL {
                            currentUser.photoURL = photoURL
                        }
                        self.userManager.currentUser = currentUser
                    }
                    
                    self.dismiss()
                }
            }
        }
    }
    
    // MARK: - Disconnect Couple
    
    private func disconnectCouple() {
        guard let currentUser = Auth.auth().currentUser,
              let coupleId = coupleManager.coupleData?.id else { return }
        
        isLoading = true
        
        // Remove user from couple
        db.collection("users").document(currentUser.uid).updateData([
            "coupleId": FieldValue.delete(),
            "updatedAt": FieldValue.serverTimestamp()
        ]) { error in
            if let error = error {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.errorMessage = "Error al desconectar pareja: \(error.localizedDescription)"
                    self.showingError = true
                }
                return
            }
            
            // Update couple data to remove this user
            self.db.collection("couples").document(coupleId).updateData([
                "members": FieldValue.arrayRemove([currentUser.uid]),
                "updatedAt": FieldValue.serverTimestamp()
            ]) { error in
                DispatchQueue.main.async {
                    self.isLoading = false
                    
                    if let error = error {
                        self.errorMessage = "Error al actualizar datos de pareja: \(error.localizedDescription)"
                        self.showingError = true
                    } else {
                        // Clear local couple data
                        self.coupleManager.coupleData = nil
                        if var currentUser = self.userManager.currentUser {
                            currentUser.coupleId = nil
                            self.userManager.currentUser = currentUser
                        }
                        
                        self.dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Extensions

extension DateFormatter {
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()
}

#Preview {
    ProfileView()
        .environmentObject(UserManager())
        .environmentObject(CoupleManager())
}
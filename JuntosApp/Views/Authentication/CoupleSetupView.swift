//
//  CoupleSetupView.swift
//  JuntosApp
//
//  Created by JuntosApp Team on 2024.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct CoupleSetupView: View {
    @State private var selectedOption: SetupOption = .create
    @State private var inviteCode = ""
    @State private var partnerName = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showError = false
    @State private var showSuccess = false
    
    @EnvironmentObject var userManager: UserManager
    @EnvironmentObject var coupleManager: CoupleManager
    
    private let db = Firestore.firestore()
    
    enum SetupOption {
        case create, join
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Fondo con gradiente suave
                LinearGradient(
                    colors: [Color("PrimaryColor").opacity(0.1), Color("SecondaryColor").opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 30) {
                        // Header
                        VStack(spacing: 15) {
                            Image(systemName: "heart.2.fill")
                                .font(.system(size: 60))
                                .foregroundColor(Color("PrimaryColor"))
                            
                            Text("¡Conecta con tu pareja!")
                                .font(.title)
                                .fontWeight(.bold)
                                .multilineTextAlignment(.center)
                            
                            Text("Para comenzar a usar JuntosApp, necesitas vincular tu cuenta con la de tu pareja.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .padding(.top, 40)
                        
                        // Opciones de configuración
                        VStack(spacing: 20) {
                            // Selector de opciones
                            HStack(spacing: 0) {
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        selectedOption = .create
                                    }
                                }) {
                                    Text("Crear Pareja")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(
                                            selectedOption == .create ?
                                            Color("PrimaryColor") : Color.clear
                                        )
                                        .foregroundColor(
                                            selectedOption == .create ? .white : Color("PrimaryColor")
                                        )
                                }
                                
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        selectedOption = .join
                                    }
                                }) {
                                    Text("Unirse a Pareja")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(
                                            selectedOption == .join ?
                                            Color("PrimaryColor") : Color.clear
                                        )
                                        .foregroundColor(
                                            selectedOption == .join ? .white : Color("PrimaryColor")
                                        )
                                }
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 25)
                                    .stroke(Color("PrimaryColor"), lineWidth: 2)
                            )
                            .padding(.horizontal)
                            
                            // Contenido según la opción seleccionada
                            if selectedOption == .create {
                                CreateCoupleView(
                                    partnerName: $partnerName,
                                    isLoading: $isLoading,
                                    onCreateCouple: createCouple
                                )
                            } else {
                                JoinCoupleView(
                                    inviteCode: $inviteCode,
                                    isLoading: $isLoading,
                                    onJoinCouple: joinCouple
                                )
                            }
                        }
                        
                        Spacer(minLength: 50)
                    }
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .alert("¡Éxito!", isPresented: $showSuccess) {
            Button("Continuar") {
                // La vista se actualizará automáticamente cuando se cargue el perfil
            }
        } message: {
            Text(selectedOption == .create ?
                 "Pareja creada exitosamente. Comparte el código de invitación con tu pareja." :
                 "Te has unido exitosamente a la pareja.")
        }
    }
    
    // MARK: - Create Couple
    private func createCouple() {
        guard let currentUser = Auth.auth().currentUser else { return }
        
        isLoading = true
        
        // Crear la pareja
        let coupleId = coupleManager.createCouple(user1Id: currentUser.uid, user2Id: "")
        
        // Actualizar el perfil del usuario con el coupleId
        var updatedProfile = userManager.userProfile ?? UserProfile(
            name: currentUser.displayName ?? "Usuario",
            email: currentUser.email ?? "",
            identityColor: "#FF6B6B"
        )
        updatedProfile.coupleId = coupleId
        
        userManager.saveUserProfile(updatedProfile)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            isLoading = false
            showSuccess = true
        }
    }
    
    // MARK: - Join Couple
    private func joinCouple() {
        guard let currentUser = Auth.auth().currentUser else { return }
        guard !inviteCode.isEmpty else {
            errorMessage = "Por favor, ingresa el código de invitación."
            showError = true
            return
        }
        
        isLoading = true
        
        // Buscar pareja por código de invitación
        db.collection("couples")
            .whereField("inviteCode", isEqualTo: inviteCode.uppercased())
            .getDocuments { snapshot, error in
                DispatchQueue.main.async {
                    if let error = error {
                        isLoading = false
                        errorMessage = "Error al buscar la pareja: \(error.localizedDescription)"
                        showError = true
                        return
                    }
                    
                    guard let documents = snapshot?.documents, !documents.isEmpty else {
                        isLoading = false
                        errorMessage = "Código de invitación no válido."
                        showError = true
                        return
                    }
                    
                    let coupleDoc = documents.first!
                    let coupleId = coupleDoc.documentID
                    
                    // Actualizar la pareja con el segundo usuario
                    db.collection("couples").document(coupleId).updateData([
                        "user2Id": currentUser.uid
                    ]) { error in
                        DispatchQueue.main.async {
                            if let error = error {
                                isLoading = false
                                errorMessage = "Error al unirse a la pareja: \(error.localizedDescription)"
                                showError = true
                                return
                            }
                            
                            // Actualizar el perfil del usuario
                            var updatedProfile = userManager.userProfile ?? UserProfile(
                                name: currentUser.displayName ?? "Usuario",
                                email: currentUser.email ?? "",
                                identityColor: "#4ECDC4"
                            )
                            updatedProfile.coupleId = coupleId
                            
                            userManager.saveUserProfile(updatedProfile)
                            
                            isLoading = false
                            showSuccess = true
                        }
                    }
                }
            }
    }
}

// MARK: - Create Couple View
struct CreateCoupleView: View {
    @Binding var partnerName: String
    @Binding var isLoading: Bool
    let onCreateCouple: () -> Void
    
    @EnvironmentObject var coupleManager: CoupleManager
    
    var body: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 15) {
                Text("Crear nueva pareja")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("Serás el primero en crear la pareja. Después podrás compartir el código de invitación con tu pareja para que se una.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                VStack(spacing: 15) {
                    HStack {
                        Image(systemName: "1.circle.fill")
                            .foregroundColor(Color("PrimaryColor"))
                        Text("Crea la pareja")
                            .font(.subheadline)
                        Spacer()
                    }
                    
                    HStack {
                        Image(systemName: "2.circle")
                            .foregroundColor(.secondary)
                        Text("Comparte el código con tu pareja")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    
                    HStack {
                        Image(systemName: "3.circle")
                            .foregroundColor(.secondary)
                        Text("¡Comienzan a usar JuntosApp!")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
                .padding(.vertical)
            }
            .padding(.horizontal)
            
            // Mostrar código de invitación si ya se creó la pareja
            if let coupleData = coupleManager.coupleData {
                VStack(spacing: 15) {
                    Text("Código de Invitación")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(coupleData.inviteCode)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(Color("PrimaryColor"))
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 15)
                                .fill(Color("PrimaryColor").opacity(0.1))
                        )
                    
                    Text("Comparte este código con tu pareja")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button("Copiar Código") {
                        UIPasteboard.general.string = coupleData.inviteCode
                    }
                    .font(.subheadline)
                    .foregroundColor(Color("PrimaryColor"))
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                )
                .padding(.horizontal)
            } else {
                // Botón para crear pareja
                Button(action: onCreateCouple) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        }
                        
                        Text("Crear Pareja")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color("PrimaryColor"))
                    .foregroundColor(.white)
                    .cornerRadius(25)
                }
                .disabled(isLoading)
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - Join Couple View
struct JoinCoupleView: View {
    @Binding var inviteCode: String
    @Binding var isLoading: Bool
    let onJoinCouple: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 15) {
                Text("Unirse a pareja existente")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("Si tu pareja ya creó la cuenta, pídele el código de invitación para unirte.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            
            VStack(spacing: 15) {
                Text("Código de Invitación")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                TextField("Ingresa el código", text: $inviteCode)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.allCharacters)
                    .disableAutocorrection(true)
                    .font(.title2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Text("El código tiene 6 caracteres")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Button(action: onJoinCouple) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    }
                    
                    Text("Unirse a Pareja")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(inviteCode.count == 6 ? Color("PrimaryColor") : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(25)
            }
            .disabled(isLoading || inviteCode.count != 6)
            .padding(.horizontal)
        }
    }
}

#Preview {
    CoupleSetupView()
        .environmentObject(UserManager())
        .environmentObject(CoupleManager())
}
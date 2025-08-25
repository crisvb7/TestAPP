//
//  AuthenticationView.swift
//  JuntosApp
//
//  Created by JuntosApp Team on 2024.
//

import SwiftUI
import FirebaseAuth
import GoogleSignIn
import AuthenticationServices

struct AuthenticationView: View {
    @State private var isShowingSignUp = false
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showError = false
    
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var userManager: UserManager
    
    var body: some View {
        NavigationView {
            ZStack {
                // Fondo con gradiente
                LinearGradient(
                    colors: [Color("PrimaryColor"), Color("SecondaryColor")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 30) {
                        Spacer(minLength: 60)
                        
                        // Logo y título
                        VStack(spacing: 20) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 80))
                                .foregroundColor(.white)
                            
                            Text("JuntosApp")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text("Organizando la vida en pareja")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                        }
                        
                        // Formulario de autenticación
                        VStack(spacing: 20) {
                            // Campos de email y contraseña
                            VStack(spacing: 15) {
                                CustomTextField(
                                    placeholder: "Email",
                                    text: $email,
                                    keyboardType: .emailAddress
                                )
                                
                                CustomSecureField(
                                    placeholder: "Contraseña",
                                    text: $password
                                )
                            }
                            
                            // Botón principal
                            Button(action: {
                                if isShowingSignUp {
                                    signUp()
                                } else {
                                    signIn()
                                }
                            }) {
                                HStack {
                                    if isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: Color("PrimaryColor")))
                                            .scaleEffect(0.8)
                                    }
                                    
                                    Text(isShowingSignUp ? "Crear Cuenta" : "Iniciar Sesión")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.white)
                                .foregroundColor(Color("PrimaryColor"))
                                .cornerRadius(25)
                            }
                            .disabled(isLoading || email.isEmpty || password.isEmpty)
                            
                            // Alternar entre login y registro
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    isShowingSignUp.toggle()
                                }
                            }) {
                                Text(isShowingSignUp ? "¿Ya tienes cuenta? Inicia sesión" : "¿No tienes cuenta? Regístrate")
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                            }
                            
                            // Separador
                            HStack {
                                Rectangle()
                                    .fill(Color.white.opacity(0.3))
                                    .frame(height: 1)
                                
                                Text("o")
                                    .foregroundColor(.white)
                                    .padding(.horizontal)
                                
                                Rectangle()
                                    .fill(Color.white.opacity(0.3))
                                    .frame(height: 1)
                            }
                            
                            // Botones de autenticación social
                            VStack(spacing: 12) {
                                // Google Sign In
                                Button(action: signInWithGoogle) {
                                    HStack {
                                        Image(systemName: "globe")
                                            .font(.title3)
                                        
                                        Text("Continuar con Google")
                                            .fontWeight(.medium)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .background(Color.white)
                                    .foregroundColor(.black)
                                    .cornerRadius(25)
                                }
                                
                                // Apple Sign In
                                SignInWithAppleButton(
                                    onRequest: { request in
                                        request.requestedScopes = [.fullName, .email]
                                    },
                                    onCompletion: { result in
                                        handleAppleSignIn(result: result)
                                    }
                                )
                                .signInWithAppleButtonStyle(.white)
                                .frame(height: 50)
                                .cornerRadius(25)
                            }
                        }
                        .padding(.horizontal, 30)
                        
                        Spacer(minLength: 40)
                    }
                }
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Authentication Methods
    private func signIn() {
        isLoading = true
        
        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            DispatchQueue.main.async {
                isLoading = false
                
                if let error = error {
                    errorMessage = error.localizedDescription
                    showError = true
                } else if let user = result?.user {
                    // Usuario autenticado exitosamente
                    userManager.loadUserProfile(userId: user.uid)
                }
            }
        }
    }
    
    private func signUp() {
        isLoading = true
        
        Auth.auth().createUser(withEmail: email, password: password) { result, error in
            DispatchQueue.main.async {
                isLoading = false
                
                if let error = error {
                    errorMessage = error.localizedDescription
                    showError = true
                } else if let user = result?.user {
                    // Crear perfil de usuario
                    createUserProfile(for: user)
                }
            }
        }
    }
    
    private func signInWithGoogle() {
        guard let presentingViewController = UIApplication.shared.windows.first?.rootViewController else {
            return
        }
        
        guard let clientID = FirebaseApp.app()?.options.clientID else { return }
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController) { result, error in
            if let error = error {
                errorMessage = error.localizedDescription
                showError = true
                return
            }
            
            guard let user = result?.user,
                  let idToken = user.idToken?.tokenString else {
                return
            }
            
            let credential = GoogleAuthProvider.credential(withIDToken: idToken,
                                                         accessToken: user.accessToken.tokenString)
            
            Auth.auth().signIn(with: credential) { result, error in
                DispatchQueue.main.async {
                    if let error = error {
                        errorMessage = error.localizedDescription
                        showError = true
                    } else if let user = result?.user {
                        // Verificar si es un usuario nuevo
                        if result?.additionalUserInfo?.isNewUser == true {
                            createUserProfile(for: user)
                        } else {
                            userManager.loadUserProfile(userId: user.uid)
                        }
                    }
                }
            }
        }
    }
    
    private func handleAppleSignIn(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                guard let nonce = currentNonce else {
                    fatalError("Invalid state: A login callback was received, but no login request was sent.")
                }
                guard let appleIDToken = appleIDCredential.identityToken else {
                    print("Unable to fetch identity token")
                    return
                }
                guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                    print("Unable to serialize token string from data: \(appleIDToken.debugDescription)")
                    return
                }
                
                let credential = OAuthProvider.credential(withProviderID: "apple.com",
                                                        idToken: idTokenString,
                                                        rawNonce: nonce)
                
                Auth.auth().signIn(with: credential) { result, error in
                    DispatchQueue.main.async {
                        if let error = error {
                            errorMessage = error.localizedDescription
                            showError = true
                        } else if let user = result?.user {
                            if result?.additionalUserInfo?.isNewUser == true {
                                createUserProfile(for: user)
                            } else {
                                userManager.loadUserProfile(userId: user.uid)
                            }
                        }
                    }
                }
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    private func createUserProfile(for user: User) {
        let colors = ["#FF6B6B", "#4ECDC4", "#45B7D1", "#96CEB4", "#FFEAA7", "#DDA0DD"]
        let randomColor = colors.randomElement() ?? "#FF6B6B"
        
        let profile = UserProfile(
            name: user.displayName ?? "Usuario",
            email: user.email ?? "",
            identityColor: randomColor
        )
        
        userManager.saveUserProfile(profile)
    }
    
    // Para Apple Sign In
    @State private var currentNonce: String?
    
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] =
        Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        
        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError(
                        "Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)"
                    )
                }
                return random
            }
            
            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }
                
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        
        return result
    }
}

// MARK: - Custom Text Fields
struct CustomTextField: View {
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    
    var body: some View {
        TextField(placeholder, text: $text)
            .keyboardType(keyboardType)
            .autocapitalization(.none)
            .disableAutocorrection(true)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 25)
                    .fill(Color.white.opacity(0.9))
            )
    }
}

struct CustomSecureField: View {
    let placeholder: String
    @Binding var text: String
    
    var body: some View {
        SecureField(placeholder, text: $text)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 25)
                    .fill(Color.white.opacity(0.9))
            )
    }
}

#Preview {
    AuthenticationView()
        .environmentObject(AuthenticationManager())
        .environmentObject(UserManager())
}
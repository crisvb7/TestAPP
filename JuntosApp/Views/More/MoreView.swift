//
//  MoreView.swift
//  JuntosApp
//
//  Created by JuntosApp Team on 2024.
//

import SwiftUI
import FirebaseAuth

struct MoreView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var userManager: UserManager
    @EnvironmentObject var coupleManager: CoupleManager
    
    @State private var showingProfile = false
    @State private var showingSettings = false
    @State private var showingChat = false
    @State private var showingSavingsGoals = false
    @State private var showingSubscriptions = false
    @State private var showingSignOutAlert = false
    
    var body: some View {
        NavigationView {
            List {
                // User Profile Section
                Section {
                    profileHeader
                } header: {
                    Text("Perfil")
                }
                
                // Couple Features
                if coupleManager.coupleData != nil {
                    Section {
                        chatRow
                        savingsGoalsRow
                        subscriptionsRow
                    } header: {
                        Text("Funciones de Pareja")
                    }
                }
                
                // App Settings
                Section {
                    settingsRow
                    helpRow
                    aboutRow
                } header: {
                    Text("Aplicación")
                }
                
                // Account
                Section {
                    signOutRow
                } header: {
                    Text("Cuenta")
                }
            }
            .navigationTitle("Más")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showingProfile) {
            ProfileView()
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showingChat) {
            ChatView()
        }
        .sheet(isPresented: $showingSavingsGoals) {
            SavingsGoalsView()
        }
        .sheet(isPresented: $showingSubscriptions) {
            SubscriptionsView()
        }
        .alert("Cerrar Sesión", isPresented: $showingSignOutAlert) {
            Button("Cancelar", role: .cancel) { }
            Button("Cerrar Sesión", role: .destructive) {
                signOut()
            }
        } message: {
            Text("¿Estás seguro de que quieres cerrar sesión?")
        }
    }
    
    // MARK: - Profile Header
    
    private var profileHeader: some View {
        Button {
            showingProfile = true
        } label: {
            HStack(spacing: 16) {
                // Profile Image
                AsyncImage(url: URL(string: userManager.currentUser?.photoURL ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color(userManager.currentUser?.color ?? "PrimaryColor"))
                        .overlay(
                            Text(userManager.currentUser?.name.prefix(1).uppercased() ?? "U")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                        )
                }
                .frame(width: 60, height: 60)
                .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(userManager.currentUser?.name ?? "Usuario")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    if let coupleData = coupleManager.coupleData {
                        Text("Pareja: \(coupleData.name)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Sin pareja vinculada")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("Ver y editar perfil")
                        .font(.caption)
                        .foregroundColor(Color("PrimaryColor"))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Menu Rows
    
    private var chatRow: some View {
        Button {
            showingChat = true
        } label: {
            MenuRow(
                icon: "message.fill",
                title: "Chat Interno",
                subtitle: "Mensajes rápidos con tu pareja",
                color: .blue
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var savingsGoalsRow: some View {
        Button {
            showingSavingsGoals = true
        } label: {
            MenuRow(
                icon: "target",
                title: "Metas de Ahorro",
                subtitle: "Planifica y ahorra juntos",
                color: .green
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var subscriptionsRow: some View {
        Button {
            showingSubscriptions = true
        } label: {
            MenuRow(
                icon: "creditcard.fill",
                title: "Suscripciones",
                subtitle: "Controla tus pagos recurrentes",
                color: .purple
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var settingsRow: some View {
        Button {
            showingSettings = true
        } label: {
            MenuRow(
                icon: "gearshape.fill",
                title: "Configuración",
                subtitle: "Notificaciones, privacidad y más",
                color: .gray
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var helpRow: some View {
        Link(destination: URL(string: "https://juntosapp.help")!) {
            MenuRow(
                icon: "questionmark.circle.fill",
                title: "Ayuda y Soporte",
                subtitle: "Preguntas frecuentes y contacto",
                color: .orange
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var aboutRow: some View {
        NavigationLink {
            AboutView()
        } label: {
            MenuRow(
                icon: "info.circle.fill",
                title: "Acerca de JuntosApp",
                subtitle: "Versión, términos y privacidad",
                color: .indigo
            )
        }
    }
    
    private var signOutRow: some View {
        Button {
            showingSignOutAlert = true
        } label: {
            MenuRow(
                icon: "rectangle.portrait.and.arrow.right",
                title: "Cerrar Sesión",
                subtitle: "Salir de tu cuenta",
                color: .red
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Actions
    
    private func signOut() {
        authManager.signOut()
    }
}

// MARK: - Menu Row Component

struct MenuRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            Circle()
                .fill(color.opacity(0.1))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(color)
                )
            
            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Chevron
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - About View

struct AboutView: View {
    var body: some View {
        List {
            Section {
                VStack(spacing: 16) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 60))
                        .foregroundColor(Color("PrimaryColor"))
                    
                    Text("JuntosApp")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Versión 1.0.0")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("La aplicación perfecta para parejas que empiezan a vivir juntas. Organiza tu vida en pareja de forma colaborativa.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical)
            }
            
            Section("Información") {
                InfoRow(title: "Desarrollado por", value: "JuntosApp Team")
                InfoRow(title: "Año", value: "2024")
                InfoRow(title: "Plataforma", value: "iOS")
            }
            
            Section("Legal") {
                Link("Términos de Servicio", destination: URL(string: "https://juntosapp.com/terms")!)
                Link("Política de Privacidad", destination: URL(string: "https://juntosapp.com/privacy")!)
                Link("Licencias de Terceros", destination: URL(string: "https://juntosapp.com/licenses")!)
            }
            
            Section("Contacto") {
                Link("Sitio Web", destination: URL(string: "https://juntosapp.com")!)
                Link("Soporte", destination: URL(string: "mailto:support@juntosapp.com")!)
                Link("Redes Sociales", destination: URL(string: "https://instagram.com/juntosapp")!)
            }
        }
        .navigationTitle("Acerca de")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    MoreView()
        .environmentObject(AuthenticationManager())
        .environmentObject(UserManager())
        .environmentObject(CoupleManager())
}
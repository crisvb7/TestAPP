//
//  ContentView.swift
//  JuntosApp
//
//  Created by JuntosApp Team on 2024.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var userManager: UserManager
    @EnvironmentObject var coupleManager: CoupleManager
    
    var body: some View {
        Group {
            if authManager.isLoading {
                SplashScreenView()
            } else if authManager.isAuthenticated {
                if userManager.userProfile?.coupleId != nil {
                    MainTabView()
                } else {
                    CoupleSetupView()
                }
            } else {
                AuthenticationView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authManager.isAuthenticated)
        .onChange(of: authManager.currentUser) { user in
            if let user = user {
                userManager.loadUserProfile(userId: user.uid)
            }
        }
        .onChange(of: userManager.userProfile?.coupleId) { coupleId in
            if let coupleId = coupleId {
                coupleManager.loadCoupleData(coupleId: coupleId)
            }
        }
    }
}

// MARK: - Splash Screen
struct SplashScreenView: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color("PrimaryColor"), Color("SecondaryColor")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Logo animado
                Image(systemName: "heart.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.white)
                    .scaleEffect(isAnimating ? 1.2 : 1.0)
                    .animation(
                        Animation.easeInOut(duration: 1.0)
                            .repeatForever(autoreverses: true),
                        value: isAnimating
                    )
                
                Text("JuntosApp")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("Organizando la vida en pareja")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Main Tab View
struct MainTabView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Inicio")
                }
                .tag(0)
            
            ShoppingListView()
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text("Lista")
                }
                .tag(1)
            
            ExpensesView()
                .tabItem {
                    Image(systemName: "creditcard.fill")
                    Text("Gastos")
                }
                .tag(2)
            
            DocumentsView()
                .tabItem {
                    Image(systemName: "folder.fill")
                    Text("Documentos")
                }
                .tag(3)
            
            MoreView()
                .tabItem {
                    Image(systemName: "ellipsis")
                    Text("Más")
                }
                .tag(4)
        }
        .accentColor(Color("PrimaryColor"))
    }
}

// MARK: - Home View
struct HomeView: View {
    @EnvironmentObject var userManager: UserManager
    @EnvironmentObject var coupleManager: CoupleManager
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header con saludo
                    HStack {
                        VStack(alignment: .leading) {
                            Text("¡Hola, \(userManager.userProfile?.name ?? "Usuario")!")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text("¿Qué haremos hoy juntos?")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // Avatar de la pareja
                        HStack(spacing: -10) {
                            Circle()
                                .fill(Color(userManager.userProfile?.identityColor ?? "#FF6B6B"))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Text(String(userManager.userProfile?.name.prefix(1) ?? "U"))
                                        .font(.headline)
                                        .foregroundColor(.white)
                                )
                            
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .foregroundColor(.gray)
                                )
                        }
                    }
                    .padding(.horizontal)
                    
                    // Tarjetas de acceso rápido
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 15) {
                        QuickAccessCard(
                            title: "Lista de Compras",
                            icon: "cart.fill",
                            color: Color("AccentColor1"),
                            destination: AnyView(ShoppingListView())
                        )
                        
                        QuickAccessCard(
                            title: "Tareas del Hogar",
                            icon: "house.fill",
                            color: Color("AccentColor2"),
                            destination: AnyView(HouseholdTasksView())
                        )
                        
                        QuickAccessCard(
                            title: "Calendario",
                            icon: "calendar",
                            color: Color("AccentColor3"),
                            destination: AnyView(CalendarView())
                        )
                        
                        QuickAccessCard(
                            title: "Recuerdos",
                            icon: "heart.fill",
                            color: Color("AccentColor4"),
                            destination: AnyView(MemoriesView())
                        )
                    }
                    .padding(.horizontal)
                    
                    // Resumen de actividad reciente
                    VStack(alignment: .leading, spacing: 15) {
                        HStack {
                            Text("Actividad Reciente")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            Spacer()
                            
                            Button("Ver todo") {
                                // Acción para ver toda la actividad
                            }
                            .font(.caption)
                            .foregroundColor(Color("PrimaryColor"))
                        }
                        
                        // Lista de actividades recientes
                        VStack(spacing: 10) {
                            ActivityRowView(
                                icon: "checkmark.circle.fill",
                                title: "Tarea completada",
                                subtitle: "Lavar los platos",
                                time: "Hace 2 horas",
                                color: .green
                            )
                            
                            ActivityRowView(
                                icon: "plus.circle.fill",
                                title: "Nuevo gasto",
                                subtitle: "Supermercado - €45.30",
                                time: "Hace 4 horas",
                                color: Color("PrimaryColor")
                            )
                            
                            ActivityRowView(
                                icon: "calendar.badge.plus",
                                title: "Evento añadido",
                                subtitle: "Cena romántica",
                                time: "Ayer",
                                color: .orange
                            )
                        }
                    }
                    .padding(.horizontal)
                    
                    Spacer(minLength: 100)
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Quick Access Card
struct QuickAccessCard: View {
    let title: String
    let icon: String
    let color: Color
    let destination: AnyView
    
    var body: some View {
        NavigationLink(destination: destination) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 30))
                    .foregroundColor(.white)
                    .frame(width: 60, height: 60)
                    .background(color)
                    .clipShape(RoundedRectangle(cornerRadius: 15))
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Activity Row View
struct ActivityRowView: View {
    let icon: String
    let title: String
    let subtitle: String
    let time: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(time)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthenticationManager())
        .environmentObject(UserManager())
        .environmentObject(CoupleManager())
}
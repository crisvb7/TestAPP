//
//  SettingsView.swift
//  JuntosApp
//
//  Created by JuntosApp Team on 2024.
//

import SwiftUI
import UserNotifications
import LocalAuthentication

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("shoppingListNotifications") private var shoppingListNotifications = true
    @AppStorage("expenseNotifications") private var expenseNotifications = true
    @AppStorage("calendarNotifications") private var calendarNotifications = true
    @AppStorage("taskNotifications") private var taskNotifications = true
    @AppStorage("chatNotifications") private var chatNotifications = true
    
    @AppStorage("biometricAuthEnabled") private var biometricAuthEnabled = false
    @AppStorage("autoLockEnabled") private var autoLockEnabled = false
    @AppStorage("offlineModeEnabled") private var offlineModeEnabled = true
    @AppStorage("dataUsageOptimized") private var dataUsageOptimized = false
    
    @AppStorage("darkModeEnabled") private var darkModeEnabled = false
    @AppStorage("compactMode") private var compactMode = false
    @AppStorage("animationsEnabled") private var animationsEnabled = true
    
    @State private var showingNotificationSettings = false
    @State private var showingBiometricError = false
    @State private var biometricErrorMessage = ""
    
    private let context = LAContext()
    
    var body: some View {
        NavigationView {
            List {
                // Notifications Section
                Section {
                    notificationToggle
                    
                    if notificationsEnabled {
                        notificationDetails
                    }
                } header: {
                    Text("Notificaciones")
                } footer: {
                    if !notificationsEnabled {
                        Text("Las notificaciones están deshabilitadas. Puedes habilitarlas en Configuración del sistema.")
                    }
                }
                
                // Privacy & Security Section
                Section {
                    biometricAuthToggle
                    autoLockToggle
                } header: {
                    Text("Privacidad y Seguridad")
                } footer: {
                    Text("La autenticación biométrica protege el acceso a documentos sensibles y funciones importantes.")
                }
                
                // Data & Storage Section
                Section {
                    offlineModeToggle
                    dataUsageToggle
                    storageInfo
                } header: {
                    Text("Datos y Almacenamiento")
                }
                
                // Appearance Section
                Section {
                    darkModeToggle
                    compactModeToggle
                    animationsToggle
                } header: {
                    Text("Apariencia")
                }
                
                // Advanced Section
                Section {
                    resetSettingsButton
                    exportDataButton
                } header: {
                    Text("Avanzado")
                }
            }
            .navigationTitle("Configuración")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Listo") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .alert("Error de Autenticación", isPresented: $showingBiometricError) {
            Button("OK") { }
        } message: {
            Text(biometricErrorMessage)
        }
    }
    
    // MARK: - Notification Settings
    
    private var notificationToggle: some View {
        HStack {
            SettingRow(
                icon: "bell.fill",
                title: "Notificaciones",
                color: .blue
            )
            
            Spacer()
            
            Toggle("", isOn: $notificationsEnabled)
                .onChange(of: notificationsEnabled) { enabled in
                    if enabled {
                        requestNotificationPermission()
                    }
                }
        }
    }
    
    private var notificationDetails: some View {
        Group {
            HStack {
                SettingRow(
                    icon: "cart.fill",
                    title: "Lista de Compras",
                    subtitle: "Nuevos elementos y recordatorios",
                    color: .green
                )
                
                Spacer()
                
                Toggle("", isOn: $shoppingListNotifications)
            }
            
            HStack {
                SettingRow(
                    icon: "dollarsign.circle.fill",
                    title: "Gastos",
                    subtitle: "Nuevos gastos y balances",
                    color: .orange
                )
                
                Spacer()
                
                Toggle("", isOn: $expenseNotifications)
            }
            
            HStack {
                SettingRow(
                    icon: "calendar",
                    title: "Calendario",
                    subtitle: "Eventos y recordatorios",
                    color: .red
                )
                
                Spacer()
                
                Toggle("", isOn: $calendarNotifications)
            }
            
            HStack {
                SettingRow(
                    icon: "checkmark.circle.fill",
                    title: "Tareas",
                    subtitle: "Tareas asignadas y vencimientos",
                    color: .purple
                )
                
                Spacer()
                
                Toggle("", isOn: $taskNotifications)
            }
            
            HStack {
                SettingRow(
                    icon: "message.fill",
                    title: "Chat",
                    subtitle: "Mensajes de tu pareja",
                    color: .blue
                )
                
                Spacer()
                
                Toggle("", isOn: $chatNotifications)
            }
        }
    }
    
    // MARK: - Privacy & Security
    
    private var biometricAuthToggle: some View {
        HStack {
            SettingRow(
                icon: getBiometricIcon(),
                title: getBiometricTitle(),
                subtitle: "Protege documentos y funciones sensibles",
                color: .indigo
            )
            
            Spacer()
            
            Toggle("", isOn: $biometricAuthEnabled)
                .onChange(of: biometricAuthEnabled) { enabled in
                    if enabled {
                        authenticateWithBiometrics()
                    }
                }
        }
    }
    
    private var autoLockToggle: some View {
        HStack {
            SettingRow(
                icon: "lock.fill",
                title: "Bloqueo Automático",
                subtitle: "Bloquea la app al salir",
                color: .gray
            )
            
            Spacer()
            
            Toggle("", isOn: $autoLockEnabled)
        }
    }
    
    // MARK: - Data & Storage
    
    private var offlineModeToggle: some View {
        HStack {
            SettingRow(
                icon: "wifi.slash",
                title: "Modo Offline",
                subtitle: "Sincroniza cuando hay conexión",
                color: .teal
            )
            
            Spacer()
            
            Toggle("", isOn: $offlineModeEnabled)
        }
    }
    
    private var dataUsageToggle: some View {
        HStack {
            SettingRow(
                icon: "antenna.radiowaves.left.and.right",
                title: "Optimizar Datos",
                subtitle: "Reduce el uso de datos móviles",
                color: .mint
            )
            
            Spacer()
            
            Toggle("", isOn: $dataUsageOptimized)
        }
    }
    
    private var storageInfo: some View {
        NavigationLink {
            StorageDetailView()
        } label: {
            SettingRow(
                icon: "internaldrive.fill",
                title: "Almacenamiento",
                subtitle: "Ver uso de espacio",
                color: .brown
            )
        }
    }
    
    // MARK: - Appearance
    
    private var darkModeToggle: some View {
        HStack {
            SettingRow(
                icon: "moon.fill",
                title: "Modo Oscuro",
                subtitle: "Tema oscuro para la aplicación",
                color: .black
            )
            
            Spacer()
            
            Toggle("", isOn: $darkModeEnabled)
        }
    }
    
    private var compactModeToggle: some View {
        HStack {
            SettingRow(
                icon: "rectangle.compress.vertical",
                title: "Modo Compacto",
                subtitle: "Interfaz más densa",
                color: .gray
            )
            
            Spacer()
            
            Toggle("", isOn: $compactMode)
        }
    }
    
    private var animationsToggle: some View {
        HStack {
            SettingRow(
                icon: "sparkles",
                title: "Animaciones",
                subtitle: "Efectos visuales y transiciones",
                color: .yellow
            )
            
            Spacer()
            
            Toggle("", isOn: $animationsEnabled)
        }
    }
    
    // MARK: - Advanced
    
    private var resetSettingsButton: some View {
        Button {
            resetAllSettings()
        } label: {
            SettingRow(
                icon: "arrow.clockwise",
                title: "Restablecer Configuración",
                subtitle: "Volver a valores predeterminados",
                color: .orange
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var exportDataButton: some View {
        Button {
            exportUserData()
        } label: {
            SettingRow(
                icon: "square.and.arrow.up",
                title: "Exportar Datos",
                subtitle: "Descargar copia de tus datos",
                color: .blue
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Helper Methods
    
    private func getBiometricIcon() -> String {
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            switch context.biometryType {
            case .faceID:
                return "faceid"
            case .touchID:
                return "touchid"
            default:
                return "lock.fill"
            }
        }
        
        return "lock.fill"
    }
    
    private func getBiometricTitle() -> String {
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            switch context.biometryType {
            case .faceID:
                return "Face ID"
            case .touchID:
                return "Touch ID"
            default:
                return "Autenticación Biométrica"
            }
        }
        
        return "Autenticación Biométrica"
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                if !granted {
                    self.notificationsEnabled = false
                }
            }
        }
    }
    
    private func authenticateWithBiometrics() {
        let reason = "Habilita la autenticación biométrica para proteger tus datos sensibles"
        
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, error in
            DispatchQueue.main.async {
                if !success {
                    self.biometricAuthEnabled = false
                    
                    if let error = error as? LAError {
                        switch error.code {
                        case .biometryNotAvailable:
                            self.biometricErrorMessage = "La autenticación biométrica no está disponible en este dispositivo."
                        case .biometryNotEnrolled:
                            self.biometricErrorMessage = "No hay datos biométricos configurados. Ve a Configuración para configurarlos."
                        case .userCancel:
                            return // User cancelled, don't show error
                        default:
                            self.biometricErrorMessage = "Error de autenticación biométrica: \(error.localizedDescription)"
                        }
                        
                        self.showingBiometricError = true
                    }
                }
            }
        }
    }
    
    private func resetAllSettings() {
        // Reset to default values
        notificationsEnabled = true
        shoppingListNotifications = true
        expenseNotifications = true
        calendarNotifications = true
        taskNotifications = true
        chatNotifications = true
        
        biometricAuthEnabled = false
        autoLockEnabled = false
        offlineModeEnabled = true
        dataUsageOptimized = false
        
        darkModeEnabled = false
        compactMode = false
        animationsEnabled = true
    }
    
    private func exportUserData() {
        // This would implement data export functionality
        // For now, we'll just show a placeholder
        print("Export user data functionality would be implemented here")
    }
}

// MARK: - Setting Row Component

struct SettingRow: View {
    let icon: String
    let title: String
    let subtitle: String?
    let color: Color
    
    init(icon: String, title: String, subtitle: String? = nil, color: Color) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.color = color
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Circle()
                .fill(color.opacity(0.1))
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(color)
                )
            
            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// MARK: - Storage Detail View

struct StorageDetailView: View {
    @State private var storageInfo: StorageInfo?
    
    var body: some View {
        List {
            if let info = storageInfo {
                Section("Uso de Almacenamiento") {
                    StorageRow(title: "Documentos", size: info.documentsSize, color: .blue)
                    StorageRow(title: "Fotos y Videos", size: info.mediaSize, color: .green)
                    StorageRow(title: "Datos de la App", size: info.appDataSize, color: .orange)
                    StorageRow(title: "Caché", size: info.cacheSize, color: .gray)
                }
                
                Section("Total") {
                    StorageRow(title: "Espacio Usado", size: info.totalSize, color: .primary)
                }
                
                Section {
                    Button("Limpiar Caché") {
                        clearCache()
                    }
                    .foregroundColor(.red)
                }
            } else {
                Section {
                    HStack {
                        ProgressView()
                        Text("Calculando uso de almacenamiento...")
                    }
                }
            }
        }
        .navigationTitle("Almacenamiento")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            calculateStorageUsage()
        }
    }
    
    private func calculateStorageUsage() {
        // This would calculate actual storage usage
        // For now, we'll use placeholder data
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.storageInfo = StorageInfo(
                documentsSize: 25.6,
                mediaSize: 128.3,
                appDataSize: 12.1,
                cacheSize: 8.7
            )
        }
    }
    
    private func clearCache() {
        // Implement cache clearing
        if var info = storageInfo {
            info.cacheSize = 0
            self.storageInfo = info
        }
    }
}

struct StorageRow: View {
    let title: String
    let size: Double
    let color: Color
    
    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
            
            Text(title)
            
            Spacer()
            
            Text("\(size, specifier: "%.1f") MB")
                .foregroundColor(.secondary)
        }
    }
}

struct StorageInfo {
    var documentsSize: Double
    var mediaSize: Double
    var appDataSize: Double
    var cacheSize: Double
    
    var totalSize: Double {
        documentsSize + mediaSize + appDataSize + cacheSize
    }
}

#Preview {
    SettingsView()
}
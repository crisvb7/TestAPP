//
//  SubscriptionsView.swift
//  JuntosApp
//
//  Created by JuntosApp Team on 2024.
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct SubscriptionsView: View {
    @Environment(\.dismiss) private var dismiss
    
    @EnvironmentObject var coupleManager: CoupleManager
    @EnvironmentObject var userManager: UserManager
    
    @State private var subscriptions: [Subscription] = []
    @State private var isLoading = true
    @State private var showingAddSubscription = false
    @State private var selectedFilter: SubscriptionFilter = .all
    @State private var listener: ListenerRegistration?
    
    private let db = Firestore.firestore()
    
    enum SubscriptionFilter: String, CaseIterable {
        case all = "Todas"
        case active = "Activas"
        case inactive = "Inactivas"
        case thisMonth = "Este Mes"
    }
    
    var filteredSubscriptions: [Subscription] {
        let now = Date()
        let calendar = Calendar.current
        
        switch selectedFilter {
        case .all:
            return subscriptions
        case .active:
            return subscriptions.filter { $0.isActive }
        case .inactive:
            return subscriptions.filter { !$0.isActive }
        case .thisMonth:
            return subscriptions.filter { subscription in
                guard subscription.isActive else { return false }
                let nextPayment = subscription.nextPaymentDate
                return calendar.isDate(nextPayment, equalTo: now, toGranularity: .month)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    loadingView
                } else if subscriptions.isEmpty {
                    emptyStateView
                } else {
                    subscriptionsList
                }
            }
            .navigationTitle("Suscripciones")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cerrar") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddSubscription = true
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddSubscription) {
            AddSubscriptionView()
        }
        .onAppear {
            setupSubscriptionsListener()
        }
        .onDisappear {
            listener?.remove()
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Cargando suscripciones...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "creditcard")
                .font(.system(size: 60))
                .foregroundColor(Color("PrimaryColor").opacity(0.6))
            
            VStack(spacing: 12) {
                Text("¡Gestionen sus suscripciones!")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Mantengan un control de todos sus pagos recurrentes en un solo lugar")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Button {
                showingAddSubscription = true
            } label: {
                HStack {
                    Image(systemName: "plus")
                    Text("Agregar Suscripción")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 25)
                        .fill(Color("PrimaryColor"))
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Subscriptions List
    
    private var subscriptionsList: some View {
        VStack(spacing: 0) {
            // Summary Card
            summaryCard
                .padding(.horizontal)
                .padding(.top)
            
            // Filter Picker
            filterPicker
                .padding(.horizontal)
                .padding(.top)
            
            // Subscriptions
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(filteredSubscriptions) { subscription in
                        SubscriptionCard(subscription: subscription)
                    }
                }
                .padding()
            }
        }
    }
    
    // MARK: - Summary Card
    
    private var summaryCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Resumen Mensual")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(Color("PrimaryColor"))
            }
            
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Mensual")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("$\(monthlyTotal, specifier: "%.2f")")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Suscripciones Activas")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(activeSubscriptionsCount)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(Color("PrimaryColor"))
                }
            }
            
            // Next payments
            if !upcomingPayments.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Próximos Pagos (7 días)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    ForEach(upcomingPayments.prefix(3), id: \.id) { subscription in
                        HStack {
                            Text(subscription.name)
                                .font(.caption)
                            
                            Spacer()
                            
                            Text(subscription.nextPaymentDate, style: .date)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("$\(subscription.amount, specifier: "%.2f")")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
        )
    }
    
    // MARK: - Filter Picker
    
    private var filterPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(SubscriptionFilter.allCases, id: \.self) { filter in
                    Button {
                        selectedFilter = filter
                    } label: {
                        Text(filter.rawValue)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(selectedFilter == filter ? Color("PrimaryColor") : Color(.systemGray6))
                            )
                            .foregroundColor(selectedFilter == filter ? .white : .primary)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Computed Properties
    
    private var monthlyTotal: Double {
        subscriptions
            .filter { $0.isActive }
            .reduce(0) { total, subscription in
                switch subscription.frequency {
                case .monthly:
                    return total + subscription.amount
                case .yearly:
                    return total + (subscription.amount / 12)
                case .weekly:
                    return total + (subscription.amount * 4.33)
                }
            }
    }
    
    private var activeSubscriptionsCount: Int {
        subscriptions.filter { $0.isActive }.count
    }
    
    private var upcomingPayments: [Subscription] {
        let calendar = Calendar.current
        let now = Date()
        let weekFromNow = calendar.date(byAdding: .day, value: 7, to: now) ?? now
        
        return subscriptions
            .filter { $0.isActive }
            .filter { subscription in
                let nextPayment = subscription.nextPaymentDate
                return nextPayment >= now && nextPayment <= weekFromNow
            }
            .sorted { $0.nextPaymentDate < $1.nextPaymentDate }
    }
    
    // MARK: - Helper Methods
    
    private func setupSubscriptionsListener() {
        guard let coupleId = coupleManager.coupleData?.id else {
            isLoading = false
            return
        }
        
        listener = db.collection("couples")
            .document(coupleId)
            .collection("subscriptions")
            .order(by: "createdAt", descending: false)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("Error listening to subscriptions: \(error)")
                    self.isLoading = false
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    self.isLoading = false
                    return
                }
                
                self.subscriptions = documents.compactMap { document in
                    try? document.data(as: Subscription.self)
                }
                
                self.isLoading = false
            }
    }
}

// MARK: - Subscription Card

struct SubscriptionCard: View {
    let subscription: Subscription
    
    @State private var showingDetail = false
    
    private var statusColor: Color {
        subscription.isActive ? .green : .gray
    }
    
    private var frequencyText: String {
        switch subscription.frequency {
        case .monthly:
            return "mensual"
        case .yearly:
            return "anual"
        case .weekly:
            return "semanal"
        }
    }
    
    private var daysUntilPayment: Int {
        let calendar = Calendar.current
        let now = Date()
        return calendar.dateComponents([.day], from: now, to: subscription.nextPaymentDate).day ?? 0
    }
    
    var body: some View {
        Button {
            showingDetail = true
        } label: {
            HStack(spacing: 12) {
                // Service Icon/Image
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color("PrimaryColor").opacity(0.1))
                        .frame(width: 50, height: 50)
                    
                    if let iconName = subscription.iconName {
                        Image(systemName: iconName)
                            .font(.title2)
                            .foregroundColor(Color("PrimaryColor"))
                    } else {
                        Text(String(subscription.name.prefix(2)).uppercased())
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(Color("PrimaryColor"))
                    }
                }
                
                // Subscription Info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(subscription.name)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Circle()
                            .fill(statusColor)
                            .frame(width: 8, height: 8)
                    }
                    
                    HStack {
                        Text("$\(subscription.amount, specifier: "%.2f") / \(frequencyText)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        if subscription.isActive {
                            if daysUntilPayment == 0 {
                                Text("¡Hoy!")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.red)
                            } else if daysUntilPayment == 1 {
                                Text("Mañana")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.orange)
                            } else if daysUntilPayment <= 7 {
                                Text("\(daysUntilPayment) días")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                Text(subscription.nextPaymentDate, style: .date)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            Text("Inactiva")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    if let category = subscription.category {
                        Text(category)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(.systemGray6))
                            )
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingDetail) {
            SubscriptionDetailView(subscription: subscription)
        }
    }
}

// MARK: - Add Subscription View

struct AddSubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    
    @EnvironmentObject var coupleManager: CoupleManager
    
    @State private var name = ""
    @State private var amount = ""
    @State private var frequency: SubscriptionFrequency = .monthly
    @State private var category = ""
    @State private var startDate = Date()
    @State private var iconName = ""
    @State private var notes = ""
    @State private var isActive = true
    @State private var isSaving = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    private let db = Firestore.firestore()
    
    private let categories = [
        "Entretenimiento", "Música", "Video", "Noticias", "Productividad",
        "Fitness", "Comida", "Transporte", "Servicios", "Otros"
    ]
    
    private let commonIcons = [
        "tv", "music.note", "newspaper", "gamecontroller", "dumbbell",
        "car", "house", "wifi", "phone", "creditcard"
    ]
    
    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !amount.isEmpty &&
        Double(amount) != nil &&
        Double(amount) ?? 0 > 0
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Información Básica") {
                    TextField("Nombre del servicio", text: $name)
                        .textInputAutocapitalization(.words)
                    
                    HStack {
                        Text("$")
                            .foregroundColor(.secondary)
                        
                        TextField("Precio", text: $amount)
                            .keyboardType(.decimalPad)
                    }
                    
                    Picker("Frecuencia", selection: $frequency) {
                        Text("Semanal").tag(SubscriptionFrequency.weekly)
                        Text("Mensual").tag(SubscriptionFrequency.monthly)
                        Text("Anual").tag(SubscriptionFrequency.yearly)
                    }
                }
                
                Section("Detalles") {
                    Picker("Categoría", selection: $category) {
                        Text("Seleccionar...").tag("")
                        ForEach(categories, id: \.self) { cat in
                            Text(cat).tag(cat)
                        }
                    }
                    
                    DatePicker("Fecha de inicio", selection: $startDate, displayedComponents: .date)
                    
                    TextField("Notas (opcional)", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }
                
                Section("Personalización") {
                    Picker("Icono", selection: $iconName) {
                        Text("Sin icono").tag("")
                        ForEach(commonIcons, id: \.self) { icon in
                            HStack {
                                Image(systemName: icon)
                                Text(icon)
                            }
                            .tag(icon)
                        }
                    }
                    
                    Toggle("Suscripción activa", isOn: $isActive)
                }
                
                if canSave {
                    Section("Vista Previa") {
                        subscriptionPreview
                    }
                }
            }
            .navigationTitle("Nueva Suscripción")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Crear") {
                        saveSubscription()
                    }
                    .disabled(!canSave || isSaving)
                    .fontWeight(.semibold)
                }
            }
        }
        .disabled(isSaving)
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private var subscriptionPreview: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color("PrimaryColor").opacity(0.1))
                    .frame(width: 40, height: 40)
                
                if !iconName.isEmpty {
                    Image(systemName: iconName)
                        .foregroundColor(Color("PrimaryColor"))
                } else {
                    Text(String(name.prefix(2)).uppercased())
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(Color("PrimaryColor"))
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("$\(amount) / \(frequency.rawValue.lowercased())")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if !category.isEmpty {
                    Text(category)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(.systemGray6))
                        )
                }
            }
            
            Spacer()
            
            Circle()
                .fill(isActive ? .green : .gray)
                .frame(width: 8, height: 8)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
    
    private func saveSubscription() {
        guard let coupleId = coupleManager.coupleData?.id,
              let currentUser = Auth.auth().currentUser,
              let price = Double(amount) else {
            return
        }
        
        isSaving = true
        
        let subscription = Subscription(
            id: UUID().uuidString,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            amount: price,
            frequency: frequency,
            category: category.isEmpty ? nil : category,
            startDate: startDate,
            iconName: iconName.isEmpty ? nil : iconName,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes.trimmingCharacters(in: .whitespacesAndNewlines),
            isActive: isActive,
            createdBy: currentUser.uid,
            createdAt: Date()
        )
        
        do {
            try db.collection("couples")
                .document(coupleId)
                .collection("subscriptions")
                .document(subscription.id)
                .setData(from: subscription) { error in
                    DispatchQueue.main.async {
                        self.isSaving = false
                        
                        if let error = error {
                            self.errorMessage = "Error al crear la suscripción: \(error.localizedDescription)"
                            self.showingError = true
                        } else {
                            self.dismiss()
                        }
                    }
                }
        } catch {
            DispatchQueue.main.async {
                self.isSaving = false
                self.errorMessage = "Error al procesar la suscripción: \(error.localizedDescription)"
                self.showingError = true
            }
        }
    }
}

// MARK: - Subscription Detail View

struct SubscriptionDetailView: View {
    @Environment(\.dismiss) private var dismiss
    
    let subscription: Subscription
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Subscription Header
                    subscriptionHeader
                    
                    // Payment History
                    paymentHistory
                    
                    // Actions
                    actionButtons
                }
                .padding()
            }
            .navigationTitle(subscription.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cerrar") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Editar") {
                        // Edit subscription logic
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private var subscriptionHeader: some View {
        VStack(spacing: 16) {
            // Icon and basic info
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color("PrimaryColor").opacity(0.1))
                        .frame(width: 80, height: 80)
                    
                    if let iconName = subscription.iconName {
                        Image(systemName: iconName)
                            .font(.system(size: 32))
                            .foregroundColor(Color("PrimaryColor"))
                    } else {
                        Text(String(subscription.name.prefix(2)).uppercased())
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(Color("PrimaryColor"))
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 8) {
                    Text("$\(subscription.amount, specifier: "%.2f")")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text(subscription.frequency.rawValue)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Circle()
                            .fill(subscription.isActive ? .green : .gray)
                            .frame(width: 8, height: 8)
                        
                        Text(subscription.isActive ? "Activa" : "Inactiva")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Details
            VStack(spacing: 12) {
                if let category = subscription.category {
                    InfoRow(title: "Categoría", value: category)
                }
                
                InfoRow(title: "Fecha de inicio", value: subscription.startDate.formatted(date: .abbreviated, time: .omitted))
                InfoRow(title: "Próximo pago", value: subscription.nextPaymentDate.formatted(date: .abbreviated, time: .omitted))
                
                if let notes = subscription.notes {
                    InfoRow(title: "Notas", value: notes)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
        )
    }
    
    private var paymentHistory: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Historial de Pagos")
                .font(.headline)
                .fontWeight(.semibold)
            
            // Placeholder for payment history
            Text("Próximamente: Historial detallado de pagos")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 20)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
        )
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                // Toggle active status
            } label: {
                HStack {
                    Image(systemName: subscription.isActive ? "pause.circle" : "play.circle")
                    Text(subscription.isActive ? "Pausar Suscripción" : "Activar Suscripción")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(subscription.isActive ? .orange : .green)
                )
            }
            
            Button {
                // Delete subscription
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("Eliminar Suscripción")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.red)
                )
            }
        }
    }
}

#Preview {
    SubscriptionsView()
        .environmentObject(CoupleManager())
        .environmentObject(UserManager())
}
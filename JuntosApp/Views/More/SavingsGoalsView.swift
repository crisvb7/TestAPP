//
//  SavingsGoalsView.swift
//  JuntosApp
//
//  Created by JuntosApp Team on 2024.
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import Charts

struct SavingsGoalsView: View {
    @Environment(\.dismiss) private var dismiss
    
    @EnvironmentObject var coupleManager: CoupleManager
    @EnvironmentObject var userManager: UserManager
    
    @State private var savingsGoals: [SavingsGoal] = []
    @State private var isLoading = true
    @State private var showingAddGoal = false
    @State private var listener: ListenerRegistration?
    
    private let db = Firestore.firestore()
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    loadingView
                } else if savingsGoals.isEmpty {
                    emptyStateView
                } else {
                    goalsList
                }
            }
            .navigationTitle("Metas de Ahorro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cerrar") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddGoal = true
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddGoal) {
            AddSavingsGoalView()
        }
        .onAppear {
            setupGoalsListener()
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
            
            Text("Cargando metas...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "target")
                .font(.system(size: 60))
                .foregroundColor(Color("PrimaryColor").opacity(0.6))
            
            VStack(spacing: 12) {
                Text("¡Creen su primera meta!")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Establezcan objetivos de ahorro y trabajen juntos para alcanzarlos")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Button {
                showingAddGoal = true
            } label: {
                HStack {
                    Image(systemName: "plus")
                    Text("Crear Meta")
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
    
    // MARK: - Goals List
    
    private var goalsList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Summary Card
                summaryCard
                
                // Goals
                ForEach(savingsGoals) { goal in
                    SavingsGoalCard(goal: goal)
                }
            }
            .padding()
        }
    }
    
    // MARK: - Summary Card
    
    private var summaryCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Resumen de Ahorros")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(Color("PrimaryColor"))
            }
            
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Ahorrado")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("$\(totalSaved, specifier: "%.2f")")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Meta Total")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("$\(totalTarget, specifier: "%.2f")")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(Color("PrimaryColor"))
                }
            }
            
            // Progress Bar
            ProgressView(value: totalProgress)
                .progressViewStyle(LinearProgressViewStyle(tint: Color("PrimaryColor")))
                .scaleEffect(x: 1, y: 2, anchor: .center)
            
            Text("\(Int(totalProgress * 100))% completado")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
        )
    }
    
    // MARK: - Computed Properties
    
    private var totalSaved: Double {
        savingsGoals.reduce(0) { $0 + $1.currentAmount }
    }
    
    private var totalTarget: Double {
        savingsGoals.reduce(0) { $0 + $1.targetAmount }
    }
    
    private var totalProgress: Double {
        guard totalTarget > 0 else { return 0 }
        return min(totalSaved / totalTarget, 1.0)
    }
    
    // MARK: - Helper Methods
    
    private func setupGoalsListener() {
        guard let coupleId = coupleManager.coupleData?.id else {
            isLoading = false
            return
        }
        
        listener = db.collection("couples")
            .document(coupleId)
            .collection("savingsGoals")
            .order(by: "createdAt", descending: false)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("Error listening to savings goals: \(error)")
                    self.isLoading = false
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    self.isLoading = false
                    return
                }
                
                self.savingsGoals = documents.compactMap { document in
                    try? document.data(as: SavingsGoal.self)
                }
                
                self.isLoading = false
            }
    }
}

// MARK: - Savings Goal Card

struct SavingsGoalCard: View {
    let goal: SavingsGoal
    
    @State private var showingDetail = false
    
    private var progress: Double {
        guard goal.targetAmount > 0 else { return 0 }
        return min(goal.currentAmount / goal.targetAmount, 1.0)
    }
    
    private var daysRemaining: Int {
        let calendar = Calendar.current
        let now = Date()
        return calendar.dateComponents([.day], from: now, to: goal.targetDate).day ?? 0
    }
    
    var body: some View {
        Button {
            showingDetail = true
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(goal.title)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        if let description = goal.description {
                            Text(description)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("$\(goal.currentAmount, specifier: "%.0f")")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                        
                        Text("de $\(goal.targetAmount, specifier: "%.0f")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Progress Bar
                VStack(alignment: .leading, spacing: 8) {
                    ProgressView(value: progress)
                        .progressViewStyle(LinearProgressViewStyle(tint: progress >= 1.0 ? .green : Color("PrimaryColor")))
                        .scaleEffect(x: 1, y: 1.5, anchor: .center)
                    
                    HStack {
                        Text("\(Int(progress * 100))% completado")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        if daysRemaining > 0 {
                            Text("\(daysRemaining) días restantes")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else if daysRemaining == 0 {
                            Text("¡Hoy es el día!")
                                .font(.caption)
                                .foregroundColor(.orange)
                                .fontWeight(.medium)
                        } else {
                            Text("Meta vencida")
                                .font(.caption)
                                .foregroundColor(.red)
                                .fontWeight(.medium)
                        }
                    }
                }
                
                // Status Badge
                HStack {
                    if progress >= 1.0 {
                        Label("¡Completada!", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    } else if daysRemaining < 0 {
                        Label("Vencida", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(.red)
                    } else {
                        Label("En progreso", systemImage: "clock.fill")
                            .font(.caption)
                            .foregroundColor(Color("PrimaryColor"))
                    }
                    
                    Spacer()
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
            SavingsGoalDetailView(goal: goal)
        }
    }
}

// MARK: - Add Savings Goal View

struct AddSavingsGoalView: View {
    @Environment(\.dismiss) private var dismiss
    
    @EnvironmentObject var coupleManager: CoupleManager
    
    @State private var title = ""
    @State private var description = ""
    @State private var targetAmount = ""
    @State private var targetDate = Date().addingTimeInterval(30 * 24 * 60 * 60) // 30 days from now
    @State private var isSaving = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    private let db = Firestore.firestore()
    
    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !targetAmount.isEmpty &&
        Double(targetAmount) != nil &&
        Double(targetAmount) ?? 0 > 0
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Información Básica") {
                    TextField("Título de la meta", text: $title)
                        .textInputAutocapitalization(.sentences)
                    
                    TextField("Descripción (opcional)", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                        .textInputAutocapitalization(.sentences)
                }
                
                Section("Objetivo") {
                    HStack {
                        Text("$")
                            .foregroundColor(.secondary)
                        
                        TextField("Cantidad objetivo", text: $targetAmount)
                            .keyboardType(.decimalPad)
                    }
                    
                    DatePicker("Fecha objetivo", selection: $targetDate, in: Date()..., displayedComponents: .date)
                }
                
                if canSave {
                    Section("Vista Previa") {
                        goalPreview
                    }
                }
            }
            .navigationTitle("Nueva Meta")
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
                        saveGoal()
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
    
    private var goalPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("$\(targetAmount)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(Color("PrimaryColor"))
            }
            
            if !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Label("Meta para \(targetDate, style: .date)", systemImage: "calendar")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
    
    private func saveGoal() {
        guard let coupleId = coupleManager.coupleData?.id,
              let currentUser = Auth.auth().currentUser,
              let amount = Double(targetAmount) else {
            return
        }
        
        isSaving = true
        
        let goal = SavingsGoal(
            id: UUID().uuidString,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            description: description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : description.trimmingCharacters(in: .whitespacesAndNewlines),
            targetAmount: amount,
            currentAmount: 0,
            targetDate: targetDate,
            createdBy: currentUser.uid,
            createdAt: Date()
        )
        
        do {
            try db.collection("couples")
                .document(coupleId)
                .collection("savingsGoals")
                .document(goal.id)
                .setData(from: goal) { error in
                    DispatchQueue.main.async {
                        self.isSaving = false
                        
                        if let error = error {
                            self.errorMessage = "Error al crear la meta: \(error.localizedDescription)"
                            self.showingError = true
                        } else {
                            self.dismiss()
                        }
                    }
                }
        } catch {
            DispatchQueue.main.async {
                self.isSaving = false
                self.errorMessage = "Error al procesar la meta: \(error.localizedDescription)"
                self.showingError = true
            }
        }
    }
}

// MARK: - Savings Goal Detail View

struct SavingsGoalDetailView: View {
    @Environment(\.dismiss) private var dismiss
    
    let goal: SavingsGoal
    
    @State private var showingAddContribution = false
    \State private var contributions: [SavingsContribution] = []
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Goal Header
                    goalHeader
                    
                    // Progress Chart
                    progressChart
                    
                    // Contributions List
                    contributionsList
                }
                .padding()
            }
            .navigationTitle(goal.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cerrar") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Agregar") {
                        showingAddContribution = true
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .sheet(isPresented: $showingAddContribution) {
            AddContributionView(goal: goal)
        }
    }
    
    private var goalHeader: some View {
        VStack(spacing: 16) {
            // Progress Ring
            ZStack {
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 8)
                    .frame(width: 120, height: 120)
                
                Circle()
                    .trim(from: 0, to: min(goal.currentAmount / goal.targetAmount, 1.0))
                    .stroke(Color("PrimaryColor"), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                
                VStack {
                    Text("\(Int((goal.currentAmount / goal.targetAmount) * 100))%")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("completado")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Amounts
            HStack(spacing: 40) {
                VStack {
                    Text("$\(goal.currentAmount, specifier: "%.0f")")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                    
                    Text("Ahorrado")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack {
                    Text("$\(goal.targetAmount - goal.currentAmount, specifier: "%.0f")")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                    
                    Text("Restante")
                        .font(.caption)
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
    
    private var progressChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Progreso en el Tiempo")
                .font(.headline)
                .fontWeight(.semibold)
            
            // Placeholder for chart - in a real app, you'd use Swift Charts
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
                .frame(height: 200)
                .overlay(
                    Text("Gráfico de Progreso")
                        .foregroundColor(.secondary)
                )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
        )
    }
    
    private var contributionsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Contribuciones")
                .font(.headline)
                .fontWeight(.semibold)
            
            if contributions.isEmpty {
                Text("Aún no hay contribuciones")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                ForEach(contributions) { contribution in
                    ContributionRow(contribution: contribution)
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
}

// MARK: - Supporting Views and Models

struct SavingsContribution: Identifiable, Codable {
    let id: String
    let goalId: String
    let amount: Double
    let contributorId: String
    let note: String?
    let date: Date
}

struct ContributionRow: View {
    let contribution: SavingsContribution
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("+$\(contribution.amount, specifier: "%.2f")")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.green)
                
                if let note = contribution.note {
                    Text(note)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Text(contribution.date, style: .date)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct AddContributionView: View {
    @Environment(\.dismiss) private var dismiss
    
    let goal: SavingsGoal
    
    @State private var amount = ""
    @State private var note = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Contribución") {
                    HStack {
                        Text("$")
                            .foregroundColor(.secondary)
                        
                        TextField("Cantidad", text: $amount)
                            .keyboardType(.decimalPad)
                    }
                    
                    TextField("Nota (opcional)", text: $note)
                        .textInputAutocapitalization(.sentences)
                }
            }
            .navigationTitle("Agregar Dinero")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Agregar") {
                        // Add contribution logic here
                        dismiss()
                    }
                    .disabled(amount.isEmpty || Double(amount) == nil)
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

#Preview {
    SavingsGoalsView()
        .environmentObject(CoupleManager())
        .environmentObject(UserManager())
}
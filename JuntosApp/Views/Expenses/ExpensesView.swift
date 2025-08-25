//
//  ExpensesView.swift
//  JuntosApp
//
//  Created by JuntosApp Team on 2024.
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import Charts

struct ExpensesView: View {
    @State private var expenses: [Expense] = []
    @State private var showingAddExpense = false
    @State private var selectedPeriod: TimePeriod = .thisMonth
    @State private var showingBalance = false
    @State private var balance: Double = 0.0
    @State private var user1Total: Double = 0.0
    @State private var user2Total: Double = 0.0
    
    @EnvironmentObject var coupleManager: CoupleManager
    @EnvironmentObject var userManager: UserManager
    
    private let db = Firestore.firestore()
    
    enum TimePeriod: String, CaseIterable {
        case thisWeek = "Esta Semana"
        case thisMonth = "Este Mes"
        case lastMonth = "Mes Anterior"
        case thisYear = "Este Año"
    }
    
    var filteredExpenses: [Expense] {
        let calendar = Calendar.current
        let now = Date()
        
        return expenses.filter { expense in
            switch selectedPeriod {
            case .thisWeek:
                return calendar.isDate(expense.date, equalTo: now, toGranularity: .weekOfYear)
            case .thisMonth:
                return calendar.isDate(expense.date, equalTo: now, toGranularity: .month)
            case .lastMonth:
                let lastMonth = calendar.date(byAdding: .month, value: -1, to: now) ?? now
                return calendar.isDate(expense.date, equalTo: lastMonth, toGranularity: .month)
            case .thisYear:
                return calendar.isDate(expense.date, equalTo: now, toGranularity: .year)
            }
        }.sorted { $0.date > $1.date }
    }
    
    var totalAmount: Double {
        filteredExpenses.reduce(0) { $0 + $1.amount }
    }
    
    var expensesByCategory: [ExpenseCategory: Double] {
        Dictionary(grouping: filteredExpenses, by: { $0.category })
            .mapValues { expenses in
                expenses.reduce(0) { $0 + $1.amount }
            }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Selector de período
                        periodSelector
                        
                        // Resumen financiero
                        financialSummaryCard
                        
                        // Balance entre usuarios
                        if coupleManager.coupleData?.user2Id != nil {
                            balanceCard
                        }
                        
                        // Gráfica por categorías
                        if !filteredExpenses.isEmpty {
                            categoryChartCard
                        }
                        
                        // Lista de gastos
                        expensesListCard
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Gastos")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddExpense = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.title2)
                            .foregroundColor(Color("PrimaryColor"))
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddExpense) {
            AddExpenseView { expense in
                addExpense(expense)
            }
        }
        .onAppear {
            loadExpenses()
            setupRealtimeListener()
        }
        .onChange(of: filteredExpenses) { _ in
            calculateBalance()
        }
    }
    
    // MARK: - UI Components
    
    private var periodSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(TimePeriod.allCases, id: \.self) { period in
                    Button(period.rawValue) {
                        selectedPeriod = period
                    }
                    .padding(.horizontal, 15)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(selectedPeriod == period ? Color("PrimaryColor") : Color(.systemBackground))
                    )
                    .foregroundColor(selectedPeriod == period ? .white : Color("PrimaryColor"))
                    .font(.subheadline)
                    .fontWeight(.medium)
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var financialSummaryCard: some View {
        VStack(spacing: 15) {
            HStack {
                Text("Resumen Financiero")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Text(selectedPeriod.rawValue)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 10) {
                HStack {
                    Text("Total Gastado")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("$\(totalAmount, specifier: "%.2f")")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(Color("PrimaryColor"))
                }
                
                HStack {
                    Text("Número de Gastos")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(filteredExpenses.count)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                if !filteredExpenses.isEmpty {
                    HStack {
                        Text("Promedio por Gasto")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("$\(totalAmount / Double(filteredExpenses.count), specifier: "%.2f")")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
    }
    
    private var balanceCard: some View {
        VStack(spacing: 15) {
            HStack {
                Text("Balance de Pareja")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Button("Ver Detalles") {
                    showingBalance = true
                }
                .font(.subheadline)
                .foregroundColor(Color("PrimaryColor"))
            }
            
            if abs(balance) < 0.01 {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Están al día")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                }
            } else {
                VStack(spacing: 8) {
                    if balance > 0 {
                        Text("Te deben $\(balance, specifier: "%.2f")")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                    } else {
                        Text("Debes $\(abs(balance), specifier: "%.2f")")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
        .sheet(isPresented: $showingBalance) {
            BalanceDetailView(
                balance: balance,
                user1Total: user1Total,
                user2Total: user2Total,
                expenses: filteredExpenses
            )
        }
    }
    
    private var categoryChartCard: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Gastos por Categoría")
                .font(.headline)
                .fontWeight(.semibold)
            
            if #available(iOS 16.0, *) {
                Chart {
                    ForEach(Array(expensesByCategory.keys), id: \.self) { category in
                        BarMark(
                            x: .value("Categoría", category.displayName),
                            y: .value("Monto", expensesByCategory[category] ?? 0)
                        )
                        .foregroundStyle(Color(category.color))
                    }
                }
                .frame(height: 200)
            } else {
                // Fallback para iOS 15
                VStack(spacing: 10) {
                    ForEach(Array(expensesByCategory.keys), id: \.self) { category in
                        HStack {
                            Circle()
                                .fill(Color(category.color))
                                .frame(width: 12, height: 12)
                            
                            Text(category.displayName)
                                .font(.subheadline)
                            
                            Spacer()
                            
                            Text("$\(expensesByCategory[category] ?? 0, specifier: "%.2f")")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
    }
    
    private var expensesListCard: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text("Gastos Recientes")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                if filteredExpenses.count > 5 {
                    Text("Mostrando \(min(5, filteredExpenses.count)) de \(filteredExpenses.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if filteredExpenses.isEmpty {
                VStack(spacing: 15) {
                    Image(systemName: "creditcard")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    
                    Text("No hay gastos registrados")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("Agrega tu primer gasto para comenzar")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(Array(filteredExpenses.prefix(5))) { expense in
                        ExpenseRow(expense: expense) {
                            deleteExpense(expense)
                        }
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
    }
    
    // MARK: - Firebase Operations
    
    private func loadExpenses() {
        guard let coupleId = coupleManager.coupleData?.id else { return }
        
        db.collection("couples").document(coupleId).collection("expenses")
            .order(by: "date", descending: true)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error loading expenses: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                DispatchQueue.main.async {
                    self.expenses = documents.compactMap { doc in
                        try? doc.data(as: Expense.self)
                    }
                }
            }
    }
    
    private func setupRealtimeListener() {
        guard let coupleId = coupleManager.coupleData?.id else { return }
        
        db.collection("couples").document(coupleId).collection("expenses")
            .order(by: "date", descending: true)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("Error in expenses listener: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                DispatchQueue.main.async {
                    self.expenses = documents.compactMap { doc in
                        try? doc.data(as: Expense.self)
                    }
                }
            }
    }
    
    private func addExpense(_ expense: Expense) {
        guard let coupleId = coupleManager.coupleData?.id else { return }
        
        do {
            try db.collection("couples").document(coupleId).collection("expenses")
                .document(expense.id).setData(from: expense)
        } catch {
            print("Error adding expense: \(error)")
        }
    }
    
    private func deleteExpense(_ expense: Expense) {
        guard let coupleId = coupleManager.coupleData?.id else { return }
        
        db.collection("couples").document(coupleId).collection("expenses")
            .document(expense.id).delete()
    }
    
    private func calculateBalance() {
        guard let currentUserId = Auth.auth().currentUser?.uid,
              let coupleData = coupleManager.coupleData else {
            return
        }
        
        let user1Id = coupleData.user1Id
        let user2Id = coupleData.user2Id ?? ""
        
        var user1Paid: Double = 0
        var user2Paid: Double = 0
        var user1Share: Double = 0
        var user2Share: Double = 0
        
        for expense in filteredExpenses {
            if expense.paidBy == user1Id {
                user1Paid += expense.amount
            } else if expense.paidBy == user2Id {
                user2Paid += expense.amount
            }
            
            if expense.isShared {
                user1Share += expense.amount / 2
                user2Share += expense.amount / 2
            } else {
                if expense.paidBy == user1Id {
                    user1Share += expense.amount
                } else {
                    user2Share += expense.amount
                }
            }
        }
        
        user1Total = user1Paid
        user2Total = user2Paid
        
        // Balance desde la perspectiva del usuario actual
        if currentUserId == user1Id {
            balance = user1Paid - user1Share
        } else {
            balance = user2Paid - user2Share
        }
    }
}

// MARK: - Expense Row
struct ExpenseRow: View {
    let expense: Expense
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Icono de categoría
            Circle()
                .fill(Color(expense.category.color))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: expense.category.icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                )
            
            // Información del gasto
            VStack(alignment: .leading, spacing: 4) {
                Text(expense.description)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                HStack {
                    Text(expense.category.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if expense.isShared {
                        Text("• Compartido")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text(expense.date, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Monto y acciones
            VStack(alignment: .trailing, spacing: 4) {
                Text("$\(expense.amount, specifier: "%.2f")")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(Color("PrimaryColor"))
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Extensions
extension ExpenseCategory {
    var displayName: String {
        switch self {
        case .food: return "Comida"
        case .transport: return "Transporte"
        case .entertainment: return "Entretenimiento"
        case .bills: return "Facturas"
        case .shopping: return "Compras"
        case .health: return "Salud"
        case .home: return "Hogar"
        case .other: return "Otros"
        }
    }
    
    var icon: String {
        switch self {
        case .food: return "fork.knife"
        case .transport: return "car.fill"
        case .entertainment: return "gamecontroller.fill"
        case .bills: return "doc.text.fill"
        case .shopping: return "bag.fill"
        case .health: return "cross.fill"
        case .home: return "house.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }
    
    var color: String {
        switch self {
        case .food: return "#FF6B6B"
        case .transport: return "#4ECDC4"
        case .entertainment: return "#45B7D1"
        case .bills: return "#FFA07A"
        case .shopping: return "#98D8C8"
        case .health: return "#96CEB4"
        case .home: return "#FECA57"
        case .other: return "#A55EEA"
        }
    }
}

#Preview {
    ExpensesView()
        .environmentObject(CoupleManager())
        .environmentObject(UserManager())
}
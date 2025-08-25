//
//  BalanceDetailView.swift
//  JuntosApp
//
//  Created by JuntosApp Team on 2024.
//

import SwiftUI
import FirebaseAuth

struct BalanceDetailView: View {
    let balance: Double
    let user1Total: Double
    let user2Total: Double
    let expenses: [Expense]
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var coupleManager: CoupleManager
    @EnvironmentObject var userManager: UserManager
    
    private var currentUserId: String {
        Auth.auth().currentUser?.uid ?? ""
    }
    
    private var partnerUserId: String {
        guard let coupleData = coupleManager.coupleData else { return "" }
        return currentUserId == coupleData.user1Id ? (coupleData.user2Id ?? "") : coupleData.user1Id
    }
    
    private var currentUserTotal: Double {
        guard let coupleData = coupleManager.coupleData else { return 0 }
        return currentUserId == coupleData.user1Id ? user1Total : user2Total
    }
    
    private var partnerTotal: Double {
        guard let coupleData = coupleManager.coupleData else { return 0 }
        return currentUserId == coupleData.user1Id ? user2Total : user1Total
    }
    
    private var sharedExpensesTotal: Double {
        expenses.filter { $0.isShared }.reduce(0) { $0 + $1.amount }
    }
    
    private var currentUserPersonalExpenses: Double {
        expenses.filter { $0.paidBy == currentUserId && !$0.isShared }.reduce(0) { $0 + $1.amount }
    }
    
    private var partnerPersonalExpenses: Double {
        expenses.filter { $0.paidBy == partnerUserId && !$0.isShared }.reduce(0) { $0 + $1.amount }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 25) {
                    // Header con balance principal
                    balanceHeader
                    
                    // Resumen de totales
                    totalsSection
                    
                    // Desglose de gastos
                    expenseBreakdown
                    
                    // Sugerencia de pago
                    if abs(balance) > 0.01 {
                        paymentSuggestion
                    }
                    
                    // Historial de gastos compartidos
                    sharedExpensesHistory
                }
                .padding()
            }
            .navigationTitle("Balance Detallado")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cerrar") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - UI Components
    
    private var balanceHeader: some View {
        VStack(spacing: 15) {
            // Icono de balance
            Circle()
                .fill(balanceColor.opacity(0.2))
                .frame(width: 80, height: 80)
                .overlay(
                    Image(systemName: balanceIcon)
                        .font(.system(size: 30, weight: .medium))
                        .foregroundColor(balanceColor)
                )
            
            // Estado del balance
            VStack(spacing: 8) {
                Text(balanceTitle)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                if abs(balance) > 0.01 {
                    Text("$\(abs(balance), specifier: "%.2f")")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(balanceColor)
                } else {
                    Text("¡Perfecto!")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
                
                Text(balanceDescription)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
    }
    
    private var totalsSection: some View {
        VStack(spacing: 15) {
            Text("Resumen de Pagos")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack(spacing: 20) {
                // Usuario actual
                VStack(spacing: 8) {
                    Text("Tú")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Text("$\(currentUserTotal, specifier: "%.2f")")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(Color("PrimaryColor"))
                    
                    Text("Pagado")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 15)
                        .fill(Color("PrimaryColor").opacity(0.1))
                )
                
                // Pareja
                VStack(spacing: 8) {
                    Text("Tu Pareja")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Text("$\(partnerTotal, specifier: "%.2f")")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(Color("SecondaryColor"))
                    
                    Text("Pagado")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 15)
                        .fill(Color("SecondaryColor").opacity(0.1))
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
    }
    
    private var expenseBreakdown: some View {
        VStack(spacing: 15) {
            Text("Desglose de Gastos")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                // Gastos compartidos
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "person.2.fill")
                            .foregroundColor(Color("PrimaryColor"))
                        Text("Gastos Compartidos")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    Spacer()
                    
                    Text("$\(sharedExpensesTotal, specifier: "%.2f")")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                
                Divider()
                
                // Gastos personales del usuario
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "person.fill")
                            .foregroundColor(Color("PrimaryColor"))
                        Text("Tus Gastos Personales")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    Spacer()
                    
                    Text("$\(currentUserPersonalExpenses, specifier: "%.2f")")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                
                // Gastos personales de la pareja
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "person.fill")
                            .foregroundColor(Color("SecondaryColor"))
                        Text("Gastos Personales de tu Pareja")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    Spacer()
                    
                    Text("$\(partnerPersonalExpenses, specifier: "%.2f")")
                        .font(.subheadline)
                        .fontWeight(.semibold)
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
    
    private var paymentSuggestion: some View {
        VStack(spacing: 15) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.orange)
                Text("Sugerencia")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            Text(paymentSuggestionText)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.orange.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private var sharedExpensesHistory: some View {
        VStack(spacing: 15) {
            HStack {
                Text("Gastos Compartidos Recientes")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(sharedExpenses.count) gastos")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if sharedExpenses.isEmpty {
                Text("No hay gastos compartidos en este período")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(Array(sharedExpenses.prefix(5))) { expense in
                        SharedExpenseRow(expense: expense, currentUserId: currentUserId)
                    }
                    
                    if sharedExpenses.count > 5 {
                        Text("Y \(sharedExpenses.count - 5) gastos más...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 5)
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
    
    // MARK: - Computed Properties
    
    private var sharedExpenses: [Expense] {
        expenses.filter { $0.isShared }.sorted { $0.date > $1.date }
    }
    
    private var balanceColor: Color {
        if abs(balance) < 0.01 {
            return .green
        } else if balance > 0 {
            return .green
        } else {
            return .red
        }
    }
    
    private var balanceIcon: String {
        if abs(balance) < 0.01 {
            return "checkmark.circle.fill"
        } else if balance > 0 {
            return "arrow.up.circle.fill"
        } else {
            return "arrow.down.circle.fill"
        }
    }
    
    private var balanceTitle: String {
        if abs(balance) < 0.01 {
            return "¡Están al día!"
        } else if balance > 0 {
            return "Te deben dinero"
        } else {
            return "Debes dinero"
        }
    }
    
    private var balanceDescription: String {
        if abs(balance) < 0.01 {
            return "No hay deudas pendientes entre ustedes"
        } else if balance > 0 {
            return "Tu pareja te debe este monto por gastos compartidos"
        } else {
            return "Debes este monto a tu pareja por gastos compartidos"
        }
    }
    
    private var paymentSuggestionText: String {
        if balance > 0 {
            return "Puedes pedirle a tu pareja que te transfiera $\(abs(balance), specifier: "%.2f") para equilibrar los gastos compartidos."
        } else {
            return "Considera transferirle $\(abs(balance), specifier: "%.2f") a tu pareja para equilibrar los gastos compartidos."
        }
    }
}

// MARK: - Shared Expense Row
struct SharedExpenseRow: View {
    let expense: Expense
    let currentUserId: String
    
    var body: some View {
        HStack(spacing: 10) {
            // Icono de categoría
            Circle()
                .fill(Color(expense.category.color))
                .frame(width: 30, height: 30)
                .overlay(
                    Image(systemName: expense.category.icon)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                )
            
            // Información del gasto
            VStack(alignment: .leading, spacing: 2) {
                Text(expense.description)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                HStack {
                    Text(expense.date, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(expense.paidBy == currentUserId ? "Pagaste tú" : "Pagó tu pareja")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Monto y división
            VStack(alignment: .trailing, spacing: 2) {
                Text("$\(expense.amount, specifier: "%.2f")")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text("$\(expense.amount / 2, specifier: "%.2f") c/u")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    BalanceDetailView(
        balance: 25.50,
        user1Total: 150.00,
        user2Total: 100.00,
        expenses: []
    )
    .environmentObject(CoupleManager())
    .environmentObject(UserManager())
}
//
//  AddExpenseView.swift
//  JuntosApp
//
//  Created by JuntosApp Team on 2024.
//

import SwiftUI
import FirebaseAuth

struct AddExpenseView: View {
    @State private var description = ""
    @State private var amount = ""
    @State private var selectedCategory: ExpenseCategory = .food
    @State private var selectedDate = Date()
    @State private var isShared = true
    @State private var showingError = false
    @State private var errorMessage = ""
    
    @Environment(\.dismiss) private var dismiss
    
    let onAdd: (Expense) -> Void
    
    var isValidForm: Bool {
        !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !amount.isEmpty &&
        Double(amount) != nil &&
        Double(amount) ?? 0 > 0
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Información del Gasto") {
                    TextField("Descripción", text: $description)
                        .textInputAutocapitalization(.sentences)
                    
                    HStack {
                        Text("$")
                            .foregroundColor(.secondary)
                        TextField("0.00", text: $amount)
                            .keyboardType(.decimalPad)
                    }
                    
                    Picker("Categoría", selection: $selectedCategory) {
                        ForEach(ExpenseCategory.allCases, id: \.self) { category in
                            HStack {
                                Image(systemName: category.icon)
                                    .foregroundColor(Color(category.color))
                                Text(category.displayName)
                            }
                            .tag(category)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    
                    DatePicker("Fecha", selection: $selectedDate, displayedComponents: .date)
                }
                
                Section {
                    Toggle("Gasto compartido", isOn: $isShared)
                } footer: {
                    Text(isShared ? 
                         "Este gasto se dividirá entre ambos miembros de la pareja." :
                         "Este gasto será solo para quien lo registra.")
                }
                
                // Vista previa del gasto
                Section("Vista Previa") {
                    ExpensePreviewRow(
                        description: description.isEmpty ? "Descripción del gasto" : description,
                        amount: Double(amount) ?? 0.0,
                        category: selectedCategory,
                        date: selectedDate,
                        isShared: isShared
                    )
                }
            }
            .navigationTitle("Nuevo Gasto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Guardar") {
                        addExpense()
                    }
                    .disabled(!isValidForm)
                }
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func addExpense() {
        guard let currentUser = Auth.auth().currentUser,
              let amountValue = Double(amount),
              amountValue > 0 else {
            errorMessage = "Por favor, verifica que todos los campos estén correctos."
            showingError = true
            return
        }
        
        let expense = Expense(
            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
            amount: amountValue,
            category: selectedCategory,
            date: selectedDate,
            paidBy: currentUser.uid,
            isShared: isShared
        )
        
        onAdd(expense)
        dismiss()
    }
}

// MARK: - Expense Preview Row
struct ExpensePreviewRow: View {
    let description: String
    let amount: Double
    let category: ExpenseCategory
    let date: Date
    let isShared: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Icono de categoría
            Circle()
                .fill(Color(category.color))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: category.icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                )
            
            // Información del gasto
            VStack(alignment: .leading, spacing: 4) {
                Text(description)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .foregroundColor(description == "Descripción del gasto" ? .secondary : .primary)
                
                HStack {
                    Text(category.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if isShared {
                        Text("• Compartido")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text(date, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Monto
            Text("$\(amount, specifier: "%.2f")")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(amount > 0 ? Color("PrimaryColor") : .secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    AddExpenseView { expense in
        print("Added expense: \(expense)")
    }
}
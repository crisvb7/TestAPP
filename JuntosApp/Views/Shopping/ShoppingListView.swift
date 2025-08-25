//
//  ShoppingListView.swift
//  JuntosApp
//
//  Created by JuntosApp Team on 2024.
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct ShoppingListView: View {
    @State private var items: [ShoppingItem] = []
    @State private var showingAddItem = false
    @State private var newItemName = ""
    @State private var selectedCategory: ShoppingCategory = .food
    @State private var searchText = ""
    @State private var selectedFilter: ShoppingCategory? = nil
    @State private var showingCategories = false
    
    @EnvironmentObject var coupleManager: CoupleManager
    @EnvironmentObject var userManager: UserManager
    
    private let db = Firestore.firestore()
    
    var filteredItems: [ShoppingItem] {
        let filtered = items.filter { item in
            let matchesSearch = searchText.isEmpty || item.name.localizedCaseInsensitiveContains(searchText)
            let matchesCategory = selectedFilter == nil || item.category == selectedFilter
            return matchesSearch && matchesCategory
        }
        
        return filtered.sorted { !$0.isPurchased && $1.isPurchased }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Fondo
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header con búsqueda y filtros
                    VStack(spacing: 15) {
                        // Barra de búsqueda
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)
                            
                            TextField("Buscar productos...", text: $searchText)
                                .textFieldStyle(PlainTextFieldStyle())
                            
                            if !searchText.isEmpty {
                                Button("Limpiar") {
                                    searchText = ""
                                }
                                .font(.caption)
                                .foregroundColor(Color("PrimaryColor"))
                            }
                        }
                        .padding(.horizontal, 15)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(.systemBackground))
                        )
                        
                        // Filtros por categoría
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                // Botón "Todos"
                                Button("Todos") {
                                    selectedFilter = nil
                                }
                                .padding(.horizontal, 15)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(selectedFilter == nil ? Color("PrimaryColor") : Color(.systemBackground))
                                )
                                .foregroundColor(selectedFilter == nil ? .white : Color("PrimaryColor"))
                                .font(.subheadline)
                                .fontWeight(.medium)
                                
                                ForEach(ShoppingCategory.allCases, id: \.self) { category in
                                    Button(category.displayName) {
                                        selectedFilter = selectedFilter == category ? nil : category
                                    }
                                    .padding(.horizontal, 15)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 20)
                                            .fill(selectedFilter == category ? Color("PrimaryColor") : Color(.systemBackground))
                                    )
                                    .foregroundColor(selectedFilter == category ? .white : Color("PrimaryColor"))
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                    .background(Color(.systemGroupedBackground))
                    
                    // Lista de productos
                    if filteredItems.isEmpty {
                        // Estado vacío
                        VStack(spacing: 20) {
                            Spacer()
                            
                            Image(systemName: "cart")
                                .font(.system(size: 60))
                                .foregroundColor(.secondary)
                            
                            Text(searchText.isEmpty ? "Lista vacía" : "Sin resultados")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                            
                            Text(searchText.isEmpty ? 
                                 "Agrega productos a tu lista de compras" :
                                 "No se encontraron productos que coincidan con '\(searchText)'")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            
                            if searchText.isEmpty {
                                Button("Agregar Producto") {
                                    showingAddItem = true
                                }
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 25)
                                .padding(.vertical, 12)
                                .background(Color("PrimaryColor"))
                                .cornerRadius(25)
                            }
                            
                            Spacer()
                        }
                    } else {
                        List {
                            ForEach(filteredItems) { item in
                                ShoppingItemRow(
                                    item: item,
                                    onTogglePurchased: { toggleItemPurchased(item) },
                                    onDelete: { deleteItem(item) }
                                )
                                .listRowBackground(Color(.systemBackground))
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 5, leading: 15, bottom: 5, trailing: 15))
                            }
                        }
                        .listStyle(PlainListStyle())
                        .refreshable {
                            loadShoppingItems()
                        }
                    }
                }
            }
            .navigationTitle("Lista de Compras")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddItem = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.title2)
                            .foregroundColor(Color("PrimaryColor"))
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddItem) {
            AddShoppingItemView { name, category in
                addShoppingItem(name: name, category: category)
            }
        }
        .onAppear {
            loadShoppingItems()
            setupRealtimeListener()
        }
    }
    
    // MARK: - Firebase Operations
    
    private func loadShoppingItems() {
        guard let coupleId = coupleManager.coupleData?.id else { return }
        
        db.collection("couples").document(coupleId).collection("shoppingItems")
            .order(by: "createdAt", descending: false)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error loading shopping items: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                DispatchQueue.main.async {
                    self.items = documents.compactMap { doc in
                        try? doc.data(as: ShoppingItem.self)
                    }
                }
            }
    }
    
    private func setupRealtimeListener() {
        guard let coupleId = coupleManager.coupleData?.id else { return }
        
        db.collection("couples").document(coupleId).collection("shoppingItems")
            .order(by: "createdAt", descending: false)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("Error in realtime listener: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                DispatchQueue.main.async {
                    self.items = documents.compactMap { doc in
                        try? doc.data(as: ShoppingItem.self)
                    }
                }
            }
    }
    
    private func addShoppingItem(name: String, category: ShoppingCategory) {
        guard let coupleId = coupleManager.coupleData?.id,
              let currentUser = Auth.auth().currentUser else { return }
        
        let newItem = ShoppingItem(
            name: name,
            category: category,
            isPurchased: false,
            isFavorite: false,
            addedBy: currentUser.uid,
            createdAt: Date()
        )
        
        do {
            try db.collection("couples").document(coupleId).collection("shoppingItems")
                .document(newItem.id).setData(from: newItem)
        } catch {
            print("Error adding shopping item: \(error)")
        }
    }
    
    private func toggleItemPurchased(_ item: ShoppingItem) {
        guard let coupleId = coupleManager.coupleData?.id else { return }
        
        db.collection("couples").document(coupleId).collection("shoppingItems")
            .document(item.id).updateData([
                "isPurchased": !item.isPurchased,
                "purchasedAt": !item.isPurchased ? Date() : FieldValue.delete(),
                "purchasedBy": !item.isPurchased ? Auth.auth().currentUser?.uid : FieldValue.delete()
            ])
    }
    
    private func deleteItem(_ item: ShoppingItem) {
        guard let coupleId = coupleManager.coupleData?.id else { return }
        
        db.collection("couples").document(coupleId).collection("shoppingItems")
            .document(item.id).delete()
    }
}

// MARK: - Shopping Item Row
struct ShoppingItemRow: View {
    let item: ShoppingItem
    let onTogglePurchased: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 15) {
            // Checkbox
            Button(action: onTogglePurchased) {
                Image(systemName: item.isPurchased ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(item.isPurchased ? Color("PrimaryColor") : .secondary)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Contenido del item
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .strikethrough(item.isPurchased)
                        .foregroundColor(item.isPurchased ? .secondary : .primary)
                    
                    if item.isFavorite {
                        Image(systemName: "heart.fill")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    
                    Spacer()
                }
                
                HStack {
                    // Categoría
                    Text(item.category.displayName)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(item.category.color).opacity(0.2))
                        )
                        .foregroundColor(Color(item.category.color))
                    
                    Spacer()
                    
                    // Información de compra
                    if item.isPurchased {
                        Text("Comprado")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Botón eliminar
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.subheadline)
                    .foregroundColor(.red)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 15)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
    }
}

// MARK: - Add Shopping Item View
struct AddShoppingItemView: View {
    @State private var itemName = ""
    @State private var selectedCategory: ShoppingCategory = .food
    @State private var isFavorite = false
    
    @Environment(\.dismiss) private var dismiss
    
    let onAdd: (String, ShoppingCategory) -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section("Información del Producto") {
                    TextField("Nombre del producto", text: $itemName)
                        .textInputAutocapitalization(.words)
                    
                    Picker("Categoría", selection: $selectedCategory) {
                        ForEach(ShoppingCategory.allCases, id: \.self) { category in
                            HStack {
                                Image(systemName: category.icon)
                                    .foregroundColor(Color(category.color))
                                Text(category.displayName)
                            }
                            .tag(category)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                Section {
                    Toggle("Marcar como favorito", isOn: $isFavorite)
                } footer: {
                    Text("Los productos favoritos aparecerán en sugerencias rápidas.")
                }
            }
            .navigationTitle("Nuevo Producto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Agregar") {
                        onAdd(itemName, selectedCategory)
                        dismiss()
                    }
                    .disabled(itemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

// MARK: - Extensions
extension ShoppingCategory {
    var displayName: String {
        switch self {
        case .food: return "Comida"
        case .cleaning: return "Limpieza"
        case .hygiene: return "Higiene"
        case .health: return "Salud"
        case .home: return "Hogar"
        case .other: return "Otros"
        }
    }
    
    var icon: String {
        switch self {
        case .food: return "fork.knife"
        case .cleaning: return "sparkles"
        case .hygiene: return "drop.fill"
        case .health: return "cross.fill"
        case .home: return "house.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }
    
    var color: String {
        switch self {
        case .food: return "#FF6B6B"
        case .cleaning: return "#4ECDC4"
        case .hygiene: return "#45B7D1"
        case .health: return "#96CEB4"
        case .home: return "#FECA57"
        case .other: return "#A55EEA"
        }
    }
}

#Preview {
    ShoppingListView()
        .environmentObject(CoupleManager())
        .environmentObject(UserManager())
}
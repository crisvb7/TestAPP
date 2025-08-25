//
//  TasksView.swift
//  JuntosApp
//
//  Created by JuntosApp Team on 2024.
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct TasksView: View {
    @State private var tasks: [HouseholdTask] = []
    @State private var showingAddTask = false
    @State private var selectedFilter: TaskFilter = .all
    @State private var searchText = ""
    @State private var isLoading = false
    
    @EnvironmentObject var coupleManager: CoupleManager
    @EnvironmentObject var userManager: UserManager
    
    private let db = Firestore.firestore()
    
    enum TaskFilter: String, CaseIterable {
        case all = "Todas"
        case pending = "Pendientes"
        case completed = "Completadas"
        case myTasks = "Mis Tareas"
        case partnerTasks = "Tareas de Pareja"
        case unassigned = "Sin Asignar"
    }
    
    var filteredTasks: [HouseholdTask] {
        let searchFiltered = tasks.filter { task in
            searchText.isEmpty || 
            task.title.localizedCaseInsensitiveContains(searchText) ||
            task.description?.localizedCaseInsensitiveContains(searchText) == true
        }
        
        let filtered = searchFiltered.filter { task in
            switch selectedFilter {
            case .all:
                return true
            case .pending:
                return !task.isCompleted
            case .completed:
                return task.isCompleted
            case .myTasks:
                guard let currentUser = Auth.auth().currentUser else { return false }
                return task.assignedTo == currentUser.uid
            case .partnerTasks:
                guard let currentUser = Auth.auth().currentUser else { return false }
                return task.assignedTo != nil && task.assignedTo != currentUser.uid
            case .unassigned:
                return task.assignedTo == nil
            }
        }
        
        return filtered.sorted { task1, task2 in
            // Completed tasks go to bottom
            if task1.isCompleted != task2.isCompleted {
                return !task1.isCompleted && task2.isCompleted
            }
            
            // Sort by priority
            if task1.priority != task2.priority {
                return task1.priority.rawValue > task2.priority.rawValue
            }
            
            // Sort by due date
            if let due1 = task1.dueDate, let due2 = task2.dueDate {
                return due1 < due2
            } else if task1.dueDate != nil {
                return true
            } else if task2.dueDate != nil {
                return false
            }
            
            // Sort by creation date
            return task1.createdAt > task2.createdAt
        }
    }
    
    var taskStats: (total: Int, completed: Int, pending: Int, overdue: Int) {
        let total = tasks.count
        let completed = tasks.filter { $0.isCompleted }.count
        let pending = tasks.filter { !$0.isCompleted }.count
        let overdue = tasks.filter { task in
            !task.isCompleted && 
            task.dueDate != nil && 
            task.dueDate! < Date()
        }.count
        
        return (total, completed, pending, overdue)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Estadísticas
                    if !tasks.isEmpty {
                        taskStatsView
                    }
                    
                    // Barra de búsqueda
                    searchBar
                    
                    // Filtros
                    filterTabs
                    
                    // Lista de tareas
                    if isLoading {
                        Spacer()
                        ProgressView("Cargando tareas...")
                            .progressViewStyle(CircularProgressViewStyle())
                        Spacer()
                    } else if filteredTasks.isEmpty {
                        emptyStateView
                    } else {
                        tasksList
                    }
                }
            }
            .navigationTitle("Tareas del Hogar")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddTask = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.title2)
                            .foregroundColor(Color("PrimaryColor"))
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddTask) {
            AddTaskView()
        }
        .onAppear {
            loadTasks()
            setupRealtimeListener()
        }
    }
    
    // MARK: - Task Stats View
    
    private var taskStatsView: some View {
        HStack(spacing: 0) {
            StatCard(
                title: "Total",
                value: "\(taskStats.total)",
                color: .secondary
            )
            
            StatCard(
                title: "Completadas",
                value: "\(taskStats.completed)",
                color: .green
            )
            
            StatCard(
                title: "Pendientes",
                value: "\(taskStats.pending)",
                color: Color("PrimaryColor")
            )
            
            if taskStats.overdue > 0 {
                StatCard(
                    title: "Vencidas",
                    value: "\(taskStats.overdue)",
                    color: .red
                )
            }
        }
        .padding(.horizontal)
        .padding(.top)
    }
    
    // MARK: - Search Bar
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Buscar tareas...", text: $searchText)
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
        .padding(.horizontal)
        .padding(.top)
    }
    
    // MARK: - Filter Tabs
    
    private var filterTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(TaskFilter.allCases, id: \.self) { filter in
                    Button(filter.rawValue) {
                        selectedFilter = filter
                    }
                    .padding(.horizontal, 15)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(selectedFilter == filter ? Color("PrimaryColor") : Color(.systemBackground))
                    )
                    .foregroundColor(selectedFilter == filter ? .white : Color("PrimaryColor"))
                    .font(.subheadline)
                    .fontWeight(.medium)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: getEmptyStateIcon())
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text(getEmptyStateTitle())
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            Text(getEmptyStateMessage())
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            if selectedFilter == .all && searchText.isEmpty {
                Button("Crear Primera Tarea") {
                    showingAddTask = true
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
    }
    
    // MARK: - Tasks List
    
    private var tasksList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(filteredTasks) { task in
                    TaskRow(task: task) {
                        toggleTaskCompletion(task)
                    }
                }
            }
            .padding(.horizontal)
        }
        .refreshable {
            loadTasks()
        }
    }
    
    // MARK: - Helper Methods
    
    private func getEmptyStateIcon() -> String {
        switch selectedFilter {
        case .all:
            return "checklist"
        case .pending:
            return "clock"
        case .completed:
            return "checkmark.circle"
        case .myTasks:
            return "person.circle"
        case .partnerTasks:
            return "person.2.circle"
        case .unassigned:
            return "questionmark.circle"
        }
    }
    
    private func getEmptyStateTitle() -> String {
        switch selectedFilter {
        case .all:
            return "No hay tareas"
        case .pending:
            return "No hay tareas pendientes"
        case .completed:
            return "No hay tareas completadas"
        case .myTasks:
            return "No tienes tareas asignadas"
        case .partnerTasks:
            return "Tu pareja no tiene tareas"
        case .unassigned:
            return "No hay tareas sin asignar"
        }
    }
    
    private func getEmptyStateMessage() -> String {
        switch selectedFilter {
        case .all:
            return "Crea tu primera tarea para organizar las actividades del hogar"
        case .pending:
            return "¡Excelente! No tienes tareas pendientes por completar"
        case .completed:
            return "Aún no has completado ninguna tarea"
        case .myTasks:
            return "No tienes tareas asignadas en este momento"
        case .partnerTasks:
            return "Tu pareja no tiene tareas asignadas"
        case .unassigned:
            return "Todas las tareas están asignadas"
        }
    }
    
    // MARK: - Firebase Operations
    
    private func loadTasks() {
        guard let coupleId = coupleManager.coupleData?.id else { return }
        
        isLoading = true
        
        db.collection("couples").document(coupleId).collection("tasks")
            .order(by: "createdAt", descending: true)
            .getDocuments { snapshot, error in
                DispatchQueue.main.async {
                    isLoading = false
                    
                    if let error = error {
                        print("Error loading tasks: \(error)")
                        return
                    }
                    
                    guard let documents = snapshot?.documents else { return }
                    
                    self.tasks = documents.compactMap { doc in
                        try? doc.data(as: HouseholdTask.self)
                    }
                }
            }
    }
    
    private func setupRealtimeListener() {
        guard let coupleId = coupleManager.coupleData?.id else { return }
        
        db.collection("couples").document(coupleId).collection("tasks")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("Error in tasks listener: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                DispatchQueue.main.async {
                    self.tasks = documents.compactMap { doc in
                        try? doc.data(as: HouseholdTask.self)
                    }
                }
            }
    }
    
    private func toggleTaskCompletion(_ task: HouseholdTask) {
        guard let coupleId = coupleManager.coupleData?.id,
              let currentUser = Auth.auth().currentUser else { return }
        
        var updatedTask = task
        updatedTask.isCompleted.toggle()
        
        if updatedTask.isCompleted {
            updatedTask.completedAt = Date()
            updatedTask.completedBy = currentUser.uid
        } else {
            updatedTask.completedAt = nil
            updatedTask.completedBy = nil
        }
        
        do {
            try db.collection("couples").document(coupleId).collection("tasks")
                .document(task.id).setData(from: updatedTask)
        } catch {
            print("Error updating task: \(error)")
        }
    }
}

// MARK: - Stat Card Component

struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemBackground))
        )
    }
}

#Preview {
    TasksView()
        .environmentObject(CoupleManager())
        .environmentObject(UserManager())
}
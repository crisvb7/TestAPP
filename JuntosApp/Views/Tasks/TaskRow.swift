//
//  TaskRow.swift
//  JuntosApp
//
//  Created by JuntosApp Team on 2024.
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct TaskRow: View {
    let task: HouseholdTask
    let onToggleCompletion: () -> Void
    
    @State private var showingTaskDetail = false
    @State private var showingDeleteAlert = false
    
    @EnvironmentObject var coupleManager: CoupleManager
    @EnvironmentObject var userManager: UserManager
    
    private let db = Firestore.firestore()
    
    private var isOverdue: Bool {
        guard let dueDate = task.dueDate, !task.isCompleted else { return false }
        return dueDate < Date()
    }
    
    private var priorityColor: Color {
        switch task.priority {
        case .high:
            return .red
        case .medium:
            return .orange
        case .low:
            return .green
        }
    }
    
    private var assignedUserName: String {
        guard let assignedTo = task.assignedTo else { return "Sin asignar" }
        
        if let currentUser = Auth.auth().currentUser, assignedTo == currentUser.uid {
            return "Yo"
        } else if let coupleData = coupleManager.coupleData {
            if assignedTo == coupleData.user1Id {
                return coupleData.user1Name
            } else if assignedTo == coupleData.user2Id {
                return coupleData.user2Name
            }
        }
        
        return "Usuario"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Checkbox
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        onToggleCompletion()
                    }
                } label: {
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundColor(task.isCompleted ? .green : .secondary)
                        .scaleEffect(task.isCompleted ? 1.1 : 1.0)
                }
                .buttonStyle(PlainButtonStyle())
                
                VStack(alignment: .leading, spacing: 4) {
                    // Title and Priority
                    HStack {
                        Text(task.title)
                            .font(.headline)
                            .fontWeight(.medium)
                            .foregroundColor(task.isCompleted ? .secondary : .primary)
                            .strikethrough(task.isCompleted)
                        
                        Spacer()
                        
                        // Priority indicator
                        Circle()
                            .fill(priorityColor)
                            .frame(width: 8, height: 8)
                    }
                    
                    // Description
                    if let description = task.description, !description.isEmpty {
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    // Task info row
                    HStack(spacing: 16) {
                        // Assigned to
                        HStack(spacing: 4) {
                            Image(systemName: "person.circle")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(assignedUserName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        // Due date
                        if let dueDate = task.dueDate {
                            HStack(spacing: 4) {
                                Image(systemName: isOverdue ? "exclamationmark.triangle" : "calendar")
                                    .font(.caption)
                                    .foregroundColor(isOverdue ? .red : .secondary)
                                
                                Text(formatDate(dueDate))
                                    .font(.caption)
                                    .foregroundColor(isOverdue ? .red : .secondary)
                            }
                        }
                        
                        // Recurring indicator
                        if task.isRecurring {
                            HStack(spacing: 4) {
                                Image(systemName: "repeat")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text("Recurrente")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                    }
                    
                    // Completion info
                    if task.isCompleted, let completedAt = task.completedAt {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle")
                                .font(.caption)
                                .foregroundColor(.green)
                            
                            Text("Completada \(formatCompletionDate(completedAt))")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
            )
            .opacity(task.isCompleted ? 0.7 : 1.0)
            .scaleEffect(task.isCompleted ? 0.98 : 1.0)
            .onTapGesture {
                showingTaskDetail = true
            }
            .contextMenu {
                contextMenuItems
            }
        }
        .sheet(isPresented: $showingTaskDetail) {
            TaskDetailView(task: task)
        }
        .alert("Eliminar Tarea", isPresented: $showingDeleteAlert) {
            Button("Cancelar", role: .cancel) { }
            Button("Eliminar", role: .destructive) {
                deleteTask()
            }
        } message: {
            Text("¿Estás seguro de que quieres eliminar esta tarea? Esta acción no se puede deshacer.")
        }
    }
    
    // MARK: - Context Menu
    
    @ViewBuilder
    private var contextMenuItems: some View {
        Button {
            onToggleCompletion()
        } label: {
            Label(task.isCompleted ? "Marcar como Pendiente" : "Marcar como Completada", 
                  systemImage: task.isCompleted ? "circle" : "checkmark.circle")
        }
        
        Button {
            showingTaskDetail = true
        } label: {
            Label("Ver Detalles", systemImage: "info.circle")
        }
        
        Divider()
        
        Button(role: .destructive) {
            showingDeleteAlert = true
        } label: {
            Label("Eliminar", systemImage: "trash")
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        
        if calendar.isToday(date) {
            return "Hoy"
        } else if calendar.isDate(date, equalTo: Date().addingTimeInterval(86400), toGranularity: .day) {
            return "Mañana"
        } else if calendar.isDate(date, equalTo: Date().addingTimeInterval(-86400), toGranularity: .day) {
            return "Ayer"
        } else {
            formatter.dateStyle = .short
            return formatter.string(from: date)
        }
    }
    
    private func formatCompletionDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        
        if calendar.isToday(date) {
            formatter.timeStyle = .short
            return "hoy a las \(formatter.string(from: date))"
        } else if calendar.isDate(date, equalTo: Date().addingTimeInterval(-86400), toGranularity: .day) {
            formatter.timeStyle = .short
            return "ayer a las \(formatter.string(from: date))"
        } else {
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            return "el \(formatter.string(from: date))"
        }
    }
    
    private func deleteTask() {
        guard let coupleId = coupleManager.coupleData?.id else { return }
        
        db.collection("couples").document(coupleId).collection("tasks")
            .document(task.id).delete { error in
                if let error = error {
                    print("Error deleting task: \(error)")
                }
            }
    }
}

// MARK: - Task Detail View

struct TaskDetailView: View {
    let task: HouseholdTask
    
    @Environment(\.dismiss) private var dismiss
    @State private var showingEditTask = false
    
    @EnvironmentObject var coupleManager: CoupleManager
    @EnvironmentObject var userManager: UserManager
    
    private var assignedUserName: String {
        guard let assignedTo = task.assignedTo else { return "Sin asignar" }
        
        if let currentUser = Auth.auth().currentUser, assignedTo == currentUser.uid {
            return "Yo"
        } else if let coupleData = coupleManager.coupleData {
            if assignedTo == coupleData.user1Id {
                return coupleData.user1Name
            } else if assignedTo == coupleData.user2Id {
                return coupleData.user2Name
            }
        }
        
        return "Usuario"
    }
    
    private var creatorName: String {
        if let currentUser = Auth.auth().currentUser, task.createdBy == currentUser.uid {
            return "Yo"
        } else if let coupleData = coupleManager.coupleData {
            if task.createdBy == coupleData.user1Id {
                return coupleData.user1Name
            } else if task.createdBy == coupleData.user2Id {
                return coupleData.user2Name
            }
        }
        
        return "Usuario"
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(task.title)
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Spacer()
                            
                            // Status badge
                            Text(task.isCompleted ? "Completada" : "Pendiente")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(task.isCompleted ? .green : Color("PrimaryColor"))
                                )
                        }
                        
                        if let description = task.description, !description.isEmpty {
                            Text(description)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Task Details
                    VStack(spacing: 16) {
                        DetailRow(icon: "person.circle", title: "Asignada a", value: assignedUserName)
                        
                        DetailRow(icon: "flag", title: "Prioridad", value: task.priority.rawValue.capitalized)
                        
                        if let dueDate = task.dueDate {
                            DetailRow(icon: "calendar", title: "Fecha límite", value: formatDetailDate(dueDate))
                        }
                        
                        if task.isRecurring {
                            DetailRow(icon: "repeat", title: "Recurrencia", value: "Tarea recurrente")
                        }
                        
                        DetailRow(icon: "person.badge.plus", title: "Creada por", value: creatorName)
                        
                        DetailRow(icon: "clock", title: "Fecha de creación", value: formatDetailDate(task.createdAt))
                        
                        if task.isCompleted, let completedAt = task.completedAt {
                            DetailRow(icon: "checkmark.circle", title: "Completada el", value: formatDetailDate(completedAt))
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemBackground))
                    )
                }
                .padding()
            }
            .navigationTitle("Detalles de Tarea")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cerrar") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Editar") {
                        showingEditTask = true
                    }
                    .foregroundColor(Color("PrimaryColor"))
                }
            }
        }
        .sheet(isPresented: $showingEditTask) {
            AddTaskView(taskToEdit: task)
        }
    }
    
    private func formatDetailDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Detail Row Component

struct DetailRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(Color("PrimaryColor"))
                .frame(width: 20)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

#Preview {
    TaskRow(task: HouseholdTask(
        id: "1",
        title: "Lavar los platos",
        description: "Lavar todos los platos después de la cena",
        assignedTo: nil,
        priority: .medium,
        dueDate: Date(),
        isCompleted: false,
        isRecurring: false,
        createdBy: "user1",
        createdAt: Date()
    )) {
        // Toggle action
    }
    .environmentObject(CoupleManager())
    .environmentObject(UserManager())
    .padding()
}
//
//  AddTaskView.swift
//  JuntosApp
//
//  Created by JuntosApp Team on 2024.
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct AddTaskView: View {
    let taskToEdit: HouseholdTask?
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = ""
    @State private var description = ""
    @State private var selectedPriority: TaskPriority = .medium
    @State private var assignedTo: String? = nil
    @State private var hasDueDate = false
    @State private var dueDate = Date()
    @State private var isRecurring = false
    @State private var isSaving = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    @EnvironmentObject var coupleManager: CoupleManager
    @EnvironmentObject var userManager: UserManager
    
    private let db = Firestore.firestore()
    
    private var isEditing: Bool {
        taskToEdit != nil
    }
    
    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private var assignmentOptions: [(id: String?, name: String)] {
        var options: [(id: String?, name: String)] = [(nil, "Sin asignar")]
        
        if let currentUser = Auth.auth().currentUser {
            options.append((currentUser.uid, "Yo"))
        }
        
        if let coupleData = coupleManager.coupleData,
           let currentUser = Auth.auth().currentUser {
            let partnerId = coupleData.user1Id == currentUser.uid ? coupleData.user2Id : coupleData.user1Id
            let partnerName = coupleData.user1Id == currentUser.uid ? coupleData.user2Name : coupleData.user1Name
            options.append((partnerId, partnerName))
        }
        
        return options
    }
    
    init(taskToEdit: HouseholdTask? = nil) {
        self.taskToEdit = taskToEdit
        
        if let task = taskToEdit {
            _title = State(initialValue: task.title)
            _description = State(initialValue: task.description ?? "")
            _selectedPriority = State(initialValue: task.priority)
            _assignedTo = State(initialValue: task.assignedTo)
            _hasDueDate = State(initialValue: task.dueDate != nil)
            _dueDate = State(initialValue: task.dueDate ?? Date())
            _isRecurring = State(initialValue: task.isRecurring)
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Basic Information
                Section("Información Básica") {
                    TextField("Título de la tarea", text: $title)
                        .textInputAutocapitalization(.sentences)
                    
                    TextField("Descripción (opcional)", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                        .textInputAutocapitalization(.sentences)
                }
                
                // Assignment and Priority
                Section("Asignación y Prioridad") {
                    // Assignment picker
                    Picker("Asignar a", selection: $assignedTo) {
                        ForEach(assignmentOptions, id: \.id) { option in
                            Text(option.name)
                                .tag(option.id)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    // Priority picker
                    Picker("Prioridad", selection: $selectedPriority) {
                        ForEach(TaskPriority.allCases, id: \.self) { priority in
                            HStack {
                                Circle()
                                    .fill(priorityColor(priority))
                                    .frame(width: 12, height: 12)
                                
                                Text(priority.rawValue.capitalized)
                            }
                            .tag(priority)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                // Due Date
                Section("Fecha Límite") {
                    Toggle("Establecer fecha límite", isOn: $hasDueDate)
                    
                    if hasDueDate {
                        DatePicker(
                            "Fecha límite",
                            selection: $dueDate,
                            in: Date()...,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .datePickerStyle(.compact)
                    }
                }
                
                // Recurrence
                Section("Opciones Adicionales") {
                    Toggle("Tarea recurrente", isOn: $isRecurring)
                    
                    if isRecurring {
                        Text("Las tareas recurrentes se recrearán automáticamente cuando se marquen como completadas.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Preview
                if !title.isEmpty {
                    Section("Vista Previa") {
                        TaskPreviewCard(
                            title: title,
                            description: description.isEmpty ? nil : description,
                            priority: selectedPriority,
                            assignedTo: assignedTo,
                            dueDate: hasDueDate ? dueDate : nil,
                            isRecurring: isRecurring,
                            assignmentOptions: assignmentOptions
                        )
                    }
                }
            }
            .navigationTitle(isEditing ? "Editar Tarea" : "Nueva Tarea")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isEditing ? "Guardar" : "Crear") {
                        saveTask()
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
    
    // MARK: - Helper Methods
    
    private func priorityColor(_ priority: TaskPriority) -> Color {
        switch priority {
        case .high:
            return .red
        case .medium:
            return .orange
        case .low:
            return .green
        }
    }
    
    private func saveTask() {
        guard canSave,
              let coupleId = coupleManager.coupleData?.id,
              let currentUser = Auth.auth().currentUser else {
            return
        }
        
        isSaving = true
        
        let taskId = taskToEdit?.id ?? UUID().uuidString
        
        let task = HouseholdTask(
            id: taskId,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            description: description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : description.trimmingCharacters(in: .whitespacesAndNewlines),
            assignedTo: assignedTo,
            priority: selectedPriority,
            dueDate: hasDueDate ? dueDate : nil,
            isCompleted: taskToEdit?.isCompleted ?? false,
            completedAt: taskToEdit?.completedAt,
            completedBy: taskToEdit?.completedBy,
            isRecurring: isRecurring,
            createdBy: taskToEdit?.createdBy ?? currentUser.uid,
            createdAt: taskToEdit?.createdAt ?? Date()
        )
        
        do {
            try db.collection("couples").document(coupleId).collection("tasks")
                .document(taskId).setData(from: task) { error in
                    DispatchQueue.main.async {
                        isSaving = false
                        
                        if let error = error {
                            errorMessage = "Error al guardar la tarea: \(error.localizedDescription)"
                            showingError = true
                        } else {
                            dismiss()
                        }
                    }
                }
        } catch {
            DispatchQueue.main.async {
                isSaving = false
                errorMessage = "Error al procesar la tarea: \(error.localizedDescription)"
                showingError = true
            }
        }
    }
}

// MARK: - Task Preview Card

struct TaskPreviewCard: View {
    let title: String
    let description: String?
    let priority: TaskPriority
    let assignedTo: String?
    let dueDate: Date?
    let isRecurring: Bool
    let assignmentOptions: [(id: String?, name: String)]
    
    private var priorityColor: Color {
        switch priority {
        case .high:
            return .red
        case .medium:
            return .orange
        case .low:
            return .green
        }
    }
    
    private var assignedUserName: String {
        guard let assignedTo = assignedTo else { return "Sin asignar" }
        return assignmentOptions.first { $0.id == assignedTo }?.name ?? "Usuario"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "circle")
                    .font(.title2)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(title)
                            .font(.headline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Circle()
                            .fill(priorityColor)
                            .frame(width: 8, height: 8)
                    }
                    
                    if let description = description, !description.isEmpty {
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    HStack(spacing: 16) {
                        HStack(spacing: 4) {
                            Image(systemName: "person.circle")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(assignedUserName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if let dueDate = dueDate {
                            HStack(spacing: 4) {
                                Image(systemName: "calendar")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text(formatPreviewDate(dueDate))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if isRecurring {
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
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
    
    private func formatPreviewDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        
        if calendar.isToday(date) {
            return "Hoy"
        } else if calendar.isDate(date, equalTo: Date().addingTimeInterval(86400), toGranularity: .day) {
            return "Mañana"
        } else {
            formatter.dateStyle = .short
            return formatter.string(from: date)
        }
    }
}

#Preview {
    AddTaskView()
        .environmentObject(CoupleManager())
        .environmentObject(UserManager())
}
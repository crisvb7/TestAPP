//
//  AddEventView.swift
//  JuntosApp
//
//  Created by JuntosApp Team on 2024.
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import UserNotifications

struct AddEventView: View {
    let selectedDate: Date
    let eventToEdit: CalendarEvent?
    
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var description = ""
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(3600) // 1 hour later
    @State private var isAllDay = false
    @State private var location = ""
    @State private var reminderMinutes = 15
    @State private var recurringType: RecurringType = .none
    @State private var isLoading = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    @EnvironmentObject var coupleManager: CoupleManager
    
    private let db = Firestore.firestore()
    
    private var isEditing: Bool {
        eventToEdit != nil
    }
    
    private var navigationTitle: String {
        isEditing ? "Editar Evento" : "Nuevo Evento"
    }
    
    private var saveButtonTitle: String {
        isEditing ? "Actualizar" : "Crear Evento"
    }
    
    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading
    }
    
    init(selectedDate: Date = Date(), eventToEdit: CalendarEvent? = nil) {
        self.selectedDate = selectedDate
        self.eventToEdit = eventToEdit
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Información básica
                Section("Información del Evento") {
                    TextField("Título del evento", text: $title)
                        .textInputAutocapitalization(.words)
                    
                    TextField("Descripción (opcional)", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                        .textInputAutocapitalization(.sentences)
                    
                    TextField("Ubicación (opcional)", text: $location)
                        .textInputAutocapitalization(.words)
                }
                
                // Fecha y hora
                Section("Fecha y Hora") {
                    Toggle("Todo el día", isOn: $isAllDay)
                        .tint(Color("PrimaryColor"))
                    
                    DatePicker(
                        "Fecha de inicio",
                        selection: $startDate,
                        displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.compact)
                    
                    if !isAllDay {
                        DatePicker(
                            "Fecha de fin",
                            selection: $endDate,
                            in: startDate...,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .datePickerStyle(.compact)
                    }
                }
                
                // Recordatorio
                Section("Recordatorio") {
                    Picker("Recordar", selection: $reminderMinutes) {
                        Text("Sin recordatorio").tag(0)
                        Text("5 minutos antes").tag(5)
                        Text("15 minutos antes").tag(15)
                        Text("30 minutos antes").tag(30)
                        Text("1 hora antes").tag(60)
                        Text("2 horas antes").tag(120)
                        Text("1 día antes").tag(1440)
                        Text("2 días antes").tag(2880)
                    }
                    .pickerStyle(.menu)
                }
                
                // Repetición
                Section("Repetición") {
                    Picker("Repetir", selection: $recurringType) {
                        ForEach(RecurringType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    if recurringType != .none {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.secondary)
                            Text("Este evento se repetirá \(recurringType.displayName.lowercased())")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Vista previa
                if !title.isEmpty {
                    Section("Vista Previa") {
                        EventPreviewCard(
                            title: title,
                            description: description.isEmpty ? nil : description,
                            startDate: startDate,
                            endDate: endDate,
                            isAllDay: isAllDay,
                            location: location.isEmpty ? nil : location,
                            reminderMinutes: reminderMinutes,
                            recurringType: recurringType
                        )
                    }
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(saveButtonTitle) {
                        saveEvent()
                    }
                    .disabled(!canSave)
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            setupInitialValues()
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .overlay {
            if isLoading {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                
                ProgressView("Guardando evento...")
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(.systemBackground))
                    )
            }
        }
    }
    
    // MARK: - Setup
    
    private func setupInitialValues() {
        if let event = eventToEdit {
            // Editing existing event
            title = event.title
            description = event.description ?? ""
            startDate = event.startDate
            endDate = event.endDate
            isAllDay = event.isAllDay
            location = event.location ?? ""
            reminderMinutes = event.reminderMinutes
            recurringType = event.recurringType
        } else {
            // Creating new event
            let calendar = Calendar.current
            startDate = calendar.dateInterval(of: .hour, for: selectedDate)?.start ?? selectedDate
            endDate = startDate.addingTimeInterval(3600) // 1 hour later
        }
    }
    
    // MARK: - Save Event
    
    private func saveEvent() {
        guard let coupleId = coupleManager.coupleData?.id,
              let currentUser = Auth.auth().currentUser else {
            errorMessage = "Error de autenticación"
            showingError = true
            return
        }
        
        guard canSave else { return }
        
        isLoading = true
        
        // Adjust end date for all-day events
        let finalEndDate = isAllDay ? 
            Calendar.current.startOfDay(for: endDate).addingTimeInterval(86400 - 1) : // End of day
            endDate
        
        let event = CalendarEvent(
            id: eventToEdit?.id ?? UUID().uuidString,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            description: description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : description.trimmingCharacters(in: .whitespacesAndNewlines),
            startDate: startDate,
            endDate: finalEndDate,
            isAllDay: isAllDay,
            location: location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : location.trimmingCharacters(in: .whitespacesAndNewlines),
            reminderMinutes: reminderMinutes,
            recurringType: recurringType,
            createdBy: eventToEdit?.createdBy ?? currentUser.uid,
            createdAt: eventToEdit?.createdAt ?? Date()
        )
        
        do {
            try db.collection("couples").document(coupleId).collection("events")
                .document(event.id).setData(from: event) { error in
                    DispatchQueue.main.async {
                        isLoading = false
                        
                        if let error = error {
                            errorMessage = "Error al guardar el evento: \(error.localizedDescription)"
                            showingError = true
                        } else {
                            // Schedule notification if needed
                            if reminderMinutes > 0 {
                                scheduleNotification(for: event)
                            }
                            
                            dismiss()
                        }
                    }
                }
        } catch {
            isLoading = false
            errorMessage = "Error al procesar el evento: \(error.localizedDescription)"
            showingError = true
        }
    }
    
    // MARK: - Notifications
    
    private func scheduleNotification(for event: CalendarEvent) {
        let content = UNMutableNotificationContent()
        content.title = event.title
        content.body = event.description ?? "Tienes un evento próximo"
        content.sound = .default
        
        if let location = event.location {
            content.body += " en \(location)"
        }
        
        let triggerDate = event.startDate.addingTimeInterval(-Double(event.reminderMinutes * 60))
        
        if triggerDate > Date() {
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate),
                repeats: false
            )
            
            let request = UNNotificationRequest(
                identifier: "event_\(event.id)",
                content: content,
                trigger: trigger
            )
            
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("Error scheduling notification: \(error)")
                }
            }
        }
    }
}

// MARK: - Event Preview Card

struct EventPreviewCard: View {
    let title: String
    let description: String?
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let location: String?
    let reminderMinutes: Int
    let recurringType: RecurringType
    
    private var timeDisplay: String {
        let formatter = DateFormatter()
        
        if isAllDay {
            formatter.dateStyle = .medium
            return formatter.string(from: startDate)
        } else {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            
            let timeFormatter = DateFormatter()
            timeFormatter.timeStyle = .short
            
            let date = dateFormatter.string(from: startDate)
            let startTime = timeFormatter.string(from: startDate)
            let endTime = timeFormatter.string(from: endDate)
            
            return "\(date)\n\(startTime) - \(endTime)"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Título
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
            
            // Descripción
            if let description = description, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Información del evento
            VStack(alignment: .leading, spacing: 8) {
                // Fecha y hora
                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .foregroundColor(Color("PrimaryColor"))
                        .frame(width: 16)
                    
                    Text(timeDisplay)
                        .font(.subheadline)
                }
                
                // Ubicación
                if let location = location, !location.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "location")
                            .foregroundColor(Color("PrimaryColor"))
                            .frame(width: 16)
                        
                        Text(location)
                            .font(.subheadline)
                    }
                }
                
                // Recordatorio
                if reminderMinutes > 0 {
                    HStack(spacing: 8) {
                        Image(systemName: "bell")
                            .foregroundColor(Color("PrimaryColor"))
                            .frame(width: 16)
                        
                        Text(formatReminder(reminderMinutes))
                            .font(.subheadline)
                    }
                }
                
                // Repetición
                if recurringType != .none {
                    HStack(spacing: 8) {
                        Image(systemName: "repeat")
                            .foregroundColor(Color("PrimaryColor"))
                            .frame(width: 16)
                        
                        Text(recurringType.displayName)
                            .font(.subheadline)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color("PrimaryColor").opacity(0.1))
        )
    }
    
    private func formatReminder(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes) minutos antes"
        } else if minutes < 1440 {
            let hours = minutes / 60
            return "\(hours) hora\(hours > 1 ? "s" : "") antes"
        } else {
            let days = minutes / 1440
            return "\(days) día\(days > 1 ? "s" : "") antes"
        }
    }
}

// MARK: - Extensions

extension RecurringType: CaseIterable {
    public static var allCases: [RecurringType] {
        return [.none, .daily, .weekly, .monthly, .yearly]
    }
}

#Preview {
    AddEventView(selectedDate: Date())
        .environmentObject(CoupleManager())
}
//
//  EventRow.swift
//  JuntosApp
//
//  Created by JuntosApp Team on 2024.
//

import SwiftUI
import FirebaseAuth

struct EventRow: View {
    let event: CalendarEvent
    let showDate: Bool
    let onTap: () -> Void
    
    @EnvironmentObject var userManager: UserManager
    
    init(event: CalendarEvent, showDate: Bool = false, onTap: @escaping () -> Void) {
        self.event = event
        self.showDate = showDate
        self.onTap = onTap
    }
    
    private var creatorName: String {
        if let currentUser = Auth.auth().currentUser,
           event.createdBy == currentUser.uid {
            return "Tú"
        } else {
            return userManager.partnerProfile?.name ?? "Pareja"
        }
    }
    
    private var timeDisplay: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        
        if event.isAllDay {
            return "Todo el día"
        } else {
            let startTime = formatter.string(from: event.startDate)
            let endTime = formatter.string(from: event.endDate)
            return "\(startTime) - \(endTime)"
        }
    }
    
    private var dateDisplay: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: event.startDate)
    }
    
    private var isUpcoming: Bool {
        event.startDate > Date()
    }
    
    private var isPast: Bool {
        event.endDate < Date()
    }
    
    private var isToday: Bool {
        Calendar.current.isDateInToday(event.startDate)
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Indicador de color y estado
                VStack {
                    Circle()
                        .fill(eventColor)
                        .frame(width: 12, height: 12)
                    
                    if event.recurringType != .none {
                        Image(systemName: "repeat")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Contenido principal
                VStack(alignment: .leading, spacing: 4) {
                    // Título del evento
                    Text(event.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    // Fecha (si se debe mostrar)
                    if showDate {
                        Text(dateDisplay)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Hora
                    Text(timeDisplay)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // Ubicación (si existe)
                    if let location = event.location, !location.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "location")
                                .font(.caption2)
                            Text(location)
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    }
                    
                    // Información adicional
                    HStack(spacing: 8) {
                        // Creador
                        Text("Por \(creatorName)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        // Recordatorio
                        if event.reminderMinutes > 0 {
                            HStack(spacing: 2) {
                                Image(systemName: "bell.fill")
                                    .font(.caption2)
                                Text(reminderText)
                                    .font(.caption2)
                            }
                            .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                // Estado visual
                VStack(spacing: 4) {
                    if isToday {
                        Text("HOY")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color("PrimaryColor"))
                            )
                    } else if isPast {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.subheadline)
                            .foregroundColor(.green)
                    } else if isUpcoming {
                        Text(timeUntilEvent)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    // Flecha
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Computed Properties
    
    private var eventColor: Color {
        if isPast {
            return Color.secondary.opacity(0.5)
        } else if isToday {
            return Color("PrimaryColor")
        } else {
            return Color("PrimaryColor").opacity(0.7)
        }
    }
    
    private var reminderText: String {
        let minutes = event.reminderMinutes
        
        if minutes < 60 {
            return "\(minutes)m"
        } else if minutes < 1440 { // Less than 24 hours
            let hours = minutes / 60
            return "\(hours)h"
        } else {
            let days = minutes / 1440
            return "\(days)d"
        }
    }
    
    private var timeUntilEvent: String {
        let now = Date()
        let timeInterval = event.startDate.timeIntervalSince(now)
        
        if timeInterval < 3600 { // Less than 1 hour
            let minutes = Int(timeInterval / 60)
            return "en \(minutes)m"
        } else if timeInterval < 86400 { // Less than 24 hours
            let hours = Int(timeInterval / 3600)
            return "en \(hours)h"
        } else {
            let days = Int(timeInterval / 86400)
            return "en \(days)d"
        }
    }
}

// MARK: - Event Detail View

struct EventDetailView: View {
    let event: CalendarEvent
    @Environment(\.dismiss) private var dismiss
    @State private var showingEditEvent = false
    @State private var showingDeleteAlert = false
    
    @EnvironmentObject var coupleManager: CoupleManager
    @EnvironmentObject var userManager: UserManager
    
    private var canEdit: Bool {
        guard let currentUser = Auth.auth().currentUser else { return false }
        return event.createdBy == currentUser.uid
    }
    
    private var creatorName: String {
        if let currentUser = Auth.auth().currentUser,
           event.createdBy == currentUser.uid {
            return "Tú"
        } else {
            return userManager.partnerProfile?.name ?? "Pareja"
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header con título
                    VStack(alignment: .leading, spacing: 8) {
                        Text(event.title)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        if let description = event.description, !description.isEmpty {
                            Text(description)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Información del evento
                    VStack(spacing: 15) {
                        // Fecha y hora
                        InfoRow(
                            icon: "calendar",
                            title: "Fecha",
                            content: formatEventDate()
                        )
                        
                        // Ubicación
                        if let location = event.location, !location.isEmpty {
                            InfoRow(
                                icon: "location",
                                title: "Ubicación",
                                content: location
                            )
                        }
                        
                        // Recordatorio
                        if event.reminderMinutes > 0 {
                            InfoRow(
                                icon: "bell",
                                title: "Recordatorio",
                                content: formatReminder()
                            )
                        }
                        
                        // Repetición
                        if event.recurringType != .none {
                            InfoRow(
                                icon: "repeat",
                                title: "Repetir",
                                content: event.recurringType.displayName
                            )
                        }
                        
                        // Creador
                        InfoRow(
                            icon: "person",
                            title: "Creado por",
                            content: creatorName
                        )
                        
                        // Fecha de creación
                        InfoRow(
                            icon: "clock",
                            title: "Creado",
                            content: event.createdAt.formatted(.dateTime.day().month().year().hour().minute())
                        )
                    }
                    
                    Spacer(minLength: 50)
                }
                .padding()
            }
            .navigationTitle("Detalles")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cerrar") {
                        dismiss()
                    }
                }
                
                if canEdit {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Button("Editar") {
                                showingEditEvent = true
                            }
                            
                            Divider()
                            
                            Button("Eliminar", role: .destructive) {
                                showingDeleteAlert = true
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingEditEvent) {
            AddEventView(eventToEdit: event)
        }
        .alert("Eliminar Evento", isPresented: $showingDeleteAlert) {
            Button("Cancelar", role: .cancel) { }
            Button("Eliminar", role: .destructive) {
                deleteEvent()
            }
        } message: {
            Text("¿Estás seguro de que quieres eliminar \"\(event.title)\"? Esta acción no se puede deshacer.")
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatEventDate() -> String {
        let formatter = DateFormatter()
        
        if event.isAllDay {
            formatter.dateStyle = .full
            return formatter.string(from: event.startDate)
        } else {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .full
            
            let timeFormatter = DateFormatter()
            timeFormatter.timeStyle = .short
            
            let date = dateFormatter.string(from: event.startDate)
            let startTime = timeFormatter.string(from: event.startDate)
            let endTime = timeFormatter.string(from: event.endDate)
            
            return "\(date)\n\(startTime) - \(endTime)"
        }
    }
    
    private func formatReminder() -> String {
        let minutes = event.reminderMinutes
        
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
    
    private func deleteEvent() {
        guard let coupleId = coupleManager.coupleData?.id else { return }
        
        let db = Firestore.firestore()
        db.collection("couples").document(coupleId).collection("events")
            .document(event.id).delete { error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("Error deleting event: \(error)")
                    } else {
                        dismiss()
                    }
                }
            }
    }
}

// MARK: - Info Row Component

struct InfoRow: View {
    let icon: String
    let title: String
    let content: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(Color("PrimaryColor"))
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Text(content)
                    .font(.subheadline)
                    .foregroundColor(.primary)
            }
            
            Spacer()
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Extensions

extension RecurringType {
    var displayName: String {
        switch self {
        case .none:
            return "No repetir"
        case .daily:
            return "Diariamente"
        case .weekly:
            return "Semanalmente"
        case .monthly:
            return "Mensualmente"
        case .yearly:
            return "Anualmente"
        }
    }
}

#Preview {
    EventRow(
        event: CalendarEvent(
            title: "Cita médica",
            description: "Revisión anual",
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            isAllDay: false,
            location: "Hospital Central",
            reminderMinutes: 30,
            recurringType: .none,
            createdBy: "user123",
            createdAt: Date()
        ),
        showDate: true
    ) {
        print("Event tapped")
    }
    .environmentObject(UserManager())
    .padding()
}
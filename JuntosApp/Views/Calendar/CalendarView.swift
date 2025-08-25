//
//  CalendarView.swift
//  JuntosApp
//
//  Created by JuntosApp Team on 2024.
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import UserNotifications

struct CalendarView: View {
    @State private var selectedDate = Date()
    @State private var events: [CalendarEvent] = []
    @State private var showingAddEvent = false
    @State private var showingEventDetail: CalendarEvent? = nil
    @State private var calendarMode: CalendarMode = .month
    @State private var isLoading = false
    
    @EnvironmentObject var coupleManager: CoupleManager
    @EnvironmentObject var userManager: UserManager
    
    private let db = Firestore.firestore()
    private let calendar = Calendar.current
    
    enum CalendarMode: String, CaseIterable {
        case month = "Mes"
        case week = "Semana"
        case day = "Día"
    }
    
    var eventsForSelectedDate: [CalendarEvent] {
        events.filter { event in
            calendar.isDate(event.startDate, inSameDayAs: selectedDate)
        }.sorted { $0.startDate < $1.startDate }
    }
    
    var upcomingEvents: [CalendarEvent] {
        let now = Date()
        return events.filter { event in
            event.startDate > now
        }.sorted { $0.startDate < $1.startDate }
        .prefix(5)
        .map { $0 }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Selector de modo de calendario
                    calendarModeSelector
                    
                    // Vista del calendario
                    calendarContent
                    
                    // Lista de eventos
                    eventsSection
                }
            }
            .navigationTitle("Calendario")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddEvent = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.title2)
                            .foregroundColor(Color("PrimaryColor"))
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddEvent) {
            AddEventView(selectedDate: selectedDate)
        }
        .sheet(item: $showingEventDetail) { event in
            EventDetailView(event: event)
        }
        .onAppear {
            loadEvents()
            setupRealtimeListener()
            requestNotificationPermission()
        }
    }
    
    // MARK: - Calendar Mode Selector
    
    private var calendarModeSelector: some View {
        HStack {
            ForEach(CalendarMode.allCases, id: \.self) { mode in
                Button(mode.rawValue) {
                    calendarMode = mode
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(calendarMode == mode ? Color("PrimaryColor") : Color(.systemBackground))
                )
                .foregroundColor(calendarMode == mode ? .white : Color("PrimaryColor"))
                .font(.subheadline)
                .fontWeight(.medium)
            }
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }
    
    // MARK: - Calendar Content
    
    private var calendarContent: some View {
        Group {
            switch calendarMode {
            case .month:
                monthView
            case .week:
                weekView
            case .day:
                dayView
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private var monthView: some View {
        VStack(spacing: 0) {
            // Header del mes
            HStack {
                Button {
                    withAnimation {
                        selectedDate = calendar.date(byAdding: .month, value: -1, to: selectedDate) ?? selectedDate
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundColor(Color("PrimaryColor"))
                }
                
                Spacer()
                
                Text(selectedDate.formatted(.dateTime.month(.wide).year()))
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button {
                    withAnimation {
                        selectedDate = calendar.date(byAdding: .month, value: 1, to: selectedDate) ?? selectedDate
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.title2)
                        .foregroundColor(Color("PrimaryColor"))
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 15)
            
            // Días de la semana
            HStack {
                ForEach(calendar.shortWeekdaySymbols, id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 10)
            
            // Grid de días
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(daysInMonth, id: \.self) { date in
                    dayCell(for: date)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 15)
        }
    }
    
    private var weekView: some View {
        VStack(spacing: 0) {
            // Header de la semana
            HStack {
                Button {
                    withAnimation {
                        selectedDate = calendar.date(byAdding: .weekOfYear, value: -1, to: selectedDate) ?? selectedDate
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundColor(Color("PrimaryColor"))
                }
                
                Spacer()
                
                Text(weekRange)
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button {
                    withAnimation {
                        selectedDate = calendar.date(byAdding: .weekOfYear, value: 1, to: selectedDate) ?? selectedDate
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.title2)
                        .foregroundColor(Color("PrimaryColor"))
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 15)
            
            // Días de la semana
            HStack(spacing: 0) {
                ForEach(daysInWeek, id: \.self) { date in
                    VStack(spacing: 4) {
                        Text(calendar.component(.day, from: date).formatted())
                            .font(.title3)
                            .fontWeight(calendar.isDate(date, inSameDayAs: selectedDate) ? .bold : .medium)
                        
                        Text(date.formatted(.dateTime.weekday(.abbreviated)))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        // Indicador de eventos
                        if hasEvents(for: date) {
                            Circle()
                                .fill(Color("PrimaryColor"))
                                .frame(width: 6, height: 6)
                        } else {
                            Circle()
                                .fill(Color.clear)
                                .frame(width: 6, height: 6)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(calendar.isDate(date, inSameDayAs: selectedDate) ? Color("PrimaryColor").opacity(0.1) : Color.clear)
                    )
                    .onTapGesture {
                        selectedDate = date
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 15)
        }
    }
    
    private var dayView: some View {
        VStack(spacing: 0) {
            // Header del día
            HStack {
                Button {
                    withAnimation {
                        selectedDate = calendar.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundColor(Color("PrimaryColor"))
                }
                
                Spacer()
                
                VStack(spacing: 2) {
                    Text(selectedDate.formatted(.dateTime.weekday(.wide)))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(selectedDate.formatted(.dateTime.day().month().year()))
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                
                Spacer()
                
                Button {
                    withAnimation {
                        selectedDate = calendar.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.title2)
                        .foregroundColor(Color("PrimaryColor"))
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 15)
            
            // Timeline del día
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(0..<24) { hour in
                        hourRow(for: hour)
                    }
                }
            }
            .frame(height: 300)
        }
    }
    
    // MARK: - Events Section
    
    private var eventsSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            if calendarMode == .month || calendarMode == .week {
                // Eventos del día seleccionado
                if !eventsForSelectedDate.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Eventos para \(selectedDate.formatted(.dateTime.weekday(.wide).day().month()))")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .padding(.horizontal)
                        
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(eventsForSelectedDate) { event in
                                    EventRow(event: event) {
                                        showingEventDetail = event
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                } else {
                    VStack(spacing: 10) {
                        Text("No hay eventos")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                        
                        Button("Agregar Evento") {
                            showingAddEvent = true
                        }
                        .font(.subheadline)
                        .foregroundColor(Color("PrimaryColor"))
                        .padding(.horizontal)
                    }
                }
            }
            
            // Próximos eventos
            if !upcomingEvents.isEmpty && calendarMode != .day {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Próximos Eventos")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .padding(.horizontal)
                    
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(upcomingEvents) { event in
                                EventRow(event: event, showDate: true) {
                                    showingEventDetail = event
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top)
    }
    
    // MARK: - Helper Views
    
    private func dayCell(for date: Date) -> some View {
        let day = calendar.component(.day, from: date)
        let isToday = calendar.isDateInToday(date)
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isCurrentMonth = calendar.isDate(date, equalTo: selectedDate, toGranularity: .month)
        let hasEventsForDate = hasEvents(for: date)
        
        return VStack(spacing: 4) {
            Text("\(day)")
                .font(.subheadline)
                .fontWeight(isToday ? .bold : .medium)
                .foregroundColor(
                    isSelected ? .white :
                    isToday ? Color("PrimaryColor") :
                    isCurrentMonth ? .primary : .secondary
                )
            
            if hasEventsForDate {
                Circle()
                    .fill(isSelected ? .white : Color("PrimaryColor"))
                    .frame(width: 4, height: 4)
            }
        }
        .frame(width: 32, height: 40)
        .background(
            Circle()
                .fill(
                    isSelected ? Color("PrimaryColor") :
                    isToday ? Color("PrimaryColor").opacity(0.1) :
                    Color.clear
                )
        )
        .onTapGesture {
            selectedDate = date
        }
    }
    
    private func hourRow(for hour: Int) -> some View {
        let eventsForHour = eventsForSelectedDate.filter { event in
            calendar.component(.hour, from: event.startDate) == hour
        }
        
        return HStack(alignment: .top, spacing: 15) {
            // Hora
            Text("\(hour):00")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 50, alignment: .trailing)
            
            VStack(alignment: .leading, spacing: 4) {
                // Línea divisoria
                Divider()
                
                // Eventos en esta hora
                ForEach(eventsForHour) { event in
                    Button {
                        showingEventDetail = event
                    } label: {
                        HStack {
                            Text(event.title)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color("PrimaryColor"))
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 40)
        .padding(.horizontal)
    }
    
    // MARK: - Computed Properties
    
    private var daysInMonth: [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: selectedDate),
              let monthFirstWeek = calendar.dateInterval(of: .weekOfYear, for: monthInterval.start),
              let monthLastWeek = calendar.dateInterval(of: .weekOfYear, for: monthInterval.end - 1) else {
            return []
        }
        
        var days: [Date] = []
        var date = monthFirstWeek.start
        
        while date < monthLastWeek.end {
            days.append(date)
            date = calendar.date(byAdding: .day, value: 1, to: date) ?? date
        }
        
        return days
    }
    
    private var daysInWeek: [Date] {
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: selectedDate) else {
            return []
        }
        
        var days: [Date] = []
        var date = weekInterval.start
        
        while date < weekInterval.end {
            days.append(date)
            date = calendar.date(byAdding: .day, value: 1, to: date) ?? date
        }
        
        return days
    }
    
    private var weekRange: String {
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: selectedDate) else {
            return ""
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        
        let start = formatter.string(from: weekInterval.start)
        let end = formatter.string(from: weekInterval.end - 1)
        
        return "\(start) - \(end)"
    }
    
    // MARK: - Helper Methods
    
    private func hasEvents(for date: Date) -> Bool {
        return events.contains { event in
            calendar.isDate(event.startDate, inSameDayAs: date)
        }
    }
    
    // MARK: - Firebase Operations
    
    private func loadEvents() {
        guard let coupleId = coupleManager.coupleData?.id else { return }
        
        isLoading = true
        
        db.collection("couples").document(coupleId).collection("events")
            .order(by: "startDate")
            .getDocuments { snapshot, error in
                DispatchQueue.main.async {
                    isLoading = false
                    
                    if let error = error {
                        print("Error loading events: \(error)")
                        return
                    }
                    
                    guard let documents = snapshot?.documents else { return }
                    
                    self.events = documents.compactMap { doc in
                        try? doc.data(as: CalendarEvent.self)
                    }
                }
            }
    }
    
    private func setupRealtimeListener() {
        guard let coupleId = coupleManager.coupleData?.id else { return }
        
        db.collection("couples").document(coupleId).collection("events")
            .order(by: "startDate")
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("Error in events listener: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                DispatchQueue.main.async {
                    self.events = documents.compactMap { doc in
                        try? doc.data(as: CalendarEvent.self)
                    }
                }
            }
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
                print("Error requesting notification permission: \(error)")
            }
        }
    }
}

#Preview {
    CalendarView()
        .environmentObject(CoupleManager())
        .environmentObject(UserManager())
}
//
//  MemoriesView.swift
//  JuntosApp
//
//  Created by JuntosApp Team on 2024.
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage
import PhotosUI

struct MemoriesView: View {
    @State private var memories: [Memory] = []
    @State private var showingAddMemory = false
    @State private var selectedViewMode: ViewMode = .grid
    @State private var searchText = ""
    @State private var selectedFilter: MediaFilter = .all
    @State private var isLoading = false
    @State private var selectedMemory: Memory?
    @State private var showingMemoryDetail = false
    
    @EnvironmentObject var coupleManager: CoupleManager
    @EnvironmentObject var userManager: UserManager
    
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    
    enum ViewMode: String, CaseIterable {
        case grid = "Cuadrícula"
        case timeline = "Línea de Tiempo"
    }
    
    enum MediaFilter: String, CaseIterable {
        case all = "Todos"
        case photos = "Fotos"
        case videos = "Videos"
        case notes = "Notas"
    }
    
    private var filteredMemories: [Memory] {
        let searchFiltered = memories.filter { memory in
            searchText.isEmpty || 
            memory.title?.localizedCaseInsensitiveContains(searchText) == true ||
            memory.description?.localizedCaseInsensitiveContains(searchText) == true
        }
        
        let filtered = searchFiltered.filter { memory in
            switch selectedFilter {
            case .all:
                return true
            case .photos:
                return memory.mediaType == .image
            case .videos:
                return memory.mediaType == .video
            case .notes:
                return memory.mediaType == .note
            }
        }
        
        return filtered.sorted { $0.createdAt > $1.createdAt }
    }
    
    private var groupedMemories: [String: [Memory]] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        
        return Dictionary(grouping: filteredMemories) { memory in
            formatter.string(from: memory.createdAt)
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Search and filters
                    searchAndFiltersView
                    
                    // View mode toggle
                    viewModeToggle
                    
                    // Content
                    if isLoading {
                        Spacer()
                        ProgressView("Cargando recuerdos...")
                            .progressViewStyle(CircularProgressViewStyle())
                        Spacer()
                    } else if filteredMemories.isEmpty {
                        emptyStateView
                    } else {
                        if selectedViewMode == .grid {
                            gridView
                        } else {
                            timelineView
                        }
                    }
                }
            }
            .navigationTitle("Recuerdos")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddMemory = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.title2)
                            .foregroundColor(Color("PrimaryColor"))
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddMemory) {
            AddMemoryView()
        }
        .sheet(item: $selectedMemory) { memory in
            MemoryDetailView(memory: memory)
        }
        .onAppear {
            loadMemories()
            setupRealtimeListener()
        }
    }
    
    // MARK: - Search and Filters
    
    private var searchAndFiltersView: some View {
        VStack(spacing: 12) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Buscar recuerdos...", text: $searchText)
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
            
            // Filter tabs
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(MediaFilter.allCases, id: \.self) { filter in
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
        }
        .padding(.horizontal)
        .padding(.top)
    }
    
    // MARK: - View Mode Toggle
    
    private var viewModeToggle: some View {
        HStack {
            Spacer()
            
            Picker("Modo de vista", selection: $selectedViewMode) {
                ForEach(ViewMode.allCases, id: \.self) { mode in
                    HStack {
                        Image(systemName: mode == .grid ? "square.grid.2x2" : "list.bullet")
                        Text(mode.rawValue)
                    }
                    .tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 200)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
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
                Button("Crear Primer Recuerdo") {
                    showingAddMemory = true
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
    
    // MARK: - Grid View
    
    private var gridView: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 4),
                GridItem(.flexible(), spacing: 4),
                GridItem(.flexible(), spacing: 4)
            ], spacing: 4) {
                ForEach(filteredMemories) { memory in
                    MemoryGridCard(memory: memory) {
                        selectedMemory = memory
                        showingMemoryDetail = true
                    }
                }
            }
            .padding(.horizontal)
        }
        .refreshable {
            loadMemories()
        }
    }
    
    // MARK: - Timeline View
    
    private var timelineView: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                ForEach(groupedMemories.keys.sorted(by: >), id: \.self) { monthYear in
                    VStack(alignment: .leading, spacing: 12) {
                        // Month header
                        HStack {
                            Text(monthYear)
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(Color("PrimaryColor"))
                            
                            Spacer()
                            
                            Text("\(groupedMemories[monthYear]?.count ?? 0) recuerdos")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                        
                        // Memories for this month
                        ForEach(groupedMemories[monthYear] ?? []) { memory in
                            MemoryTimelineCard(memory: memory) {
                                selectedMemory = memory
                                showingMemoryDetail = true
                            }
                        }
                    }
                }
            }
            .padding(.vertical)
        }
        .refreshable {
            loadMemories()
        }
    }
    
    // MARK: - Helper Methods
    
    private func getEmptyStateIcon() -> String {
        switch selectedFilter {
        case .all:
            return "heart.circle"
        case .photos:
            return "photo.circle"
        case .videos:
            return "video.circle"
        case .notes:
            return "note.text.circle"
        }
    }
    
    private func getEmptyStateTitle() -> String {
        switch selectedFilter {
        case .all:
            return "No hay recuerdos"
        case .photos:
            return "No hay fotos"
        case .videos:
            return "No hay videos"
        case .notes:
            return "No hay notas"
        }
    }
    
    private func getEmptyStateMessage() -> String {
        switch selectedFilter {
        case .all:
            return "Crea tu primer recuerdo para guardar momentos especiales juntos"
        case .photos:
            return "Aún no has subido ninguna foto"
        case .videos:
            return "Aún no has subido ningún video"
        case .notes:
            return "Aún no has creado ninguna nota"
        }
    }
    
    // MARK: - Firebase Operations
    
    private func loadMemories() {
        guard let coupleId = coupleManager.coupleData?.id else { return }
        
        isLoading = true
        
        db.collection("couples").document(coupleId).collection("memories")
            .order(by: "createdAt", descending: true)
            .getDocuments { snapshot, error in
                DispatchQueue.main.async {
                    isLoading = false
                    
                    if let error = error {
                        print("Error loading memories: \(error)")
                        return
                    }
                    
                    guard let documents = snapshot?.documents else { return }
                    
                    self.memories = documents.compactMap { doc in
                        try? doc.data(as: Memory.self)
                    }
                }
            }
    }
    
    private func setupRealtimeListener() {
        guard let coupleId = coupleManager.coupleData?.id else { return }
        
        db.collection("couples").document(coupleId).collection("memories")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("Error in memories listener: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                DispatchQueue.main.async {
                    self.memories = documents.compactMap { doc in
                        try? doc.data(as: Memory.self)
                    }
                }
            }
    }
}

#Preview {
    MemoriesView()
        .environmentObject(CoupleManager())
        .environmentObject(UserManager())
}
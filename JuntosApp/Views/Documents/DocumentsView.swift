//
//  DocumentsView.swift
//  JuntosApp
//
//  Created by JuntosApp Team on 2024.
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage
import LocalAuthentication
import UniformTypeIdentifiers

struct DocumentsView: View {
    @State private var documents: [Document] = []
    @State private var selectedFolder: DocumentFolder? = nil
    @State private var showingAddDocument = false
    @State private var showingDocumentPicker = false
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var isAuthenticated = false
    @State private var showingAuthError = false
    @State private var authErrorMessage = ""
    @State private var searchText = ""
    @State private var isLoading = false
    
    @EnvironmentObject var coupleManager: CoupleManager
    @EnvironmentObject var userManager: UserManager
    
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    
    var filteredDocuments: [Document] {
        let folderFiltered = documents.filter { document in
            selectedFolder == nil || document.folder == selectedFolder
        }
        
        if searchText.isEmpty {
            return folderFiltered.sorted { $0.uploadedAt > $1.uploadedAt }
        } else {
            return folderFiltered.filter { document in
                document.name.localizedCaseInsensitiveContains(searchText) ||
                document.description?.localizedCaseInsensitiveContains(searchText) == true
            }.sorted { $0.uploadedAt > $1.uploadedAt }
        }
    }
    
    var documentsByFolder: [DocumentFolder: [Document]] {
        Dictionary(grouping: documents, by: { $0.folder })
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if !isAuthenticated {
                    // Vista de autenticación
                    authenticationView
                } else {
                    // Vista principal de documentos
                    mainDocumentsView
                }
            }
            .navigationTitle("Documentos")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if isAuthenticated {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Button("Tomar Foto") {
                                showingCamera = true
                            }
                            
                            Button("Seleccionar Foto") {
                                showingImagePicker = true
                            }
                            
                            Button("Seleccionar Archivo") {
                                showingDocumentPicker = true
                            }
                        } label: {
                            Image(systemName: "plus")
                                .font(.title2)
                                .foregroundColor(Color("PrimaryColor"))
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingDocumentPicker) {
            DocumentPicker { url in
                uploadDocument(from: url)
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(sourceType: .photoLibrary) { image in
                uploadImage(image)
            }
        }
        .sheet(isPresented: $showingCamera) {
            ImagePicker(sourceType: .camera) { image in
                uploadImage(image)
            }
        }
        .alert("Error de Autenticación", isPresented: $showingAuthError) {
            Button("OK") { }
        } message: {
            Text(authErrorMessage)
        }
        .onAppear {
            authenticateUser()
        }
    }
    
    // MARK: - Authentication View
    
    private var authenticationView: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Icono de seguridad
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 80))
                .foregroundColor(Color("PrimaryColor"))
            
            VStack(spacing: 15) {
                Text("Documentos Seguros")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Tus documentos están protegidos con autenticación biométrica")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Button("Desbloquear") {
                authenticateUser()
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color("PrimaryColor"))
            .cornerRadius(25)
            .padding(.horizontal, 40)
            
            Spacer()
        }
    }
    
    // MARK: - Main Documents View
    
    private var mainDocumentsView: some View {
        VStack(spacing: 0) {
            // Barra de búsqueda
            searchBar
            
            // Filtros por carpeta
            folderFilters
            
            // Contenido principal
            if isLoading {
                Spacer()
                ProgressView("Cargando documentos...")
                    .progressViewStyle(CircularProgressViewStyle())
                Spacer()
            } else if filteredDocuments.isEmpty {
                emptyStateView
            } else {
                documentsGrid
            }
        }
        .onAppear {
            if isAuthenticated {
                loadDocuments()
                setupRealtimeListener()
            }
        }
    }
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Buscar documentos...", text: $searchText)
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
    
    private var folderFilters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                // Botón "Todos"
                Button("Todos") {
                    selectedFolder = nil
                }
                .padding(.horizontal, 15)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(selectedFolder == nil ? Color("PrimaryColor") : Color(.systemBackground))
                )
                .foregroundColor(selectedFolder == nil ? .white : Color("PrimaryColor"))
                .font(.subheadline)
                .fontWeight(.medium)
                
                ForEach(DocumentFolder.allCases, id: \.self) { folder in
                    Button("\(folder.displayName) (\(documentsByFolder[folder]?.count ?? 0))") {
                        selectedFolder = selectedFolder == folder ? nil : folder
                    }
                    .padding(.horizontal, 15)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(selectedFolder == folder ? Color("PrimaryColor") : Color(.systemBackground))
                    )
                    .foregroundColor(selectedFolder == folder ? .white : Color("PrimaryColor"))
                    .font(.subheadline)
                    .fontWeight(.medium)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: selectedFolder != nil ? "folder" : "doc.text")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text(selectedFolder != nil ? "Carpeta vacía" : "No hay documentos")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            Text(selectedFolder != nil ?
                 "No tienes documentos en la carpeta \(selectedFolder?.displayName ?? "")" :
                 "Agrega tu primer documento para comenzar")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            if selectedFolder == nil {
                Button("Agregar Documento") {
                    showingDocumentPicker = true
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
    
    private var documentsGrid: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 15) {
                ForEach(filteredDocuments) { document in
                    DocumentCard(document: document) {
                        deleteDocument(document)
                    }
                }
            }
            .padding(.horizontal)
        }
        .refreshable {
            loadDocuments()
        }
    }
    
    // MARK: - Authentication
    
    private func authenticateUser() {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            let reason = "Accede a tus documentos seguros"
            
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, authenticationError in
                DispatchQueue.main.async {
                    if success {
                        isAuthenticated = true
                    } else {
                        authErrorMessage = authenticationError?.localizedDescription ?? "Error de autenticación"
                        showingAuthError = true
                    }
                }
            }
        } else if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            let reason = "Accede a tus documentos seguros"
            
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, authenticationError in
                DispatchQueue.main.async {
                    if success {
                        isAuthenticated = true
                    } else {
                        authErrorMessage = authenticationError?.localizedDescription ?? "Error de autenticación"
                        showingAuthError = true
                    }
                }
            }
        } else {
            // No hay autenticación disponible, permitir acceso
            isAuthenticated = true
        }
    }
    
    // MARK: - Firebase Operations
    
    private func loadDocuments() {
        guard let coupleId = coupleManager.coupleData?.id else { return }
        
        isLoading = true
        
        db.collection("couples").document(coupleId).collection("documents")
            .order(by: "uploadedAt", descending: true)
            .getDocuments { snapshot, error in
                DispatchQueue.main.async {
                    isLoading = false
                    
                    if let error = error {
                        print("Error loading documents: \(error)")
                        return
                    }
                    
                    guard let documents = snapshot?.documents else { return }
                    
                    self.documents = documents.compactMap { doc in
                        try? doc.data(as: Document.self)
                    }
                }
            }
    }
    
    private func setupRealtimeListener() {
        guard let coupleId = coupleManager.coupleData?.id else { return }
        
        db.collection("couples").document(coupleId).collection("documents")
            .order(by: "uploadedAt", descending: true)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("Error in documents listener: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                DispatchQueue.main.async {
                    self.documents = documents.compactMap { doc in
                        try? doc.data(as: Document.self)
                    }
                }
            }
    }
    
    private func uploadDocument(from url: URL) {
        guard let coupleId = coupleManager.coupleData?.id,
              let currentUser = Auth.auth().currentUser else { return }
        
        isLoading = true
        
        let fileName = url.lastPathComponent
        let storageRef = storage.reference().child("documents/\(coupleId)/\(UUID().uuidString)_\(fileName)")
        
        storageRef.putFile(from: url, metadata: nil) { metadata, error in
            if let error = error {
                print("Error uploading document: \(error)")
                DispatchQueue.main.async {
                    isLoading = false
                }
                return
            }
            
            storageRef.downloadURL { downloadURL, error in
                DispatchQueue.main.async {
                    isLoading = false
                    
                    if let error = error {
                        print("Error getting download URL: \(error)")
                        return
                    }
                    
                    guard let downloadURL = downloadURL else { return }
                    
                    let document = Document(
                        name: fileName,
                        type: DocumentType.fromFileExtension(url.pathExtension),
                        folder: .contracts, // Default folder
                        url: downloadURL.absoluteString,
                        uploadedBy: currentUser.uid,
                        uploadedAt: Date(),
                        fileSize: metadata?.size ?? 0
                    )
                    
                    saveDocument(document)
                }
            }
        }
    }
    
    private func uploadImage(_ image: UIImage) {
        guard let coupleId = coupleManager.coupleData?.id,
              let currentUser = Auth.auth().currentUser,
              let imageData = image.jpegData(compressionQuality: 0.8) else { return }
        
        isLoading = true
        
        let fileName = "image_\(Date().timeIntervalSince1970).jpg"
        let storageRef = storage.reference().child("documents/\(coupleId)/\(fileName)")
        
        storageRef.putData(imageData, metadata: nil) { metadata, error in
            if let error = error {
                print("Error uploading image: \(error)")
                DispatchQueue.main.async {
                    isLoading = false
                }
                return
            }
            
            storageRef.downloadURL { downloadURL, error in
                DispatchQueue.main.async {
                    isLoading = false
                    
                    if let error = error {
                        print("Error getting download URL: \(error)")
                        return
                    }
                    
                    guard let downloadURL = downloadURL else { return }
                    
                    let document = Document(
                        name: fileName,
                        type: .image,
                        folder: .photos, // Default folder for images
                        url: downloadURL.absoluteString,
                        uploadedBy: currentUser.uid,
                        uploadedAt: Date(),
                        fileSize: Int64(imageData.count)
                    )
                    
                    saveDocument(document)
                }
            }
        }
    }
    
    private func saveDocument(_ document: Document) {
        guard let coupleId = coupleManager.coupleData?.id else { return }
        
        do {
            try db.collection("couples").document(coupleId).collection("documents")
                .document(document.id).setData(from: document)
        } catch {
            print("Error saving document: \(error)")
        }
    }
    
    private func deleteDocument(_ document: Document) {
        guard let coupleId = coupleManager.coupleData?.id else { return }
        
        // Eliminar de Firestore
        db.collection("couples").document(coupleId).collection("documents")
            .document(document.id).delete()
        
        // Eliminar de Storage
        let storageRef = storage.reference(forURL: document.url)
        storageRef.delete { error in
            if let error = error {
                print("Error deleting file from storage: \(error)")
            }
        }
    }
}

// MARK: - Extensions
extension DocumentFolder {
    var displayName: String {
        switch self {
        case .contracts: return "Contratos"
        case .bills: return "Facturas"
        case .medical: return "Médicos"
        case .insurance: return "Seguros"
        case .taxes: return "Impuestos"
        case .photos: return "Fotos"
        case .other: return "Otros"
        }
    }
    
    var icon: String {
        switch self {
        case .contracts: return "doc.text.fill"
        case .bills: return "receipt.fill"
        case .medical: return "cross.fill"
        case .insurance: return "shield.fill"
        case .taxes: return "percent"
        case .photos: return "photo.fill"
        case .other: return "folder.fill"
        }
    }
    
    var color: String {
        switch self {
        case .contracts: return "#FF6B6B"
        case .bills: return "#4ECDC4"
        case .medical: return "#45B7D1"
        case .insurance: return "#96CEB4"
        case .taxes: return "#FECA57"
        case .photos: return "#A55EEA"
        case .other: return "#95A5A6"
        }
    }
}

extension DocumentType {
    static func fromFileExtension(_ ext: String) -> DocumentType {
        switch ext.lowercased() {
        case "pdf":
            return .pdf
        case "jpg", "jpeg", "png", "heic":
            return .image
        case "txt", "rtf":
            return .text
        case "doc", "docx":
            return .word
        case "xls", "xlsx":
            return .excel
        default:
            return .other
        }
    }
    
    var displayName: String {
        switch self {
        case .pdf: return "PDF"
        case .image: return "Imagen"
        case .text: return "Texto"
        case .word: return "Word"
        case .excel: return "Excel"
        case .other: return "Archivo"
        }
    }
    
    var icon: String {
        switch self {
        case .pdf: return "doc.fill"
        case .image: return "photo.fill"
        case .text: return "doc.text.fill"
        case .word: return "doc.richtext.fill"
        case .excel: return "tablecells.fill"
        case .other: return "doc.fill"
        }
    }
}

#Preview {
    DocumentsView()
        .environmentObject(CoupleManager())
        .environmentObject(UserManager())
}
//
//  AddMemoryView.swift
//  JuntosApp
//
//  Created by JuntosApp Team on 2024.
//

import SwiftUI
import PhotosUI
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage
import AVFoundation

struct AddMemoryView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedMediaType: MediaType = .image
    @State private var title = ""
    @State private var description = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var selectedVideoURL: URL?
    @State private var videoThumbnail: UIImage?
    @State private var isSaving = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var uploadProgress: Double = 0.0
    
    @EnvironmentObject var coupleManager: CoupleManager
    @EnvironmentObject var userManager: UserManager
    
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    
    private var canSave: Bool {
        switch selectedMediaType {
        case .image:
            return selectedImage != nil
        case .video:
            return selectedVideoURL != nil
        case .note:
            return !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Media Type Selection
                Section("Tipo de Recuerdo") {
                    Picker("Tipo", selection: $selectedMediaType) {
                        ForEach(MediaType.allCases, id: \.self) { type in
                            HStack {
                                Image(systemName: mediaTypeIcon(type))
                                Text(mediaTypeName(type))
                            }
                            .tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: selectedMediaType) { _ in
                        resetSelection()
                    }
                }
                
                // Media Content
                switch selectedMediaType {
                case .image:
                    imageSection
                case .video:
                    videoSection
                case .note:
                    noteSection
                }
                
                // Title and Description
                Section("Detalles") {
                    TextField("Título (opcional)", text: $title)
                        .textInputAutocapitalization(.sentences)
                    
                    TextField("Descripción (opcional)", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                        .textInputAutocapitalization(.sentences)
                }
                
                // Preview
                if canSave {
                    Section("Vista Previa") {
                        memoryPreview
                    }
                }
            }
            .navigationTitle("Nuevo Recuerdo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Guardar") {
                        saveMemory()
                    }
                    .disabled(!canSave || isSaving)
                    .fontWeight(.semibold)
                }
            }
        }
        .disabled(isSaving)
        .overlay {
            if isSaving {
                savingOverlay
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Image Section
    
    private var imageSection: some View {
        Section("Foto") {
            if let selectedImage = selectedImage {
                VStack {
                    Image(uiImage: selectedImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 200)
                        .cornerRadius(8)
                    
                    Button("Cambiar Foto") {
                        self.selectedImage = nil
                        self.selectedPhoto = nil
                    }
                    .foregroundColor(Color("PrimaryColor"))
                }
            } else {
                PhotosPicker(
                    selection: $selectedPhoto,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    VStack(spacing: 12) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 40))
                            .foregroundColor(Color("PrimaryColor"))
                        
                        Text("Seleccionar Foto")
                            .font(.headline)
                            .foregroundColor(Color("PrimaryColor"))
                        
                        Text("Toca para elegir una foto de tu galería")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color("PrimaryColor").opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color("PrimaryColor"), style: StrokeStyle(lineWidth: 2, dash: [5]))
                            )
                    )
                }
                .onChange(of: selectedPhoto) { newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            await MainActor.run {
                                selectedImage = image
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Video Section
    
    private var videoSection: some View {
        Section("Video") {
            if let selectedVideoURL = selectedVideoURL {
                VStack {
                    if let thumbnail = videoThumbnail {
                        ZStack {
                            Image(uiImage: thumbnail)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 200)
                                .cornerRadius(8)
                            
                            Circle()
                                .fill(.black.opacity(0.6))
                                .frame(width: 60, height: 60)
                                .overlay(
                                    Image(systemName: "play.fill")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                        .offset(x: 3)
                                )
                        }
                    }
                    
                    Button("Cambiar Video") {
                        self.selectedVideoURL = nil
                        self.videoThumbnail = nil
                    }
                    .foregroundColor(Color("PrimaryColor"))
                }
            } else {
                PhotosPicker(
                    selection: $selectedPhoto,
                    matching: .videos,
                    photoLibrary: .shared()
                ) {
                    VStack(spacing: 12) {
                        Image(systemName: "video.badge.plus")
                            .font(.system(size: 40))
                            .foregroundColor(Color("PrimaryColor"))
                        
                        Text("Seleccionar Video")
                            .font(.headline)
                            .foregroundColor(Color("PrimaryColor"))
                        
                        Text("Toca para elegir un video de tu galería")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color("PrimaryColor").opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color("PrimaryColor"), style: StrokeStyle(lineWidth: 2, dash: [5]))
                            )
                    )
                }
                .onChange(of: selectedPhoto) { newItem in
                    Task {
                        if let movie = try? await newItem?.loadTransferable(type: VideoTransferable.self) {
                            await MainActor.run {
                                selectedVideoURL = movie.url
                                generateVideoThumbnail(from: movie.url)
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Note Section
    
    private var noteSection: some View {
        Section("Nota") {
            VStack(alignment: .leading, spacing: 12) {
                TextField("Título de la nota", text: $title)
                    .textInputAutocapitalization(.sentences)
                    .font(.headline)
                
                TextField("Escribe tu nota aquí...", text: $description, axis: .vertical)
                    .lineLimit(5...15)
                    .textInputAutocapitalization(.sentences)
            }
        }
    }
    
    // MARK: - Memory Preview
    
    @ViewBuilder
    private var memoryPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: mediaTypeIcon(selectedMediaType))
                    .foregroundColor(Color("PrimaryColor"))
                
                Text(mediaTypeName(selectedMediaType))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("Ahora")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if !title.isEmpty {
                Text(title)
                    .font(.headline)
                    .fontWeight(.medium)
            }
            
            if !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }
            
            // Media preview
            switch selectedMediaType {
            case .image:
                if let selectedImage = selectedImage {
                    Image(uiImage: selectedImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 100)
                        .cornerRadius(8)
                }
            case .video:
                if let thumbnail = videoThumbnail {
                    ZStack {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 100)
                            .cornerRadius(8)
                        
                        Circle()
                            .fill(.black.opacity(0.6))
                            .frame(width: 30, height: 30)
                            .overlay(
                                Image(systemName: "play.fill")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .offset(x: 1)
                            )
                    }
                }
            case .note:
                EmptyView()
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
    
    // MARK: - Saving Overlay
    
    private var savingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(1.2)
                
                Text("Guardando recuerdo...")
                    .font(.headline)
                    .foregroundColor(.white)
                
                if uploadProgress > 0 {
                    ProgressView(value: uploadProgress)
                        .progressViewStyle(LinearProgressViewStyle())
                        .frame(width: 200)
                    
                    Text("\(Int(uploadProgress * 100))%")
                        .font(.caption)
                        .foregroundColor(.white)
                }
            }
            .padding(30)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
            )
        }
    }
    
    // MARK: - Helper Methods
    
    private func mediaTypeIcon(_ type: MediaType) -> String {
        switch type {
        case .image:
            return "photo"
        case .video:
            return "video"
        case .note:
            return "note.text"
        }
    }
    
    private func mediaTypeName(_ type: MediaType) -> String {
        switch type {
        case .image:
            return "Foto"
        case .video:
            return "Video"
        case .note:
            return "Nota"
        }
    }
    
    private func resetSelection() {
        selectedPhoto = nil
        selectedImage = nil
        selectedVideoURL = nil
        videoThumbnail = nil
        if selectedMediaType != .note {
            title = ""
            description = ""
        }
    }
    
    private func generateVideoThumbnail(from url: URL) {
        let asset = AVAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        
        let time = CMTime(seconds: 1, preferredTimescale: 60)
        
        DispatchQueue.global(qos: .background).async {
            do {
                let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
                let thumbnail = UIImage(cgImage: cgImage)
                
                DispatchQueue.main.async {
                    self.videoThumbnail = thumbnail
                }
            } catch {
                print("Error generating video thumbnail: \(error)")
            }
        }
    }
    
    // MARK: - Save Memory
    
    private func saveMemory() {
        guard let coupleId = coupleManager.coupleData?.id,
              let currentUser = Auth.auth().currentUser else {
            return
        }
        
        isSaving = true
        uploadProgress = 0.0
        
        let memoryId = UUID().uuidString
        
        switch selectedMediaType {
        case .image:
            uploadImage(memoryId: memoryId, coupleId: coupleId, userId: currentUser.uid)
        case .video:
            uploadVideo(memoryId: memoryId, coupleId: coupleId, userId: currentUser.uid)
        case .note:
            saveNoteMemory(memoryId: memoryId, coupleId: coupleId, userId: currentUser.uid)
        }
    }
    
    private func uploadImage(memoryId: String, coupleId: String, userId: String) {
        guard let image = selectedImage,
              let imageData = image.jpegData(compressionQuality: 0.8) else {
            handleSaveError("Error al procesar la imagen")
            return
        }
        
        let storageRef = storage.reference().child("couples/\(coupleId)/memories/\(memoryId).jpg")
        
        let uploadTask = storageRef.putData(imageData, metadata: nil) { metadata, error in
            if let error = error {
                self.handleSaveError("Error al subir la imagen: \(error.localizedDescription)")
                return
            }
            
            storageRef.downloadURL { url, error in
                if let error = error {
                    self.handleSaveError("Error al obtener URL: \(error.localizedDescription)")
                    return
                }
                
                guard let downloadURL = url else {
                    self.handleSaveError("URL de descarga no válida")
                    return
                }
                
                self.saveMemoryToFirestore(
                    memoryId: memoryId,
                    coupleId: coupleId,
                    userId: userId,
                    mediaURL: downloadURL.absoluteString,
                    thumbnailURL: nil
                )
            }
        }
        
        uploadTask.observe(.progress) { snapshot in
            let progress = Double(snapshot.progress?.completedUnitCount ?? 0) / Double(snapshot.progress?.totalUnitCount ?? 1)
            DispatchQueue.main.async {
                self.uploadProgress = progress
            }
        }
    }
    
    private func uploadVideo(memoryId: String, coupleId: String, userId: String) {
        guard let videoURL = selectedVideoURL else {
            handleSaveError("Error al procesar el video")
            return
        }
        
        let videoRef = storage.reference().child("couples/\(coupleId)/memories/\(memoryId).mov")
        
        let uploadTask = videoRef.putFile(from: videoURL, metadata: nil) { metadata, error in
            if let error = error {
                self.handleSaveError("Error al subir el video: \(error.localizedDescription)")
                return
            }
            
            videoRef.downloadURL { url, error in
                if let error = error {
                    self.handleSaveError("Error al obtener URL del video: \(error.localizedDescription)")
                    return
                }
                
                guard let downloadURL = url else {
                    self.handleSaveError("URL de descarga del video no válida")
                    return
                }
                
                // Upload thumbnail if available
                if let thumbnail = self.videoThumbnail,
                   let thumbnailData = thumbnail.jpegData(compressionQuality: 0.7) {
                    
                    let thumbnailRef = self.storage.reference().child("couples/\(coupleId)/memories/\(memoryId)_thumb.jpg")
                    
                    thumbnailRef.putData(thumbnailData, metadata: nil) { _, error in
                        if let error = error {
                            print("Error uploading thumbnail: \(error)")
                            // Continue without thumbnail
                            self.saveMemoryToFirestore(
                                memoryId: memoryId,
                                coupleId: coupleId,
                                userId: userId,
                                mediaURL: downloadURL.absoluteString,
                                thumbnailURL: nil
                            )
                            return
                        }
                        
                        thumbnailRef.downloadURL { thumbURL, error in
                            let thumbnailURLString = thumbURL?.absoluteString
                            
                            self.saveMemoryToFirestore(
                                memoryId: memoryId,
                                coupleId: coupleId,
                                userId: userId,
                                mediaURL: downloadURL.absoluteString,
                                thumbnailURL: thumbnailURLString
                            )
                        }
                    }
                } else {
                    self.saveMemoryToFirestore(
                        memoryId: memoryId,
                        coupleId: coupleId,
                        userId: userId,
                        mediaURL: downloadURL.absoluteString,
                        thumbnailURL: nil
                    )
                }
            }
        }
        
        uploadTask.observe(.progress) { snapshot in
            let progress = Double(snapshot.progress?.completedUnitCount ?? 0) / Double(snapshot.progress?.totalUnitCount ?? 1)
            DispatchQueue.main.async {
                self.uploadProgress = progress * 0.8 // Reserve 20% for thumbnail upload
            }
        }
    }
    
    private func saveNoteMemory(memoryId: String, coupleId: String, userId: String) {
        saveMemoryToFirestore(
            memoryId: memoryId,
            coupleId: coupleId,
            userId: userId,
            mediaURL: nil,
            thumbnailURL: nil
        )
    }
    
    private func saveMemoryToFirestore(memoryId: String, coupleId: String, userId: String, mediaURL: String?, thumbnailURL: String?) {
        let memory = Memory(
            id: memoryId,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : title.trimmingCharacters(in: .whitespacesAndNewlines),
            description: description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : description.trimmingCharacters(in: .whitespacesAndNewlines),
            mediaType: selectedMediaType,
            mediaURL: mediaURL,
            thumbnailURL: thumbnailURL,
            createdBy: userId,
            createdAt: Date()
        )
        
        do {
            try db.collection("couples").document(coupleId).collection("memories")
                .document(memoryId).setData(from: memory) { error in
                    DispatchQueue.main.async {
                        self.isSaving = false
                        
                        if let error = error {
                            self.handleSaveError("Error al guardar el recuerdo: \(error.localizedDescription)")
                        } else {
                            self.dismiss()
                        }
                    }
                }
        } catch {
            DispatchQueue.main.async {
                self.isSaving = false
                self.handleSaveError("Error al procesar el recuerdo: \(error.localizedDescription)")
            }
        }
    }
    
    private func handleSaveError(_ message: String) {
        DispatchQueue.main.async {
            self.isSaving = false
            self.errorMessage = message
            self.showingError = true
        }
    }
}

// MARK: - Video Transferable

struct VideoTransferable: Transferable {
    let url: URL
    
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { video in
            SentTransferredFile(video.url)
        } importing: { received in
            let copy = URL.documentsDirectory.appending(path: "\(UUID().uuidString).mov")
            try FileManager.default.copyItem(at: received.file, to: copy)
            return Self(url: copy)
        }
    }
}

#Preview {
    AddMemoryView()
        .environmentObject(CoupleManager())
        .environmentObject(UserManager())
}
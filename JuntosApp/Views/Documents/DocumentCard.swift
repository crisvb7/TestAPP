//
//  DocumentCard.swift
//  JuntosApp
//
//  Created by JuntosApp Team on 2024.
//

import SwiftUI
import FirebaseAuth

struct DocumentCard: View {
    let document: Document
    let onDelete: () -> Void
    
    @State private var showingDeleteAlert = false
    @State private var showingDocumentViewer = false
    @State private var showingShareSheet = false
    
    @EnvironmentObject var userManager: UserManager
    
    private var uploaderName: String {
        if let currentUser = Auth.auth().currentUser,
           document.uploadedBy == currentUser.uid {
            return "Tú"
        } else {
            return userManager.partnerProfile?.name ?? "Pareja"
        }
    }
    
    private var fileSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: document.fileSize)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header con tipo de archivo
            HStack {
                // Icono del tipo de archivo
                Image(systemName: document.type.icon)
                    .font(.title2)
                    .foregroundColor(Color(hex: document.folder.color))
                
                Spacer()
                
                // Menú de opciones
                Menu {
                    Button("Ver") {
                        showingDocumentViewer = true
                    }
                    
                    Button("Compartir") {
                        showingShareSheet = true
                    }
                    
                    Divider()
                    
                    Button("Eliminar", role: .destructive) {
                        showingDeleteAlert = true
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(8)
                }
            }
            .padding(.horizontal, 15)
            .padding(.top, 15)
            
            // Contenido principal
            VStack(spacing: 8) {
                // Nombre del archivo
                Text(document.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
                
                // Descripción si existe
                if let description = document.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
                
                // Información adicional
                VStack(spacing: 4) {
                    // Carpeta
                    HStack(spacing: 4) {
                        Image(systemName: document.folder.icon)
                            .font(.caption2)
                        Text(document.folder.displayName)
                            .font(.caption2)
                    }
                    .foregroundColor(.secondary)
                    
                    // Tamaño del archivo
                    Text(fileSize)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 10)
            
            Spacer()
            
            // Footer con información de subida
            VStack(spacing: 4) {
                Divider()
                
                HStack {
                    Text("Por \(uploaderName)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(document.uploadedAt.timeAgoDisplay)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 15)
                .padding(.vertical, 8)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
        .onTapGesture {
            showingDocumentViewer = true
        }
        .sheet(isPresented: $showingDocumentViewer) {
            DocumentViewer(document: document)
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: [URL(string: document.url)!])
        }
        .alert("Eliminar Documento", isPresented: $showingDeleteAlert) {
            Button("Cancelar", role: .cancel) { }
            Button("Eliminar", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("¿Estás seguro de que quieres eliminar \"\(document.name)\"? Esta acción no se puede deshacer.")
        }
    }
}

// MARK: - Document Viewer

struct DocumentViewer: View {
    let document: Document
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if document.type == .image {
                    // Visor de imágenes
                    AsyncImage(url: URL(string: document.url)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    // Visor web para otros tipos de archivo
                    WebView(url: URL(string: document.url)!)
                }
            }
            .navigationTitle(document.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cerrar") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    ShareLink(item: URL(string: document.url)!) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
    }
}

// MARK: - Web View

import WebKit

struct WebView: UIViewRepresentable {
    let url: URL
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.load(URLRequest(url: url))
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        // No need to update
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiView: UIActivityViewController, context: Context) {
        // No need to update
    }
}

// MARK: - Document Picker

struct DocumentPicker: UIViewControllerRepresentable {
    let onDocumentPicked: (URL) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [
            .pdf,
            .plainText,
            .rtf,
            .image,
            .jpeg,
            .png,
            .item // Para otros tipos de archivo
        ])
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }
    
    func updateUIViewController(_ uiView: UIDocumentPickerViewController, context: Context) {
        // No need to update
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            parent.onDocumentPicked(url)
        }
    }
}

// MARK: - Image Picker

import UIKit

struct ImagePicker: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    let onImagePicked: (UIImage) -> Void
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiView: UIImagePickerController, context: Context) {
        // No need to update
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImagePicked(image)
            }
            picker.dismiss(animated: true)
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - Extensions

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

extension Date {
    var timeAgoDisplay: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

#Preview {
    DocumentCard(
        document: Document(
            name: "Contrato de Alquiler.pdf",
            type: .pdf,
            folder: .contracts,
            url: "https://example.com/document.pdf",
            uploadedBy: "user123",
            uploadedAt: Date(),
            fileSize: 1024000
        )
    ) {
        print("Delete tapped")
    }
    .environmentObject(UserManager())
    .padding()
}
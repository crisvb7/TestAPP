//
//  ChatView.swift
//  JuntosApp
//
//  Created by JuntosApp Team on 2024.
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct ChatView: View {
    @Environment(\.dismiss) private var dismiss
    
    @EnvironmentObject var coupleManager: CoupleManager
    @EnvironmentObject var userManager: UserManager
    
    @State private var messages: [ChatMessage] = []
    @State private var newMessage = ""
    @State private var isLoading = true
    @State private var listener: ListenerRegistration?
    
    private let db = Firestore.firestore()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Messages List
                if isLoading {
                    loadingView
                } else if messages.isEmpty {
                    emptyStateView
                } else {
                    messagesList
                }
                
                // Message Input
                messageInputView
            }
            .navigationTitle("Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cerrar") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            setupMessageListener()
        }
        .onDisappear {
            listener?.remove()
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Cargando mensajes...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "message.circle")
                .font(.system(size: 60))
                .foregroundColor(Color("PrimaryColor").opacity(0.6))
            
            VStack(spacing: 8) {
                Text("¡Empiecen a chatear!")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Envíense mensajes rápidos y notas importantes")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Messages List
    
    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(messages) { message in
                        MessageBubble(
                            message: message,
                            isCurrentUser: message.senderId == Auth.auth().currentUser?.uid,
                            senderName: getSenderName(for: message.senderId),
                            senderColor: getSenderColor(for: message.senderId)
                        )
                        .id(message.id)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .onChange(of: messages.count) { _ in
                if let lastMessage = messages.last {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }
    
    // MARK: - Message Input
    
    private var messageInputView: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(spacing: 12) {
                // Text Input
                TextField("Escribe un mensaje...", text: $newMessage, axis: .vertical)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(.systemGray6))
                    )
                    .lineLimit(1...4)
                
                // Send Button
                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(newMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : Color("PrimaryColor"))
                }
                .disabled(newMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
        }
    }
    
    // MARK: - Helper Methods
    
    private func setupMessageListener() {
        guard let coupleId = coupleManager.coupleData?.id else {
            isLoading = false
            return
        }
        
        listener = db.collection("couples")
            .document(coupleId)
            .collection("messages")
            .order(by: "timestamp", descending: false)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("Error listening to messages: \(error)")
                    self.isLoading = false
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    self.isLoading = false
                    return
                }
                
                self.messages = documents.compactMap { document in
                    try? document.data(as: ChatMessage.self)
                }
                
                self.isLoading = false
            }
    }
    
    private func sendMessage() {
        guard let coupleId = coupleManager.coupleData?.id,
              let currentUser = Auth.auth().currentUser,
              !newMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        let message = ChatMessage(
            id: UUID().uuidString,
            senderId: currentUser.uid,
            content: newMessage.trimmingCharacters(in: .whitespacesAndNewlines),
            timestamp: Date(),
            isRead: false
        )
        
        do {
            try db.collection("couples")
                .document(coupleId)
                .collection("messages")
                .document(message.id)
                .setData(from: message)
            
            newMessage = ""
        } catch {
            print("Error sending message: \(error)")
        }
    }
    
    private func getSenderName(for senderId: String) -> String {
        if senderId == userManager.currentUser?.id {
            return "Tú"
        } else if let coupleData = coupleManager.coupleData,
                  let partnerId = coupleData.members.first(where: { $0 != userManager.currentUser?.id }) {
            // In a real app, you'd fetch the partner's name from the database
            return "Tu pareja"
        }
        return "Usuario"
    }
    
    private func getSenderColor(for senderId: String) -> String {
        if senderId == userManager.currentUser?.id {
            return userManager.currentUser?.color ?? "PrimaryColor"
        } else {
            // In a real app, you'd fetch the partner's color from the database
            return "blue"
        }
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: ChatMessage
    let isCurrentUser: Bool
    let senderName: String
    let senderColor: String
    
    var body: some View {
        HStack {
            if isCurrentUser {
                Spacer(minLength: 60)
            }
            
            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
                // Sender name (only for partner's messages)
                if !isCurrentUser {
                    Text(senderName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                }
                
                // Message content
                Text(message.content)
                    .font(.body)
                    .foregroundColor(isCurrentUser ? .white : .primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(isCurrentUser ? Color(senderColor) : Color(.systemGray5))
                    )
                
                // Timestamp
                Text(formatTimestamp(message.timestamp))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
            }
            
            if !isCurrentUser {
                Spacer(minLength: 60)
            }
        }
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        
        if calendar.isDateInToday(date) {
            formatter.timeStyle = .short
            return formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            return "Ayer"
        } else {
            formatter.dateStyle = .short
            return formatter.string(from: date)
        }
    }
}

// MARK: - Quick Messages

struct QuickMessageView: View {
    let onMessageSelected: (String) -> Void
    
    private let quickMessages = [
        "👋 ¡Hola!",
        "❤️ Te amo",
        "🏠 Ya llegué a casa",
        "🛒 ¿Necesitas algo del super?",
        "🍕 ¿Pedimos comida?",
        "😴 Buenas noches",
        "☕ ¿Café?",
        "🚗 Saliendo ahora"
    ]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(quickMessages, id: \.self) { message in
                    Button {
                        onMessageSelected(message)
                    } label: {
                        Text(message)
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color(.systemGray6))
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

#Preview {
    ChatView()
        .environmentObject(CoupleManager())
        .environmentObject(UserManager())
}
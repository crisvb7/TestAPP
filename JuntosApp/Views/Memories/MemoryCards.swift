//
//  MemoryCards.swift
//  JuntosApp
//
//  Created by JuntosApp Team on 2024.
//

import SwiftUI
import FirebaseAuth

// MARK: - Memory Grid Card

struct MemoryGridCard: View {
    let memory: Memory
    let onTap: () -> Void
    
    @EnvironmentObject var coupleManager: CoupleManager
    
    private var creatorName: String {
        if let currentUser = Auth.auth().currentUser, memory.createdBy == currentUser.uid {
            return "Yo"
        } else if let coupleData = coupleManager.coupleData {
            if memory.createdBy == coupleData.user1Id {
                return coupleData.user1Name
            } else if memory.createdBy == coupleData.user2Id {
                return coupleData.user2Name
            }
        }
        return "Usuario"
    }
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemBackground))
                    .aspectRatio(1, contentMode: .fit)
                
                // Content based on media type
                switch memory.mediaType {
                case .image:
                    imageContent
                case .video:
                    videoContent
                case .note:
                    noteContent
                }
                
                // Overlay with info
                VStack {
                    Spacer()
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            if let title = memory.title {
                                Text(title)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                            }
                            
                            Text(formatDate(memory.createdAt))
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        
                        Spacer()
                        
                        // Creator indicator
                        Text(creatorName.prefix(1))
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(width: 16, height: 16)
                            .background(
                                Circle()
                                    .fill(Color("PrimaryColor"))
                            )
                    }
                    .padding(8)
                    .background(
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.6)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    @ViewBuilder
    private var imageContent: some View {
        if let mediaURL = memory.mediaURL {
            AsyncImage(url: URL(string: mediaURL)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .overlay(
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    )
            }
        } else {
            Rectangle()
                .fill(Color(.systemGray5))
                .overlay(
                    Image(systemName: "photo")
                        .font(.title2)
                        .foregroundColor(.secondary)
                )
        }
    }
    
    @ViewBuilder
    private var videoContent: some View {
        ZStack {
            if let thumbnailURL = memory.thumbnailURL {
                AsyncImage(url: URL(string: thumbnailURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .overlay(
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        )
                }
            } else {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .overlay(
                        Image(systemName: "video")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    )
            }
            
            // Play button overlay
            Circle()
                .fill(.black.opacity(0.6))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "play.fill")
                        .font(.title3)
                        .foregroundColor(.white)
                        .offset(x: 2)
                )
        }
    }
    
    @ViewBuilder
    private var noteContent: some View {
        VStack(spacing: 8) {
            Image(systemName: "note.text")
                .font(.title)
                .foregroundColor(Color("PrimaryColor"))
            
            if let title = memory.title {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            
            if let description = memory.description {
                Text(description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
        .padding(8)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        
        if calendar.isToday(date) {
            return "Hoy"
        } else if calendar.isDate(date, equalTo: Date().addingTimeInterval(-86400), toGranularity: .day) {
            return "Ayer"
        } else if calendar.dateInterval(of: .weekOfYear, for: Date())?.contains(date) == true {
            formatter.dateFormat = "EEEE"
            return formatter.string(from: date)
        } else {
            formatter.dateStyle = .short
            return formatter.string(from: date)
        }
    }
}

// MARK: - Memory Timeline Card

struct MemoryTimelineCard: View {
    let memory: Memory
    let onTap: () -> Void
    
    @EnvironmentObject var coupleManager: CoupleManager
    
    private var creatorName: String {
        if let currentUser = Auth.auth().currentUser, memory.createdBy == currentUser.uid {
            return "Yo"
        } else if let coupleData = coupleManager.coupleData {
            if memory.createdBy == coupleData.user1Id {
                return coupleData.user1Name
            } else if memory.createdBy == coupleData.user2Id {
                return coupleData.user2Name
            }
        }
        return "Usuario"
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Media preview
                mediaPreview
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    // Title
                    if let title = memory.title {
                        Text(title)
                            .font(.headline)
                            .fontWeight(.medium)
                            .lineLimit(1)
                    }
                    
                    // Description
                    if let description = memory.description {
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    Spacer()
                    
                    // Metadata
                    HStack {
                        HStack(spacing: 4) {
                            Image(systemName: "person.circle")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(creatorName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Text(formatTimelineDate(memory.createdAt))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Media type indicator
                Image(systemName: mediaTypeIcon)
                    .font(.title3)
                    .foregroundColor(Color("PrimaryColor"))
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
            )
            .padding(.horizontal)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    @ViewBuilder
    private var mediaPreview: some View {
        switch memory.mediaType {
        case .image:
            if let mediaURL = memory.mediaURL {
                AsyncImage(url: URL(string: mediaURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .overlay(
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        )
                }
            } else {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.secondary)
                    )
            }
            
        case .video:
            ZStack {
                if let thumbnailURL = memory.thumbnailURL {
                    AsyncImage(url: URL(string: thumbnailURL)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .overlay(
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            )
                    }
                } else {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .overlay(
                            Image(systemName: "video")
                                .foregroundColor(.secondary)
                        )
                }
                
                Circle()
                    .fill(.black.opacity(0.6))
                    .frame(width: 24, height: 24)
                    .overlay(
                        Image(systemName: "play.fill")
                            .font(.caption)
                            .foregroundColor(.white)
                            .offset(x: 1)
                    )
            }
            
        case .note:
            Rectangle()
                .fill(Color("PrimaryColor").opacity(0.1))
                .overlay(
                    Image(systemName: "note.text")
                        .font(.title2)
                        .foregroundColor(Color("PrimaryColor"))
                )
        }
    }
    
    private var mediaTypeIcon: String {
        switch memory.mediaType {
        case .image:
            return "photo"
        case .video:
            return "video"
        case .note:
            return "note.text"
        }
    }
    
    private func formatTimelineDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        
        if calendar.isToday(date) {
            formatter.timeStyle = .short
            return "Hoy, \(formatter.string(from: date))"
        } else if calendar.isDate(date, equalTo: Date().addingTimeInterval(-86400), toGranularity: .day) {
            formatter.timeStyle = .short
            return "Ayer, \(formatter.string(from: date))"
        } else if calendar.dateInterval(of: .weekOfYear, for: Date())?.contains(date) == true {
            formatter.dateFormat = "EEEE"
            let dayName = formatter.string(from: date)
            formatter.timeStyle = .short
            return "\(dayName), \(formatter.string(from: date))"
        } else {
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        MemoryGridCard(memory: Memory(
            id: "1",
            title: "Nuestra primera cita",
            description: "Un día increíble en el parque",
            mediaType: .image,
            mediaURL: nil,
            thumbnailURL: nil,
            createdBy: "user1",
            createdAt: Date()
        )) {
            // Action
        }
        .frame(width: 120, height: 120)
        
        MemoryTimelineCard(memory: Memory(
            id: "2",
            title: "Video de nuestro viaje",
            description: "Recuerdos de las vacaciones en la playa",
            mediaType: .video,
            mediaURL: nil,
            thumbnailURL: nil,
            createdBy: "user2",
            createdAt: Date()
        )) {
            // Action
        }
    }
    .environmentObject(CoupleManager())
    .padding()
}
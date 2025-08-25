//
//  DataModels.swift
//  JuntosApp
//
//  Created by JuntosApp Team on 2024.
//

import Foundation
import FirebaseFirestoreSwift

// MARK: - User Profile
struct UserProfile: Codable, Identifiable {
    @DocumentID var id: String?
    var name: String
    var email: String
    var profileImageURL: String?
    var identityColor: String // Hex color code
    var coupleId: String?
    var createdAt: Date
    var lastActive: Date
    
    init(name: String, email: String, identityColor: String) {
        self.name = name
        self.email = email
        self.identityColor = identityColor
        self.createdAt = Date()
        self.lastActive = Date()
    }
}

// MARK: - Couple Data
struct CoupleData: Codable, Identifiable {
    @DocumentID var id: String?
    var user1Id: String
    var user2Id: String
    var createdAt: Date
    var inviteCode: String
    var relationshipStartDate: Date?
    var anniversaryDate: Date?
    
    init(id: String, user1Id: String, user2Id: String, createdAt: Date, inviteCode: String) {
        self.id = id
        self.user1Id = user1Id
        self.user2Id = user2Id
        self.createdAt = createdAt
        self.inviteCode = inviteCode
    }
}

// MARK: - Shopping List
struct ShoppingItem: Codable, Identifiable {
    @DocumentID var id: String?
    var name: String
    var category: ShoppingCategory
    var isCompleted: Bool
    var isFavorite: Bool
    var addedBy: String // User ID
    var completedBy: String? // User ID
    var createdAt: Date
    var completedAt: Date?
    var coupleId: String
    
    init(name: String, category: ShoppingCategory, addedBy: String, coupleId: String) {
        self.name = name
        self.category = category
        self.isCompleted = false
        self.isFavorite = false
        self.addedBy = addedBy
        self.createdAt = Date()
        self.coupleId = coupleId
    }
}

enum ShoppingCategory: String, CaseIterable, Codable {
    case food = "Comida"
    case cleaning = "Limpieza"
    case hygiene = "Higiene"
    case household = "Hogar"
    case clothing = "Ropa"
    case electronics = "Electrónicos"
    case other = "Otros"
    
    var icon: String {
        switch self {
        case .food: return "🍎"
        case .cleaning: return "🧽"
        case .hygiene: return "🧴"
        case .household: return "🏠"
        case .clothing: return "👕"
        case .electronics: return "📱"
        case .other: return "📦"
        }
    }
}

// MARK: - Expenses
struct Expense: Codable, Identifiable {
    @DocumentID var id: String?
    var description: String
    var amount: Double
    var date: Date
    var category: ExpenseCategory
    var paidBy: String // User ID
    var isShared: Bool
    var coupleId: String
    var createdAt: Date
    
    init(description: String, amount: Double, category: ExpenseCategory, paidBy: String, isShared: Bool, coupleId: String) {
        self.description = description
        self.amount = amount
        self.date = Date()
        self.category = category
        self.paidBy = paidBy
        self.isShared = isShared
        self.coupleId = coupleId
        self.createdAt = Date()
    }
}

enum ExpenseCategory: String, CaseIterable, Codable {
    case food = "Alimentación"
    case entertainment = "Ocio"
    case bills = "Facturas"
    case transport = "Transporte"
    case health = "Salud"
    case shopping = "Compras"
    case home = "Hogar"
    case other = "Otros"
    
    var icon: String {
        switch self {
        case .food: return "🍽️"
        case .entertainment: return "🎬"
        case .bills: return "📄"
        case .transport: return "🚗"
        case .health: return "🏥"
        case .shopping: return "🛍️"
        case .home: return "🏠"
        case .other: return "💰"
        }
    }
    
    var color: String {
        switch self {
        case .food: return "#FF6B6B"
        case .entertainment: return "#4ECDC4"
        case .bills: return "#45B7D1"
        case .transport: return "#96CEB4"
        case .health: return "#FFEAA7"
        case .shopping: return "#DDA0DD"
        case .home: return "#98D8C8"
        case .other: return "#F7DC6F"
        }
    }
}

// MARK: - Documents
struct Document: Codable, Identifiable {
    @DocumentID var id: String?
    var name: String
    var type: DocumentType
    var fileURL: String
    var folder: DocumentFolder
    var uploadedBy: String // User ID
    var coupleId: String
    var createdAt: Date
    var fileSize: Int64
    var mimeType: String
    
    init(name: String, type: DocumentType, fileURL: String, folder: DocumentFolder, uploadedBy: String, coupleId: String, fileSize: Int64, mimeType: String) {
        self.name = name
        self.type = type
        self.fileURL = fileURL
        self.folder = folder
        self.uploadedBy = uploadedBy
        self.coupleId = coupleId
        self.createdAt = Date()
        self.fileSize = fileSize
        self.mimeType = mimeType
    }
}

enum DocumentType: String, CaseIterable, Codable {
    case pdf = "PDF"
    case image = "Imagen"
    case text = "Texto"
    case other = "Otro"
}

enum DocumentFolder: String, CaseIterable, Codable {
    case contracts = "Contratos"
    case bills = "Facturas"
    case medical = "Recetas Médicas"
    case insurance = "Seguros"
    case important = "Importantes"
    case other = "Otros"
    
    var icon: String {
        switch self {
        case .contracts: return "📋"
        case .bills: return "🧾"
        case .medical: return "💊"
        case .insurance: return "🛡️"
        case .important: return "⭐"
        case .other: return "📁"
        }
    }
}

// MARK: - Calendar Events
struct CalendarEvent: Codable, Identifiable {
    @DocumentID var id: String?
    var title: String
    var description: String?
    var date: Date
    var location: String?
    var isRecurring: Bool
    var recurringType: RecurringType?
    var createdBy: String // User ID
    var coupleId: String
    var createdAt: Date
    var reminderMinutes: Int // Minutes before event
    
    init(title: String, description: String?, date: Date, location: String?, isRecurring: Bool, recurringType: RecurringType?, createdBy: String, coupleId: String, reminderMinutes: Int = 15) {
        self.title = title
        self.description = description
        self.date = date
        self.location = location
        self.isRecurring = isRecurring
        self.recurringType = recurringType
        self.createdBy = createdBy
        self.coupleId = coupleId
        self.createdAt = Date()
        self.reminderMinutes = reminderMinutes
    }
}

enum RecurringType: String, CaseIterable, Codable {
    case daily = "Diario"
    case weekly = "Semanal"
    case monthly = "Mensual"
    case yearly = "Anual"
}

// MARK: - Household Tasks
struct HouseholdTask: Codable, Identifiable {
    @DocumentID var id: String?
    var title: String
    var description: String?
    var priority: TaskPriority
    var dueDate: Date?
    var assignedTo: String? // User ID, nil means "tarea libre"
    var isCompleted: Bool
    var completedBy: String? // User ID
    var completedAt: Date?
    var isRecurring: Bool
    var recurringType: RecurringType?
    var createdBy: String // User ID
    var coupleId: String
    var createdAt: Date
    
    init(title: String, description: String?, priority: TaskPriority, dueDate: Date?, assignedTo: String?, isRecurring: Bool, recurringType: RecurringType?, createdBy: String, coupleId: String) {
        self.title = title
        self.description = description
        self.priority = priority
        self.dueDate = dueDate
        self.assignedTo = assignedTo
        self.isCompleted = false
        self.isRecurring = isRecurring
        self.recurringType = recurringType
        self.createdBy = createdBy
        self.coupleId = coupleId
        self.createdAt = Date()
    }
}

enum TaskPriority: String, CaseIterable, Codable {
    case low = "Baja"
    case medium = "Media"
    case high = "Alta"
    
    var color: String {
        switch self {
        case .low: return "#4CAF50"
        case .medium: return "#FF9800"
        case .high: return "#F44336"
        }
    }
}

// MARK: - Memories
struct Memory: Codable, Identifiable {
    @DocumentID var id: String?
    var title: String?
    var description: String?
    var mediaURL: String
    var mediaType: MediaType
    var uploadedBy: String // User ID
    var coupleId: String
    var createdAt: Date
    var tags: [String]
    
    init(title: String?, description: String?, mediaURL: String, mediaType: MediaType, uploadedBy: String, coupleId: String, tags: [String] = []) {
        self.title = title
        self.description = description
        self.mediaURL = mediaURL
        self.mediaType = mediaType
        self.uploadedBy = uploadedBy
        self.coupleId = coupleId
        self.createdAt = Date()
        self.tags = tags
    }
}

enum MediaType: String, CaseIterable, Codable {
    case photo = "Foto"
    case video = "Video"
}

// MARK: - Chat Messages
struct ChatMessage: Codable, Identifiable {
    @DocumentID var id: String?
    var content: String
    var senderId: String // User ID
    var coupleId: String
    var createdAt: Date
    var isRead: Bool
    
    init(content: String, senderId: String, coupleId: String) {
        self.content = content
        self.senderId = senderId
        self.coupleId = coupleId
        self.createdAt = Date()
        self.isRead = false
    }
}

// MARK: - Savings Goals
struct SavingsGoal: Codable, Identifiable {
    @DocumentID var id: String?
    var title: String
    var description: String?
    var targetAmount: Double
    var currentAmount: Double
    var targetDate: Date
    var createdBy: String // User ID
    var coupleId: String
    var createdAt: Date
    var isCompleted: Bool
    
    init(title: String, description: String?, targetAmount: Double, targetDate: Date, createdBy: String, coupleId: String) {
        self.title = title
        self.description = description
        self.targetAmount = targetAmount
        self.currentAmount = 0.0
        self.targetDate = targetDate
        self.createdBy = createdBy
        self.coupleId = coupleId
        self.createdAt = Date()
        self.isCompleted = false
    }
    
    var progress: Double {
        return targetAmount > 0 ? currentAmount / targetAmount : 0
    }
}
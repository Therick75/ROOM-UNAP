import Foundation
import SwiftUI

enum UserRole: String, Codable, CaseIterable, Identifiable {
    case estudiante
    case arrendador
    case superAdmin = "super_admin"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .estudiante:
            return "Estudiante"
        case .arrendador:
            return "Arrendador"
        case .superAdmin:
            return "Super admin"
        }
    }

    var canAccessAdminDashboard: Bool {
        self == .arrendador || self == .superAdmin
    }

    var canEditListings: Bool {
        canAccessAdminDashboard
    }

    var canManageUserRoles: Bool {
        self == .superAdmin
    }

    var availableRoleOptions: [UserRole] {
        switch self {
        case .superAdmin:
            return [.estudiante, .arrendador, .superAdmin]
        case .arrendador:
            return [.estudiante]
        case .estudiante:
            return [.estudiante]
        }
    }
}

enum InterfaceTone: String, CaseIterable, Identifiable {
    case black
    case white

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .black:
            return "Negro"
        case .white:
            return "Blanco"
        }
    }

    var tintColor: Color {
        switch self {
        case .black:
            return .black
        case .white:
            return .white
        }
    }
}

enum InteractionAccent: String, CaseIterable, Identifiable {
    case blue
    case teal
    case emerald
    case orange
    case rose

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .blue:
            return "Azul"
        case .teal:
            return "Verde azulado"
        case .emerald:
            return "Verde"
        case .orange:
            return "Naranja"
        case .rose:
            return "Rosa"
        }
    }

    var tintColor: Color {
        switch self {
        case .blue:
            return Color(red: 0.20, green: 0.58, blue: 0.86)
        case .teal:
            return Color(red: 0.18, green: 0.67, blue: 0.72)
        case .emerald:
            return Color(red: 0.18, green: 0.72, blue: 0.40)
        case .orange:
            return Color(red: 0.96, green: 0.58, blue: 0.18)
        case .rose:
            return Color(red: 0.90, green: 0.34, blue: 0.49)
        }
    }
}

struct AppUser: Codable, Identifiable, Equatable {
    let id: String
    let email: String
    let fullName: String
    let phone: String?
    let avatarUrl: String?
    let bio: String?
    let role: UserRole
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case fullName = "full_name"
        case phone
        case avatarUrl = "avatar_url"
        case bio
        case role
        case createdAt = "created_at"
    }

    var initials: String {
        fullName
            .split(separator: " ")
            .prefix(2)
            .map { String($0.prefix(1)) }
            .joined()
            .uppercased()
    }
}

struct AppUserInsert: Encodable {
    let id: String
    let email: String
    let fullName: String
    let phone: String?
    let avatarUrl: String?
    let bio: String?
    let role: UserRole

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case fullName = "full_name"
        case phone
        case avatarUrl = "avatar_url"
        case bio
        case role
    }
}

struct AppUserUpdate: Encodable {
    let fullName: String
    let phone: String?
    let avatarUrl: String?
    let bio: String?

    enum CodingKeys: String, CodingKey {
        case fullName = "full_name"
        case phone
        case avatarUrl = "avatar_url"
        case bio
    }
}

struct AppUserRoleUpdate: Encodable {
    let role: UserRole
}

struct ListingFeatures: Codable, Equatable {
    var hasWifi: Bool
    var hasPrivateBathroom: Bool
    var hasSecurityCameras: Bool
    var isSharedBed: Bool
    var hasKitchen: Bool
    var hasWashingMachine: Bool
    var imageUrls: [String]
    var tags: [String]

    init(
        hasWifi: Bool = false,
        hasPrivateBathroom: Bool = false,
        hasSecurityCameras: Bool = false,
        isSharedBed: Bool = false,
        hasKitchen: Bool = false,
        hasWashingMachine: Bool = false,
        imageUrls: [String] = [],
        tags: [String] = []
    ) {
        self.hasWifi = hasWifi
        self.hasPrivateBathroom = hasPrivateBathroom
        self.hasSecurityCameras = hasSecurityCameras
        self.isSharedBed = isSharedBed
        self.hasKitchen = hasKitchen
        self.hasWashingMachine = hasWashingMachine
        self.imageUrls = imageUrls
        self.tags = tags
    }

    enum CodingKeys: String, CodingKey {
        case hasWifi = "has_wifi"
        case hasPrivateBathroom = "has_private_bathroom"
        case hasSecurityCameras = "has_security_cameras"
        case isSharedBed = "is_shared_bed"
        case hasKitchen = "has_kitchen"
        case hasWashingMachine = "has_washing_machine"
        case imageUrls = "image_urls"
        case tags
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        hasWifi = try container.decodeIfPresent(Bool.self, forKey: .hasWifi) ?? false
        hasPrivateBathroom = try container.decodeIfPresent(Bool.self, forKey: .hasPrivateBathroom) ?? false
        hasSecurityCameras = try container.decodeIfPresent(Bool.self, forKey: .hasSecurityCameras) ?? false
        isSharedBed = try container.decodeIfPresent(Bool.self, forKey: .isSharedBed) ?? false
        hasKitchen = try container.decodeIfPresent(Bool.self, forKey: .hasKitchen) ?? false
        hasWashingMachine = try container.decodeIfPresent(Bool.self, forKey: .hasWashingMachine) ?? false
        imageUrls = try container.decodeIfPresent([String].self, forKey: .imageUrls) ?? []
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
    }

    var enabledAmenities: [Amenity] {
        var items: [Amenity] = []
        if hasWifi { items.append(.init(title: "WiFi", symbol: "wifi")) }
        if hasPrivateBathroom { items.append(.init(title: "Bano privado", symbol: "shower")) }
        if hasSecurityCameras { items.append(.init(title: "Seguridad", symbol: "camera.viewfinder")) }
        if isSharedBed { items.append(.init(title: "Cama compartida", symbol: "bed.double")) }
        if hasKitchen { items.append(.init(title: "Cocina", symbol: "fork.knife")) }
        if hasWashingMachine { items.append(.init(title: "Lavadora", symbol: "washer")) }
        return items
    }
}

struct Amenity: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let symbol: String
}

enum ListingStatus: String, Codable {
    case active
    case inactive
    case rented
}

struct Listing: Codable, Identifiable, Equatable {
    let id: String
    let ownerId: String
    let title: String
    let description: String?
    let price: Double
    let zone: String
    let imageUrl: String?
    let status: ListingStatus
    let isVerified: Bool
    let isNew: Bool
    let features: ListingFeatures
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case ownerId = "owner_id"
        case title
        case description
        case price
        case zone
        case imageUrl = "image_url"
        case status
        case isVerified = "is_verified"
        case isNew = "is_new"
        case features
        case createdAt = "created_at"
    }
}

extension ListingStatus {
    var displayName: String {
        switch self {
        case .active:
            return "Disponible"
        case .inactive:
            return "Oculto"
        case .rented:
            return "Rentado"
        }
    }

    var symbol: String {
        switch self {
        case .active:
            return "checkmark.circle.fill"
        case .inactive:
            return "eye.slash.fill"
        case .rented:
            return "key.fill"
        }
    }
}

extension Listing {
    var imageUrls: [String] {
        if !features.imageUrls.isEmpty {
            return features.imageUrls
        }

        if let imageUrl {
            return [imageUrl]
        }

        return []
    }

    var coverImageUrl: String? {
        imageUrls.first
    }

    var galleryCount: Int {
        imageUrls.count
    }

    var searchText: String {
        [
            title,
            zone,
            description ?? "",
            features.tags.joined(separator: " "),
            features.enabledAmenities.map(\.title).joined(separator: " ")
        ]
        .joined(separator: " ")
        .lowercased()
    }

    var priceText: String {
        String(format: "S/ %.0f / mes", price)
    }

    var isAvailable: Bool {
        status == .active
    }
}

struct ListingImage: Codable, Identifiable, Equatable {
    let id: String
    let listingId: String
    let url: String
    let position: Int
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case listingId = "listing_id"
        case url
        case position
        case createdAt = "created_at"
    }
}

struct ListingInsert: Encodable {
    let ownerId: String
    let title: String
    let description: String?
    let price: Double
    let zone: String
    let imageUrl: String?
    let status: ListingStatus
    let isVerified: Bool
    let isNew: Bool
    let features: ListingFeatures

    enum CodingKeys: String, CodingKey {
        case ownerId = "owner_id"
        case title
        case description
        case price
        case zone
        case imageUrl = "image_url"
        case status
        case isVerified = "is_verified"
        case isNew = "is_new"
        case features
    }
}

struct ListingUpdate: Encodable {
    let title: String
    let description: String?
    let price: Double
    let zone: String
    let imageUrl: String?
    let features: ListingFeatures

    enum CodingKeys: String, CodingKey {
        case title
        case description
        case price
        case zone
        case imageUrl = "image_url"
        case features
    }
}

struct Favorite: Codable, Identifiable, Equatable {
    let id: String
    let userId: String
    let listingId: String
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case listingId = "listing_id"
        case createdAt = "created_at"
    }
}

struct FavoriteInsert: Encodable {
    let userId: String
    let listingId: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case listingId = "listing_id"
    }
}

struct FavoriteWithListing: Codable, Identifiable {
    let id: String
    let userId: String
    let listingId: String
    let createdAt: String?
    let listings: Listing

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case listingId = "listing_id"
        case createdAt = "created_at"
        case listings
    }
}

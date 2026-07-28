import Foundation

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
}

struct AppUser: Codable, Identifiable, Equatable {
    let id: String
    let email: String
    let fullName: String
    let phone: String?
    let role: UserRole
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case fullName = "full_name"
        case phone
        case role
        case createdAt = "created_at"
    }
}

struct AppUserInsert: Encodable {
    let id: String
    let email: String
    let fullName: String
    let phone: String?
    let role: UserRole

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case fullName = "full_name"
        case phone
        case role
    }
}

struct ListingFeatures: Codable, Equatable {
    var hasWifi: Bool
    var hasPrivateBathroom: Bool
    var hasSecurityCameras: Bool
    var isSharedBed: Bool
    var hasKitchen: Bool
    var hasWashingMachine: Bool
    var imageUrls: [String]

    init(
        hasWifi: Bool = false,
        hasPrivateBathroom: Bool = false,
        hasSecurityCameras: Bool = false,
        isSharedBed: Bool = false,
        hasKitchen: Bool = false,
        hasWashingMachine: Bool = false,
        imageUrls: [String] = []
    ) {
        self.hasWifi = hasWifi
        self.hasPrivateBathroom = hasPrivateBathroom
        self.hasSecurityCameras = hasSecurityCameras
        self.isSharedBed = isSharedBed
        self.hasKitchen = hasKitchen
        self.hasWashingMachine = hasWashingMachine
        self.imageUrls = imageUrls
    }

    enum CodingKeys: String, CodingKey {
        case hasWifi = "has_wifi"
        case hasPrivateBathroom = "has_private_bathroom"
        case hasSecurityCameras = "has_security_cameras"
        case isSharedBed = "is_shared_bed"
        case hasKitchen = "has_kitchen"
        case hasWashingMachine = "has_washing_machine"
        case imageUrls = "image_urls"
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

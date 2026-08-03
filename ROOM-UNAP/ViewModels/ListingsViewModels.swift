import Foundation
import Combine
import PhotosUI
import SwiftUI

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var searchText = "" {
        didSet { applyFilters() }
    }
    @Published var quickFilter: ListingQuickFilter = .all {
        didSet { applyFilters() }
    }
    @Published var sortOption: ListingSortOption = .recent {
        didSet { applyFilters() }
    }
    @Published private(set) var listings: [Listing] = []
    @Published private(set) var favoriteIds: Set<String> = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service: RoomUnapService
    private var allListings: [Listing] = []

    init(service: RoomUnapService = RoomUnapService()) {
        self.service = service
    }

    func load(userId: String?) async {
        isLoading = true
        errorMessage = nil

        do {
            async let listings = service.fetchActiveListings()
            if let userId {
                async let favoriteIds = service.favoriteIds(userId: userId)
                allListings = try await listings
                applyFilters()
                self.favoriteIds = try await favoriteIds
            } else {
                allListings = try await listings
                applyFilters()
                self.favoriteIds = []
            }
        } catch {
            errorMessage = error.localizedDescription
            Haptics.error()
        }

        isLoading = false
    }

    func replaceListing(_ updatedListing: Listing) {
        guard let index = allListings.firstIndex(where: { $0.id == updatedListing.id }) else { return }
        allListings[index] = updatedListing
        applyFilters()
    }

    func removeListing(id: String) {
        allListings.removeAll { $0.id == id }
        applyFilters()
    }

    func toggleFavorite(listing: Listing, userId: String?) async {
        guard let userId else {
            errorMessage = AppError.missingSession.localizedDescription
            return
        }

        do {
            if favoriteIds.contains(listing.id) {
                try await service.removeFavorite(userId: userId, listingId: listing.id)
                withAnimation { favoriteIds.remove(listing.id) }
            } else {
                try await service.addFavorite(userId: userId, listingId: listing.id)
                withAnimation { favoriteIds.insert(listing.id) }
            }
            Haptics.success()
        } catch {
            errorMessage = error.localizedDescription
            Haptics.error()
        }
    }

    func clearFilters() {
        searchText = ""
        quickFilter = .all
        sortOption = .recent
    }

    var hasActiveFilters: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || quickFilter != .all || sortOption != .recent
    }

    private func applyFilters() {
        var filtered = allListings
        let normalizedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if !normalizedQuery.isEmpty {
            filtered = filtered.filter { $0.searchText.contains(normalizedQuery) }
        }

        filtered = filtered.filter { matches(filter: quickFilter, listing: $0) }
        listings = sort(filtered)
    }

    private func matches(filter: ListingQuickFilter, listing: Listing) -> Bool {
        switch filter {
        case .all:
            return true
        case .nearby:
            return nearbyKeywords.contains { listing.searchText.contains($0) }
        case .cheap:
            return listing.price <= cheapThreshold
        case .verified:
            return listing.isVerified
        case .bathroom:
            return listing.features.hasPrivateBathroom
        case .kitchen:
            return listing.features.hasKitchen
        case .fresh:
            return listing.isNew
        }
    }

    private func sort(_ listings: [Listing]) -> [Listing] {
        switch sortOption {
        case .recent:
            return listings.sorted { lhs, rhs in
                listingDate(rhs.createdAt) < listingDate(lhs.createdAt)
            }
        case .priceLow:
            return listings.sorted { $0.price < $1.price }
        case .priceHigh:
            return listings.sorted { $0.price > $1.price }
        case .featured:
            return listings.sorted { lhs, rhs in
                let lhsScore = (lhs.isVerified ? 2 : 0) + (lhs.isNew ? 1 : 0)
                let rhsScore = (rhs.isVerified ? 2 : 0) + (rhs.isNew ? 1 : 0)
                if lhsScore == rhsScore {
                    return listingDate(rhs.createdAt) < listingDate(lhs.createdAt)
                }
                return lhsScore > rhsScore
            }
        }
    }

    private func listingDate(_ value: String?) -> Date {
        guard let value else { return .distantPast }

        if let date = Self.isoFormatter.date(from: value) {
            return date
        }

        return .distantPast
    }

    private var cheapThreshold: Double {
        let prices = allListings.map(\.price).sorted()
        guard !prices.isEmpty else { return .greatestFiniteMagnitude }
        return prices[(prices.count - 1) / 2]
    }

    private var nearbyKeywords: [String] {
        ["unap", "universidad", "campus", "centro", "cerca", "universitaria"]
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

@MainActor
final class FavoritesViewModel: ObservableObject {
    @Published private(set) var favorites: [FavoriteWithListing] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service: RoomUnapService

    init(service: RoomUnapService = RoomUnapService()) {
        self.service = service
    }

    func load(userId: String?) async {
        guard let userId else { return }
        isLoading = true
        errorMessage = nil

        do {
            favorites = try await service.fetchFavorites(userId: userId)
        } catch {
            errorMessage = error.localizedDescription
            Haptics.error()
        }

        isLoading = false
    }

    func removeFavorite(at offsets: IndexSet, userId: String?) async {
        guard let userId else { return }
        let removed = offsets.map { favorites[$0] }

        do {
            for favorite in removed {
                try await service.removeFavorite(userId: userId, listingId: favorite.listingId)
            }
            favorites.remove(atOffsets: offsets)
            Haptics.success()
        } catch {
            errorMessage = error.localizedDescription
            Haptics.error()
        }
    }
}

@MainActor
final class PublishListingViewModel: ObservableObject {
    @Published var title = ""
    @Published var description = ""
    @Published var price = ""
    @Published var zone = ""
    @Published var features = ListingFeatures()
    @Published var selectedPhotos: [PhotosUI.PhotosPickerItem] = []
    @Published var customTag = ""
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service: RoomUnapService
    private let editingListing: Listing?

    var isEditing: Bool { editingListing != nil }

    init(listing: Listing? = nil, service: RoomUnapService = RoomUnapService()) {
        self.service = service
        self.editingListing = listing

        if let listing {
            title = listing.title
            description = listing.description ?? ""
            price = listing.price.formatted(.number.precision(.fractionLength(0...2)))
            zone = listing.zone
            features = listing.features
        }
    }

    var availableTagOptions: [String] {
        ["Sala", "Cocina", "Comedor", "Baño privado", "Dormitorio", "Patio", "Lavandería", "Garaje", "Exterior"]
    }

    var selectedTagValues: [String] {
        features.tags
    }

    var currentImageUrls: [String] {
        if let editingListing {
            if !editingListing.features.imageUrls.isEmpty {
                return editingListing.features.imageUrls
            }
            if let imageUrl = editingListing.imageUrl {
                return [imageUrl]
            }
        }
        return features.imageUrls
    }

    func isSelectedTag(_ tag: String) -> Bool {
        features.tags.contains(tag)
    }

    func toggleTag(_ tag: String) {
        if let index = features.tags.firstIndex(of: tag) {
            features.tags.remove(at: index)
        } else {
            features.tags.append(tag)
        }
    }

    func addCustomTag() {
        let tag = customTag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tag.isEmpty else { return }
        guard !features.tags.contains(tag) else {
            customTag = ""
            return
        }
        features.tags.append(tag)
        customTag = ""
    }

    func save(ownerId: String?) async -> Listing? {
        guard let ownerId else {
            errorMessage = AppError.missingSession.localizedDescription
            return nil
        }

        guard let parsedPrice = Double(price.replacingOccurrences(of: ",", with: ".")) else {
            errorMessage = "Ingresa un precio valido."
            return nil
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let selectedImageData = try await loadSelectedPhotoData()
            let uploadedImageUrls = selectedImageData.isEmpty
                ? currentImageUrls
                : try await service.uploadListingImages(data: selectedImageData, ownerId: ownerId)

            let imageUrl = uploadedImageUrls.first ?? editingListing?.imageUrl
            var updatedFeatures = features

            updatedFeatures.imageUrls = uploadedImageUrls

            if let editingListing {
                let update = ListingUpdate(
                    title: title.trimmed,
                    description: description.trimmed.nilIfEmpty,
                    price: parsedPrice,
                    zone: zone.trimmed,
                    imageUrl: imageUrl,
                    features: updatedFeatures
                )
                let updatedListing = try await service.updateListing(id: editingListing.id, update: update)
                if !selectedImageData.isEmpty {
                    _ = try await service.replaceListingImages(listingId: updatedListing.id, urls: uploadedImageUrls)
                }
                Haptics.success()
                return updatedListing
            } else {
                let listing = ListingInsert(
                    ownerId: ownerId,
                    title: title.trimmed,
                    description: description.trimmed.nilIfEmpty,
                    price: parsedPrice,
                    zone: zone.trimmed,
                    imageUrl: imageUrl,
                    status: .active,
                    isVerified: false,
                    isNew: true,
                    features: updatedFeatures
                )
                let createdListing = try await service.createListing(listing)
                if !selectedImageData.isEmpty {
                    _ = try await service.replaceListingImages(listingId: createdListing.id, urls: uploadedImageUrls)
                }
                Haptics.success()
                return createdListing
            }
        } catch {
            errorMessage = error.localizedDescription
            Haptics.error()
            return nil
        }
    }

    func delete() async -> Bool {
        guard let editingListing else { return false }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await service.deleteListing(id: editingListing.id)
            Haptics.success()
            return true
        } catch {
            errorMessage = error.localizedDescription
            Haptics.error()
            return false
        }
    }

    private func loadSelectedPhotoData() async throws -> [Data] {
        guard !selectedPhotos.isEmpty else { return [] }

        var data: [Data] = []
        for item in selectedPhotos {
            guard let imageData = try await item.loadTransferable(type: Data.self) else {
                throw AppError.missingImageData
            }
            data.append(imageData)
        }
        return data
    }
}

@MainActor
final class AdminDashboardViewModel: ObservableObject {
    @Published private(set) var listings: [Listing] = []
    @Published private(set) var users: [AppUser] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service: RoomUnapService

    init(service: RoomUnapService = RoomUnapService()) {
        self.service = service
    }

    func load(ownerId: String?, shouldLoadUsers: Bool) async {
        guard let ownerId else {
            errorMessage = AppError.missingSession.localizedDescription
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            async let ownerListings = service.fetchOwnerListings(ownerId: ownerId)
            if shouldLoadUsers {
                async let allUsers = service.fetchUsers()
                listings = try await ownerListings
                users = try await allUsers
            } else {
                listings = try await ownerListings
                users = []
            }
        } catch {
            errorMessage = error.localizedDescription
            Haptics.error()
        }

        isLoading = false
    }

    func replaceListing(_ updatedListing: Listing) {
        guard let index = listings.firstIndex(where: { $0.id == updatedListing.id }) else { return }
        listings[index] = updatedListing
    }

    func addListing(_ listing: Listing) {
        listings.insert(listing, at: 0)
    }

    func removeListing(id: String) {
        listings.removeAll { $0.id == id }
    }

    func replaceUser(_ updatedUser: AppUser) {
        if let index = users.firstIndex(where: { $0.id == updatedUser.id }) {
            users[index] = updatedUser
        } else {
            users.insert(updatedUser, at: 0)
        }
    }

    func updateUserRole(userId: String, role: UserRole) async -> AppUser? {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let updatedUser = try await service.updateUserRole(userId: userId, role: role)
            replaceUser(updatedUser)
            Haptics.success()
            return updatedUser
        } catch {
            errorMessage = "No se pudo actualizar el rol: \(error.localizedDescription)"
            if error.localizedDescription == errorDescriptionFallback(for: error) {
                errorMessage = "No se pudo actualizar el rol: \(String(describing: error))"
            }
            Haptics.error()
            return nil
        }
    }

    func deleteListing(_ listing: Listing) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await service.deleteListing(id: listing.id)
            listings.removeAll { $0.id == listing.id }
            Haptics.success()
            return true
        } catch {
            errorMessage = error.localizedDescription
            Haptics.error()
            return false
        }
    }

    var activeCount: Int {
        listings.filter { $0.status == .active }.count
    }

    var verifiedCount: Int {
        listings.filter { $0.isVerified }.count
    }

    var newCount: Int {
        listings.filter { $0.isNew }.count
    }

    var rentedCount: Int {
        listings.filter { $0.status == .rented }.count
    }

    private func errorDescriptionFallback(for error: Error) -> String {
        error.localizedDescription
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

enum ListingQuickFilter: String, CaseIterable, Identifiable {
    case all
    case nearby
    case cheap
    case verified
    case bathroom
    case kitchen
    case fresh

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "Todo"
        case .nearby:
            return "Cerca"
        case .cheap:
            return "Barato"
        case .verified:
            return "Verificado"
        case .bathroom:
            return "Con baño"
        case .kitchen:
            return "Con cocina"
        case .fresh:
            return "Nuevo"
        }
    }

    var symbol: String {
        switch self {
        case .all:
            return "circle.grid.2x2.fill"
        case .nearby:
            return "location.fill"
        case .cheap:
            return "tag.fill"
        case .verified:
            return "checkmark.seal.fill"
        case .bathroom:
            return "shower.fill"
        case .kitchen:
            return "fork.knife"
        case .fresh:
            return "sparkles"
        }
    }
}

enum ListingSortOption: String, CaseIterable, Identifiable {
    case recent
    case priceLow
    case priceHigh
    case featured

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recent:
            return "Recientes"
        case .priceLow:
            return "Precio bajo"
        case .priceHigh:
            return "Precio alto"
        case .featured:
            return "Destacadas"
        }
    }
}

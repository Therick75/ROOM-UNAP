import Foundation
import Combine
import PhotosUI
import SwiftUI

@MainActor
final class HomeViewModel: ObservableObject {
    @Published private(set) var listings: [Listing] = []
    @Published private(set) var favoriteIds: Set<String> = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service: RoomUnapService

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
                self.listings = try await listings
                self.favoriteIds = try await favoriteIds
            } else {
                self.listings = try await listings
                self.favoriteIds = []
            }
        } catch {
            errorMessage = error.localizedDescription
            Haptics.error()
        }

        isLoading = false
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
    @Published var selectedPhoto: PhotosPickerItem?
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

    func save(ownerId: String?) async -> Bool {
        guard let ownerId else {
            errorMessage = AppError.missingSession.localizedDescription
            return false
        }

        guard let parsedPrice = Double(price.replacingOccurrences(of: ",", with: ".")) else {
            errorMessage = "Ingresa un precio valido."
            return false
        }

        isLoading = true
        errorMessage = nil

        do {
            var imageUrl = editingListing?.imageUrl
            var updatedFeatures = features

            if let selectedPhoto {
                guard let data = try await selectedPhoto.loadTransferable(type: Data.self) else {
                    throw AppError.missingImageData
                }
                imageUrl = try await service.uploadListingImage(data: data, ownerId: ownerId)
                if let imageUrl {
                    updatedFeatures.imageUrls = [imageUrl]
                }
            }

            if let editingListing {
                let update = ListingUpdate(
                    title: title.trimmed,
                    description: description.trimmed.nilIfEmpty,
                    price: parsedPrice,
                    zone: zone.trimmed,
                    imageUrl: imageUrl,
                    features: updatedFeatures
                )
                _ = try await service.updateListing(id: editingListing.id, update: update)
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
                _ = try await service.createListing(listing)
            }

            Haptics.success()
            isLoading = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            Haptics.error()
            isLoading = false
            return false
        }
    }

    func delete() async -> Bool {
        guard let editingListing else { return false }
        isLoading = true
        errorMessage = nil

        do {
            try await service.deleteListing(id: editingListing.id)
            Haptics.success()
            isLoading = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            Haptics.error()
            isLoading = false
            return false
        }
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

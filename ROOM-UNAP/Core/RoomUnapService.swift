import Foundation
import Supabase

struct RoomUnapService {
    private let client: SupabaseClient
    private let imageBucket = "listings_images"

    init(client: SupabaseClient = SupabaseManager.shared.client) {
        self.client = client
    }

    func fetchProfile(userId: String) async throws -> AppUser {
        try await client
            .from("users")
            .select()
            .eq("id", value: userId)
            .single()
            .execute()
            .value
    }

    func createProfile(_ profile: AppUserInsert) async throws {
        try await client
            .from("users")
            .insert(profile)
            .execute()
    }

    func fetchActiveListings() async throws -> [Listing] {
        try await client
            .from("listings")
            .select()
            .eq("status", value: ListingStatus.active.rawValue)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    func fetchOwnerListings(ownerId: String) async throws -> [Listing] {
        try await client
            .from("listings")
            .select()
            .eq("owner_id", value: ownerId)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    func fetchFavorites(userId: String) async throws -> [FavoriteWithListing] {
        try await client
            .from("favorites")
            .select("*, listings(*)")
            .eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    func favoriteIds(userId: String) async throws -> Set<String> {
        let favorites: [Favorite] = try await client
            .from("favorites")
            .select()
            .eq("user_id", value: userId)
            .execute()
            .value
        return Set(favorites.map(\.listingId))
    }

    func addFavorite(userId: String, listingId: String) async throws {
        let favorite = FavoriteInsert(userId: userId, listingId: listingId)
        try await client
            .from("favorites")
            .insert(favorite)
            .execute()
    }

    func removeFavorite(userId: String, listingId: String) async throws {
        try await client
            .from("favorites")
            .delete()
            .eq("user_id", value: userId)
            .eq("listing_id", value: listingId)
            .execute()
    }

    func createListing(_ listing: ListingInsert) async throws -> Listing {
        try await client
            .from("listings")
            .insert(listing)
            .select()
            .single()
            .execute()
            .value
    }

    func updateListing(id: String, update: ListingUpdate) async throws -> Listing {
        try await client
            .from("listings")
            .update(update)
            .eq("id", value: id)
            .select()
            .single()
            .execute()
            .value
    }

    func deleteListing(id: String) async throws {
        try await client
            .from("listings")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    func uploadListingImage(data: Data, ownerId: String) async throws -> String {
        let fileName = "\(ownerId)/\(UUID().uuidString).jpg"

        try await client.storage
            .from(imageBucket)
            .upload(
                path: fileName,
                file: data,
                options: FileOptions(
                    cacheControl: "3600",
                    contentType: "image/jpeg",
                    upsert: false
                )
            )

        return try client.storage
            .from(imageBucket)
            .getPublicURL(path: fileName)
            .absoluteString
    }
}

import Foundation
import Supabase

struct RoomUnapService {
    private let client: SupabaseClient
    private let imageBucket = "listings_images"
    private let avatarBucket = "avatars"

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

    func fetchUsers() async throws -> [AppUser] {
        try await client
            .from("users")
            .select()
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    func createProfile(_ profile: AppUserInsert) async throws {
        try await client
            .from("users")
            .insert(profile)
            .execute()
    }

    func updateProfile(userId: String, update: AppUserUpdate) async throws -> AppUser {
        try await client
            .from("users")
            .update(update)
            .eq("id", value: userId)
            .select()
            .single()
            .execute()
            .value
    }

    func updateUserRole(userId: String, role: UserRole) async throws -> AppUser {
        do {
            _ = try await client
                .from("users")
                .update(AppUserRoleUpdate(role: role))
                .eq("id", value: userId)
                .execute()
        } catch {
            _ = try await client
                .rpc(
                    "set_user_role",
                    params: [
                        "target_user_id": userId,
                        "new_role": role.rawValue
                    ]
                )
                .execute()
        }

        return try await fetchProfile(userId: userId)
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

    func fetchListingImages(listingId: String) async throws -> [ListingImage] {
        try await client
            .from("listing_images")
            .select()
            .eq("listing_id", value: listingId)
            .order("position", ascending: true)
            .order("created_at", ascending: true)
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
                fileName,
                data: data,
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

    func uploadListingImages(data: [Data], ownerId: String) async throws -> [String] {
        var urls: [String] = []

        for data in data {
            let url = try await uploadListingImage(data: data, ownerId: ownerId)
            urls.append(url)
        }

        return urls
    }

    func replaceListingImages(listingId: String, urls: [String]) async throws -> [ListingImage] {
        try await client
            .from("listing_images")
            .delete()
            .eq("listing_id", value: listingId)
            .execute()

        guard !urls.isEmpty else { return [] }

        var insertedImages: [ListingImage] = []
        for (index, url) in urls.enumerated() {
            let payload = ListingImageInsert(listingId: listingId, url: url, position: index)
            let insertedImage: ListingImage = try await client
                .from("listing_images")
                .insert(payload)
                .select()
                .single()
                .execute()
                .value
            insertedImages.append(insertedImage)
        }

        return insertedImages
    }

    func uploadAvatarImage(data: Data, userId: String) async throws -> String {
        let fileName = "\(userId)/\(UUID().uuidString).jpg"

        try await client.storage
            .from(avatarBucket)
            .upload(
                fileName,
                data: data,
                options: FileOptions(
                    cacheControl: "3600",
                    contentType: "image/jpeg",
                    upsert: false
                )
            )

        return try client.storage
            .from(avatarBucket)
            .getPublicURL(path: fileName)
            .absoluteString
    }
}

private struct ListingImageInsert: Encodable {
    let listingId: String
    let url: String
    let position: Int

    enum CodingKeys: String, CodingKey {
        case listingId = "listing_id"
        case url
        case position
    }
}

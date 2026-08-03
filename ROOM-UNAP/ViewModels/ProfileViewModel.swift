import Foundation
import Combine
import PhotosUI
import SwiftUI

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var fullName = ""
    @Published var phone = ""
    @Published var bio = ""
    @Published var avatarUrl: String?
    @Published var selectedAvatar: PhotosPickerItem?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service: RoomUnapService
    private var configuredUserId: String?

    init(service: RoomUnapService = RoomUnapService()) {
        self.service = service
    }

    func configure(with user: AppUser?, force: Bool = false) {
        guard let user else { return }
        guard force || configuredUserId != user.id else { return }

        configuredUserId = user.id
        fullName = user.fullName
        phone = user.phone ?? ""
        bio = user.bio ?? ""
        avatarUrl = user.avatarUrl
    }

    func apply(_ user: AppUser) {
        configuredUserId = user.id
        fullName = user.fullName
        phone = user.phone ?? ""
        bio = user.bio ?? ""
        avatarUrl = user.avatarUrl
    }

    func save(userId: String?) async -> AppUser? {
        guard let userId else {
            errorMessage = AppError.missingSession.localizedDescription
            return nil
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            var resolvedAvatarUrl = avatarUrl
            if let selectedAvatar {
                guard let data = try await selectedAvatar.loadTransferable(type: Data.self) else {
                    throw AppError.missingImageData
                }
                resolvedAvatarUrl = try await service.uploadAvatarImage(data: data, userId: userId)
            }

            let update = AppUserUpdate(
                fullName: fullName.trimmed,
                phone: phone.trimmed.nilIfEmpty,
                avatarUrl: resolvedAvatarUrl,
                bio: bio.trimmed.nilIfEmpty
            )

            let updatedUser = try await service.updateProfile(userId: userId, update: update)
            Haptics.success()
            apply(updatedUser)
            selectedAvatar = nil
            return updatedUser
        } catch {
            errorMessage = error.localizedDescription
            Haptics.error()
            return nil
        }
    }

    var initials: String {
        let components = fullName
            .split(separator: " ")
            .prefix(2)
            .map { String($0.prefix(1)) }
        return components.joined().uppercased()
    }

    var hasPendingAvatarChange: Bool {
        selectedAvatar != nil
    }
}

@MainActor
final class OwnerProfileViewModel: ObservableObject {
    @Published private(set) var owner: AppUser?
    @Published private(set) var listings: [Listing] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service: RoomUnapService
    private let ownerId: String

    init(ownerId: String, initialOwner: AppUser? = nil, service: RoomUnapService = RoomUnapService()) {
        self.ownerId = ownerId
        self.service = service
        self.owner = initialOwner
    }

    func load() async {
        isLoading = true
        errorMessage = nil

        do {
            if owner == nil {
                owner = try await service.fetchProfile(userId: ownerId)
            }

            listings = try await service.fetchOwnerListings(ownerId: ownerId)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
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

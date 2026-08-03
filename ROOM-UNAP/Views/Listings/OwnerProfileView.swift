import SwiftUI

struct OwnerProfileView: View {
    @StateObject private var viewModel: OwnerProfileViewModel

    init(ownerId: String, initialOwner: AppUser? = nil) {
        _viewModel = StateObject(wrappedValue: OwnerProfileViewModel(ownerId: ownerId, initialOwner: initialOwner))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color.accentColor.opacity(0.12), Color(.systemBackground), Color(.secondarySystemBackground)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 18) {
                        if viewModel.isLoading && viewModel.owner == nil {
                            OwnerProfileSkeleton()
                        } else if let owner = viewModel.owner {
                            header(for: owner)
                            statsSection(for: owner)
                            contactCard(for: owner)
                            listingsSection(for: owner)
                        } else {
                            EmptyStateView(
                                symbol: "person.crop.rectangle",
                                title: "Perfil no disponible",
                                message: "No se pudo cargar la información de este arrendador."
                            )
                            .padding(.top, 60)
                        }
                    }
                    .padding(16)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Perfil público")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .task {
                await viewModel.load()
            }
            .alert("No se pudo cargar el perfil", isPresented: errorBinding) {
                Button("OK", role: .cancel) { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "Intenta nuevamente.")
            }
        }
    }

    private func header(for owner: AppUser) -> some View {
        VStack(spacing: 16) {
            PublicAvatarView(
                avatarUrl: owner.avatarUrl,
                initials: owner.initials,
                role: owner.role
            )
            .frame(width: 118, height: 118)

            VStack(spacing: 8) {
                Text(owner.fullName)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)

                HStack(spacing: 8) {
                    Text(owner.role.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    if viewModel.listings.contains(where: { $0.isVerified }) {
                        ListingBadgeView(
                            title: "Verificado",
                            systemImage: "checkmark.seal.fill",
                            tint: .green,
                            isFilled: true,
                            usesLightText: false
                        )
                    }
                }

                if let bio = owner.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(22)
        .glassCard(cornerRadius: 30)
    }

    private func statsSection(for owner: AppUser) -> some View {
        let activeListings = viewModel.listings.filter { $0.status == .active }
        let verifiedCount = viewModel.listings.filter { $0.isVerified }.count
        let averagePrice = averageListingPrice

        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            ProfileMetricCard(
                title: "Publicaciones",
                value: "\(viewModel.listings.count)",
                symbol: "house.fill"
            )
            ProfileMetricCard(
                title: "Activas",
                value: "\(activeListings.count)",
                symbol: "checkmark.circle.fill"
            )
            ProfileMetricCard(
                title: "Verificadas",
                value: "\(verifiedCount)",
                symbol: "checkmark.seal.fill"
            )
            ProfileMetricCard(
                title: "Precio medio",
                value: averagePrice,
                symbol: "tag.fill"
            )
        }
    }

    private func contactCard(for owner: AppUser) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Contacto")
                .font(.headline)

            OwnerInfoRow(title: "Correo", value: owner.email, symbol: "envelope.fill")

            if let phone = owner.phone, !phone.isEmpty {
                OwnerInfoRow(title: "Telefono", value: phone, symbol: "phone.fill")
            }

            HStack(spacing: 12) {
                if let phone = owner.phone, !phone.isEmpty, let url = URL(string: "tel://\(phone.filter(\.isNumber))") {
                    Link(destination: url) {
                        Text("Llamar")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .foregroundStyle(.white)
                            .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }

                ShareLink(item: shareText(for: owner)) {
                    Text("Compartir perfil")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .foregroundStyle(.primary)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.16), lineWidth: 1)
                        )
                }
            }
        }
        .padding(20)
        .glassCard(cornerRadius: 28)
    }

    private func listingsSection(for owner: AppUser) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Habitaciones publicadas")
                        .font(.headline)
                    Text("\(viewModel.listings.count) publicación(es)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            if viewModel.listings.isEmpty {
                EmptyStateView(
                    symbol: "house",
                    title: "Sin publicaciones",
                    message: "Este usuario todavía no ha publicado habitaciones."
                )
            } else {
                VStack(spacing: 12) {
                    ForEach(viewModel.listings) { listing in
                        NavigationLink {
                            ListingDetailView(
                                listing: listing,
                                isFavorite: false,
                                onFavoriteTap: {},
                                onListingUpdated: { _ in }
                            )
                        } label: {
                            OwnerListingRow(listing: listing)
                        }
                    }
                }
            }
        }
        .padding(20)
        .glassCard(cornerRadius: 28)
    }

    private var averageListingPrice: String {
        guard !viewModel.listings.isEmpty else { return "S/ 0" }

        let total = viewModel.listings.reduce(0) { $0 + $1.price }
        let average = total / Double(viewModel.listings.count)
        return String(format: "S/ %.0f", average)
    }

    private func shareText(for owner: AppUser) -> String {
        """
        Perfil de \(owner.fullName)
        \(owner.role.displayName)
        \(viewModel.listings.count) publicaciones en RoomUnap
        """
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }
}

private struct OwnerProfileSkeleton: View {
    var body: some View {
        VStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 999, style: .continuous)
                .fill(.quaternary)
                .frame(width: 118, height: 118)

            VStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.quaternary)
                    .frame(width: 180, height: 22)
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.quaternary)
                    .frame(width: 130, height: 16)
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.quaternary)
                    .frame(width: 260, height: 16)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(22)
        .glassCard(cornerRadius: 30)
        .redacted(reason: .placeholder)
    }
}

private struct PublicAvatarView: View {
    let avatarUrl: String?
    let initials: String
    let role: UserRole

    var body: some View {
        ZStack {
            if let avatarUrl, let url = URL(string: avatarUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        placeholder
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        placeholder
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))
    }

    private var placeholder: some View {
        LinearGradient(
            colors: [roleColor.opacity(0.9), roleColor.opacity(0.45)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            Text(initials.isEmpty ? "U" : initials)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        )
    }

    private var roleColor: Color {
        switch role {
        case .estudiante:
            return .blue
        case .arrendador:
            return .orange
        case .superAdmin:
            return .purple
        }
    }
}

private struct OwnerInfoRow: View {
    let title: String
    let value: String
    let symbol: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
        )
    }
}

private struct OwnerListingRow: View {
    let listing: Listing

    var body: some View {
        HStack(spacing: 12) {
            ListingImageView(urlString: listing.coverImageUrl)
                .frame(width: 88, height: 76)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(listing.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    Spacer(minLength: 8)
                    ListingBadgeView(
                        title: listing.status.displayName,
                        systemImage: listing.status.symbol,
                        tint: listing.status == .active ? .green : .secondary,
                        isFilled: true,
                        usesLightText: false
                    )
                }

                Text(listing.zone)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(listing.priceText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .glassCard(cornerRadius: 22)
    }
}

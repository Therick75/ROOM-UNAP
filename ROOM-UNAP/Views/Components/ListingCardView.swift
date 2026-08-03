import SwiftUI

struct ListingCardView: View {
    let listing: Listing
    let isFavorite: Bool
    let onFavoriteTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .topLeading) {
                imageGallery
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        ListingBadgeView(
                            title: listing.status.displayName,
                            systemImage: listing.status.symbol,
                            tint: statusTint,
                            isFilled: true,
                            usesLightText: false
                        )

                        if listing.isNew {
                            ListingBadgeView(
                                title: "Nuevo",
                                systemImage: "sparkles",
                                tint: .orange,
                                isFilled: true,
                                usesLightText: false
                            )
                        }

                        Spacer(minLength: 0)

                        if imageUrls.count > 1 {
                            ListingBadgeView(
                                title: "\(imageUrls.count) fotos",
                                systemImage: "photo.on.rectangle.angled",
                                tint: .white,
                                isFilled: false,
                                usesLightText: true
                            )
                        }
                    }

                    if listing.isVerified {
                        ListingBadgeView(
                            title: "Verificado",
                            systemImage: "checkmark.seal.fill",
                            tint: .green,
                            isFilled: true,
                            usesLightText: false
                        )
                    }
                }
                .padding(12)

                Button(action: onFavoriteTap) {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(isFavorite ? .red : .primary)
                        .frame(width: 40, height: 40)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(listing.priceText)
                        .font(.title3.bold())
                        .foregroundStyle(.primary)

                    Spacer()
                }

                Text(listing.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Label(listing.zone, systemImage: "mappin.and.ellipse")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if !listing.features.enabledAmenities.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(listing.features.enabledAmenities.prefix(3))) { amenity in
                                ListingBadgeView(
                                    title: amenity.title,
                                    systemImage: amenity.symbol,
                                    tint: .secondary,
                                    isFilled: false,
                                    usesLightText: false
                                )
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 2)
        }
        .padding(12)
        .glassCard(cornerRadius: 28)
    }

    private var imageUrls: [String] {
        listing.imageUrls
    }

    private var statusTint: Color {
        switch listing.status {
        case .active:
            return .green
        case .inactive:
            return .secondary
        case .rented:
            return .blue
        }
    }

    @ViewBuilder
    private var imageGallery: some View {
        if imageUrls.count > 1 {
            TabView {
                ForEach(imageUrls, id: \.self) { url in
                    ListingImageView(urlString: url)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        } else {
            ListingImageView(urlString: imageUrls.first)
        }
    }
}

struct ListingBadgeView: View {
    let title: String
    let systemImage: String
    let tint: Color
    let isFilled: Bool
    let usesLightText: Bool

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(isFilled ? foregroundColor : tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(backgroundColor, in: Capsule())
            .overlay(
                Capsule().stroke(borderColor, lineWidth: 1)
            )
    }

    private var foregroundColor: Color {
        if usesLightText {
            return .white
        }

        return .primary
    }

    private var backgroundColor: Color {
        if isFilled {
            if usesLightText {
                return Color.black.opacity(0.28)
            } else {
                return tint.opacity(0.14)
            }
        } else {
            return Color.primary.opacity(0.04)
        }
    }

    private var borderColor: Color {
        if usesLightText {
            return .white.opacity(0.18)
        }

        return isFilled ? tint.opacity(0.22) : Color.white.opacity(0.14)
    }
}

struct ListingImageView: View {
    let urlString: String?

    var body: some View {
        AsyncImage(url: urlString.flatMap(URL.init(string:))) { phase in
            switch phase {
            case .empty:
                ZStack {
                    LinearGradient(
                        colors: [Color(.tertiarySystemFill), Color(.secondarySystemBackground)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    ProgressView()
                }
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            case .failure:
                ZStack {
                    LinearGradient(
                        colors: [Color(.tertiarySystemFill), Color(.secondarySystemBackground)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                }
            @unknown default:
                Rectangle().fill(.quaternary)
            }
        }
        .clipped()
    }
}

struct EmptyStateView: View {
    let symbol: String
    let title: String
    let message: String

    var body: some View {
        ContentUnavailableView(title, systemImage: symbol, description: Text(message))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
            .glassCard(cornerRadius: 28)
    }
}

struct LoadingCardsView: View {
    var body: some View {
        VStack(spacing: 16) {
            ForEach(0..<3, id: \.self) { _ in
                ListingCardSkeleton()
            }
        }
        .padding(.horizontal)
    }
}

private struct ListingCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(.quaternary)
                .frame(height: 220)

            VStack(alignment: .leading, spacing: 10) {
                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .fill(.quaternary)
                    .frame(width: 150, height: 28)

                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.quaternary)
                    .frame(width: 240, height: 18)

                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.quaternary)
                    .frame(width: 160, height: 16)
            }
        }
        .padding(12)
        .glassCard(cornerRadius: 28)
        .redacted(reason: .placeholder)
    }
}

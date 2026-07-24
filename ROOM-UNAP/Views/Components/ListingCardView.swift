import SwiftUI

struct ListingCardView: View {
    let listing: Listing
    let isFavorite: Bool
    let onFavoriteTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .topTrailing) {
                ListingImageView(urlString: listing.imageUrl)
                    .frame(height: 210)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                Button(action: onFavoriteTap) {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(isFavorite ? .red : .primary)
                        .frame(width: 38, height: 38)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                .padding(10)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text("S/ \(listing.price, specifier: "%.0f")")
                        .font(.title3.bold())
                        .foregroundStyle(.primary)
                    Text("/ mes")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if listing.isVerified {
                        Label("Verificado", systemImage: "checkmark.seal.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.green)
                    }
                }

                Text(listing.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Label(listing.zone, systemImage: "mappin.and.ellipse")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct ListingImageView: View {
    let urlString: String?

    var body: some View {
        AsyncImage(url: urlString.flatMap(URL.init(string:))) { phase in
            switch phase {
            case .empty:
                ZStack {
                    Rectangle().fill(.quaternary)
                    ProgressView()
                }
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            case .failure:
                ZStack {
                    Rectangle().fill(.quaternary)
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
    }
}

struct LoadingCardsView: View {
    var body: some View {
        VStack(spacing: 16) {
            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.quaternary)
                    .frame(height: 300)
                    .redacted(reason: .placeholder)
            }
        }
        .padding(.horizontal)
    }
}

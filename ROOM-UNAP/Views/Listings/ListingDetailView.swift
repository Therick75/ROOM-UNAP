import SwiftUI

struct ListingDetailView: View {
    let listing: Listing
    let isFavorite: Bool
    let onFavoriteTap: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                GeometryReader { proxy in
                    let minY = proxy.frame(in: .global).minY
                    ListingImageView(urlString: listing.imageUrl)
                        .frame(
                            width: proxy.size.width,
                            height: minY > 0 ? 340 + minY : 340
                        )
                        .clipped()
                        .offset(y: minY > 0 ? -minY : 0)
                }
                .frame(height: 340)

                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("S/ \(listing.price, specifier: "%.0f")")
                                .font(.largeTitle.bold())
                            Text("/ mes")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }

                        Text(listing.title)
                            .font(.title2.bold())
                            .fixedSize(horizontal: false, vertical: true)

                        Label(listing.zone, systemImage: "mappin.and.ellipse")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if let description = listing.description, !description.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Descripcion")
                                .font(.headline)
                            Text(description)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Comodidades")
                            .font(.headline)
                        if listing.features.enabledAmenities.isEmpty {
                            Text("El arrendador aun no registro comodidades.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 12)], spacing: 12) {
                                ForEach(listing.features.enabledAmenities) { amenity in
                                    Label(amenity.title, systemImage: amenity.symbol)
                                        .font(.subheadline.weight(.medium))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(12)
                                        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                                }
                            }
                        }
                    }
                }
                .padding(20)
                .background(.background)
            }
        }
        .ignoresSafeArea(edges: .top)
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 12) {
                Button(action: onFavoriteTap) {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(isFavorite ? .red : .primary)
                        .frame(width: 52, height: 52)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .buttonStyle(.plain)

                Button {
                    Haptics.success()
                } label: {
                    Label("Contactar", systemImage: "message.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .background(.ultraThinMaterial)
        }
    }
}

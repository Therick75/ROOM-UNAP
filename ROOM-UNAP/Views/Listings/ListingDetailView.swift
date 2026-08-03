import SwiftUI

struct ListingDetailView: View {
    let listing: Listing
    let isFavorite: Bool
    let canEdit: Bool
    let onFavoriteTap: () -> Void
    let onListingUpdated: (Listing) -> Void

    @State private var displayedListing: Listing
    @State private var showingEditor = false
    @State private var owner: AppUser?
    @State private var isLoadingOwner = false
    @State private var galleryImages: [ListingImage] = []
    @State private var showingOwnerProfile = false
    @State private var showingContactSheet = false
    @State private var showingActionsSheet = false
    @State private var selectedImageIndex = 0

    private let service = RoomUnapService()

    init(
        listing: Listing,
        isFavorite: Bool,
        canEdit: Bool = false,
        onFavoriteTap: @escaping () -> Void,
        onListingUpdated: @escaping (Listing) -> Void = { _ in }
    ) {
        self.listing = listing
        self.isFavorite = isFavorite
        self.canEdit = canEdit
        self.onFavoriteTap = onFavoriteTap
        self.onListingUpdated = onListingUpdated
        _displayedListing = State(initialValue: listing)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                headerImage
                detailsCard
            }
        }
        .ignoresSafeArea(edges: .top)
        .background(
            LinearGradient(
                colors: [Color(.systemBackground), Color(.secondarySystemBackground)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .safeAreaInset(edge: .bottom) {
            actionBar
        }
        .sheet(isPresented: $showingEditor) {
            EditListingView(listing: displayedListing) { updatedListing in
                displayedListing = updatedListing
                onListingUpdated(updatedListing)
            }
        }
        .sheet(isPresented: $showingOwnerProfile) {
            if let owner {
                OwnerProfileView(ownerId: owner.id, initialOwner: owner)
            } else {
                ProgressView()
                    .padding()
            }
        }
        .sheet(isPresented: $showingContactSheet) {
            ContactOptionsSheet(listing: displayedListing, owner: owner)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingActionsSheet) {
            ListingActionsSheet(
                listing: displayedListing,
                owner: owner,
                onReport: {
                    Haptics.success()
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .onAppear {
            displayedListing = listing
        }
        .task {
            await loadListingContext()
        }
    }

    private var headerImage: some View {
        GeometryReader { proxy in
            let minY = proxy.frame(in: .global).minY

            ZStack(alignment: .topTrailing) {
                ListingDetailGalleryView(
                    imageUrls: galleryImageUrls,
                    tags: displayedListing.features.tags,
                    currentIndex: $selectedImageIndex,
                    status: displayedListing.status,
                    isVerified: displayedListing.isVerified,
                    isNew: displayedListing.isNew
                )
                    .frame(
                        width: proxy.size.width,
                        height: minY > 0 ? 390 + minY : 390
                    )
                    .clipped()
                    .offset(y: minY > 0 ? -minY : 0)

                if canEdit {
                    Button {
                        showingEditor = true
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.primary)
                            .frame(width: 46, height: 46)
                            .background(.ultraThinMaterial, in: Circle())
                            .overlay(
                                Circle().stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                    }
                    .padding(.top, proxy.safeAreaInsets.top + 12)
                    .padding(.trailing, 16)
                }
            }
        }
        .frame(height: 390)
    }

    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(displayedListing.priceText)
                        .font(.largeTitle.bold())
                    Text("al mes")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }

                Text(displayedListing.title)
                    .font(.title2.bold())
                    .fixedSize(horizontal: false, vertical: true)

                Label(displayedListing.zone, systemImage: "mappin.and.ellipse")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ListingBadgesRow(listing: displayedListing)

            ownerSection

            tagsSection

            if let description = displayedListing.description, !description.isEmpty {
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

                if displayedListing.features.enabledAmenities.isEmpty {
                    Text("El arrendador aun no registro comodidades.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 12)], spacing: 12) {
                        ForEach(displayedListing.features.enabledAmenities) { amenity in
                            Label(amenity.title, systemImage: amenity.symbol)
                                .font(.subheadline.weight(.medium))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                                )
                        }
                    }
                }
            }
        }
        .padding(20)
        .glassCard(cornerRadius: 28)
        .padding(16)
        .padding(.top, 8)
    }

    private var ownerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Publicado por")
                .font(.headline)

            if isLoadingOwner {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if let owner {
                Button {
                    showingOwnerProfile = true
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        AvatarBadge(urlString: owner.avatarUrl, initials: owner.initials, role: owner.role)
                            .frame(width: 54, height: 54)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Text(owner.fullName)
                                    .font(.headline)

                                if owner.role.canAccessAdminDashboard || displayedListing.isVerified {
                                    ListingBadgeView(
                                        title: "Verificado",
                                        systemImage: "checkmark.seal.fill",
                                        tint: .green,
                                        isFilled: true,
                                        usesLightText: false
                                    )
                                }
                            }

                            Text(owner.role.displayName)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)

                            if let bio = owner.bio, !bio.isEmpty {
                                Text(bio)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            } else {
                                Text("Perfil sin bio todavía.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(14)
                    .glassCard(cornerRadius: 22)
                }
            }
        }
    }

    private var tagsSection: some View {
        Group {
            if !displayedListing.features.tags.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Ambientes marcados")
                        .font(.headline)

                    FlowChipGrid(tags: displayedListing.features.tags)
                }
                .padding(14)
                .glassCard(cornerRadius: 22)
            }
        }
    }

    private var actionBar: some View {
        HStack(spacing: 12) {
            Button(action: onFavoriteTap) {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isFavorite ? .red : .primary)
                    .frame(width: 52, height: 52)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
            }

            Button {
                showingContactSheet = true
            } label: {
                Label("Contactar", systemImage: "message.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
            }
            .buttonStyle(.borderedProminent)
            .tint(.accentColor)

            ShareLink(item: shareText) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 52, height: 52)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
            }

            Button {
                showingActionsSheet = true
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 52, height: 52)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .background(.ultraThinMaterial)
        .overlay(
            Rectangle().stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    private func loadOwner() async {
        guard owner == nil else { return }
        isLoadingOwner = true

        do {
            owner = try await service.fetchProfile(userId: displayedListing.ownerId)
        } catch {
            owner = nil
        }

        isLoadingOwner = false
    }

    private func loadListingContext() async {
        await loadOwner()

        do {
            galleryImages = try await service.fetchListingImages(listingId: displayedListing.id)
        } catch {
            galleryImages = []
        }
    }

    private var galleryImageUrls: [String] {
        if !galleryImages.isEmpty {
            return galleryImages.map(\.url)
        }

        return displayedListing.imageUrls
    }

    private var shareText: String {
        """
        \(displayedListing.title)
        \(displayedListing.priceText)
        Zona: \(displayedListing.zone)
        """
    }
}

private struct ListingDetailGalleryView: View {
    let imageUrls: [String]
    let tags: [String]
    @Binding var currentIndex: Int
    let status: ListingStatus
    let isVerified: Bool
    let isNew: Bool

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if imageUrls.count > 1 {
                TabView(selection: $currentIndex) {
                    ForEach(Array(imageUrls.enumerated()), id: \.offset) { index, url in
                        ListingImageView(urlString: url)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            } else {
                ListingImageView(urlString: imageUrls.first)
            }

            LinearGradient(
                colors: [Color.black.opacity(0.46), .clear],
                startPoint: .bottom,
                endPoint: .top
            )

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            ListingBadgeView(
                                title: status.displayName,
                                systemImage: status.symbol,
                                tint: .white,
                                isFilled: true,
                                usesLightText: true
                            )

                            if isNew {
                                ListingBadgeView(
                                    title: "Nuevo",
                                    systemImage: "sparkles",
                                    tint: .orange,
                                    isFilled: true,
                                    usesLightText: false
                                )
                            }

                            if isVerified {
                                ListingBadgeView(
                                    title: "Verificado",
                                    systemImage: "checkmark.seal.fill",
                                    tint: .green,
                                    isFilled: true,
                                    usesLightText: false
                                )
                            }
                        }
                    }

                    Spacer()

                    if imageUrls.count > 1 {
                        ListingBadgeView(
                            title: "\(currentIndex + 1)/\(imageUrls.count)",
                            systemImage: "photo.on.rectangle.angled",
                            tint: .white,
                            isFilled: true,
                            usesLightText: true
                        )
                    }
                }

                if !tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(.ultraThinMaterial, in: Capsule())
                                    .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1))
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(Color(.secondarySystemBackground))
    }
}

private struct ListingBadgesRow: View {
    let listing: Listing

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ListingBadgeView(
                    title: listing.status.displayName,
                    systemImage: listing.status.symbol,
                    tint: statusTint,
                    isFilled: true,
                    usesLightText: false
                )

                if listing.isVerified {
                    ListingBadgeView(
                        title: "Verificado",
                        systemImage: "checkmark.seal.fill",
                        tint: .green,
                        isFilled: true,
                        usesLightText: false
                    )
                }

                if listing.isNew {
                    ListingBadgeView(
                        title: "Nuevo",
                        systemImage: "sparkles",
                        tint: .orange,
                        isFilled: true,
                        usesLightText: false
                    )
                }

                ListingBadgeView(
                    title: listing.galleryCount > 0 ? "\(listing.galleryCount) fotos" : "Sin fotos",
                    systemImage: "photo.on.rectangle.angled",
                    tint: .secondary,
                    isFilled: false,
                    usesLightText: false
                )
            }
        }
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
}

private struct AvatarBadge: View {
    let urlString: String?
    let initials: String
    let role: UserRole

    var body: some View {
        ZStack {
            if let urlString, let url = URL(string: urlString) {
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
        .overlay(Circle().stroke(Color.white.opacity(0.16), lineWidth: 1))
    }

    private var placeholder: some View {
        LinearGradient(
            colors: [roleColor.opacity(0.9), roleColor.opacity(0.45)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            Text(initials.isEmpty ? "U" : initials)
                .font(.caption.weight(.bold))
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

private struct FlowChipGrid: View {
    let tags: [String]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 10)], spacing: 10) {
            ForEach(tags, id: \.self) { tag in
                Text(tag)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .foregroundStyle(.primary)
                    .background(Color.primary.opacity(0.05), in: Capsule())
                    .overlay(
                        Capsule().stroke(Color.white.opacity(0.14), lineWidth: 1)
                    )
            }
        }
    }
}

private struct ContactOptionsSheet: View {
    let listing: Listing
    let owner: AppUser?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Opciones de contacto")
                        .font(.title2.bold())

                    Text("Elige el canal que te resulte mas rapido para hablar con el arrendador.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if let owner {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(owner.fullName)
                                .font(.headline)

                            if let phone = owner.phone, !phone.isEmpty {
                                contactLink(
                                    title: "Llamar",
                                    subtitle: phone,
                                    systemImage: "phone.fill",
                                    urlString: "tel://\(sanitizedPhone(phone))"
                                )

                                contactLink(
                                    title: "WhatsApp",
                                    subtitle: "Abrir chat directo",
                                    systemImage: "message.fill",
                                    urlString: whatsAppURL(for: phone)
                                )
                            }

                            contactLink(
                                title: "Enviar correo",
                                subtitle: owner.email,
                                systemImage: "envelope.fill",
                                urlString: "mailto:\(owner.email)"
                            )
                        }
                    }

                    Text("Consejo")
                        .font(.headline)

                    Text("Pregunta disponibilidad, reglas de convivencia y si el anuncio sigue activo antes de coordinar visita.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(16)
            }
            .navigationTitle("Contactar")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func contactLink(title: String, subtitle: String, systemImage: String, urlString: String) -> some View {
        Group {
            if let url = URL(string: urlString) {
                Link(destination: url) {
                    contactRow(title: title, subtitle: subtitle, systemImage: systemImage)
                }
            } else {
                contactRow(title: title, subtitle: subtitle, systemImage: systemImage)
            }
        }
    }

    private func contactRow(title: String, subtitle: String, systemImage: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 26, height: 26)
                .foregroundStyle(Color.accentColor)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
            Image(systemName: "arrow.up.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .glassCard(cornerRadius: 22)
    }

    private func sanitizedPhone(_ phone: String) -> String {
        phone.filter(\.isNumber)
    }

    private func whatsAppURL(for phone: String) -> String {
        let digits = peruvianPhoneDigits(for: phone)
        return "https://wa.me/\(digits)"
    }

    private func peruvianPhoneDigits(for phone: String) -> String {
        let digits = sanitizedPhone(phone)
        guard !digits.hasPrefix("51") else { return digits }
        return "51\(digits)"
    }
}

private struct ListingActionsSheet: View {
    let listing: Listing
    let owner: AppUser?
    let onReport: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Mas acciones")
                        .font(.title2.bold())

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Esta publicación")
                            .font(.headline)
                        Text(listing.title)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .glassCard(cornerRadius: 24)

                    if let owner {
                        Button {
                            onReport()
                        } label: {
                            actionRow(
                                title: "Reportar publicación",
                                subtitle: "Avisar a moderación si algo no coincide",
                                systemImage: "exclamationmark.triangle.fill"
                            )
                        }
                        if let url = URL(string: "mailto:\(owner.email)") {
                            Link(destination: url) {
                                actionRow(
                                    title: "Ver más del arrendador",
                                    subtitle: owner.fullName,
                                    systemImage: "person.crop.circle.fill"
                                )
                            }
                        } else {
                            actionRow(
                                title: "Ver más del arrendador",
                                subtitle: owner.fullName,
                                systemImage: "person.crop.circle.fill"
                            )
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Reglas rápidas")
                            .font(.headline)
                        Text("Confirma precio, disponibilidad, fotos reales y fecha de visita antes de reservar.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .glassCard(cornerRadius: 24)
                }
                .padding(16)
            }
            .navigationTitle("Opciones")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func actionRow(title: String, subtitle: String, systemImage: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .glassCard(cornerRadius: 22)
    }
}

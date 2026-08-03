import PhotosUI
import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @AppStorage("preferredColorScheme") private var preferredColorScheme = "system"
    @State private var showingPublish = false

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Inicio", systemImage: "house") }

            FavoritesView()
                .tabItem { Label("Favoritos", systemImage: "heart") }

            if authViewModel.currentUser?.role.canAccessAdminDashboard == true {
                AdminDashboardView()
                    .tabItem { Label("Panel", systemImage: "rectangle.grid.2x2") }
            }

            ProfileView(showingPublish: $showingPublish)
                .tabItem { Label("Perfil", systemImage: "person") }
        }
        .sheet(isPresented: $showingPublish) {
            PublishListingView()
                .environmentObject(authViewModel)
        }
        .preferredColorScheme(colorScheme)
    }

    private var colorScheme: ColorScheme? {
        switch preferredColorScheme {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }
}

struct HomeView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @StateObject private var viewModel = HomeViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.listings.isEmpty {
                    LoadingListingsView()
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            HomeSummaryCard(
                                title: "Explora habitaciones",
                                subtitle: "Busca por zona, precio, comodidades y estado antes de entrar al detalle.",
                                countText: "\(viewModel.listings.count) resultados"
                            )

                            HomeFilterStrip(
                                filters: ListingQuickFilter.allCases,
                                selectedFilter: viewModel.quickFilter
                            ) { filter in
                                viewModel.quickFilter = filter
                            }

                            if viewModel.listings.isEmpty {
                                if viewModel.hasActiveFilters {
                                    EmptyStateView(
                                        symbol: "line.3.horizontal.decrease.circle",
                                        title: "Sin coincidencias",
                                        message: "Prueba con otra zona, quita filtros o cambia el orden."
                                    )
                                    .overlay(alignment: .bottom) {
                                        Button("Limpiar filtros") {
                                            viewModel.clearFilters()
                                        }
                                        .font(.subheadline.weight(.semibold))
                                        .padding(.top, 12)
                                    }
                                } else {
                                    EmptyStateView(
                                        symbol: "house.lodge",
                                        title: "Sin habitaciones activas",
                                        message: "Cuando haya publicaciones disponibles aparecerán aquí."
                                    )
                                }
                            } else {
                                LazyVStack(spacing: 16) {
                                    ForEach(viewModel.listings) { listing in
                                        NavigationLink {
                                            ListingDetailView(
                                                listing: listing,
                                                isFavorite: viewModel.favoriteIds.contains(listing.id),
                                                canEdit: canEdit(listing: listing)
                                            ) {
                                                Task {
                                                    await viewModel.toggleFavorite(
                                                        listing: listing,
                                                        userId: authViewModel.currentUser?.id
                                                    )
                                                }
                                            } onListingUpdated: { updatedListing in
                                                viewModel.replaceListing(updatedListing)
                                            }
                                        } label: {
                                            ListingCardView(
                                                listing: listing,
                                                isFavorite: viewModel.favoriteIds.contains(listing.id)
                                            ) {
                                                Task {
                                                    await viewModel.toggleFavorite(
                                                        listing: listing,
                                                        userId: authViewModel.currentUser?.id
                                                    )
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(16)
                    }
                    .refreshable {
                        await viewModel.load(userId: authViewModel.currentUser?.id)
                    }
                }
            }
            .navigationTitle("Habitaciones")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    LogoView(isCompact: true)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        ForEach(ListingSortOption.allCases) { option in
                            Button {
                                viewModel.sortOption = option
                            } label: {
                                if viewModel.sortOption == option {
                                    Label(option.title, systemImage: "checkmark")
                                } else {
                                    Text(option.title)
                                }
                            }
                        }

                        Divider()

                        Button(role: .destructive) {
                            viewModel.clearFilters()
                        } label: {
                            Label("Limpiar filtros", systemImage: "arrow.counterclockwise")
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down.circle")
                    }
                }
            }
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .searchable(
                text: $viewModel.searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Zona, precio, comodidades, verificado"
            )
            .task {
                await viewModel.load(userId: authViewModel.currentUser?.id)
            }
            .alert("Error", isPresented: errorBinding) {
                Button("OK", role: .cancel) { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "Intenta nuevamente.")
            }
        }
    }

    private func canEdit(listing: Listing) -> Bool {
        guard let currentUser = authViewModel.currentUser else { return false }
        return currentUser.role.canEditListings && (currentUser.role == .superAdmin || currentUser.id == listing.ownerId)
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }
}

struct FavoritesView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @StateObject private var viewModel = FavoritesViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.favorites.isEmpty {
                    ProgressView()
                } else if viewModel.favorites.isEmpty {
                    EmptyStateView(
                        symbol: "heart",
                        title: "Sin favoritos",
                        message: "Guarda habitaciones para compararlas rapidamente."
                    )
                } else {
                    List {
                        ForEach(viewModel.favorites) { favorite in
                            NavigationLink {
                                ListingDetailView(listing: favorite.listings, isFavorite: true) {
                                    Task {
                                        await viewModel.removeFavorite(
                                            at: IndexSet(integer: viewModel.favorites.firstIndex(where: { $0.id == favorite.id }) ?? 0),
                                            userId: authViewModel.currentUser?.id
                                        )
                                    }
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    ListingImageView(urlString: favorite.listings.imageUrl)
                                        .frame(width: 84, height: 72)
                                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(favorite.listings.title)
                                            .font(.headline)
                                            .lineLimit(2)
                                        Text(favorite.listings.zone)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                        Text("S/ \(favorite.listings.price, specifier: "%.0f")")
                                            .font(.subheadline.bold())
                                    }
                                }
                            }
                        }
                        .onDelete { offsets in
                            Task {
                                await viewModel.removeFavorite(at: offsets, userId: authViewModel.currentUser?.id)
                            }
                        }
                    }
                    .refreshable {
                        await viewModel.load(userId: authViewModel.currentUser?.id)
                    }
                }
            }
            .navigationTitle("Favoritos")
            .task {
                await viewModel.load(userId: authViewModel.currentUser?.id)
            }
            .alert("Error", isPresented: errorBinding) {
                Button("OK", role: .cancel) { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "Intenta nuevamente.")
            }
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }
}

struct ProfileView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @AppStorage("preferredColorScheme") private var preferredColorScheme = "system"
    @AppStorage("preferredInterfaceTone") private var preferredInterfaceTone = InterfaceTone.black.rawValue
    @AppStorage("preferredInteractionAccent") private var preferredInteractionAccent = InteractionAccent.blue.rawValue
    @Binding var showingPublish: Bool
    @StateObject private var viewModel = ProfileViewModel()

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
                        if let user = authViewModel.currentUser {
                            profileHeader(for: user)
                            rolePanel(for: user)
                            appearancePanel
                            editPanel
                            if user.role.canAccessAdminDashboard {
                                adminActions(for: user)
                            }
                            sessionActions
                        } else {
                            EmptyStateView(
                                symbol: "person.crop.circle",
                                title: "Perfil no disponible",
                                message: "Inicia sesion para ver y editar tus datos."
                            )
                            .padding(.top, 80)
                        }
                    }
                    .padding(16)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Perfil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .task {
                viewModel.configure(with: authViewModel.currentUser)
            }
            .onChange(of: authViewModel.currentUser) { _, newValue in
                viewModel.configure(with: newValue, force: true)
            }
            .alert("No se pudo guardar el perfil", isPresented: errorBinding) {
                Button("OK", role: .cancel) { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "Intenta nuevamente.")
            }
        }
    }

    private var appearancePanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Apariencia")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text("Tema")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                Picker("Tema", selection: $preferredColorScheme) {
                    Text("Sistema").tag("system")
                    Text("Claro").tag("light")
                    Text("Oscuro").tag("dark")
                }
                .pickerStyle(.segmented)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Color de interfaz")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                Picker("Color de interfaz", selection: $preferredInterfaceTone) {
                    ForEach(InterfaceTone.allCases) { tone in
                        Text(tone.displayName).tag(tone.rawValue)
                    }
                }
                .pickerStyle(.segmented)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Color de interacción")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                Picker("Color de interacción", selection: $preferredInteractionAccent) {
                    ForEach(InteractionAccent.allCases) { accent in
                        Text(accent.displayName).tag(accent.rawValue)
                    }
                }
                .pickerStyle(.menu)
            }
        }
        .padding(20)
        .glassCard(cornerRadius: 28)
    }

    private func profileHeader(for user: AppUser) -> some View {
        VStack(spacing: 16) {
            let avatarUrl = viewModel.selectedAvatar == nil ? viewModel.avatarUrl : nil
            let initials = viewModel.initials

            PhotosPicker(selection: $viewModel.selectedAvatar, matching: .images) {
                AvatarView(
                    avatarUrl: avatarUrl,
                    initials: initials,
                    role: user.role
                )
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(Color.accentColor, in: Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.22), lineWidth: 1))
                        .offset(x: 2, y: 2)
                }
            }

            VStack(spacing: 8) {
                Text(viewModel.fullName.isEmpty ? user.fullName : viewModel.fullName)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)

                Text(user.email)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(user.role.displayName.uppercased())
                    .font(.caption.weight(.bold))
                    .foregroundStyle(roleAccentColor(for: user.role))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(roleAccentColor(for: user.role).opacity(0.12), in: Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(22)
        .glassCard(cornerRadius: 30)
    }

    private func rolePanel(for user: AppUser) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Tu espacio")
                .font(.headline)

            Text(roleTitle(for: user.role))
                .font(.title3.bold())

            Text(roleSubtitle(for: user.role))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if !user.role.canManageUserRoles {
                Text("El cambio de rol solo lo puede hacer un super admin desde el panel.")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }

            HStack(spacing: 12) {
                ProfileMetricCard(
                    title: "Rol",
                    value: user.role.displayName,
                    symbol: "person.badge.key"
                )
                ProfileMetricCard(
                    title: "Perfil",
                    value: user.bio?.isEmpty == false ? "Completo" : "Pendiente",
                    symbol: "square.and.pencil"
                )
            }
        }
        .padding(20)
        .glassCard(cornerRadius: 28)
    }

    private var editPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Editar perfil")
                .font(.headline)

            glassField(title: "Nombre", text: $viewModel.fullName, symbol: "text.cursor")
            glassField(title: "Telefono", text: $viewModel.phone, symbol: "phone.fill")

            VStack(alignment: .leading, spacing: 8) {
                Text("Bio")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                ZStack(alignment: .topLeading) {
                    if viewModel.bio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Cuéntale a otros quién eres o qué buscas en RoomUnap")
                            .foregroundStyle(.secondary.opacity(0.65))
                            .padding(.horizontal, 18)
                            .padding(.vertical, 16)
                    }

                    TextEditor(text: $viewModel.bio)
                        .frame(minHeight: 118)
                        .scrollContentBackground(.hidden)
                        .padding(10)
                }
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                )
            }

            Button {
                Task {
                    if let updated = await viewModel.save(userId: authViewModel.currentUser?.id) {
                        await authViewModel.loadProfile(userId: updated.id)
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    if viewModel.isLoading {
                        ProgressView()
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                    }
                    Text("Guardar cambios")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .foregroundStyle(.white)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )
                .shadow(color: Color.accentColor.opacity(0.24), radius: 14, x: 0, y: 6)
            }
            .disabled(viewModel.isLoading || viewModel.fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(20)
        .glassCard(cornerRadius: 28)
    }

    private var sessionActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sesión")
                .font(.headline)

            Button {
                Task {
                    await authViewModel.signOut()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                    Text("Cerrar sesión")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .foregroundStyle(.primary)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                )
            }
        }
        .padding(20)
        .glassCard(cornerRadius: 28)
    }

    private func adminActions(for user: AppUser) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Accesos rapidos")
                .font(.headline)

            HStack(spacing: 12) {
                Button {
                    showingPublish = true
                } label: {
                    Label("Publicar", systemImage: "plus")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .foregroundStyle(.white)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                NavigationLink {
                    AdminDashboardView()
                } label: {
                    Label("Panel", systemImage: "rectangle.grid.2x2")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
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

    private func glassField(title: String, text: Binding<String>, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 18)

                TextField(title, text: text)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
            )
        }
    }

    private func roleTitle(for role: UserRole) -> String {
        switch role {
        case .estudiante:
            return "Tu perfil como estudiante"
        case .arrendador:
            return "Tu perfil como arrendador"
        case .superAdmin:
            return "Tu perfil como super admin"
        }
    }

    private func roleSubtitle(for role: UserRole) -> String {
        switch role {
        case .estudiante:
            return "Personaliza tu presencia, guarda una bio breve y mantén tu información lista para contactar rápido."
        case .arrendador:
            return "Refuerza confianza con una foto clara, tu teléfono y una bio breve para potenciales inquilinos."
        case .superAdmin:
            return "Mantén tu perfil pulido para operar el panel con una presencia institucional y consistente."
        }
    }

    private func roleAccentColor(for role: UserRole) -> Color {
        switch role {
        case .estudiante:
            return .blue
        case .arrendador:
            return .orange
        case .superAdmin:
            return .purple
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }
}

private struct AvatarView: View {
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
        .frame(width: 132, height: 132)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.white.opacity(0.22), lineWidth: 1))
        .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 8)
    }

    private var placeholder: some View {
        LinearGradient(
            colors: [roleColor.opacity(0.9), roleColor.opacity(0.45)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            Text(initials.isEmpty ? "U" : initials)
                .font(.system(size: 34, weight: .bold, design: .rounded))
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

struct ProfileMetricCard: View {
    let title: String
    let value: String
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.headline)
                .lineLimit(1)

            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(cornerRadius: 20)
    }
}

private struct HomeSummaryCard: View {
    let title: String
    let subtitle: String
    let countText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.title2.bold())
                        .fixedSize(horizontal: false, vertical: true)

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)
            }

            Text(countText)
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.accentColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color.accentColor.opacity(0.12), in: Capsule())
        }
        .padding(20)
        .glassCard(cornerRadius: 28)
    }
}

private struct HomeFilterStrip: View {
    let filters: [ListingQuickFilter]
    let selectedFilter: ListingQuickFilter
    let onSelect: (ListingQuickFilter) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(filters) { filter in
                    Button {
                        onSelect(filter)
                    } label: {
                        Label(filter.title, systemImage: filter.symbol)
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .foregroundStyle(selectedFilter == filter ? .white : .primary)
                            .background(backgroundColor(for: filter), in: Capsule())
                            .overlay(
                                Capsule().stroke(borderColor(for: filter), lineWidth: 1)
                            )
                    }
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private func backgroundColor(for filter: ListingQuickFilter) -> some ShapeStyle {
        selectedFilter == filter ? Color.accentColor : Color.primary.opacity(0.05)
    }

    private func borderColor(for filter: ListingQuickFilter) -> Color {
        selectedFilter == filter ? Color.clear : Color.white.opacity(0.15)
    }
}

private struct LoadingListingsView: View {
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                HomeSummarySkeleton()
                HomeFilterStripSkeleton()
                ForEach(0..<3, id: \.self) { _ in
                    ListingCardSkeleton()
                }
            }
            .padding(16)
        }
    }
}

private struct HomeSummarySkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.quaternary)
                .frame(width: 210, height: 28)

            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.quaternary)
                .frame(width: 320, height: 16)

            RoundedRectangle(cornerRadius: 999, style: .continuous)
                .fill(.quaternary)
                .frame(width: 124, height: 28)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .glassCard(cornerRadius: 28)
        .redacted(reason: .placeholder)
    }
}

private struct HomeFilterStripSkeleton: View {
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(0..<6, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 999, style: .continuous)
                        .fill(.quaternary)
                        .frame(width: 88, height: 38)
                }
            }
        }
        .redacted(reason: .placeholder)
    }
}

private struct ListingCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.quaternary)
                .frame(height: 220)

            VStack(alignment: .leading, spacing: 10) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.quaternary)
                    .frame(width: 120, height: 22)
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.quaternary)
                    .frame(width: 220, height: 18)
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.quaternary)
                    .frame(width: 160, height: 16)
            }
        }
        .padding(12)
        .glassCard(cornerRadius: 28)
        .redacted(reason: .placeholder)
    }
}

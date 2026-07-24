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
                    LoadingCardsView()
                } else if viewModel.listings.isEmpty {
                    EmptyStateView(
                        symbol: "house.lodge",
                        title: "Sin habitaciones activas",
                        message: "Cuando haya publicaciones disponibles apareceran aqui."
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(viewModel.listings) { listing in
                                NavigationLink {
                                    ListingDetailView(
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
                                .buttonStyle(.plain)
                            }
                        }
                        .padding()
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
            }
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
    @Binding var showingPublish: Bool

    var body: some View {
        NavigationStack {
            List {
                if let user = authViewModel.currentUser {
                    Section {
                        HStack(spacing: 14) {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 52))
                                .foregroundStyle(.tint)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(user.fullName)
                                    .font(.headline)
                                Text(user.email)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text(user.role.displayName)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }

                Section("Apariencia") {
                    Picker("Tema", selection: $preferredColorScheme) {
                        Label("Sistema", systemImage: "circle.lefthalf.filled").tag("system")
                        Label("Claro", systemImage: "sun.max").tag("light")
                        Label("Oscuro", systemImage: "moon").tag("dark")
                    }
                }

                if authViewModel.currentUser?.role == .arrendador {
                    Section {
                        Button {
                            showingPublish = true
                        } label: {
                            Label("Publicar Habitacion", systemImage: "plus.circle.fill")
                                .fontWeight(.semibold)
                        }
                    }
                }

                Section {
                    Button(role: .destructive) {
                        Task { await authViewModel.signOut() }
                    } label: {
                        Label("Cerrar Sesion", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .navigationTitle("Perfil")
            .refreshable {
                await authViewModel.loadProfile()
            }
        }
    }
}

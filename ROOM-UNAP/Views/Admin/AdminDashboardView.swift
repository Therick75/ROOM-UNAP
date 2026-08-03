import SwiftUI

struct AdminDashboardView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @StateObject private var viewModel = AdminDashboardViewModel()
    @State private var showingPublish = false
    @State private var editingListing: Listing?
    @State private var editingUser: AppUser?

    private var canManageRoles: Bool {
        authViewModel.currentUser?.role.canManageUserRoles == true
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                LinearGradient(
                    colors: [Color.accentColor.opacity(0.14), Color(.systemBackground), Color(.secondarySystemBackground)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                content

                publishButton
            }
            .navigationTitle("Panel de administrador")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .task {
                await viewModel.load(ownerId: authViewModel.currentUser?.id, shouldLoadUsers: canManageRoles)
            }
            .refreshable {
                await viewModel.load(ownerId: authViewModel.currentUser?.id, shouldLoadUsers: canManageRoles)
            }
            .sheet(isPresented: $showingPublish) {
                PublishListingView { newListing in
                    viewModel.addListing(newListing)
                }
                .environmentObject(authViewModel)
            }
            .sheet(item: $editingListing) { listing in
                EditListingView(listing: listing, onSaved: { updatedListing in
                    viewModel.replaceListing(updatedListing)
                }, onDeleted: {
                    viewModel.removeListing(id: listing.id)
                })
                .environmentObject(authViewModel)
            }
            .sheet(item: $editingUser) { user in
                UserRoleEditorView(
                    user: user,
                    availableRoles: UserRole.allCases
                ) { newRole in
                    await viewModel.updateUserRole(userId: user.id, role: newRole)
                } onSaved: { updatedUser in
                    viewModel.replaceUser(updatedUser)
                    if updatedUser.id == authViewModel.currentUser?.id {
                        Task {
                            await authViewModel.loadProfile(userId: updatedUser.id)
                        }
                    }
                }
            }
            .alert("Error", isPresented: errorBinding) {
                Button("OK", role: .cancel) { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "Intenta nuevamente.")
            }
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                introCard
                statsGrid
                if canManageRoles {
                    usersSection
                }
                listingsSection
            }
            .padding(16)
            .padding(.bottom, 120)
        }
    }

    private var introCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Gestiona tus publicaciones y perfiles desde un mismo panel limpio.")
                .font(.title2.bold())
                .fixedSize(horizontal: false, vertical: true)

            Text("Las habitaciones se administran con swipe actions y los roles de usuario se editan desde una hoja dedicada para super admin.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .glassCard(cornerRadius: 28)
    }

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            GlassMetricCard(title: "Anuncios activos", value: "\(viewModel.activeCount)", systemImage: "house.fill", tint: .accentColor)
            GlassMetricCard(title: "Verificados", value: "\(viewModel.verifiedCount)", systemImage: "checkmark.seal.fill", tint: .green)
            GlassMetricCard(title: "Nuevos", value: "\(viewModel.newCount)", systemImage: "sparkles", tint: .orange)
            GlassMetricCard(title: "En renta", value: "\(viewModel.rentedCount)", systemImage: "key.fill", tint: .blue)
        }
    }

    private var usersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Perfiles")
                        .font(.headline)
                    Text("Solo super admin puede cambiar roles.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if viewModel.isLoading && !viewModel.users.isEmpty {
                    ProgressView()
                }
            }

            if viewModel.users.isEmpty {
                EmptyStateView(
                    symbol: "person.3",
                    title: "Sin perfiles para gestionar",
                    message: "Asegurate de que la policy de lectura de users permita ver todos los perfiles."
                )
                .padding(.vertical, 8)
            } else {
                VStack(spacing: 12) {
                    ForEach(viewModel.users) { user in
                        Button {
                            editingUser = user
                        } label: {
                            UserAdminRow(user: user, isCurrentUser: user.id == authViewModel.currentUser?.id)
                        }
                    }
                }
            }
        }
        .padding(18)
        .glassCard(cornerRadius: 28)
    }

    private var listingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Tus habitaciones publicadas")
                    .font(.headline)
                Spacer()
                if viewModel.isLoading && !viewModel.listings.isEmpty {
                    ProgressView()
                }
            }

            if viewModel.isLoading && viewModel.listings.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .glassCard(cornerRadius: 24)
            } else if viewModel.listings.isEmpty {
                EmptyStateView(
                    symbol: "house.lodge",
                    title: "Sin publicaciones",
                    message: "Crea tu primera habitacion usando el boton flotante de abajo."
                )
                .padding(.vertical, 12)
            } else {
                List {
                    ForEach(viewModel.listings) { listing in
                        Button {
                            editingListing = listing
                        } label: {
                            ListingAdminRow(listing: listing)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button {
                                editingListing = listing
                            } label: {
                                Label("Editar", systemImage: "pencil")
                            }
                            .tint(.blue)

                            Button(role: .destructive) {
                                Task {
                                    _ = await viewModel.deleteListing(listing)
                                }
                            } label: {
                                Label("Eliminar", systemImage: "trash")
                            }
                        }
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 320)
            }
        }
        .padding(18)
        .glassCard(cornerRadius: 28)
    }

    private var publishButton: some View {
        Button {
            showingPublish = true
        } label: {
            Label("Publicar nueva habitacion", systemImage: "plus")
                .font(.headline)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .foregroundStyle(.white)
                .background(Color.accentColor, in: Capsule())
                .overlay(
                    Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1)
                )
                .shadow(color: Color.accentColor.opacity(0.32), radius: 16, x: 0, y: 8)
        }
        .padding(.trailing, 18)
        .padding(.bottom, 18)
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }
}

private struct GlassMetricCard: View {
    let title: String
    let value: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(tint)
                Spacer()
            }

            Text(value)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .glassCard(cornerRadius: 24)
    }
}

private struct ListingAdminRow: View {
    let listing: Listing

    var body: some View {
        HStack(spacing: 14) {
            ListingImageView(urlString: listing.imageUrl)
                .frame(width: 86, height: 74)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(listing.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    Spacer(minLength: 8)
                    statusChip
                }

                Text(listing.zone)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text("S/ \(listing.price, specifier: "%.0f") / mes")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
            }
        }
        .padding(14)
        .glassCard(cornerRadius: 22)
    }

    private var statusChip: some View {
        Text(statusText)
            .font(.caption.weight(.semibold))
            .foregroundStyle(statusColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(statusColor.opacity(0.12), in: Capsule())
    }

    private var statusText: String {
        switch listing.status {
        case .active:
            return "Activa"
        case .inactive:
            return "Inactiva"
        case .rented:
            return "Rentada"
        }
    }

    private var statusColor: Color {
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

private struct UserAdminRow: View {
    let user: AppUser
    let isCurrentUser: Bool

    var body: some View {
        HStack(spacing: 14) {
            UserAvatarView(user: user)
                .frame(width: 58, height: 58)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(user.fullName)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if isCurrentUser {
                        Text("Tú")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.blue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.blue.opacity(0.12), in: Capsule())
                    }
                }

                Text(user.email)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if let bio = user.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 6) {
                RoleBadge(role: user.role)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .glassCard(cornerRadius: 22)
    }
}

private struct RoleBadge: View {
    let role: UserRole

    var body: some View {
        Text(role.displayName)
            .font(.caption.weight(.bold))
            .foregroundStyle(roleColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(roleColor.opacity(0.12), in: Capsule())
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

private struct UserAvatarView: View {
    let user: AppUser

    var body: some View {
        ZStack {
            if let avatarUrl = user.avatarUrl, let url = URL(string: avatarUrl) {
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
        .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
    }

    private var placeholder: some View {
        LinearGradient(
            colors: [roleColor.opacity(0.88), roleColor.opacity(0.46)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            Text(user.initials.isEmpty ? "U" : user.initials)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        )
    }

    private var roleColor: Color {
        switch user.role {
        case .estudiante:
            return .blue
        case .arrendador:
            return .orange
        case .superAdmin:
            return .purple
        }
    }
}

private struct UserRoleEditorView: View {
    let user: AppUser
    let availableRoles: [UserRole]
    let onSave: (UserRole) async -> AppUser?
    let onSaved: (AppUser) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedRole: UserRole
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(
        user: AppUser,
        availableRoles: [UserRole],
        onSave: @escaping (UserRole) async -> AppUser?,
        onSaved: @escaping (AppUser) -> Void
    ) {
        self.user = user
        self.availableRoles = availableRoles
        self.onSave = onSave
        self.onSaved = onSaved
        _selectedRole = State(initialValue: user.role)
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
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        rolePickerCard
                        noteCard
                        saveButton
                    }
                    .padding(16)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Cambiar rol")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
            .alert("No se pudo actualizar el rol", isPresented: errorBinding) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "Intenta nuevamente.")
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                UserAvatarView(user: user)
                    .frame(width: 56, height: 56)

                VStack(alignment: .leading, spacing: 3) {
                    Text(user.fullName)
                        .font(.headline)
                    Text(user.email)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Text("Selecciona el rol para este perfil.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .glassCard(cornerRadius: 28)
    }

    private var rolePickerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Nuevo rol")
                .font(.headline)

            Picker("Rol", selection: $selectedRole) {
                ForEach(availableRoles) { role in
                    Text(role.displayName).tag(role)
                }
            }
            .pickerStyle(.menu)
        }
        .padding(20)
        .glassCard(cornerRadius: 28)
    }

    private var noteCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Este cambio afecta permisos de acceso en la app", systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.semibold))
            Text("Usa esta acción solo para perfiles que realmente necesiten publicar o administrar publicaciones.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .glassCard(cornerRadius: 28)
    }

    private var saveButton: some View {
        Button {
            Task {
                isSaving = true
                defer { isSaving = false }

                if let updatedUser = await onSave(selectedRole) {
                    onSaved(updatedUser)
                    dismiss()
                } else {
                    errorMessage = "No se pudo actualizar el rol."
                }
            }
        } label: {
            HStack(spacing: 10) {
                if isSaving {
                    ProgressView()
                } else {
                    Image(systemName: "checkmark.circle.fill")
                }
                Text("Guardar rol")
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
        .disabled(isSaving || selectedRole == user.role)
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }
}

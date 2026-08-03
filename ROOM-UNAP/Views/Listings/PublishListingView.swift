import PhotosUI
import SwiftUI

struct PublishListingView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authViewModel: AuthViewModel
    @StateObject private var viewModel: PublishListingViewModel

    private let onSaved: ((Listing) -> Void)?
    private let onDeleted: (() -> Void)?

    init(
        listing: Listing? = nil,
        onSaved: ((Listing) -> Void)? = nil,
        onDeleted: (() -> Void)? = nil
    ) {
        _viewModel = StateObject(wrappedValue: PublishListingViewModel(listing: listing))
        self.onSaved = onSaved
        self.onDeleted = onDeleted
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color.accentColor.opacity(0.14), Color(.systemBackground), Color(.secondarySystemBackground)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        header
                        detailsSection
                        photoSection
                        tagsSection
                        amenitiesSection
                        destructiveSection
                    }
                    .padding(16)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle(viewModel.isEditing ? "Editar habitacion" : "Publicar habitacion")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            if let listing = await viewModel.save(ownerId: authViewModel.currentUser?.id) {
                                onSaved?(listing)
                                dismiss()
                            }
                        }
                    } label: {
                        if viewModel.isLoading {
                            ProgressView()
                        } else {
                            Text(viewModel.isEditing ? "Guardar" : "Publicar")
                        }
                    }
                    .disabled(!canSave || viewModel.isLoading)
                }
            }
            .alert("No se pudo guardar", isPresented: errorBinding) {
                Button("OK", role: .cancel) { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "Intenta nuevamente.")
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.isEditing ? "Ajusta los detalles con un acabado limpio" : "Publica una habitacion con un flujo minimalista")
                .font(.title2.bold())
                .fixedSize(horizontal: false, vertical: true)

            Text("Campos amplios, superficies suaves y una carga de fotos clara para mantener la interfaz sin ruido visual.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .glassCard(cornerRadius: 28)
    }

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("Informacion principal")

            glassTextField(
                title: "Titulo",
                text: $viewModel.title,
                systemImage: "text.alignleft"
            )

            glassTextField(
                title: "Zona",
                text: $viewModel.zone,
                systemImage: "mappin.and.ellipse"
            )

            glassTextField(
                title: "Precio mensual",
                text: $viewModel.price,
                systemImage: "banknote"
            )
            .keyboardType(.decimalPad)

            VStack(alignment: .leading, spacing: 8) {
                Text("Descripcion")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                ZStack(alignment: .topLeading) {
                    if viewModel.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Describe la habitacion, servicios o normas importantes")
                            .foregroundStyle(.secondary.opacity(0.7))
                            .padding(.horizontal, 18)
                            .padding(.vertical, 16)
                    }

                    TextEditor(text: $viewModel.description)
                        .frame(minHeight: 130)
                        .scrollContentBackground(.hidden)
                        .padding(10)
                }
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

    private var photoSection: some View {
        let hasSelectedPhotos = !viewModel.selectedPhotos.isEmpty
        let hasCurrentPhotos = !viewModel.currentImageUrls.isEmpty
        let imageSymbol = hasSelectedPhotos ? "photo.on.rectangle.angled" : "camera.fill"
        let pickerTitle = hasSelectedPhotos ? "Fotos seleccionadas" : "Toca para añadir fotos"

        return VStack(alignment: .leading, spacing: 14) {
            sectionTitle("Fotos")

            PhotosPicker(
                selection: $viewModel.selectedPhotos,
                maxSelectionCount: 8,
                matching: .images
            ) {
                ZStack {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .frame(height: 220)
                        .overlay(
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .strokeBorder(style: StrokeStyle(lineWidth: 1.2, dash: [7, 6]))
                                .foregroundStyle(Color.white.opacity(0.24))
                        )

                    VStack(spacing: 12) {
                        Image(systemName: imageSymbol)
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(.primary)

                        Text(pickerTitle)
                            .font(.headline)

                        Text("Puedes cargar varias fotos para mostrar sala, cocina, baño o cualquier espacio relevante.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 240)
                    }
                    .padding(20)
                }
            }

            if hasSelectedPhotos || hasCurrentPhotos {
                VStack(alignment: .leading, spacing: 10) {
                    Text(hasSelectedPhotos ? "Fotos a guardar" : "Fotos actuales")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            if !hasSelectedPhotos {
                                ForEach(viewModel.currentImageUrls, id: \.self) { url in
                                    ListingImageView(urlString: url)
                                        .frame(width: 92, height: 92)
                                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                }
                            } else {
                                ForEach(Array(viewModel.selectedPhotos.enumerated()), id: \.offset) { index, _ in
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(.ultraThinMaterial)
                                        .frame(width: 92, height: 92)
                                        .overlay(
                                            VStack(spacing: 6) {
                                                Image(systemName: "photo.fill")
                                                Text("#\(index + 1)")
                                                    .font(.caption.weight(.semibold))
                                            }
                                            .foregroundStyle(.primary)
                                        )
                                }
                            }
                        }
                    }

                    if hasSelectedPhotos {
                        Label("Se reemplazara la galeria actual al guardar", systemImage: "sparkles")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(20)
        .glassCard(cornerRadius: 28)
    }

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("Etiquetas de espacios")

            Text("Marca los ambientes que aparecen en la publicación para que se entienda mejor la distribución.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            FlowTagsView(
                tags: viewModel.availableTagOptions,
                selectedTags: Binding(
                    get: { Set(viewModel.selectedTagValues) },
                    set: { newValue in
                        viewModel.features.tags = Array(newValue).sorted()
                    }
                ),
                onToggle: { viewModel.toggleTag($0) }
            )

            HStack(spacing: 12) {
                glassTextField(
                    title: "Etiqueta personalizada",
                    text: $viewModel.customTag,
                    systemImage: "tag.fill"
                )
                .frame(maxWidth: .infinity)

                Button {
                    viewModel.addCustomTag()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 46, height: 46)
                        .foregroundStyle(.white)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }

            if !viewModel.selectedTagValues.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.selectedTagValues, id: \.self) { tag in
                            HStack(spacing: 6) {
                                Text(tag)
                                    .font(.caption.weight(.semibold))
                                Button {
                                    viewModel.toggleTag(tag)
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.caption2.weight(.bold))
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.accentColor.opacity(0.12), in: Capsule())
                            .overlay(
                                Capsule().stroke(Color.white.opacity(0.16), lineWidth: 1)
                            )
                        }
                    }
                }
            }
        }
        .padding(20)
        .glassCard(cornerRadius: 28)
    }

    private var amenitiesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("Comodidades")

            VStack(spacing: 12) {
                glassToggle(title: "WiFi", isOn: $viewModel.features.hasWifi, symbol: "wifi")
                glassToggle(title: "Baño privado", isOn: $viewModel.features.hasPrivateBathroom, symbol: "shower")
                glassToggle(title: "Camara de seguridad", isOn: $viewModel.features.hasSecurityCameras, symbol: "camera.viewfinder")
                glassToggle(title: "Cama compartida", isOn: $viewModel.features.isSharedBed, symbol: "bed.double")
                glassToggle(title: "Cocina", isOn: $viewModel.features.hasKitchen, symbol: "fork.knife")
                glassToggle(title: "Lavadora", isOn: $viewModel.features.hasWashingMachine, symbol: "washer")
            }
        }
        .padding(20)
        .glassCard(cornerRadius: 28)
    }

    private var destructiveSection: some View {
        Group {
            if viewModel.isEditing {
                Button(role: .destructive) {
                    Task {
                        if await viewModel.delete() {
                            onDeleted?()
                            dismiss()
                        }
                    }
                } label: {
                    Text("Eliminar publicacion")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                }
                .padding(.horizontal, 2)
                .padding(.top, 4)
                .glassCard(cornerRadius: 20)
            }
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(.primary)
    }

    private func glassTextField(title: String, text: Binding<String>, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 18)

                TextField(title, text: text)
                    .textInputAutocapitalization(.sentences)
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

    private func glassToggle(title: String, isOn: Binding<Bool>, symbol: String) -> some View {
        Toggle(isOn: isOn) {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.medium))
        }
        .tint(.accentColor)
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
    }

    private var canSave: Bool {
        !viewModel.title.isEmpty && !viewModel.zone.isEmpty && !viewModel.price.isEmpty
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }
}

private struct FlowTagsView: View {
    let tags: [String]
    let selectedTags: Binding<Set<String>>
    let onToggle: (String) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 108), spacing: 10)], spacing: 10) {
            ForEach(tags, id: \.self) { tag in
                Button {
                    onToggle(tag)
                } label: {
                    Text(tag)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .foregroundStyle(isSelected(tag) ? .white : .primary)
                        .background(isSelected(tag) ? Color.accentColor : Color.primary.opacity(0.04), in: Capsule())
                        .overlay(
                            Capsule().stroke(Color.white.opacity(isSelected(tag) ? 0.18 : 0.12), lineWidth: 1)
                        )
                }
            }
        }
    }

    private func isSelected(_ tag: String) -> Bool {
        selectedTags.wrappedValue.contains(tag)
    }
}

struct EditListingView: View {
    let listing: Listing
    var onSaved: ((Listing) -> Void)? = nil
    var onDeleted: (() -> Void)? = nil

    var body: some View {
        PublishListingView(listing: listing, onSaved: onSaved, onDeleted: onDeleted)
    }
}

import PhotosUI
import SwiftUI

struct PublishListingView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authViewModel: AuthViewModel
    @StateObject private var viewModel: PublishListingViewModel

    init(listing: Listing? = nil) {
        _viewModel = StateObject(wrappedValue: PublishListingViewModel(listing: listing))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Informacion") {
                    TextField("Titulo", text: $viewModel.title)
                    TextField("Zona", text: $viewModel.zone)
                    TextField("Precio mensual", text: $viewModel.price)
                    TextField("Descripcion", text: $viewModel.description, axis: .vertical)
                        .lineLimit(4...8)
                }

                Section("Imagen") {
                    PhotosPicker(selection: $viewModel.selectedPhoto, matching: .images) {
                        Label("Seleccionar imagen", systemImage: "photo.badge.plus")
                    }

                    if viewModel.selectedPhoto != nil {
                        Label("Imagen lista para subir", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }

                Section("Comodidades") {
                    Toggle("WiFi", isOn: $viewModel.features.hasWifi)
                    Toggle("Bano privado", isOn: $viewModel.features.hasPrivateBathroom)
                    Toggle("Camara de seguridad", isOn: $viewModel.features.hasSecurityCameras)
                    Toggle("Cama compartida", isOn: $viewModel.features.isSharedBed)
                    Toggle("Cocina", isOn: $viewModel.features.hasKitchen)
                    Toggle("Lavadora", isOn: $viewModel.features.hasWashingMachine)
                }

                if viewModel.isEditing {
                    Section {
                        Button("Eliminar publicacion", role: .destructive) {
                            Task {
                                if await viewModel.delete() {
                                    dismiss()
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(viewModel.isEditing ? "Editar" : "Publicar")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            if await viewModel.save(ownerId: authViewModel.currentUser?.id) {
                                dismiss()
                            }
                        }
                    } label: {
                        if viewModel.isLoading {
                            ProgressView()
                        } else {
                            Text("Guardar")
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

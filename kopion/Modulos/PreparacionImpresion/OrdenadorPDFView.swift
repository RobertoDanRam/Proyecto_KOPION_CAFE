//
//  OrdenadorPDFView.swift
//  kopion / Modulos / PreparacionImpresion
//
//  Miniaturas de páginas PDF: reordenar arrastrando, eliminar con confirmación y deshacer.
//

import SwiftUI

struct OrdenadorPDFView: View {
    @ObservedObject var viewModel: PrintPreparationViewModel
    let idDocumento: UUID
    @Environment(\.dismiss) private var cerrar

    /// Historial de estados anteriores para deshacer (máximo 10 pasos).
    @State private var historial: [[PaginaPDF]] = []
    /// Página pendiente de confirmar eliminación.
    @State private var paginaAEliminar: PaginaPDF?

    private var indiceDoc: Int? {
        viewModel.documentos.firstIndex { $0.id == idDocumento }
    }

    private var paginas: [PaginaPDF] {
        indiceDoc.map { viewModel.documentos[$0].paginas } ?? []
    }

    var body: some View {
        NavigationStack {
            Group {
                if !paginas.isEmpty {
                    List {
                        Section {
                            HStack(spacing: 6) {
                                Image(systemName: "hand.draw")
                                    .foregroundStyle(.secondary)
                                Text("Arrastra para reordenar · Desliza para eliminar")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        ForEach(paginas) { pagina in
                            FilaPaginaView(pagina: pagina, nombreDoc: indiceDoc.map { viewModel.documentos[$0].nombre } ?? "")
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        paginaAEliminar = pagina
                                    } label: {
                                        Label("Eliminar", systemImage: "trash")
                                    }
                                }
                        }
                        .onMove { origen, destino in
                            guardarHistorial()
                            guard let idx = indiceDoc else { return }
                            viewModel.documentos[idx].paginas.move(fromOffsets: origen, toOffset: destino)
                            Task { await viewModel.regenerarPDFOrdenado(idDocumento: idDocumento) }
                        }
                    }
                    .environment(\.editMode, .constant(.active))
                } else {
                    ContentUnavailableView(
                        "Sin páginas",
                        systemImage: "doc.badge.questionmark",
                        description: Text("El PDF no tiene páginas para mostrar.")
                    )
                }
            }
            .navigationTitle("Ordenar páginas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Deshacer último movimiento.
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        deshacerUltimoCambio()
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                    }
                    .disabled(historial.isEmpty)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { cerrar() }
                }
            }
            // Confirmación de eliminación.
            .confirmationDialog(
                "¿Eliminar esta página?",
                isPresented: Binding(
                    get: { paginaAEliminar != nil },
                    set: { if !$0 { paginaAEliminar = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Eliminar página", role: .destructive) {
                    if let pagina = paginaAEliminar {
                        eliminarPagina(pagina)
                    }
                    paginaAEliminar = nil
                }
                Button("Cancelar", role: .cancel) {
                    paginaAEliminar = nil
                }
            } message: {
                Text("Esta acción no se puede deshacer automáticamente, pero puedes usar el botón ← para revertir.")
            }
        }
    }

    // MARK: - Acciones

    private func guardarHistorial() {
        guard let idx = indiceDoc else { return }
        historial.append(viewModel.documentos[idx].paginas)
        if historial.count > 10 { historial.removeFirst() }
    }

    private func eliminarPagina(_ pagina: PaginaPDF) {
        guardarHistorial()
        guard let idx = indiceDoc else { return }
        viewModel.documentos[idx].paginas.removeAll { $0.id == pagina.id }
        Task { await viewModel.regenerarPDFOrdenado(idDocumento: idDocumento) }
    }

    private func deshacerUltimoCambio() {
        guard let idx = indiceDoc, let anterior = historial.popLast() else { return }
        viewModel.documentos[idx].paginas = anterior
        Task { await viewModel.regenerarPDFOrdenado(idDocumento: idDocumento) }
    }
}

// MARK: - Fila de página

private struct FilaPaginaView: View {
    let pagina: PaginaPDF
    let nombreDoc: String

    var body: some View {
        HStack(spacing: 14) {
            Group {
                if let img = pagina.miniatura {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                } else {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .overlay(Image(systemName: "doc").foregroundStyle(.secondary))
                }
            }
            .frame(width: 52, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .shadow(radius: 2)

            VStack(alignment: .leading, spacing: 4) {
                Text("Página \(pagina.indiceOriginal + 1)")
                    .font(.subheadline.weight(.medium))
                Text(nombreDoc)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}

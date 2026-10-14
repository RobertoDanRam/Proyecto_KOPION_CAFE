//
//  PrintPreparationView.swift
//  kopion / Modules / PrintPreparation
//
//  Módulo 1: Conversión de archivos y preparación de impresión.
//  Muestra la cola de documentos, reglas de conversión activas y el botón de fusión.
//  El botón "Unir PDFs" se deshabilita mientras isSubmitting sea true.
//

import Combine
import SwiftUI

struct PrintPreparationView: View {
    @StateObject private var viewModel = PrintPreparationViewModel()

    var body: some View {
        List {

            // MARK: Reglas de conversión activas
            Section("Conversión y reglas PDF") {
                ModuleRow(title: "Word, JPG y PNG a PDF", detail: "Preparación nativa para imprimir sin retrabajos", systemImage: "doc.richtext", tint: .blue)
                ModuleRow(title: "Páginas blancas", detail: "Conteo y eliminación automática registrada", systemImage: "doc.text.magnifyingglass", tint: .orange)
                ModuleRow(title: "Canvas de imágenes", detail: "Base para redimensionar imágenes antes de imprimir", systemImage: "rectangle.and.hand.point.up.left", tint: .purple)
                ModuleRow(title: "Compresión", detail: "Reduce archivos pesados antes de enviarlos a impresora", systemImage: "arrow.down.doc", tint: .green)
            }

            // MARK: Cola de documentos
            Section("Documentos en cola") {
                if viewModel.isLoading { ProgressView() }

                ForEach(viewModel.documents) { document in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(document.fileName).font(.headline)
                        Text("\(document.sourceType) · \(document.pageCount) páginas · repetir \(document.repeatCopies)x")
                            .font(.subheadline).foregroundStyle(.secondary)
                        Text("Blancas removidas: \(document.blankPagesRemoved) · Tamaño: \(document.compressedSizeInMB, specifier: "%.1f") MB")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

            // MARK: Fusión de PDFs
            Section("Fusión") {
                // Botón deshabilitado mientras isSubmitting para evitar doble fusión.
                Button {
                    viewModel.mergeDocuments()
                } label: {
                    Label(
                        viewModel.isSubmitting ? "Fusionando…" : "Unir PDFs",
                        systemImage: "doc.on.doc"
                    )
                }
                .disabled(viewModel.isSubmitting || viewModel.documents.isEmpty)

                if viewModel.isSubmitting {
                    ProgressView("Preparando archivo")
                }

                if let merged = viewModel.mergedDocument {
                    ModuleRow(
                        title: merged.fileName,
                        detail: "\(merged.pageCount) páginas listas para imprimir",
                        systemImage: "checkmark.seal",
                        tint: .green
                    )
                }
            }
        }
        .navigationTitle("PDF e impresión")
        .task { viewModel.load() }
        .onDisappear { viewModel.cancel() }
    }
}

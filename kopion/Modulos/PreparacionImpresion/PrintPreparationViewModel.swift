//
//  PrintPreparationViewModel.swift
//  kopion / Modules / PrintPreparation
//
//  Lógica del módulo de conversión de archivos y preparación de impresión.
//  Gestiona la cola de documentos, la fusión de PDFs y el respeto de copias repetidas.
//  isSubmitting bloquea el botón "Unir PDFs" para evitar fusiones duplicadas.
//

import Combine
import Foundation

/// ViewModel del módulo de conversión, canvas y preparación de impresión.
@MainActor
final class PrintPreparationViewModel: LoadableViewModel {

    // MARK: - Estado publicado

    /// Documentos en cola (Word, JPG, PNG ya convertidos o PDFs recibidos).
    @Published private(set) var documents: [PrintDocument] = []

    /// Resultado de la fusión: un solo PDF listo para imprimir.
    @Published private(set) var mergedDocument: PrintDocument?

    // MARK: - Dependencias

    private let service: PrintPreparationServicing
    private var task: Task<Void, Never>?

    // MARK: - Init

    override init() {
        self.service = PrintPreparationService()
        super.init()
    }

    init(service: PrintPreparationServicing) {
        self.service = service
        super.init()
    }

    // MARK: - Acciones

    /// Carga documentos en cola. Ignora llamadas mientras haya una Task activa.
    func load() {
        guard task == nil else { return }
        isLoading = true
        errorMessage = nil

        task = Task {
            do {
                documents = try await service.fetchDocuments()
            } catch is CancellationError {
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
            task = nil
        }
    }

    /// Fusiona todos los documentos en un solo PDF respetando repeatCopies.
    /// isSubmitting bloquea el botón para evitar fusiones simultáneas.
    func mergeDocuments() {
        guard !isSubmitting else { return }
        isSubmitting = true
        errorMessage = nil

        Task {
            do {
                mergedDocument = try await service.prepareMergedPDF(documents: documents)
            } catch {
                errorMessage = error.localizedDescription
            }
            isSubmitting = false
        }
    }

    /// Cancela la carga activa al salir de pantalla.
    func cancel() {
        task?.cancel()
        task = nil
        isLoading = false
    }
}

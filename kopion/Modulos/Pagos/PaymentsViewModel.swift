//
//  PaymentsViewModel.swift
//  kopion / Modules / Payments
//
//  Lógica del módulo de gestión de pagos y conciliación manual.
//  Fase 1: los pagos se validan manualmente vinculando capturas de transferencias o vouchers al folio.
//

import Combine
import Foundation

/// ViewModel de pagos: conciliación manual de transferencias y vouchers por folio de venta.
@MainActor
final class PaymentsViewModel: LoadableViewModel {

    // MARK: - Estado publicado

    /// Conciliaciones pendientes o ya vinculadas a un folio de venta.
    @Published private(set) var reconciliations: [PaymentReconciliation] = []

    // MARK: - Dependencias

    private let service: PaymentServicing
    private var task: Task<Void, Never>?

    // MARK: - Init

    override init() {
        self.service = PaymentService()
        super.init()
    }

    init(service: PaymentServicing) {
        self.service = service
        super.init()
    }

    // MARK: - Acciones

    /// Carga conciliaciones. Ignora llamadas duplicadas.
    func load() {
        guard task == nil else { return }
        isLoading = true
        errorMessage = nil

        task = Task {
            do {
                reconciliations = try await service.fetchReconciliations()
            } catch is CancellationError {
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
            task = nil
        }
    }

    /// Cancela la carga activa al salir de pantalla.
    func cancel() {
        task?.cancel()
        task = nil
        isLoading = false
    }
}

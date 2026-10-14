//
//  CustomerPortalViewModel.swift
//  kopion / Modules / CustomerPortal
//
//  Lógica del portal cliente (CRM y tienda digital).
//  Carga en paralelo las promociones del carrusel y los pedidos/trabajos del cliente.
//

import Combine
import Foundation

/// ViewModel del portal cliente: promociones, tienda digital y seguimiento de pedidos.
@MainActor
final class CustomerPortalViewModel: LoadableViewModel {

    // MARK: - Estado publicado

    /// Textos del carrusel de promociones gestionado por la dueña.
    @Published private(set) var promotions: [String] = []

    /// Pedidos y trabajos especiales visibles para el cliente.
    @Published private(set) var workOrders: [WorkOrder] = []

    // MARK: - Dependencias

    private let service: CustomerPortalServicing
    private var task: Task<Void, Never>?

    // MARK: - Init

    override init() {
        self.service = CustomerPortalService()
        super.init()
    }

    init(service: CustomerPortalServicing) {
        self.service = service
        super.init()
    }

    // MARK: - Acciones

    /// Carga promociones y pedidos en paralelo. Ignora llamadas duplicadas.
    func load() {
        guard task == nil else { return }
        isLoading = true
        errorMessage = nil

        task = Task {
            do {
                async let promotions = service.fetchPromotions()
                async let workOrders = service.fetchWorkOrders()
                self.promotions = try await promotions
                self.workOrders = try await workOrders
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

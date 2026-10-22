//
//  CustomerPortalViewModel.swift
//  kopion / Modulos / PortalCliente
//
//  Lógica del portal cliente: promociones, tienda digital y seguimiento de pedidos.
//

import Combine
import Foundation

@MainActor
final class CustomerPortalViewModel: LoadableViewModel {

    @Published private(set) var promociones: [String] = []
    @Published private(set) var ordenesTrabajo: [WorkOrder] = []

    private let servicio: CustomerPortalServicing
    private var tarea: Task<Void, Never>?

    override init() {
        self.servicio = CustomerPortalService()
        super.init()
    }

    init(servicio: CustomerPortalServicing) {
        self.servicio = servicio
        super.init()
    }

    func cargar() {
        guard tarea == nil else { return }
        estaCargando = true
        mensajeError = nil

        tarea = Task {
            do {
                async let promociones = servicio.fetchPromotions()
                async let ordenes = servicio.fetchWorkOrders()
                self.promociones = try await promociones
                self.ordenesTrabajo = try await ordenes
            } catch is CancellationError {
            } catch {
                mensajeError = error.localizedDescription
            }
            estaCargando = false
            tarea = nil
        }
    }

    func cancelar() {
        tarea?.cancel()
        tarea = nil
        estaCargando = false
    }
}

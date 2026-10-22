//
//  PaymentsViewModel.swift
//  kopion / Modulos / Pagos
//
//  Lógica del módulo de gestión de pagos y conciliación manual.
//

import Combine
import Foundation

@MainActor
final class PaymentsViewModel: LoadableViewModel {

    @Published private(set) var conciliaciones: [PaymentReconciliation] = []

    private let servicio: PaymentServicing
    private var tarea: Task<Void, Never>?

    override init() {
        self.servicio = PaymentService()
        super.init()
    }

    init(servicio: PaymentServicing) {
        self.servicio = servicio
        super.init()
    }

    func cargar() {
        guard tarea == nil else { return }
        estaCargando = true
        mensajeError = nil

        tarea = Task {
            do {
                conciliaciones = try await servicio.fetchReconciliations()
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

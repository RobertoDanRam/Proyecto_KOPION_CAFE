//
//  AdminDashboardViewModel.swift
//  kopion / Modulos / PanelAdministrador
//
//  Lógica del dashboard administrativo.
//  Carga en paralelo el snapshot de ventas/caja y los productos con stock bajo.
//

import Combine
import Foundation

@MainActor
final class AdminDashboardViewModel: LoadableViewModel {

    @Published private(set) var resumen: AdminDashboardSnapshot?
    @Published private(set) var productosStockBajo: [Product] = []

    private let servicioAnalitica: AnalyticsServicing
    private var tareaActiva: Task<Void, Never>?

    override init() {
        self.servicioAnalitica = AnalyticsService()
        super.init()
    }

    init(servicioAnalitica: AnalyticsServicing) {
        self.servicioAnalitica = servicioAnalitica
        super.init()
    }

    func cargar() {
        guard tareaActiva == nil else { return }
        estaCargando = true
        mensajeError = nil

        tareaActiva = Task {
            do {
                async let resumen = servicioAnalitica.fetchDashboardSnapshot()
                async let stockBajo = servicioAnalitica.fetchLowStockProducts()
                self.resumen = try await resumen
                self.productosStockBajo = try await stockBajo
            } catch is CancellationError {
            } catch {
                self.mensajeError = error.localizedDescription
            }
            self.estaCargando = false
            self.tareaActiva = nil
        }
    }

    func cancelar() {
        tareaActiva?.cancel()
        tareaActiva = nil
        estaCargando = false
    }
}

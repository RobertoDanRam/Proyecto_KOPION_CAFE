//
//  AnalyticsViewModel.swift
//  kopion / Modulos / Analitica
//
//  Lógica del módulo de analítica, alertas y machine learning de tóner/stock.
//

import Combine
import Foundation

@MainActor
final class AnalyticsViewModel: LoadableViewModel {

    @Published private(set) var resumen: AdminDashboardSnapshot?
    @Published private(set) var productosStockBajo: [Product] = []

    private let servicio: AnalyticsServicing
    private var tareaActiva: Task<Void, Never>?

    override init() {
        self.servicio = AnalyticsService()
        super.init()
    }

    init(servicio: AnalyticsServicing) {
        self.servicio = servicio
        super.init()
    }

    func cargar() {
        guard tareaActiva == nil else { return }
        estaCargando = true
        mensajeError = nil

        tareaActiva = Task {
            do {
                async let resumen = servicio.fetchDashboardSnapshot()
                async let stockBajo = servicio.fetchLowStockProducts()
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

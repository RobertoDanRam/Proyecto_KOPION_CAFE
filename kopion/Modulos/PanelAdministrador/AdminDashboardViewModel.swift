//
//  AdminDashboardViewModel.swift
//  kopion / Modules / Dashboard
//
//  Lógica del dashboard administrativo.
//  Carga en paralelo el snapshot de ventas/caja y los productos con stock bajo.
//  Usa una sola Task para evitar cargas duplicadas y la cancela al salir de pantalla.
//

import Combine
import Foundation

/// ViewModel del dashboard administrativo.
/// Prioridades: ventas del día, caja, pedidos pendientes, alertas de stock y tóner.
@MainActor
final class AdminDashboardViewModel: LoadableViewModel {

    // MARK: - Estado publicado

    /// Resumen del día: ventas, caja, trabajos pendientes, top productos.
    @Published private(set) var snapshot: AdminDashboardSnapshot?

    /// Productos por debajo de su punto de reorden en cualquier sucursal.
    @Published private(set) var lowStockProducts: [Product] = []

    // MARK: - Dependencias

    private let analyticsService: AnalyticsServicing

    /// Task activa de carga. nil = no hay carga en curso.
    private var loadTask: Task<Void, Never>?

    // MARK: - Init

    override init() {
        self.analyticsService = AnalyticsService()
        super.init()
    }

    init(analyticsService: AnalyticsServicing) {
        self.analyticsService = analyticsService
        super.init()
    }

    // MARK: - Acciones

    /// Carga snapshot y stock bajo en paralelo.
    /// Si ya hay una Task activa, ignora la llamada (protección contra doble carga).
    func load() {
        guard loadTask == nil else { return }
        isLoading = true
        errorMessage = nil

        loadTask = Task {
            do {
                async let snapshot = analyticsService.fetchDashboardSnapshot()
                async let lowStock = analyticsService.fetchLowStockProducts()
                self.snapshot = try await snapshot
                self.lowStockProducts = try await lowStock
            } catch is CancellationError {
                // Cancelación limpia: no mostrar error al usuario.
            } catch {
                self.errorMessage = error.localizedDescription
            }
            self.isLoading = false
            self.loadTask = nil
        }
    }

    /// Cancela la carga activa. Llamar desde .onDisappear para ciclo de vida limpio.
    func cancel() {
        loadTask?.cancel()
        loadTask = nil
        isLoading = false
    }
}

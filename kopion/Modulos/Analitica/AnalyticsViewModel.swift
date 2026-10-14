//
//  AnalyticsViewModel.swift
//  kopion / Modules / Analytics
//
//  Lógica del módulo de analítica, alertas y machine learning de tóner/stock.
//  Reutiliza AnalyticsService para proyecciones de agotamiento y semáforo operativo.
//

import Combine
import Foundation

/// ViewModel del módulo de analítica: tóner, stock bajo, proyecciones y alertas.
@MainActor
final class AnalyticsViewModel: LoadableViewModel {

    // MARK: - Estado publicado

    /// Snapshot con conteos de alertas de tóner y stock bajo.
    @Published private(set) var snapshot: AdminDashboardSnapshot?

    /// Productos que requieren resurtido en alguna sucursal.
    @Published private(set) var lowStockProducts: [Product] = []

    // MARK: - Dependencias

    private let service: AnalyticsServicing
    private var loadTask: Task<Void, Never>?

    // MARK: - Init

    override init() {
        self.service = AnalyticsService()
        super.init()
    }

    init(service: AnalyticsServicing) {
        self.service = service
        super.init()
    }

    // MARK: - Acciones

    /// Carga snapshot y productos con stock bajo en paralelo.
    func load() {
        guard loadTask == nil else { return }
        isLoading = true
        errorMessage = nil

        loadTask = Task {
            do {
                async let snapshot = service.fetchDashboardSnapshot()
                async let lowStock = service.fetchLowStockProducts()
                self.snapshot = try await snapshot
                self.lowStockProducts = try await lowStock
            } catch is CancellationError {
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
            loadTask = nil
        }
    }

    /// Cancela la carga activa al salir de pantalla.
    func cancel() {
        loadTask?.cancel()
        loadTask = nil
        isLoading = false
    }
}

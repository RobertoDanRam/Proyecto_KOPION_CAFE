//
//  OperationsViewModel.swift
//  kopion / Modules / Operations
//
//  Lógica del módulo de recepción de mercancía, RRHH y comunicación interna.
//  Carga en paralelo el checklist de limpieza y las peticiones de insumos.
//

import Combine
import Foundation

/// ViewModel de operaciones internas: limpieza, insumos, vales, checador y recepción.
@MainActor
final class OperationsViewModel: LoadableViewModel {

    // MARK: - Estado publicado

    /// Tareas de limpieza con evidencia fotográfica por turno y sucursal.
    @Published private(set) var cleaningTasks: [CleaningTask] = []

    /// Peticiones de insumos internos con nivel de urgencia y aprobación de la dueña.
    @Published private(set) var supplyRequests: [InternalSupplyRequest] = []

    // MARK: - Dependencias

    private let service: OperationsServicing
    private var task: Task<Void, Never>?

    // MARK: - Init

    override init() {
        self.service = OperationsService()
        super.init()
    }

    init(service: OperationsServicing) {
        self.service = service
        super.init()
    }

    // MARK: - Acciones

    /// Carga limpieza e insumos en paralelo. Ignora llamadas duplicadas.
    func load() {
        guard task == nil else { return }
        isLoading = true
        errorMessage = nil

        task = Task {
            do {
                async let cleaning = service.fetchCleaningTasks()
                async let supplies = service.fetchSupplyRequests()
                cleaningTasks = try await cleaning
                supplyRequests = try await supplies
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

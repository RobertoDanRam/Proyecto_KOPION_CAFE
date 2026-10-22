//
//  OperationsViewModel.swift
//  kopion / Modulos / Operaciones
//
//  Lógica del módulo de recepción de mercancía, RRHH y comunicación interna.
//

import Combine
import Foundation

@MainActor
final class OperationsViewModel: LoadableViewModel {

    @Published private(set) var tareasLimpieza: [CleaningTask] = []
    @Published private(set) var solicitudesInsumos: [InternalSupplyRequest] = []

    private let servicio: OperationsServicing
    private var tarea: Task<Void, Never>?

    override init() {
        self.servicio = OperationsService()
        super.init()
    }

    init(servicio: OperationsServicing) {
        self.servicio = servicio
        super.init()
    }

    func cargar() {
        guard tarea == nil else { return }
        estaCargando = true
        mensajeError = nil

        tarea = Task {
            do {
                async let limpieza = servicio.fetchCleaningTasks()
                async let insumos = servicio.fetchSupplyRequests()
                tareasLimpieza = try await limpieza
                solicitudesInsumos = try await insumos
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

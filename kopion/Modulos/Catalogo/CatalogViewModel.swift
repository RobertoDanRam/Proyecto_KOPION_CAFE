//
//  CatalogViewModel.swift
//  kopion / Modulos / Catalogo
//
//  Lógica del catálogo centralizado con búsqueda debounced (Combine).
//  El pipeline espera 0.5 s después del último carácter antes de consultar.
//

import Combine
import Foundation

@MainActor
final class CatalogViewModel: LoadableViewModel {

    @Published var sucursalSeleccionada: Branch = .kopionESCA
    @Published var textoBusqueda = ""
    @Published private(set) var productos: [Product] = []

    private let servicio: CatalogServicing
    private var suscripciones: Set<AnyCancellable> = []
    private var tareaActiva: Task<Void, Never>?

    override init() {
        self.servicio = CatalogService()
        super.init()
        configurarPipelineBusqueda()
    }

    init(servicio: CatalogServicing) {
        self.servicio = servicio
        super.init()
        configurarPipelineBusqueda()
    }

    func cargar() {
        estaCargando = true
        mensajeError = nil
        tareaActiva?.cancel()

        tareaActiva = Task {
            do {
                productos = try await servicio.fetchProducts()
            } catch is CancellationError {
            } catch {
                mensajeError = error.localizedDescription
            }
            estaCargando = false
        }
    }

    func cancelar() {
        tareaActiva?.cancel()
        tareaActiva = nil
        estaCargando = false
    }

    private func configurarPipelineBusqueda() {
        Publishers.CombineLatest($textoBusqueda, $sucursalSeleccionada)
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
            .sink { [weak self] consulta, sucursal in
                self?.ejecutarBusqueda(consulta: consulta, sucursal: sucursal)
            }
            .store(in: &suscripciones)
    }

    private func ejecutarBusqueda(consulta: String, sucursal: Branch) {
        tareaActiva?.cancel()
        estaCargando = true

        tareaActiva = Task {
            do {
                productos = try await servicio.searchProducts(query: consulta, branch: sucursal)
            } catch is CancellationError {
            } catch {
                mensajeError = error.localizedDescription
            }
            estaCargando = false
        }
    }
}

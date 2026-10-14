//
//  CatalogViewModel.swift
//  kopion / Modules / Catalog
//
//  Lógica del catálogo centralizado con búsqueda debounced (Combine).
//  El pipeline de búsqueda espera 0.5 s después del último carácter antes de consultar,
//  y cancela la Task anterior si el usuario sigue escribiendo.
//

import Combine
import Foundation

/// ViewModel del catálogo: productos, precios y stock por sucursal con búsqueda debounced.
@MainActor
final class CatalogViewModel: LoadableViewModel {

    // MARK: - Estado publicado

    /// Sucursal activa. Cambia precios y stock mostrados.
    @Published var selectedBranch: Branch = .kopionESCA

    /// Texto del campo de búsqueda. El pipeline Combine reacciona a sus cambios.
    @Published var searchText = ""

    /// Lista de productos filtrada por sucursal y texto de búsqueda.
    @Published private(set) var products: [Product] = []

    // MARK: - Dependencias

    private let service: CatalogServicing
    private var cancellables: Set<AnyCancellable> = []

    /// Task de búsqueda activa. Se cancela antes de iniciar una nueva.
    private var searchTask: Task<Void, Never>?

    // MARK: - Init

    override init() {
        self.service = CatalogService()
        super.init()
        configureSearchPipeline()
    }

    init(service: CatalogServicing) {
        self.service = service
        super.init()
        configureSearchPipeline()
    }

    // MARK: - Acciones

    /// Carga inicial del catálogo completo para la sucursal seleccionada.
    func load() {
        isLoading = true
        errorMessage = nil
        searchTask?.cancel()

        searchTask = Task {
            do {
                products = try await service.fetchProducts()
            } catch is CancellationError {
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    /// Cancela la búsqueda activa al salir de pantalla.
    func cancel() {
        searchTask?.cancel()
        searchTask = nil
        isLoading = false
    }

    // MARK: - Pipeline Combine

    /// Debounce de 0.5 s sobre texto y sucursal para no saturar búsquedas mientras se escribe.
    private func configureSearchPipeline() {
        Publishers.CombineLatest($searchText, $selectedBranch)
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
            .sink { [weak self] query, branch in
                self?.performSearch(query: query, branch: branch)
            }
            .store(in: &cancellables)
    }

    /// Cancela la Task anterior y lanza una nueva búsqueda.
    private func performSearch(query: String, branch: Branch) {
        searchTask?.cancel()
        isLoading = true

        searchTask = Task {
            do {
                products = try await service.searchProducts(query: query, branch: branch)
            } catch is CancellationError {
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

//
//  ModuleViewModels.swift
//  kopion
//
//  ViewModels MVVM para todos los modulos iniciales.
//  Cada ViewModel conserva estado de carga, errores visibles y tareas cancelables
//  para evitar duplicados, dobles taps y trabajo asincrono vivo fuera de pantalla.
//

import Combine
import Foundation

/// Base sencilla para compartir estado de carga y mensajes de error entre ViewModels.
@MainActor
class LoadableViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var isSubmitting = false
    @Published var errorMessage: String?

    func clearError() {
        errorMessage = nil
    }
}

/// Dashboard administrativo con prioridades altas, medias y bajas.
@MainActor
final class AdminDashboardViewModel: LoadableViewModel {
    @Published private(set) var snapshot: AdminDashboardSnapshot?
    @Published private(set) var lowStockProducts: [Product] = []

    private let analyticsService: AnalyticsServicing
    private var loadTask: Task<Void, Never>?

    init(analyticsService: AnalyticsServicing = AnalyticsService()) {
        self.analyticsService = analyticsService
    }

    /// Carga ventas del dia, caja, trabajos pendientes y alertas de stock/toner.
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
                self.errorMessage = nil
            } catch {
                self.errorMessage = error.localizedDescription
            }

            self.isLoading = false
            self.loadTask = nil
        }
    }

    func cancel() {
        loadTask?.cancel()
        loadTask = nil
        isLoading = false
    }
}

/// ViewModel del modulo de conversion, canvas y preparacion de impresion.
@MainActor
final class PrintPreparationViewModel: LoadableViewModel {
    @Published private(set) var documents: [PrintDocument] = []
    @Published private(set) var mergedDocument: PrintDocument?

    private let service: PrintPreparationServicing
    private var task: Task<Void, Never>?

    init(service: PrintPreparationServicing = PrintPreparationService()) {
        self.service = service
    }

    /// Carga documentos enviados a cola y su estado de preparacion.
    func load() {
        guard task == nil else { return }
        isLoading = true
        errorMessage = nil

        task = Task {
            do {
                documents = try await service.fetchDocuments()
            } catch is CancellationError {
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }

            isLoading = false
            task = nil
        }
    }

    /// Fusiona documentos, respeta copias repetidas y conserva una sola accion activa.
    func mergeDocuments() {
        guard !isSubmitting else { return }
        isSubmitting = true
        errorMessage = nil

        Task {
            do {
                mergedDocument = try await service.prepareMergedPDF(documents: documents)
            } catch {
                errorMessage = error.localizedDescription
            }

            isSubmitting = false
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
        isLoading = false
    }
}

/// ViewModel del portal cliente, CRM, promociones y pedidos.
@MainActor
final class CustomerPortalViewModel: LoadableViewModel {
    @Published private(set) var promotions: [String] = []
    @Published private(set) var workOrders: [WorkOrder] = []

    private let service: CustomerPortalServicing
    private var task: Task<Void, Never>?

    init(service: CustomerPortalServicing = CustomerPortalService()) {
        self.service = service
    }

    /// Carga promociones administrables y trabajos del cliente/sucursal.
    func load() {
        guard task == nil else { return }
        isLoading = true
        errorMessage = nil

        task = Task {
            do {
                async let promotions = service.fetchPromotions()
                async let workOrders = service.fetchWorkOrders()
                self.promotions = try await promotions
                self.workOrders = try await workOrders
            } catch is CancellationError {
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }

            isLoading = false
            task = nil
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
        isLoading = false
    }
}

/// ViewModel del catalogo centralizado con busqueda debounced usando Combine.
@MainActor
final class CatalogViewModel: LoadableViewModel {
    @Published var selectedBranch: Branch = .kopionESCA
    @Published var searchText = ""
    @Published private(set) var products: [Product] = []

    private let service: CatalogServicing
    private var cancellables: Set<AnyCancellable> = []
    private var searchTask: Task<Void, Never>?

    init(service: CatalogServicing = CatalogService()) {
        self.service = service
        configureSearchPipeline()
    }

    /// Carga inicial del catalogo completo.
    func load() {
        isLoading = true
        errorMessage = nil

        searchTask?.cancel()
        searchTask = Task {
            do {
                products = try await service.fetchProducts()
            } catch is CancellationError {
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }

            isLoading = false
        }
    }

    /// Configura debounce de 0.5 segundos para no saturar busquedas mientras se escribe.
    private func configureSearchPipeline() {
        Publishers.CombineLatest($searchText, $selectedBranch)
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
            .sink { [weak self] query, branch in
                self?.performSearch(query: query, branch: branch)
            }
            .store(in: &cancellables)
    }

    /// Cancela la busqueda anterior antes de iniciar una nueva.
    private func performSearch(query: String, branch: Branch) {
        searchTask?.cancel()
        isLoading = true

        searchTask = Task {
            do {
                products = try await service.searchProducts(query: query, branch: branch)
            } catch is CancellationError {
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }

            isLoading = false
        }
    }

    func cancel() {
        searchTask?.cancel()
        searchTask = nil
        isLoading = false
    }
}

/// ViewModel del POS de empleados.
@MainActor
final class POSViewModel: LoadableViewModel {
    @Published private(set) var recentSales: [Sale] = []
    @Published var selectedBranch: Branch = .kopionESCA
    @Published var paidAmountText = "100"

    private let service: POSServicing
    private var task: Task<Void, Never>?

    init(service: POSServicing = POSService()) {
        self.service = service
    }

    /// Carga ventas recientes para reimpresion y precorte.
    func load() {
        guard task == nil else { return }
        isLoading = true
        errorMessage = nil

        task = Task {
            do {
                recentSales = try await service.fetchRecentSales()
            } catch is CancellationError {
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }

            isLoading = false
            task = nil
        }
    }

    /// Registra una venta semilla y evita doble cobro con isSubmitting.
    func registerSampleSale() {
        guard !isSubmitting else { return }
        isSubmitting = true
        errorMessage = nil

        Task {
            do {
                let product = SampleData.products[0]
                let sale = Sale(
                    id: UUID(),
                    folio: "V-\(Int.random(in: 3000...9999))",
                    branch: selectedBranch,
                    collaboratorName: "Colaborador",
                    items: [SaleLineItem(id: UUID(), productID: product.id, productName: product.name, branch: selectedBranch, quantity: 1, unitPrice: product.price(for: selectedBranch))],
                    paymentMethod: .cash,
                    paidAmount: Decimal(string: paidAmountText) ?? 0,
                    createdAt: .now
                )
                let savedSale = try await service.registerSale(sale)
                recentSales.insert(savedSale, at: 0)
            } catch {
                errorMessage = error.localizedDescription
            }

            isSubmitting = false
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
        isLoading = false
    }
}

/// ViewModel de recepcion, RRHH, limpieza, insumos y checador.
@MainActor
final class OperationsViewModel: LoadableViewModel {
    @Published private(set) var cleaningTasks: [CleaningTask] = []
    @Published private(set) var supplyRequests: [InternalSupplyRequest] = []

    private let service: OperationsServicing
    private var task: Task<Void, Never>?

    init(service: OperationsServicing = OperationsService()) {
        self.service = service
    }

    /// Carga tareas internas para supervision de sucursales.
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
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }

            isLoading = false
            task = nil
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
        isLoading = false
    }
}

/// ViewModel de gestion de pagos y conciliacion manual.
@MainActor
final class PaymentsViewModel: LoadableViewModel {
    @Published private(set) var reconciliations: [PaymentReconciliation] = []

    private let service: PaymentServicing
    private var task: Task<Void, Never>?

    init(service: PaymentServicing = PaymentService()) {
        self.service = service
    }

    /// Carga evidencias pendientes o conciliadas por folio de venta.
    func load() {
        guard task == nil else { return }
        isLoading = true
        errorMessage = nil

        task = Task {
            do {
                reconciliations = try await service.fetchReconciliations()
            } catch is CancellationError {
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }

            isLoading = false
            task = nil
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
        isLoading = false
    }
}

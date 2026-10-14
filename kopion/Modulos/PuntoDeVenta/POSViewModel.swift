//
//  POSViewModel.swift
//  kopion / Modules / POS
//
//  Lógica del POS exclusivo de empleados.
//  isSubmitting bloquea el botón de cobro para evitar doble registro de ventas.
//  Las ventas recientes permiten reimpresión de tickets y pre-corte de caja.
//

import Combine
import Foundation

/// ViewModel del POS: cobro rápido, ventas recientes, cambios y devoluciones.
@MainActor
final class POSViewModel: LoadableViewModel {

    // MARK: - Estado publicado

    /// Ventas del día para reimpresión de tickets y pre-corte.
    @Published private(set) var recentSales: [Sale] = []

    /// Sucursal activa del empleado en turno.
    @Published var selectedBranch: Branch = .kopionESCA

    /// Monto recibido del cliente (texto para campo numérico táctil).
    @Published var paidAmountText = "100"

    // MARK: - Dependencias

    private let service: POSServicing
    private var task: Task<Void, Never>?

    // MARK: - Init

    override init() {
        self.service = POSService()
        super.init()
    }

    init(service: POSServicing) {
        self.service = service
        super.init()
    }

    // MARK: - Acciones

    /// Carga ventas recientes para reimpresión y pre-corte de caja.
    func load() {
        guard task == nil else { return }
        isLoading = true
        errorMessage = nil

        task = Task {
            do {
                recentSales = try await service.fetchRecentSales()
            } catch is CancellationError {
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
            task = nil
        }
    }

    /// Registra una venta de muestra.
    /// isSubmitting bloquea el botón para evitar doble cobro por doble tap.
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
                    items: [
                        SaleLineItem(
                            id: UUID(),
                            productID: product.id,
                            productName: product.name,
                            branch: selectedBranch,
                            quantity: 1,
                            unitPrice: product.price(for: selectedBranch)
                        )
                    ],
                    paymentMethod: .cash,
                    paidAmount: Decimal(string: paidAmountText) ?? 0,
                    createdAt: .now
                )
                let saved = try await service.registerSale(sale)
                recentSales.insert(saved, at: 0)
            } catch {
                errorMessage = error.localizedDescription
            }
            isSubmitting = false
        }
    }

    /// Cancela la carga activa al salir de pantalla.
    func cancel() {
        task?.cancel()
        task = nil
        isLoading = false
    }
}

//
//  POSViewModel.swift
//  kopion / Modulos / PuntoDeVenta
//
//  Lógica del POS exclusivo de empleados.
//  estaEnviando bloquea el botón de cobro para evitar doble registro de ventas.
//

import Combine
import Foundation

@MainActor
final class POSViewModel: LoadableViewModel {

    @Published private(set) var ventasRecientes: [Sale] = []
    @Published var sucursalSeleccionada: Branch = .kopionESCA
    @Published var textoPagoRecibido = "100"

    private let servicio: POSServicing
    private var tarea: Task<Void, Never>?

    override init() {
        self.servicio = POSService()
        super.init()
    }

    init(servicio: POSServicing) {
        self.servicio = servicio
        super.init()
    }

    func cargar() {
        guard tarea == nil else { return }
        estaCargando = true
        mensajeError = nil

        tarea = Task {
            do {
                ventasRecientes = try await servicio.fetchRecentSales()
            } catch is CancellationError {
            } catch {
                mensajeError = error.localizedDescription
            }
            estaCargando = false
            tarea = nil
        }
    }

    /// Registra una venta de muestra. estaEnviando bloquea el botón para evitar doble cobro.
    func registrarVentaRapida() {
        guard !estaEnviando else { return }
        estaEnviando = true
        mensajeError = nil

        Task {
            do {
                let producto = SampleData.products[0]
                let venta = Sale(
                    id: UUID(),
                    folio: "V-\(Int.random(in: 3000...9999))",
                    branch: sucursalSeleccionada,
                    collaboratorName: "Colaborador",
                    items: [
                        SaleLineItem(
                            id: UUID(),
                            productID: producto.id,
                            productName: producto.name,
                            branch: sucursalSeleccionada,
                            quantity: 1,
                            unitPrice: producto.price(for: sucursalSeleccionada)
                        )
                    ],
                    paymentMethod: .cash,
                    paidAmount: Decimal(string: textoPagoRecibido) ?? 0,
                    createdAt: .now
                )
                let guardada = try await servicio.registerSale(venta)
                ventasRecientes.insert(guardada, at: 0)
            } catch {
                mensajeError = error.localizedDescription
            }
            estaEnviando = false
        }
    }

    func cancelar() {
        tarea?.cancel()
        tarea = nil
        estaCargando = false
    }
}

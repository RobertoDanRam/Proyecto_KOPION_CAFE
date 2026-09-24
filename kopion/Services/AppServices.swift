//
//  AppServices.swift
//  kopion
//
//  Servicios iniciales por modulo.
//  En esta primera etapa entregan datos semilla y simulan latencia de red; mantienen
//  la misma frontera que usaremos despues para Firebase, SQL o APIs propias.
//

import Foundation

/// Utilidad compartida para simular red y respetar cancelacion de tareas.
enum ServiceDelay {
    static func short() async throws {
        try Task.checkCancellation()
        try await Task.sleep(nanoseconds: 250_000_000)
        try Task.checkCancellation()
    }
}

/// Servicio del catalogo centralizado y stock por sucursal.
protocol CatalogServicing: Sendable {
    func fetchProducts() async throws -> [Product]
    func searchProducts(query: String, branch: Branch) async throws -> [Product]
}

/// Implementacion local inicial del catalogo. Sustituible por API sin cambiar ViewModels.
struct CatalogService: CatalogServicing {
    func fetchProducts() async throws -> [Product] {
        try await ServiceDelay.short()
        return SampleData.products
    }

    func searchProducts(query: String, branch: Branch) async throws -> [Product] {
        try await ServiceDelay.short()
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard !normalizedQuery.isEmpty else {
            return SampleData.products.filter { $0.stock(for: branch) > 0 }
        }

        return SampleData.products.filter { product in
            product.normalizedName.contains(normalizedQuery) || product.name.lowercased().contains(normalizedQuery)
        }
    }
}

/// Servicio de preparacion de impresion y conversion de archivos.
protocol PrintPreparationServicing: Sendable {
    func fetchDocuments() async throws -> [PrintDocument]
    func prepareMergedPDF(documents: [PrintDocument]) async throws -> PrintDocument
}

/// Implementacion inicial para flujos PDF: conteo, compresion, remocion de hojas blancas y fusion.
struct PrintPreparationService: PrintPreparationServicing {
    func fetchDocuments() async throws -> [PrintDocument] {
        try await ServiceDelay.short()
        return SampleData.printDocuments
    }

    func prepareMergedPDF(documents: [PrintDocument]) async throws -> PrintDocument {
        try await ServiceDelay.short()
        let pages = documents.reduce(0) { $0 + ($1.pageCount * max($1.repeatCopies, 1)) }
        let removedBlankPages = documents.reduce(0) { $0 + $1.blankPagesRemoved }
        let size = documents.reduce(0.0) { $0 + $1.compressedSizeInMB }

        return PrintDocument(
            id: UUID(),
            fileName: "documentos-unificados.pdf",
            sourceType: "PDF fusionado",
            pageCount: pages,
            blankPagesRemoved: removedBlankPages,
            repeatCopies: 1,
            compressedSizeInMB: max(size * 0.72, 0.1),
            status: .ready
        )
    }
}

/// Servicio del portal cliente, CRM, carrito y pedidos.
protocol CustomerPortalServicing: Sendable {
    func fetchPromotions() async throws -> [String]
    func fetchWorkOrders() async throws -> [WorkOrder]
}

struct CustomerPortalService: CustomerPortalServicing {
    func fetchPromotions() async throws -> [String] {
        try await ServiceDelay.short()
        return [
            "Copias por volumen desde $0.50",
            "Enmicado tamano carta disponible",
            "Agua Wai $32 en ESE Cafe"
        ]
    }

    func fetchWorkOrders() async throws -> [WorkOrder] {
        try await ServiceDelay.short()
        return SampleData.workOrders
    }
}

/// Servicio de analitica, toner, stock bajo y proyecciones.
protocol AnalyticsServicing: Sendable {
    func fetchDashboardSnapshot() async throws -> AdminDashboardSnapshot
    func fetchLowStockProducts() async throws -> [Product]
}

struct AnalyticsService: AnalyticsServicing {
    func fetchDashboardSnapshot() async throws -> AdminDashboardSnapshot {
        try await ServiceDelay.short()
        return SampleData.dashboardSnapshot
    }

    func fetchLowStockProducts() async throws -> [Product] {
        try await ServiceDelay.short()
        return SampleData.products.filter { product in
            Branch.allCases.contains { product.isLowStock(at: $0) }
        }
    }
}

/// Servicio del POS: busqueda, cobro, tickets, cambios y devoluciones.
protocol POSServicing: Sendable {
    func fetchRecentSales() async throws -> [Sale]
    func registerSale(_ sale: Sale) async throws -> Sale
}

struct POSService: POSServicing {
    func fetchRecentSales() async throws -> [Sale] {
        try await ServiceDelay.short()
        return SampleData.sales
    }

    func registerSale(_ sale: Sale) async throws -> Sale {
        try await ServiceDelay.short()
        return sale
    }
}

/// Servicio de RRHH, comunicacion interna, limpieza, checador, vales e insumos.
protocol OperationsServicing: Sendable {
    func fetchCleaningTasks() async throws -> [CleaningTask]
    func fetchSupplyRequests() async throws -> [InternalSupplyRequest]
}

struct OperationsService: OperationsServicing {
    func fetchCleaningTasks() async throws -> [CleaningTask] {
        try await ServiceDelay.short()
        return SampleData.cleaningTasks
    }

    func fetchSupplyRequests() async throws -> [InternalSupplyRequest] {
        try await ServiceDelay.short()
        return SampleData.supplyRequests
    }
}

/// Servicio de conciliacion financiera manual.
protocol PaymentServicing: Sendable {
    func fetchReconciliations() async throws -> [PaymentReconciliation]
}

struct PaymentService: PaymentServicing {
    func fetchReconciliations() async throws -> [PaymentReconciliation] {
        try await ServiceDelay.short()
        return SampleData.paymentReconciliations
    }
}

/// Datos semilla para que todos los modulos tengan informacion desde la primera corrida.
enum SampleData {
    static let products: [Product] = [
        Product(
            id: UUID(),
            name: "USB 16GB",
            normalizedName: "usb 16gb",
            category: "Papeleria",
            barcode: "7500000000016",
            imageURL: nil,
            pricesByBranch: [.kopionESCA: 95, .kopionCECyT1: 92, .cafeESE: 110],
            stockByBranch: [.kopionESCA: 9, .kopionCECyT1: 4, .cafeESE: 2],
            reorderPointByBranch: [.kopionESCA: 5, .kopionCECyT1: 5, .cafeESE: 3],
            lastRestockDate: .now.addingTimeInterval(-86400 * 8)
        ),
        Product(
            id: UUID(),
            name: "Papel bond cuadro chico",
            normalizedName: "papel bond cuadro chico",
            category: "Papel",
            barcode: nil,
            imageURL: nil,
            pricesByBranch: [.kopionESCA: 1.5, .kopionCECyT1: 1.5, .cafeESE: 2],
            stockByBranch: [.kopionESCA: 240, .kopionCECyT1: 80, .cafeESE: 20],
            reorderPointByBranch: [.kopionESCA: 100, .kopionCECyT1: 100, .cafeESE: 25],
            lastRestockDate: .now.addingTimeInterval(-86400 * 3)
        ),
        Product(
            id: UUID(),
            name: "Engargolado",
            normalizedName: "engargolado",
            category: "Servicio",
            barcode: nil,
            imageURL: nil,
            pricesByBranch: [.kopionESCA: 28, .kopionCECyT1: 30, .cafeESE: 35],
            stockByBranch: [.kopionESCA: 50, .kopionCECyT1: 40, .cafeESE: 12],
            reorderPointByBranch: [.kopionESCA: 20, .kopionCECyT1: 20, .cafeESE: 10],
            lastRestockDate: .now.addingTimeInterval(-86400 * 5)
        ),
        Product(
            id: UUID(),
            name: "Agua simple 1L",
            normalizedName: "agua simple litro",
            category: "Cafe",
            barcode: "7500000000111",
            imageURL: nil,
            pricesByBranch: [.kopionESCA: 11, .kopionCECyT1: 11, .cafeESE: 11],
            stockByBranch: [.kopionESCA: 15, .kopionCECyT1: 10, .cafeESE: 42],
            reorderPointByBranch: [.kopionESCA: 8, .kopionCECyT1: 8, .cafeESE: 20],
            lastRestockDate: .now.addingTimeInterval(-86400)
        ),
        Product(
            id: UUID(),
            name: "Agua de sabor Wai",
            normalizedName: "agua sabor wai",
            category: "Cafe",
            barcode: "7500000000320",
            imageURL: nil,
            pricesByBranch: [.kopionESCA: 32, .kopionCECyT1: 32, .cafeESE: 32],
            stockByBranch: [.kopionESCA: 6, .kopionCECyT1: 5, .cafeESE: 18],
            reorderPointByBranch: [.kopionESCA: 6, .kopionCECyT1: 6, .cafeESE: 12],
            lastRestockDate: .now.addingTimeInterval(-86400 * 2)
        )
    ]

    static let printDocuments: [PrintDocument] = [
        PrintDocument(id: UUID(), fileName: "acta.pdf", sourceType: "PDF", pageCount: 2, blankPagesRemoved: 1, repeatCopies: 1, compressedSizeInMB: 0.8, status: .ready),
        PrintDocument(id: UUID(), fileName: "horario.jpg", sourceType: "JPG convertido", pageCount: 1, blankPagesRemoved: 0, repeatCopies: 2, compressedSizeInMB: 0.4, status: .printing),
        PrintDocument(id: UUID(), fileName: "carta.docx", sourceType: "Word convertido", pageCount: 3, blankPagesRemoved: 1, repeatCopies: 1, compressedSizeInMB: 1.1, status: .received)
    ]

    static let workOrders: [WorkOrder] = [
        WorkOrder(id: UUID(), folio: "TR-1001", branch: .kopionESCA, customerName: "Alumno ESCA", status: .printing, documents: [printDocuments[0]], createdAt: .now),
        WorkOrder(id: UUID(), folio: "TR-1002", branch: .kopionCECyT1, customerName: "Profesor CECyT", status: .ready, documents: [printDocuments[1]], createdAt: .now.addingTimeInterval(-3600))
    ]

    static let sales: [Sale] = [
        Sale(
            id: UUID(),
            folio: "V-2041",
            branch: .kopionESCA,
            collaboratorName: "Mostrador 1",
            items: [SaleLineItem(id: UUID(), productID: products[0].id, productName: products[0].name, branch: .kopionESCA, quantity: 1, unitPrice: 95)],
            paymentMethod: .cash,
            paidAmount: 100,
            createdAt: .now
        )
    ]

    static let cleaningTasks: [CleaningTask] = [
        CleaningTask(id: UUID(), title: "Limpiar impresoras", collaboratorName: "Turno matutino", branch: .kopionESCA, shift: .morning, evidenceDescription: "Foto del area enviada", completedAt: .now),
        CleaningTask(id: UUID(), title: "Relleno de hojas", collaboratorName: "Turno vespertino", branch: .kopionCECyT1, shift: .evening, evidenceDescription: "Pendiente de evidencia", completedAt: nil)
    ]

    static let supplyRequests: [InternalSupplyRequest] = [
        InternalSupplyRequest(id: UUID(), itemName: "Toner negro", urgency: .high, branch: .kopionESCA, collaboratorName: "Mostrador 1", shift: .morning, requestedAt: .now, ownerComment: nil, isApproved: nil),
        InternalSupplyRequest(id: UUID(), itemName: "Fabuloso", urgency: .medium, branch: .kopionCECyT1, collaboratorName: "Mostrador 2", shift: .evening, requestedAt: .now.addingTimeInterval(-7200), ownerComment: "Comprar manana", isApproved: true)
    ]

    static let paymentReconciliations: [PaymentReconciliation] = [
        PaymentReconciliation(id: UUID(), saleFolio: "V-2041", branch: .kopionESCA, method: .transfer, evidenceFileName: "transferencia-v2041.png", isMatched: true, createdAt: .now),
        PaymentReconciliation(id: UUID(), saleFolio: "V-2042", branch: .cafeESE, method: .card, evidenceFileName: "voucher-v2042.jpg", isMatched: false, createdAt: .now.addingTimeInterval(-1800))
    ]

    static let dashboardSnapshot = AdminDashboardSnapshot(
        todaySalesAmount: 3842,
        cashInDrawer: 1250,
        pendingBindingJobs: 3,
        lowStockCount: 4,
        tonerAlertCount: 1,
        topProductNames: ["Copias", "Engargolado", "USB 16GB", "Agua Wai", "Papel bond"],
        pendingQuotes: 2
    )
}

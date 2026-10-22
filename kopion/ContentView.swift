//
//  ContentView.swift
//  kopion
//
//  Raíz de navegación de la app.
//  Observa AuthManager.currentUser y decide qué pantalla mostrar:
//  - Sin sesión       → AccesoLoginView
//  - Cliente          → MenuClienteView  (tienda, pedidos, cotizador)
//  - Colaborador      → MenuColaboradorView  (POS, operaciones)
//  - Editor           → MenuEditorView  (catálogo, inventario)
//  - Administrador    → MenuAdminView  (todo + dashboard + finanzas)
//

import SwiftUI

struct ContentView: View {
    // AuthManager se inyecta desde kopionApp como EnvironmentObject.
    @EnvironmentObject private var authManager: AuthManager

    var body: some View {
        // Reacciona automáticamente cada vez que currentUser cambia
        // (login, logout, restauración de sesión al abrir la app).
        Group {
            if let usuario = authManager.usuarioActual {
                // Usuario autenticado: enrutar por rol.
                NavigationStack {
                    vistaRaiz(para: usuario)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Salir") {
                                    try? authManager.cerrarSesion()
                                }
                                .foregroundStyle(.red)
                            }
                        }
                }
            } else {
                // Sin sesión: mostrar login.
                NavigationStack {
                    AccesoLoginView()
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authManager.usuarioActual != nil)
    }

    // MARK: - Enrutador por rol

    /// Devuelve la vista raíz correcta según el rol del perfil de Firestore.
    @ViewBuilder
    private func vistaRaiz(para usuario: UserProfile) -> some View {
        switch usuario.rol {
        case .administrador: MenuAdminView(user: usuario)
        case .editor:        MenuEditorView(user: usuario)
        case .colaborador:   MenuColaboradorView(user: usuario)
        case .cliente:       MenuClienteView(user: usuario)
        }
    }
}

// MARK: - Menú Administrador

/// Acceso total: dashboard, POS, catálogo, operaciones, analítica, pagos.
struct MenuAdminView: View {
    let user: UserProfile

    var body: some View {
        List {
            usuarioHeader(user)

            Section("Alta prioridad") {
                NavigationLink { AdminDashboardView() } label: {
                    ModuleRow(title: "Dashboard", detail: "Ventas, caja, pedidos, stock y tóner", systemImage: "rectangle.grid.2x2", tint: .blue)
                }
                NavigationLink { POSView() } label: {
                    ModuleRow(title: "Punto de venta", detail: "Cobro rápido, tickets y devoluciones", systemImage: "cart", tint: .indigo)
                }
                NavigationLink { AnalyticsView() } label: {
                    ModuleRow(title: "Analítica y alertas", detail: "Tóner, stock bajo y proyecciones", systemImage: "chart.xyaxis.line", tint: .green)
                }
            }

            Section("Operación") {
                NavigationLink { CatalogView() } label: {
                    ModuleRow(title: "Catálogo", detail: "Productos, precios y stock por sucursal", systemImage: "shippingbox", tint: .orange)
                }
                NavigationLink { OperationsView() } label: {
                    ModuleRow(title: "Operaciones y RRHH", detail: "Limpieza, insumos, vales y checador", systemImage: "checklist", tint: .teal)
                }
                NavigationLink { PrintPreparationView() } label: {
                    ModuleRow(title: "PDF e impresión", detail: "Conversión, fusión y compresión", systemImage: "doc.richtext", tint: .purple)
                }
            }

            Section("Finanzas") {
                NavigationLink { PaymentsView() } label: {
                    ModuleRow(title: "Gestión de pagos", detail: "Transferencias, vouchers y folios", systemImage: "creditcard", tint: .mint)
                }
                NavigationLink { CustomerPortalView(usuario: user) } label: {
                    ModuleRow(title: "Portal cliente", detail: "CRM, tienda digital y pedidos", systemImage: "person.crop.circle.badge.checkmark", tint: .pink)
                }
            }
        }
        .navigationTitle("Kopion — Admin")
    }
}

// MARK: - Menú Editor

/// Catálogo, inventario y promociones. Sin acceso a finanzas ni usuarios.
struct MenuEditorView: View {
    let user: UserProfile

    var body: some View {
        List {
            usuarioHeader(user)

            Section("Módulos") {
                NavigationLink { CatalogView() } label: {
                    ModuleRow(title: "Catálogo", detail: "Productos, precios y stock por sucursal", systemImage: "shippingbox", tint: .orange)
                }
                NavigationLink { AnalyticsView() } label: {
                    ModuleRow(title: "Analítica", detail: "Stock bajo y alertas de tóner", systemImage: "chart.xyaxis.line", tint: .green)
                }
                NavigationLink { CustomerPortalView(usuario: user) } label: {
                    ModuleRow(title: "Portal cliente", detail: "Promociones y pedidos", systemImage: "tag", tint: .pink)
                }
            }
        }
        .navigationTitle("Kopion — Editor")
    }
}

// MARK: - Menú Colaborador

/// POS, operaciones y checador. Sin acceso a finanzas ni catálogo completo.
struct MenuColaboradorView: View {
    let user: UserProfile

    var body: some View {
        List {
            usuarioHeader(user)

            Section("Módulos") {
                NavigationLink { POSView() } label: {
                    ModuleRow(title: "Punto de venta", detail: "Cobro rápido, tickets y devoluciones", systemImage: "cart", tint: .indigo)
                }
                NavigationLink { OperationsView() } label: {
                    ModuleRow(title: "Operaciones", detail: "Limpieza, insumos, vales y checador", systemImage: "checklist", tint: .teal)
                }
                NavigationLink { RecepcionImpresionesView(sucursal: user.sucursal.sucursalApp) } label: {
                    ModuleRow(title: "Recepción impresiones", detail: "Recibidos por sucursal, búsqueda y descarga", systemImage: "tray.full", tint: .purple)
                }
            }
        }
        .navigationTitle("Kopion — Sucursal")
    }
}

// MARK: - Menú Cliente

/// Portal CRM del cliente: todos los módulos desde CustomerPortalView.
struct MenuClienteView: View {
    let user: UserProfile

    var body: some View {
        CustomerPortalView(usuario: user)
    }
}

// MARK: - Componente compartido

/// Encabezado con nombre, correo y rol del usuario autenticado.
@ViewBuilder
private func usuarioHeader(_ usuario: UserProfile) -> some View {
    Section {
        HStack(spacing: 12) {
            Image(systemName: "person.circle.fill")
                .font(.largeTitle)
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 4) {
                Text(usuario.nombreCompleto)
                    .font(.headline)
                    .lineLimit(1)
                Text(usuario.correo)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(usuario.rol.rawValue)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.15))
                        .clipShape(Capsule())
                    if let sucursal = usuario.sucursal.sucursalApp {
                        Text(sucursal.shortName)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthManager())
}

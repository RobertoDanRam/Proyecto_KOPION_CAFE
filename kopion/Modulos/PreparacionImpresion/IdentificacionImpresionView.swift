//
//  IdentificacionImpresionView.swift
//  kopion / Modulos / PreparacionImpresion
//
//  Pantalla inicial del módulo. Pide identificarse antes de enviar archivos.
//

import SwiftUI

struct IdentificacionImpresionView: View {
    @ObservedObject var viewModel: PrintPreparationViewModel
    @EnvironmentObject private var authManager: AuthManager
    @State private var mostrarLogin      = false
    @State private var mostrarFormInvitado = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 20) {
                Image(systemName: "printer.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(.purple)

                Text("Enviar archivos a imprimir")
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)

                Text("Identifícate para que podamos rastrear tu pedido y avisarte cuando esté listo.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Spacer()

            VStack(spacing: 12) {
                // Iniciar sesión con cuenta existente.
                Button {
                    mostrarLogin = true
                } label: {
                    Label("Iniciar sesión", systemImage: "person.circle")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)

                // Continuar sin cuenta.
                Button {
                    mostrarFormInvitado = true
                } label: {
                    Label("Continuar sin correo", systemImage: "person.crop.circle.badge.questionmark")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.bordered)

                Text("Al continuar sin correo se te asignará un código de seguimiento único.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        // Login completo.
        .sheet(isPresented: $mostrarLogin) {
            NavigationStack {
                AccesoLoginView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancelar") { mostrarLogin = false }
                        }
                    }
            }
        }
        // Formulario de invitado.
        .sheet(isPresented: $mostrarFormInvitado) {
            FormularioInvitadoView(viewModel: viewModel)
        }
        // Si el usuario inicia sesión desde el sheet, detectarlo.
        .onChange(of: authManager.usuarioActual) { _, nuevo in
            if let usuario = nuevo {
                viewModel.configurar(perfil: usuario)
                mostrarLogin = false
            }
        }
    }
}

// MARK: - Formulario de invitado

struct FormularioInvitadoView: View {
    @ObservedObject var viewModel: PrintPreparationViewModel
    @Environment(\.dismiss) private var cerrar

    @State private var nombre    = ""
    @State private var apellidos = ""
    @State private var tipo: CustomerType = .student
    @State private var escuela: School    = .escaSantoTomas

    private var puedeConfirmar: Bool {
        !nombre.trimmingCharacters(in: .whitespaces).isEmpty &&
        !apellidos.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Tus datos") {
                    TextField("Nombre(s)", text: $nombre)
                        .textContentType(.givenName)
                        .textInputAutocapitalization(.words)

                    TextField("Apellidos", text: $apellidos)
                        .textContentType(.familyName)
                        .textInputAutocapitalization(.words)

                    Picker("Tipo", selection: $tipo) {
                        ForEach(CustomerType.allCases) { t in
                            Text(t.displayName).tag(t)
                        }
                    }

                    Picker("Escuela / Sucursal", selection: $escuela) {
                        ForEach(School.allCases) { e in
                            Text(e.displayName).tag(e)
                        }
                    }
                }

                Section {
                    Text("Se te asignará un código único para rastrear tu pedido. Guárdalo cuando aparezca.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button {
                        viewModel.confirmarInvitado(
                            nombre:    nombre.trimmingCharacters(in: .whitespaces),
                            apellidos: apellidos.trimmingCharacters(in: .whitespaces),
                            tipo:      tipo,
                            escuela:   escuela
                        )
                        cerrar()
                    } label: {
                        Label("Confirmar y continuar", systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(!puedeConfirmar)
                }
            }
            .navigationTitle("Datos de contacto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { cerrar() }
                }
            }
        }
    }
}

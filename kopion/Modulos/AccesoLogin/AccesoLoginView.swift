//
//  AccesoLoginView.swift
//  kopion / Modulos / AccesoLogin
//
//  Pantalla inicial de la app.
//  Login único con correo, contraseña y Google.
//  El rol real se obtiene desde Firebase/Firestore después de iniciar sesión.
//

import SwiftUI

/// Tipo de registro que determina qué formulario se muestra en la pantalla de registro.
enum AccessRegistrationKind: String, CaseIterable, Identifiable {
    case customer
    case staff

    var id: String { rawValue }

    var titulo: String {
        switch self {
        case .customer: return "Cliente"
        case .staff:    return "Empleado"
        }
    }
}

// MARK: - Vista raíz del módulo

struct AccesoLoginView: View {
    @StateObject private var viewModel = AccesoLoginViewModel()

    var body: some View {
        PanelLoginCliente(viewModel: viewModel)
            .navigationTitle("Kopion")
            .onDisappear { viewModel.cancelar() }
            .alert("Aviso", isPresented: enlaceError(para: viewModel)) {
                Button("OK") { viewModel.limpiarError() }
            } message: {
                Text(viewModel.mensajeError ?? "")
            }
    }
}

// MARK: - Panel de acceso

/// Login único: Firebase determina el rol real del usuario después de autenticar.
private struct PanelLoginCliente: View {
    @ObservedObject var viewModel: AccesoLoginViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {

                EncabezadoLogin(
                    titulo: "Bienvenido",
                    subtitulo: "Entra con tu correo o cuenta de Google. Kopion abrirá el menú según tu rol."
                )

                // Campos de correo y contraseña
                VStack(spacing: 12) {
                    TextField("Correo", text: $viewModel.correoCliente)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)

                    CampoContrasenaVisible(
                        titulo: "Contraseña",
                        texto: $viewModel.contrasenaCliente,
                        textContentType: .password
                    )
                }
                .textFieldStyle(.roundedBorder)

                // Botón de inicio de sesión con correo
                Button {
                    viewModel.iniciarSesionCliente()
                } label: {
                    Label("Entrar", systemImage: "arrow.right.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.estaEnviando)

                // Botón de inicio de sesión con Google
                Button {
                    viewModel.iniciarSesionConGoogle()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "globe")
                        Text("Continuar con Google")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.estaEnviando)

                // Enlace a registro
                NavigationLink {
                    VistaRegistro(viewModel: viewModel, tipoInicial: .customer)
                } label: {
                    Text("¿No tienes cuenta? Regístrate")
                        .font(.subheadline.weight(.semibold))
                }

                // Restablecimiento de contraseña
                Button {
                    viewModel.restablecerContrasenaCliente()
                } label: {
                    Text("Restablecer contraseña")
                        .font(.subheadline.weight(.semibold))
                }
                .disabled(viewModel.estaEnviando)

                // Acceso como invitado
                NavigationLink {
                    MenuInternoView()
                } label: {
                    Label("Continuar como invitado", systemImage: "person.crop.circle")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.bordered)

                // Indicador de estado
                VistaEstado(mensaje: viewModel.mensajeConfirmacion, cargando: viewModel.estaEnviando)

                // Confirmación de sesión activa
                if let sesion = viewModel.sesion, sesion.role == .customer {
                    ModuleRow(
                        title: "Tienda virtual desbloqueada",
                        detail: sesion.branch?.displayName ?? "Sucursal asignada por escuela",
                        systemImage: "cart.badge.checkmark",
                        tint: .green
                    )
                }
            }
            .padding()
        }
    }
}

// MARK: - Pantalla de registro

/// Pantalla de registro completo separada del login inicial.
private struct VistaRegistro: View {
    @ObservedObject var viewModel: AccesoLoginViewModel
    let tipoInicial: AccessRegistrationKind

    var body: some View {
        Form {
            // Selector de tipo de cuenta
            Section("Tipo de cuenta") {
                Picker("Cuenta", selection: $viewModel.tipoRegistro) {
                    ForEach(AccessRegistrationKind.allCases) { tipo in
                        Text(tipo.titulo).tag(tipo)
                    }
                }
                .pickerStyle(.segmented)
            }

            // Formulario según tipo seleccionado
            if viewModel.tipoRegistro == .customer {
                SeccionRegistroCliente(viewModel: viewModel)
            } else {
                SeccionRegistroPersonal(viewModel: viewModel)
            }

            // Botón de acción
            SeccionAccionesRegistro(viewModel: viewModel)

            // Indicador de carga
            if viewModel.estaEnviando {
                Section("Estado") {
                    ProgressView("Creando cuenta…")
                }
            }

            // Mensaje de confirmación
            if let mensaje = viewModel.mensajeConfirmacion {
                Section("Estado") {
                    Text(mensaje).foregroundStyle(.secondary)
                }
            }

            // Mensaje de error
            if let error = viewModel.mensajeError {
                Section("Error") {
                    Text(error).foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Registro")
        .onAppear {
            viewModel.tipoRegistro = tipoInicial
            viewModel.estaRegistrandoPersonal = tipoInicial == .staff
        }
        .onChange(of: viewModel.tipoRegistro) { _, nuevo in
            viewModel.estaRegistrandoPersonal = nuevo == .staff
        }
    }
}

// MARK: - Sección de datos del cliente

private struct SeccionRegistroCliente: View {
    @ObservedObject var viewModel: AccesoLoginViewModel

    var body: some View {
        Section("Datos del cliente") {
            TextField("Nombres", text: $viewModel.nombreCliente)
                .textContentType(.givenName)
                .textInputAutocapitalization(.words)

            TextField("Apellidos", text: $viewModel.apellidosCliente)
                .textContentType(.familyName)
                .textInputAutocapitalization(.words)

            TextField("Correo", text: $viewModel.correoCliente)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)

            SecureField("Contraseña (mín. 6 caracteres)", text: $viewModel.contrasenaCliente)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .textContentType(.newPassword)

            Picker("Tipo", selection: $viewModel.tipoCliente) {
                ForEach(CustomerType.allCases) { tipo in
                    Text(tipo.displayName).tag(tipo)
                }
            }

            Picker("Escuela", selection: $viewModel.escuelaSeleccionada) {
                ForEach(School.allCases) { escuela in
                    Text(escuela.displayName).tag(escuela)
                }
            }
        }
    }
}

// MARK: - Sección de datos del personal

private struct SeccionRegistroPersonal: View {
    @ObservedObject var viewModel: AccesoLoginViewModel

    var body: some View {
        // Filtro de seguridad: código de acceso requerido antes de mostrar el formulario.
        Section("Filtro de seguridad") {
            TextField("Código de acceso", text: $viewModel.codigoAccesoRegistro)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .keyboardType(.numberPad)

            Text("Escribe la clave autorizada para registrar cuentas de sucursal.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }

        // Formulario visible solo cuando el código es correcto.
        if viewModel.codigoAccesoValido {
            Section("Datos de sucursal") {
                TextField("Nombres", text: $viewModel.nombrePersonal)
                    .textContentType(.givenName)
                    .textInputAutocapitalization(.words)

                TextField("Apellidos", text: $viewModel.apellidosPersonal)
                    .textContentType(.familyName)
                    .textInputAutocapitalization(.words)

                TextField("Correo", text: $viewModel.correoPersonal)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)

                SecureField("Contraseña (mín. 6 caracteres)", text: $viewModel.contrasenaPersonal)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .textContentType(.newPassword)

                Picker("Sucursal", selection: $viewModel.sucursalSeleccionada) {
                    ForEach(Branch.allCases) { sucursal in
                        Text(sucursal.displayName).tag(sucursal)
                    }
                }

                Picker("Rol solicitado", selection: $viewModel.rolSolicitado) {
                    Text(UserRole.collaborator.displayName).tag(UserRole.collaborator)
                    Text(UserRole.editor.displayName).tag(UserRole.editor)
                    Text(UserRole.administrator.displayName).tag(UserRole.administrator)
                }

                Text("Las cuentas nuevas se guardan como Colaborador hasta que la dueña las autorice.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Sección de acciones de registro

private struct SeccionAccionesRegistro: View {
    @ObservedObject var viewModel: AccesoLoginViewModel

    var body: some View {
        Section {
            if viewModel.tipoRegistro == .customer {
                Button {
                    viewModel.crearCuentaCliente()
                } label: {
                    Label("Crear cuenta", systemImage: "person.badge.plus")
                }
                .disabled(viewModel.estaEnviando)
            } else {
                Button {
                    viewModel.estaRegistrandoPersonal = true
                    viewModel.crearCuentaPersonal()
                } label: {
                    Label("Crear cuenta", systemImage: "person.badge.plus")
                }
                .disabled(viewModel.estaEnviando)
            }
        }
    }
}

// MARK: - Componentes de UI compartidos

/// Encabezado compacto con título y subtítulo para formularios de acceso.
private struct EncabezadoLogin: View {
    let titulo: String
    let subtitulo: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(titulo)
                .font(.largeTitle.weight(.bold))
            Text(subtitulo)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

/// Campo de contraseña con botón para mostrar u ocultar el texto escrito.
private struct CampoContrasenaVisible: View {
    let titulo: String
    @Binding var texto: String
    let textContentType: UITextContentType
    @State private var muestraContrasena = false

    var body: some View {
        ZStack(alignment: .trailing) {
            Group {
                if muestraContrasena {
                    TextField(titulo, text: $texto)
                } else {
                    SecureField(titulo, text: $texto)
                }
            }
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)
            .textContentType(textContentType)
            .padding(.trailing, 42)

            Button {
                muestraContrasena.toggle()
            } label: {
                Image(systemName: muestraContrasena ? "eye.slash" : "eye")
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(muestraContrasena ? "Ocultar contraseña" : "Mostrar contraseña")
        }
    }
}

/// Indicador de estado: muestra ProgressView durante la carga y el mensaje de confirmación.
private struct VistaEstado: View {
    let mensaje: String?
    let cargando: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if cargando {
                ProgressView("Validando…")
            }
            if let mensaje {
                Text(mensaje)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Menú de invitado

/// Menú para explorar la app como cliente invitado, sin acceso a módulos internos.
private struct MenuInternoView: View {
    var body: some View {
        List {
            Section("Modo invitado") {
                ModuleRow(
                    title: "Cliente invitado",
                    detail: "Puedes cotizar, enviar archivos y revisar el catálogo.",
                    systemImage: "person.crop.circle",
                    tint: .orange
                )
            }

            Section("Módulos") {
                NavigationLink { CustomerPortalView(usuario: UserProfile(id: "invitado", correo: "invitado@kopion.mx", nombre: "Invitado", rol: .cliente, sucursal: .ningunaCliente)) } label: {
                    ModuleRow(
                        title: "Tienda y cotizador",
                        detail: "Copias, engargolados, enmicados y más",
                        systemImage: "cart.badge.checkmark",
                        tint: .pink
                    )
                }
                NavigationLink { PrintPreparationView() } label: {
                    ModuleRow(
                        title: "Enviar archivos",
                        detail: "PDF, Word, JPG a cola de impresión",
                        systemImage: "doc.richtext",
                        tint: .purple
                    )
                }
                NavigationLink { CatalogView() } label: {
                    ModuleRow(
                        title: "Catálogo",
                        detail: "Precios y disponibilidad en tiempo real",
                        systemImage: "shippingbox",
                        tint: .orange
                    )
                }
            }
        }
        .navigationTitle("Kopion")
    }
}

#Preview {
    NavigationStack {
        AccesoLoginView()
    }
}

//
//  AccesoLoginView.swift
//  kopion
//
//  Módulo inicial de acceso.
//  La app abre aquí: primero se muestra login de cliente con correo y contraseña.
//  El acceso de sucursal queda en una segunda página por deslizamiento horizontal.
//  El código de correo aparece exclusivamente al crear una cuenta nueva.
//

import SwiftUI

/// Tipo de registro que determina qué formulario completo se muestra.
enum AccessRegistrationKind: String, CaseIterable, Identifiable {
    case customer
    case staff

    var id: String { rawValue }

    var title: String {
        switch self {
        case .customer:
            return "Cliente"
        case .staff:
            return "Empleado"
        }
    }
}

struct AccesoLoginView: View {
    @StateObject private var viewModel = AccesoLoginViewModel()
    @State private var selectedPage = 0

    var body: some View {
        TabView(selection: $selectedPage) {
            CustomerLoginPane(viewModel: viewModel)
                .tag(0)

            StaffLoginPane(viewModel: viewModel)
                .tag(1)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .navigationTitle(selectedPage == 0 ? "Kopion" : "Sucursal")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Desliza para acceso de sucursal")
            }
        }
        .onDisappear { viewModel.cancel() }
        .alert("Aviso", isPresented: errorBinding(for: viewModel)) {
            Button("OK") { viewModel.clearError() }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}

/// Login visible para clientes: solo correo y contraseña antes de entrar.
private struct CustomerLoginPane: View {
    @ObservedObject var viewModel: AccesoLoginViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                LoginHeader(
                    title: "Bienvenido",
                    subtitle: "Entra a la tienda virtual con tu correo Gmail."
                )

                VStack(spacing: 12) {
                    TextField("Correo Gmail", text: $viewModel.customerEmail)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                    SecureField("Contraseña", text: $viewModel.customerPassword)
                        .textContentType(.password)
                }
                .textFieldStyle(.roundedBorder)

                Button {
                    viewModel.loginCustomer()
                } label: {
                    Label("Entrar", systemImage: "arrow.right.circle")
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isSubmitting)

                NavigationLink {
                    RegistroAccesoView(viewModel: viewModel, initialKind: .customer)
                } label: {
                    Text("¿No tienes cuenta? Regístrate")
                        .font(.subheadline.weight(.semibold))
                }

                StatusMessageView(message: viewModel.confirmationMessage, isSubmitting: viewModel.isSubmitting)

                if let session = viewModel.session, session.role == .customer {
                    ModuleRow(
                        title: "Tienda virtual desbloqueada",
                        detail: session.branch?.displayName ?? "Sucursal asignada por escuela",
                        systemImage: "cart.badge.checkmark",
                        tint: .green
                    )
                }
            }
            .padding()
        }
    }
}

/// Login de sucursal oculto en la segunda página por deslizamiento.
private struct StaffLoginPane: View {
    @ObservedObject var viewModel: AccesoLoginViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                LoginHeader(
                    title: "Acceso de sucursal",
                    subtitle: "Para empleado, editor o dueña autorizada."
                )

                VStack(spacing: 12) {
                    TextField("Correo Gmail", text: $viewModel.staffEmail)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                    SecureField("Contraseña", text: $viewModel.staffPassword)
                        .textContentType(.password)
                }
                .textFieldStyle(.roundedBorder)

                Picker("Rol", selection: $viewModel.requestedRole) {
                    Text(UserRole.collaborator.displayName).tag(UserRole.collaborator)
                    Text(UserRole.editor.displayName).tag(UserRole.editor)
                    Text(UserRole.administrator.displayName).tag(UserRole.administrator)
                }
                .pickerStyle(.segmented)

                Button {
                    viewModel.loginStaff()
                } label: {
                    Label("Entrar", systemImage: "lock.open")
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isSubmitting)

                NavigationLink {
                    RegistroAccesoView(viewModel: viewModel, initialKind: .staff)
                } label: {
                    Text("¿No tienes cuenta? Regístrate")
                        .font(.subheadline.weight(.semibold))
                }

                StatusMessageView(message: viewModel.confirmationMessage, isSubmitting: viewModel.isSubmitting)

                if let session = viewModel.session, session.role != .customer {
                    ModuleRow(
                        title: session.role.displayName,
                        detail: "\(session.email) - \(session.branch?.displayName ?? "Sucursal")",
                        systemImage: "lock.shield",
                        tint: .green
                    )
                }
            }
            .padding()
        }
    }
}

/// Pantalla de registro completo separada del login inicial.
private struct RegistroAccesoView: View {
    @ObservedObject var viewModel: AccesoLoginViewModel
    let initialKind: AccessRegistrationKind

    var body: some View {
        Form {
            Section("Tipo de cuenta") {
                Picker("Cuenta", selection: $viewModel.registrationKind) {
                    ForEach(AccessRegistrationKind.allCases) { kind in
                        Text(kind.title).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
            }

            if viewModel.registrationKind == .customer {
                CustomerRegistrationSection(viewModel: viewModel)
            } else {
                StaffRegistrationSection(viewModel: viewModel)
            }

            RegistrationActionsSection(viewModel: viewModel)

            if let message = viewModel.confirmationMessage {
                Section("Estado") {
                    Text(message)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Registro")
        .onAppear {
            viewModel.registrationKind = initialKind
            viewModel.isRegisteringStaff = initialKind == .staff
        }
        .onChange(of: viewModel.registrationKind) { _, newValue in
            viewModel.isRegisteringStaff = newValue == .staff
        }
    }
}

/// Datos completos para cliente.
private struct CustomerRegistrationSection: View {
    @ObservedObject var viewModel: AccesoLoginViewModel

    var body: some View {
        Section("Datos del cliente") {
            TextField("Nombres", text: $viewModel.customerFirstName)
                .textContentType(.givenName)
                .textInputAutocapitalization(.words)
            TextField("Apellidos", text: $viewModel.customerLastName)
                .textContentType(.familyName)
                .textInputAutocapitalization(.words)
            TextField("Correo Gmail", text: $viewModel.customerEmail)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
            SecureField("Contraseña", text: $viewModel.customerPassword)
                .textContentType(.newPassword)

            Picker("Tipo", selection: $viewModel.customerType) {
                ForEach(CustomerType.allCases) { type in
                    Text(type.displayName).tag(type)
                }
            }

            Picker("Escuela", selection: $viewModel.selectedSchool) {
                ForEach(School.allCases) { school in
                    Text(school.displayName).tag(school)
                }
            }
        }

        if viewModel.hasSentCustomerCode {
            Section("Verificación por correo") {
                TextField("Código de correo", text: $viewModel.customerCode)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
            }
        }
    }
}

/// Datos completos para empleado/editor/dueña.
private struct StaffRegistrationSection: View {
    @ObservedObject var viewModel: AccesoLoginViewModel

    var body: some View {
        Section("Filtro de seguridad") {
            SecureField("Contraseña de registro", text: $viewModel.staffRegistrationAccessCode)
                .keyboardType(.numberPad)
            Text("Para registrar cuentas de sucursal, escribe la clave autorizada.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }

        if viewModel.hasValidStaffRegistrationAccessCode {
            Section("Datos de sucursal") {
                TextField("Nombres", text: $viewModel.staffFirstName)
                    .textContentType(.givenName)
                    .textInputAutocapitalization(.words)
                TextField("Apellidos", text: $viewModel.staffLastName)
                    .textContentType(.familyName)
                    .textInputAutocapitalization(.words)
                TextField("Correo Gmail", text: $viewModel.staffEmail)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                SecureField("Contraseña", text: $viewModel.staffPassword)
                    .textContentType(.newPassword)

                Picker("Sucursal", selection: $viewModel.selectedBranch) {
                    ForEach(Branch.allCases) { branch in
                        Text(branch.displayName).tag(branch)
                    }
                }

                Picker("Rol solicitado", selection: $viewModel.requestedRole) {
                    Text(UserRole.collaborator.displayName).tag(UserRole.collaborator)
                    Text(UserRole.editor.displayName).tag(UserRole.editor)
                    Text(UserRole.administrator.displayName).tag(UserRole.administrator)
                }

                Text("Las cuentas nuevas de sucursal se guardan como Colaborador hasta autorización.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if viewModel.hasSentStaffCode {
                Section("Verificación por correo") {
                    TextField("Código de correo", text: $viewModel.staffCode)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                }
            }
        }
    }
}

/// Acciones progresivas de registro: primero enviar código, luego crear cuenta.
private struct RegistrationActionsSection: View {
    @ObservedObject var viewModel: AccesoLoginViewModel

    var body: some View {
        Section {
            if viewModel.registrationKind == .customer {
                Button {
                    viewModel.sendCustomerCode()
                } label: {
                    Label("Enviar código Gmail", systemImage: "envelope")
                }
                .disabled(viewModel.isSubmitting)

                if viewModel.canCreateCustomerAccount {
                    Button {
                        viewModel.createCustomerAccount()
                    } label: {
                        Label("Crear cuenta", systemImage: "person.badge.plus")
                    }
                    .disabled(viewModel.isSubmitting)
                }
            } else {
                Button {
                    viewModel.isRegisteringStaff = true
                    viewModel.sendStaffCode()
                } label: {
                    Label("Enviar código Gmail", systemImage: "envelope")
                }
                .disabled(viewModel.isSubmitting || !viewModel.hasValidStaffRegistrationAccessCode)

                if viewModel.canCreateStaffAccount {
                    Button {
                        viewModel.isRegisteringStaff = true
                        viewModel.createStaffAccount()
                    } label: {
                        Label("Crear cuenta", systemImage: "person.badge.plus")
                    }
                    .disabled(viewModel.isSubmitting)
                }
            }
        }
    }
}

/// Encabezado compacto para formularios de acceso.
private struct LoginHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.largeTitle.weight(.bold))
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

/// Estado visible para envío de código, validación y éxito.
private struct StatusMessageView: View {
    let message: String?
    let isSubmitting: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isSubmitting {
                ProgressView("Validando con Google/Gmail")
            }

            if let message {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    NavigationStack {
        AccesoLoginView()
    }
}

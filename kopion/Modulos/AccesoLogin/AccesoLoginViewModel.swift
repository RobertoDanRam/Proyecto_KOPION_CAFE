//
//  AccesoLoginViewModel.swift
//  kopion
//
//  ViewModel del módulo Acceso Login.
//  Maneja login, registro por enlaces nativos de Firebase, restablecimiento de
//  contraseña y estados de carga para evitar envíos duplicados.
//

import Combine
import Foundation

@MainActor
final class AccesoLoginViewModel: LoadableViewModel {
    @Published var customerFirstName = ""
    @Published var customerLastName = ""
    @Published var customerEmail = ""
    @Published var customerPassword = ""
    @Published var customerType: CustomerType = .student
    @Published var selectedSchool: School = .escaSantoTomas

    @Published var staffFirstName = ""
    @Published var staffLastName = ""
    @Published var staffEmail = ""
    @Published var staffPassword = ""
    @Published var staffRegistrationAccessCode = ""
    @Published var selectedBranch: Branch = .kopionESCA
    @Published var requestedRole: UserRole = .collaborator
    @Published var isRegisteringStaff = false
    @Published var registrationKind: AccessRegistrationKind = .customer

    @Published private(set) var session: AuthSession?
    @Published private(set) var confirmationMessage: String?

    var hasValidStaffRegistrationAccessCode: Bool {
        staffRegistrationAccessCode == "2024"
    }

    var canCreateCustomerAccount: Bool {
        !customerFirstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !customerLastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !customerEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !customerPassword.isEmpty
    }

    var canCreateStaffAccount: Bool {
        !staffFirstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !staffLastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !staffEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !staffPassword.isEmpty &&
        hasValidStaffRegistrationAccessCode
    }

    private let authenticationService: AuthenticationServicing
    private var task: Task<Void, Never>?

    override init() {
        self.authenticationService = AuthenticationService()
        super.init()
    }

    init(authenticationService: AuthenticationServicing) {
        self.authenticationService = authenticationService
        super.init()
    }

    /// Inicia sesión de cliente existente.
    func loginCustomer() {
        guard !isSubmitting else { return }
        isSubmitting = true
        errorMessage = nil
        confirmationMessage = nil

        task = Task {
            do {
                let profile = CustomerLoginProfile(
                    firstName: customerFirstName.isEmpty ? "Cliente" : customerFirstName,
                    lastName: customerLastName,
                    email: customerEmail,
                    customerType: customerType,
                    school: selectedSchool
                )
                session = try await authenticationService.signInCustomer(profile: profile, password: customerPassword)
                confirmationMessage = "Bienvenido. Tienda virtual lista."
            } catch {
                errorMessage = error.localizedDescription
            }

            isSubmitting = false
            task = nil
        }
    }

    /// Solicita instrucciones para restablecer contraseña de cliente.
    func resetCustomerPassword() {
        resetPassword(email: customerEmail)
    }

    /// Solicita instrucciones para restablecer contraseña de personal de sucursal.
    func resetStaffPassword() {
        resetPassword(email: staffEmail)
    }

    /// Ejecuta el flujo compartido de recuperación de contraseña por enlace Firebase.
    private func resetPassword(email: String) {
        guard !isSubmitting else { return }
        isSubmitting = true
        errorMessage = nil
        confirmationMessage = nil

        task = Task {
            do {
                try await authenticationService.sendPasswordReset(to: email)
                confirmationMessage = "Te hemos enviado un enlace a tu correo para restablecer tu contraseña."
            } catch {
                errorMessage = error.localizedDescription
            }

            isSubmitting = false
            task = nil
        }
    }

    /// Inicia sesión de empleado/editor/dueña existente.
    func loginStaff() {
        guard !isSubmitting else { return }
        isSubmitting = true
        errorMessage = nil
        confirmationMessage = nil

        task = Task {
            do {
                let profile = StaffLoginProfile(
                    email: staffEmail,
                    branch: selectedBranch,
                    requestedRole: requestedRole
                )
                session = try await authenticationService.signInStaff(profile: profile, password: staffPassword)
                confirmationMessage = "Acceso de sucursal activo: \(session?.role.displayName ?? "Colaborador")."
            } catch {
                errorMessage = error.localizedDescription
            }

            isSubmitting = false
            task = nil
        }
    }

    /// Crea una cuenta de cliente y dispara el enlace nativo de verificación de Firebase.
    func createCustomerAccount() {
        guard !isSubmitting else { return }
        isSubmitting = true
        errorMessage = nil
        confirmationMessage = nil

        task = Task {
            do {
                let profile = CustomerLoginProfile(
                    firstName: customerFirstName,
                    lastName: customerLastName,
                    email: customerEmail,
                    customerType: customerType,
                    school: selectedSchool
                )
                session = try await authenticationService.registerCustomer(profile: profile, password: customerPassword)
                confirmationMessage = "Cuenta creada. Te enviamos un enlace a tu correo para verificar tu cuenta."
            } catch {
                errorMessage = error.localizedDescription
            }

            isSubmitting = false
            task = nil
        }
    }

    /// Crea una cuenta de sucursal como Colaborador y dispara el enlace nativo de verificación de Firebase.
    func createStaffAccount() {
        guard !isSubmitting else { return }
        isSubmitting = true
        errorMessage = nil
        confirmationMessage = nil

        task = Task {
            do {
                guard hasValidStaffRegistrationAccessCode else {
                    throw AuthenticationError.unauthorizedRole
                }

                let profile = StaffLoginProfile(
                    email: staffEmail,
                    branch: selectedBranch,
                    requestedRole: .collaborator
                )
                session = try await authenticationService.registerStaffRequest(profile: profile, password: staffPassword)
                confirmationMessage = "Cuenta registrada como Colaborador. Te enviamos un enlace a tu correo para verificar tu cuenta."
            } catch {
                errorMessage = error.localizedDescription
            }

            isSubmitting = false
            task = nil
        }
    }

    /// Cancela cualquier tarea viva al cerrar la pantalla.
    func cancel() {
        task?.cancel()
        task = nil
        isLoading = false
        isSubmitting = false
    }
}

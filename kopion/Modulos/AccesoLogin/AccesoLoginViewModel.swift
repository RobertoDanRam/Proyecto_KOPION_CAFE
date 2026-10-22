//
//  AccesoLoginViewModel.swift
//  kopion / Modulos / AccesoLogin
//
//  ViewModel del módulo de acceso.
//  Maneja inicio de sesión, registro, restablecimiento de contraseña
//  y estados de carga para evitar envíos duplicados (isSubmitting).
//

import Combine
import Foundation

@MainActor
final class AccesoLoginViewModel: LoadableViewModel {

    // MARK: - Campos del formulario de cliente

    @Published var nombreCliente    = ""
    @Published var apellidosCliente = ""
    @Published var correoCliente    = ""
    @Published var contrasenaCliente = ""
    @Published var tipoCliente: CustomerType = .student
    @Published var escuelaSeleccionada: School = .escaSantoTomas

    // MARK: - Campos del formulario de personal de sucursal

    @Published var nombrePersonal    = ""
    @Published var apellidosPersonal = ""
    @Published var correoPersonal    = ""
    @Published var contrasenaPersonal = ""
    @Published var codigoAccesoRegistro = ""
    @Published var sucursalSeleccionada: Branch = .kopionESCA
    @Published var rolSolicitado: UserRole = .collaborator
    @Published var estaRegistrandoPersonal = false
    @Published var tipoRegistro: AccessRegistrationKind = .customer

    // MARK: - Estado de sesión y mensajes

    @Published private(set) var sesion: AuthSession?
    @Published private(set) var mensajeConfirmacion: String?

    // MARK: - Validaciones

    /// Verifica que el código de acceso para registrar personal sea correcto.
    var codigoAccesoValido: Bool {
        codigoAccesoRegistro == "2024"
    }

    /// Verifica que todos los campos del registro de cliente estén completos.
    var puedeCrearCuentaCliente: Bool {
        !nombreCliente.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !apellidosCliente.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !correoCliente.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !contrasenaCliente.isEmpty
    }

    /// Verifica que todos los campos del registro de personal estén completos.
    var puedeCrearCuentaPersonal: Bool {
        !nombrePersonal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !apellidosPersonal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !correoPersonal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !contrasenaPersonal.isEmpty &&
        codigoAccesoValido
    }

    // MARK: - Dependencias

    private let servicioAutenticacion: AuthenticationServicing
    private var tarea: Task<Void, Never>?

    override init() {
        self.servicioAutenticacion = AuthenticationService()
        super.init()
    }

    init(servicioAutenticacion: AuthenticationServicing) {
        self.servicioAutenticacion = servicioAutenticacion
        super.init()
    }

    // MARK: - Inicio de sesión con correo

    /// Inicia sesión con correo y contraseña. Firestore determina el rol real del usuario.
    func iniciarSesionCliente() {
        guard !estaEnviando else { return }
        estaEnviando = true
        mensajeError = nil
        mensajeConfirmacion = nil

        tarea = Task {
            do {
                let perfil = CustomerLoginProfile(
                    firstName: nombreCliente.isEmpty ? "Cliente" : nombreCliente,
                    lastName:  apellidosCliente,
                    email:     correoCliente,
                    customerType: tipoCliente,
                    school:    escuelaSeleccionada
                )
                sesion = try await servicioAutenticacion.iniciarSesionCliente(
                    perfil: perfil,
                    contrasena: contrasenaCliente
                )
                mensajeConfirmacion = "Bienvenido. Abriendo tu menú."
            } catch {
                mensajeError = error.localizedDescription
            }
            estaEnviando = false
            tarea = nil
        }
    }

    /// Inicia sesión de personal de sucursal con correo y contraseña.
    func iniciarSesionPersonal() {
        guard !estaEnviando else { return }
        estaEnviando = true
        mensajeError = nil
        mensajeConfirmacion = nil

        tarea = Task {
            do {
                let perfil = StaffLoginProfile(
                    email:         correoPersonal,
                    branch:        sucursalSeleccionada,
                    requestedRole: rolSolicitado
                )
                sesion = try await servicioAutenticacion.iniciarSesionPersonal(
                    perfil: perfil,
                    contrasena: contrasenaPersonal
                )
                mensajeConfirmacion = "Acceso de sucursal activo: \(sesion?.role.displayName ?? "Colaborador")."
            } catch {
                mensajeError = error.localizedDescription
            }
            estaEnviando = false
            tarea = nil
        }
    }

    // MARK: - Inicio de sesión con Google

    /// Presenta el sheet nativo de Google y autentica sin necesidad de escribir correo ni contraseña.
    func iniciarSesionConGoogle(rol: UserProfileRole = .cliente, sucursal: UserProfileBranch = .ningunaCliente) {
        guard !estaEnviando else { return }
        estaEnviando = true
        mensajeError = nil
        mensajeConfirmacion = nil

        tarea = Task {
            do {
                sesion = try await servicioAutenticacion.iniciarSesionConGoogle(
                    rol: rol,
                    sucursal: sucursal
                )
                mensajeConfirmacion = "Bienvenido. Sesión iniciada con Google."
            } catch let error as ErrorGoogleSignIn {
                // Cancelación silenciosa: el usuario cerró el sheet sin elegir cuenta.
                if case .cancelado = error {
                    mensajeError = nil
                } else {
                    mensajeError = error.localizedDescription
                }
            } catch {
                mensajeError = error.localizedDescription
            }
            estaEnviando = false
            tarea = nil
        }
    }

    // MARK: - Restablecimiento de contraseña

    /// Envía correo de restablecimiento al correo del cliente.
    func restablecerContrasenaCliente() {
        restablecerContrasena(correo: correoCliente)
    }

    /// Envía correo de restablecimiento al correo del personal.
    func restablecerContrasenaPersonal() {
        restablecerContrasena(correo: correoPersonal)
    }

    /// Flujo compartido de restablecimiento de contraseña por enlace de Firebase.
    private func restablecerContrasena(correo: String) {
        guard !estaEnviando else { return }
        estaEnviando = true
        mensajeError = nil
        mensajeConfirmacion = nil

        tarea = Task {
            do {
                try await servicioAutenticacion.enviarCorreoRestablecimiento(a: correo)
                mensajeConfirmacion = "Te enviamos un enlace a \(correo) para restablecer tu contraseña."
            } catch {
                mensajeError = error.localizedDescription
            }
            estaEnviando = false
            tarea = nil
        }
    }

    // MARK: - Registro de cuenta nueva

    /// Crea una cuenta de cliente y envía el correo de verificación de Firebase.
    /// Si el correo de verificación falla, muestra el detalle técnico sin bloquear el acceso.
    func crearCuentaCliente() {
        guard !estaEnviando else { return }
        guard validarRegistroCliente() else { return }

        estaEnviando = true
        mensajeError = nil
        mensajeConfirmacion = nil

        tarea = Task {
            do {
                let escuelaGuardada = UserProfileEscuela(escuela: escuelaSeleccionada)
                let sucursalDerivada = escuelaGuardada.sucursalAsociada
                let perfil = CustomerLoginProfile(
                    firstName: nombreCliente.trimmingCharacters(in: .whitespacesAndNewlines),
                    lastName:  apellidosCliente.trimmingCharacters(in: .whitespacesAndNewlines),
                    email:     correoCliente.trimmingCharacters(in: .whitespacesAndNewlines),
                    customerType: tipoCliente,
                    school:    escuelaSeleccionada
                )
                sesion = try await servicioAutenticacion.registrarCliente(
                    perfil: perfil,
                    contrasena: contrasenaCliente,
                    escuela: escuelaGuardada,
                    sucursal: sucursalDerivada
                )

                // Verificar si el envío del correo de verificación tuvo un error separado.
                if let errorVerificacion = servicioAutenticacion.errorVerificacionCorreo {
                    mensajeConfirmacion = "Cuenta creada. No se pudo enviar el correo de verificación:"
                    mensajeError = errorVerificacion.localizedDescription
                } else {
                    mensajeConfirmacion = "Cuenta creada. Revisa \(correoCliente.trimmingCharacters(in: .whitespacesAndNewlines)) para verificar tu cuenta."
                }
            } catch {
                mensajeError = error.localizedDescription
            }
            estaEnviando = false
            tarea = nil
        }
    }

    /// Registra una solicitud de cuenta de sucursal como Colaborador y envía correo de verificación.
    func crearCuentaPersonal() {
        guard !estaEnviando else { return }
        guard validarRegistroPersonal() else { return }

        estaEnviando = true
        mensajeError = nil
        mensajeConfirmacion = nil

        tarea = Task {
            do {
                let perfil = StaffLoginProfile(
                    email:     correoPersonal.trimmingCharacters(in: .whitespacesAndNewlines),
                    firstName: nombrePersonal.trimmingCharacters(in: .whitespacesAndNewlines),
                    lastName:  apellidosPersonal.trimmingCharacters(in: .whitespacesAndNewlines),
                    branch:    sucursalSeleccionada,
                    requestedRole: .collaborator
                )
                sesion = try await servicioAutenticacion.registrarSolicitudPersonal(
                    perfil: perfil,
                    contrasena: contrasenaPersonal
                )

                if let errorVerificacion = servicioAutenticacion.errorVerificacionCorreo {
                    mensajeConfirmacion = "Cuenta registrada como Colaborador. No se pudo enviar el correo de verificación:"
                    mensajeError = errorVerificacion.localizedDescription
                } else {
                    mensajeConfirmacion = "Cuenta registrada como Colaborador. Revisa \(correoPersonal.trimmingCharacters(in: .whitespacesAndNewlines)) para verificar tu cuenta."
                }
            } catch {
                mensajeError = error.localizedDescription
            }
            estaEnviando = false
            tarea = nil
        }
    }

    // MARK: - Validaciones locales

    /// Valida los campos del formulario de cliente antes de llamar a Firebase.
    private func validarRegistroCliente() -> Bool {
        if nombreCliente.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            mensajeError = "Escribe tus nombres."
            return false
        }
        if apellidosCliente.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            mensajeError = "Escribe tus apellidos."
            return false
        }
        if correoCliente.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            mensajeError = "Escribe tu correo."
            return false
        }
        if contrasenaCliente.count < 6 {
            mensajeError = "La contraseña debe tener al menos 6 caracteres."
            return false
        }
        return true
    }

    /// Valida los campos del formulario de personal antes de llamar a Firebase.
    private func validarRegistroPersonal() -> Bool {
        guard codigoAccesoValido else {
            mensajeError = "El código de acceso no es correcto."
            return false
        }
        if nombrePersonal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            mensajeError = "Escribe tus nombres."
            return false
        }
        if apellidosPersonal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            mensajeError = "Escribe tus apellidos."
            return false
        }
        if correoPersonal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            mensajeError = "Escribe tu correo."
            return false
        }
        if contrasenaPersonal.count < 6 {
            mensajeError = "La contraseña debe tener al menos 6 caracteres."
            return false
        }
        return true
    }

    // MARK: - Ciclo de vida

    /// Cancela cualquier tarea activa al cerrar la pantalla para evitar trabajo huérfano.
    func cancelar() {
        tarea?.cancel()
        tarea = nil
        estaCargando = false
        estaEnviando = false
    }

    // Alias para compatibilidad con onDisappear que llama cancel()
    func cancel() { cancelar() }
}

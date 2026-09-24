//
//  NetworkManager.swift
//  kopion
//
//  Capa base de red para Kopion.
//  Centraliza URLSession, llaves de idempotencia, reintentos por rate limiting
//  y protección contra peticiones duplicadas iniciadas desde la interfaz.
//

import Combine
import Foundation

/// Errores normalizados de red para que los ViewModels puedan mostrar mensajes claros al usuario.
enum NetworkError: Error, LocalizedError, Equatable {
    case invalidURL
    case invalidResponse
    case decodingFailed
    case duplicateRequestInProgress
    case rateLimited
    case serverError(statusCode: Int)
    case requestFailed(String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "La URL solicitada no es valida."
        case .invalidResponse:
            return "El servidor envio una respuesta no valida."
        case .decodingFailed:
            return "No fue posible interpretar la respuesta del servidor."
        case .duplicateRequestInProgress:
            return "La solicitud ya esta en proceso."
        case .rateLimited:
            return "Demasiadas solicitudes. Por favor, espera unos segundos."
        case .serverError(let statusCode):
            return "El servidor respondio con el codigo \(statusCode)."
        case .requestFailed(let message):
            return message
        case .cancelled:
            return "La solicitud fue cancelada."
        }
    }
}

/// Metodos HTTP soportados por la capa base.
enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

/// Describe una solicitud tipada. Cada modulo podra crear endpoints sin duplicar logica de red.
struct NetworkRequest<Response: Decodable> {
    let path: String
    let method: HTTPMethod
    let queryItems: [URLQueryItem]
    let headers: [String: String]
    let body: Encodable?
    let deduplicationKey: String
    let requiresIdempotencyKey: Bool

    /// - Parameters:
    ///   - path: Ruta relativa al servidor base, por ejemplo "/products".
    ///   - method: Metodo HTTP. Las mutaciones usan POST/PUT/PATCH/DELETE.
    ///   - queryItems: Parametros de busqueda o filtros.
    ///   - headers: Headers especificos del modulo.
    ///   - body: Cuerpo JSON opcional para mutaciones.
    ///   - deduplicationKey: Llave logica para ignorar ejecuciones simultaneas iguales.
    ///   - requiresIdempotencyKey: Activa el header X-Idempotency-Key. Debe usarse en acciones que modifican datos.
    init(
        path: String,
        method: HTTPMethod = .get,
        queryItems: [URLQueryItem] = [],
        headers: [String: String] = [:],
        body: Encodable? = nil,
        deduplicationKey: String? = nil,
        requiresIdempotencyKey: Bool = true
    ) {
        self.path = path
        self.method = method
        self.queryItems = queryItems
        self.headers = headers
        self.body = body
        self.deduplicationKey = deduplicationKey ?? "\(method.rawValue):\(path):\(queryItems.description)"
        self.requiresIdempotencyKey = requiresIdempotencyKey
    }
}

/// Contrato para inyectar la red en ViewModels y permitir pruebas unitarias con mocks.
protocol NetworkManaging: Sendable {
    func send<Response: Decodable & Sendable>(_ request: NetworkRequest<Response>) async throws -> Response
    func publisher<Response: Decodable & Sendable>(for request: NetworkRequest<Response>) -> AnyPublisher<Response, NetworkError>
}

/// Implementacion principal de la capa de red.
///
/// Reglas obligatorias cubiertas:
/// - Evita peticiones duplicadas mientras una tarea con la misma deduplicationKey este activa.
/// - Genera y envia X-Idempotency-Key por accion.
/// - Conserva la misma llave de idempotencia durante reintentos de la misma accion.
/// - Maneja HTTP 429 con Retry-After y exponential backoff.
/// - Expone API async/await y un publisher Combine para flujos que requieran debounce/throttle.
actor NetworkManager: NetworkManaging {
    static let shared = NetworkManager(baseURL: URL(string: "https://api.kopion.local")!)

    private let baseURL: URL
    private let session: URLSession
    private let jsonDecoder: JSONDecoder
    private let jsonEncoder: JSONEncoder
    private let maximumRetryCount: Int
    private var activeRequestKeys: Set<String> = []

    init(
        baseURL: URL,
        session: URLSession = .shared,
        jsonDecoder: JSONDecoder = JSONDecoder(),
        jsonEncoder: JSONEncoder = JSONEncoder(),
        maximumRetryCount: Int = 3
    ) {
        self.baseURL = baseURL
        self.session = session
        self.jsonDecoder = jsonDecoder
        self.jsonEncoder = jsonEncoder
        self.maximumRetryCount = maximumRetryCount
    }

    /// Ejecuta una solicitud y devuelve el modelo decodificado.
    /// Si ya existe una solicitud activa con la misma llave, se ignora para evitar dobles taps o envios repetidos.
    func send<Response: Decodable & Sendable>(_ request: NetworkRequest<Response>) async throws -> Response {
        guard !activeRequestKeys.contains(request.deduplicationKey) else {
            throw NetworkError.duplicateRequestInProgress
        }

        activeRequestKeys.insert(request.deduplicationKey)
        defer { activeRequestKeys.remove(request.deduplicationKey) }

        let idempotencyKey = request.requiresIdempotencyKey ? UUID().uuidString : nil
        return try await execute(request, idempotencyKey: idempotencyKey, attempt: 0)
    }

    /// Puente Combine para pantallas con busquedas o controles que usen debounce/throttle.
    /// Los ViewModels pueden aplicar .debounce(for:scheduler:) antes de llamar a este publisher.
    nonisolated func publisher<Response: Decodable & Sendable>(for request: NetworkRequest<Response>) -> AnyPublisher<Response, NetworkError> {
        Deferred {
            Future { promise in
                Task {
                    do {
                        let response: Response = try await self.send(request)
                        promise(.success(response))
                    } catch let error as NetworkError {
                        promise(.failure(error))
                    } catch is CancellationError {
                        promise(.failure(.cancelled))
                    } catch {
                        promise(.failure(.requestFailed(error.localizedDescription)))
                    }
                }
            }
        }
        .eraseToAnyPublisher()
    }

    /// Construye y ejecuta la solicitud. La funcion es recursiva solo para reintentos controlados.
    private func execute<Response: Decodable & Sendable>(
        _ request: NetworkRequest<Response>,
        idempotencyKey: String?,
        attempt: Int
    ) async throws -> Response {
        try Task.checkCancellation()

        let urlRequest = try buildURLRequest(from: request, idempotencyKey: idempotencyKey)

        do {
            let (data, response) = try await session.data(for: urlRequest)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }

            switch httpResponse.statusCode {
            case 200...299:
                return try decode(Response.self, from: data)
            case 429:
                return try await retryAfterRateLimit(
                    request,
                    response: httpResponse,
                    idempotencyKey: idempotencyKey,
                    attempt: attempt
                )
            case 500...599 where attempt < maximumRetryCount:
                try await sleepForBackoff(attempt: attempt, retryAfter: nil)
                return try await execute(request, idempotencyKey: idempotencyKey, attempt: attempt + 1)
            default:
                throw NetworkError.serverError(statusCode: httpResponse.statusCode)
            }
        } catch is CancellationError {
            throw NetworkError.cancelled
        } catch let error as NetworkError {
            throw error
        } catch {
            if attempt < maximumRetryCount {
                try await sleepForBackoff(attempt: attempt, retryAfter: nil)
                return try await execute(request, idempotencyKey: idempotencyKey, attempt: attempt + 1)
            }

            throw NetworkError.requestFailed(error.localizedDescription)
        }
    }

    /// Maneja HTTP 429. Respeta Retry-After cuando viene del servidor y usa exponential backoff como respaldo.
    private func retryAfterRateLimit<Response: Decodable & Sendable>(
        _ request: NetworkRequest<Response>,
        response: HTTPURLResponse,
        idempotencyKey: String?,
        attempt: Int
    ) async throws -> Response {
        guard attempt < maximumRetryCount else {
            throw NetworkError.rateLimited
        }

        let retryAfter = parseRetryAfter(from: response)
        try await sleepForBackoff(attempt: attempt, retryAfter: retryAfter)
        return try await execute(request, idempotencyKey: idempotencyKey, attempt: attempt + 1)
    }

    /// Crea URLRequest, aplica headers base, JSON body y X-Idempotency-Key cuando corresponde.
    private func buildURLRequest<Response: Decodable>(
        from request: NetworkRequest<Response>,
        idempotencyKey: String?
    ) throws -> URLRequest {
        guard var components = URLComponents(url: baseURL.appendingPathComponent(request.path), resolvingAgainstBaseURL: false) else {
            throw NetworkError.invalidURL
        }

        if !request.queryItems.isEmpty {
            components.queryItems = request.queryItems
        }

        guard let url = components.url else {
            throw NetworkError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")

        request.headers.forEach { key, value in
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }

        if let body = request.body {
            urlRequest.httpBody = try jsonEncoder.encode(AnyEncodable(body))
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        if let idempotencyKey {
            urlRequest.setValue(idempotencyKey, forHTTPHeaderField: "X-Idempotency-Key")
        }

        return urlRequest
    }

    /// Decodifica el JSON de respuesta. EmptyResponse permite endpoints sin cuerpo.
    private func decode<Response: Decodable>(_ type: Response.Type, from data: Data) throws -> Response {
        if Response.self == EmptyResponse.self, data.isEmpty {
            return EmptyResponse() as! Response
        }

        do {
            return try jsonDecoder.decode(Response.self, from: data)
        } catch {
            throw NetworkError.decodingFailed
        }
    }

    /// Interpreta Retry-After como segundos o fecha HTTP.
    private func parseRetryAfter(from response: HTTPURLResponse) -> TimeInterval? {
        guard let value = response.value(forHTTPHeaderField: "Retry-After") else {
            return nil
        }

        if let seconds = TimeInterval(value) {
            return seconds
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"

        guard let date = formatter.date(from: value) else {
            return nil
        }

        return max(date.timeIntervalSinceNow, 0)
    }

    /// Aplica exponential backoff: 1s, 2s, 4s... usando Retry-After cuando el servidor lo indique.
    private func sleepForBackoff(attempt: Int, retryAfter: TimeInterval?) async throws {
        let exponentialDelay = pow(2.0, Double(attempt))
        let delay = retryAfter ?? exponentialDelay
        let nanoseconds = UInt64(delay * 1_000_000_000)
        try await Task.sleep(nanoseconds: nanoseconds)
    }
}

/// Respuesta util para endpoints que devuelven 204 o cuerpo vacio.
struct EmptyResponse: Decodable, Sendable {
    init() {}
}

/// Wrapper que permite codificar un Encodable existencial como JSON.
private struct AnyEncodable: Encodable {
    private let encodeClosure: (Encoder) throws -> Void

    init(_ value: Encodable) {
        self.encodeClosure = value.encode
    }

    func encode(to encoder: Encoder) throws {
        try encodeClosure(encoder)
    }
}

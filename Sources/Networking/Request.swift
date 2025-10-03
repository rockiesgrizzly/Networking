//
//  Request.swift
//
//
//  Created by joshmac on 8/30/24.
//

import Combine
import Foundation

/// Protocol enables injection of test URLSession objects
protocol URLSessionAsyncProtocol: Sendable {
    func data(for request: URLRequest, delegate: (any URLSessionTaskDelegate)?) async throws -> (Data, URLResponse)
}


extension URLSession : URLSessionAsyncProtocol { }

class Request<Model: Decodable & Sendable> {
    
    private var task: Task<Void, Never>?
    
    // MARK: - Async/Await

    /// This function takes the provided `requestModel` and utilizes
    /// URLSession to retrieve the desired `ResponseModel`.
    /// - Parameter requestModel: `RequestModel` offers various parameters. This function defaults to
    /// `cachePolicy` : `.reloadIgnoringLocalAndRemoteCacheData` & `timeoutInterval` 0 if not provided in `requestModel`
    /// - Returns: any object conforming to `Decodable`
    public static func asyncGet(_ request: URLRequest, session: any URLSessionAsyncProtocol = URLSession.shared) async throws -> Model? {
        let (data, response) = try await session.data(for: request, delegate: nil)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw RequestError.httpUrlResponseFailed(response)
        }
        
        return try JSONDecoder().decode(Model.self, from: data)
    }
    
    /// Creates a polling stream that repeatedly fetches data from the provided request
    /// - Parameters:
    ///   - request: URLRequest to poll
    ///   - interval: Time interval between polling requests (default: 3 seconds)
    ///   - session: URLSession to use for requests (default: URLSession.shared)
    /// - Returns: AsyncStream of decoded Model objects
    /// - Note: adapted from Wesley Matlock's writeup: http://bit.ly/42WOjjT
    public static func asyncStream(_ request: URLRequest,
                                   interval: Duration = .seconds(3), session: any
                                   URLSessionAsyncProtocol = URLSession.shared) -> AsyncStream<Model> {
        AsyncStream { @Sendable continuation in
            Task {
                while !Task.isCancelled {
                    do {
                        if let update = try await
                            asyncGet(request, session: session) {
                            continuation.yield(update)
                        }
                    } catch {
                        // Continue polling even if individual requests fail
                    }
                    try? await Task.sleep(for: interval)
                }
                continuation.finish()
            }
        }
    }
    
    // MARK: - Combine
    
    /// Creates a Combine publisher that repeatedly fetches data from the provided request
    /// - Parameters:
    ///   - request: URLRequest to poll
    ///   - interval: Time interval between polling requests (default: 3 seconds)
    ///   - session: URLSession to use for requests (default: URLSession.shared)
    /// - Returns: AnyPublisher that emits decoded Model objects
    public static func publisher(_ request: URLRequest, interval: TimeInterval = 3, session: URLSession = URLSession.shared) ->
    AnyPublisher<Model, Error> {
        Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .setFailureType(to: Error.self)
            .flatMap { _ in
                session.dataTaskPublisher(for: request)
                    .tryMap { data, response in
                        guard let httpResponse = response as? HTTPURLResponse,
                              httpResponse.statusCode == 200 else {
                            throw RequestError.httpUrlResponseFailed(response)
                        }
                        return data
                    }
                    .decode(type: Model.self, decoder: JSONDecoder())
                    .catch { _ in Empty<Model, Error>() }
            }
            .eraseToAnyPublisher()
    }
    


    // MARK: - Errors
    public enum RequestError: Error {
        case httpUrlResponseFailed(URLResponse)
        case taskCancelled
    }
}


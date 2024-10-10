//
//  Request.swift
//
//
//  Created by joshmac on 8/30/24.
//

import Combine
import Foundation

/// Protocol enables injection of test URLSession objects
protocol URLSessionProtocol {
    func data(from url: URL, delegate: (any URLSessionTaskDelegate)?) async throws -> (Data, URLResponse)
}

extension URLSession : URLSessionProtocol { }

class Request<Model:Decodable> {
    
    private var streamTask: Task<(), Error>?

    /// This function takes the provided `requestModel` and utilizes
    /// URLSession to retrieve the desired `ResponseModel`.
    /// - Parameter requestModel: `RequestModel` offers various parameters. This function defaults to
    /// `cachePolicy` : `.reloadIgnoringLocalAndRemoteCacheData` & `timeoutInterval` 0 if not provided in `requestModel`
    /// - Returns: any object conforming to `Decodable`
    public static func asyncGet(from url: URL, session: any URLSessionProtocol = URLSession.shared) async throws -> Model? {
        let (data, response) = try await session.data(from: url, delegate: nil)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw RequestError.httpUrlResponseFailed(response)
        }
        
        return try JSONDecoder().decode(Model.self, from: data)
    }
    
    
    /// This function creates a throwing stream of generic type `Model`on a time interval
    /// - Parameters:
    ///   - url: endpoint from which to retrieve
    ///   - repeatTimeInterval: desired time interval stream should return
    /// - Returns: generic model requested
    public func asyncThrowingStream(from url: URL, repeatTimeInterval: TimeInterval, session: any URLSessionProtocol = URLSession.shared) async -> AsyncThrowingStream<Model, Error> {
        return AsyncThrowingStream<Model, Error> { continuation in
            streamTask = Task {
                do {
                    try await withThrowingTaskGroup(of: Model?.self) { group in
                        repeat {
                            guard !Task.isCancelled else { throw RequestError.taskCancelled }
                            
                            if let model = try await Request.asyncGet(from: url, session: session) {
                                continuation.yield(model)
                            }
                            
                            try await Task.sleep(nanoseconds: UInt64(repeatTimeInterval * 1_000_000_000))
                        } while !Task.isCancelled
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    public func cancelAsyncThrowingStreamTask() {
        streamTask?.cancel()
    }

    // MARK: - Combine
    
    public static func repeatingPublisher(from url: URL, interval: TimeInterval, session: URLSession = URLSession.shared) -> AnyPublisher<Model, Error> {
        return Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .flatMap { _ in
                return session.dataTaskPublisher(for: url)
                    .tryMap { result -> Model in
                        return try JSONDecoder().decode(Model.self, from: result.data)
                    }
                    .receive(on: RunLoop.main)
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Errors
    public enum RequestError: Error {
        case httpUrlResponseFailed(URLResponse)
        case taskCancelled
    }
}


//
//  Request.swift
//
//
//  Created by joshmac on 8/30/24.
//

import Foundation

class Request<Model:Decodable> {
    
    private var streamTask: Task<(), Error>?
    
    /// This function takes the provided `requestModel` and utilizes
    /// URLSession to retrieve the desired `ResponseModel`.
    /// - Parameter requestModel: `RequestModel` offers various parameters. This function defaults to
    /// `cachePolicy` : `.reloadIgnoringLocalAndRemoteCacheData` & `timeoutInterval` 0 if not provided in `requestModel`
    /// - Returns: any object conforming to `Decodable`
    public static func asyncGet(from url: URL) async throws -> Model? {
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw RequestError.httpUrlResponseFailed(response)
        }
        
        return try JSONDecoder().decode(Model.self, from: data)
    }
    
    public func asyncThrowingStream(from url: URL, repeatTimeInterval: TimeInterval) async -> AsyncThrowingStream<Model, Error> {
        return AsyncThrowingStream<Model, Error> { continuation in
            streamTask = Task {
                do {
                    try await withThrowingTaskGroup(of: Model?.self) { group in
                        repeat {
                            guard !Task.isCancelled else { throw RequestError.taskCancelled }
                            
                            if let model = try await Request.asyncGet(from: url) {
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
    
    public enum RequestError: Error {
        case httpUrlResponseFailed(URLResponse)
        case taskCancelled
    }
}

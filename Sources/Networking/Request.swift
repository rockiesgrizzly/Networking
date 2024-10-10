//
//  Request.swift
//
//
//  Created by joshmac on 8/30/24.
//

import Combine
import Foundation

/// Protocol enables injection of test URLSession objects
protocol URLSessionAsycProtocol {
    func data(for request: URLRequest, delegate: (any URLSessionTaskDelegate)?) async throws -> (Data, URLResponse)
}


extension URLSession : URLSessionAsycProtocol { }

class Request<Model: Decodable & Sendable> {
    
    // MARK: - Async/Await

    /// This function takes the provided `requestModel` and utilizes
    /// URLSession to retrieve the desired `ResponseModel`.
    /// - Parameter requestModel: `RequestModel` offers various parameters. This function defaults to
    /// `cachePolicy` : `.reloadIgnoringLocalAndRemoteCacheData` & `timeoutInterval` 0 if not provided in `requestModel`
    /// - Returns: any object conforming to `Decodable`
    public static func asyncGet(_ request: URLRequest, session: any URLSessionAsycProtocol = URLSession.shared) async throws -> Model? {
        let (data, response) = try await session.data(for: request, delegate: nil)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw RequestError.httpUrlResponseFailed(response)
        }
        
        return try JSONDecoder().decode(Model.self, from: data)
    }

    // MARK: - Errors
    public enum RequestError: Error {
        case httpUrlResponseFailed(URLResponse)
        case taskCancelled
    }
}


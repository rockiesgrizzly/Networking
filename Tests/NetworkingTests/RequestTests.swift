//
//  RequestTests.swift
//
//
//  Created by joshmac on 8/30/24.
//

import Testing
@testable import Networking

import Combine
import Foundation


final class NetworkingTests {
    static let url = URL(string: "https://jsonplaceholder.typicode.com/todos/1")!
    static let request = URLRequest(url: url)
    static let session = TestURLSession()
    
    @Test("Request.asyncGet Success")
    static func asyncGetSuccess() async throws {
        let model: MockModel? = try await Request<MockModel>.asyncGet(request, session: session)
        #expect(model != nil)
        #expect(model?.id == 1)
        #expect(model?.name == "delectus aut autem")
    }
    
    @Test("Request.asyncGet Failure")
    static func asyncGetFailure() async throws {
        let model: MockModel? = try await Request<MockModel>.asyncGet(request, session: session)
        #expect(model?.id != 2)
        #expect(model?.name != "lorum ipsum")
    }

    @Test("Request.asyncStream Success")
    static func asyncStreamSuccess() async throws {
        let stream = Request<MockModel>.asyncStream(request, interval: .milliseconds(100), session: session)
        var count = 0

        for await model in stream {
            #expect(model.id == 1)
            #expect(model.name == "delectus aut autem")
            count += 1
            if count >= 3 {
                break
            }
        }

        #expect(count == 3)
    }

    @Test("Request.asyncStream Cancellation")
    static func asyncStreamCancellation() async throws {
        let stream = Request<MockModel>.asyncStream(request, interval: .milliseconds(100), session: session)

        let task = Task {
            var count = 0
            for await _ in stream {
                count += 1
            }
            return count
        }

        try await Task.sleep(for: .milliseconds(250))
        task.cancel()

        let count = await task.value
        #expect(count >= 2)
        #expect(count <= 3)
    }
}

// MARK: - Test Models

private let modelId = 1
private let modelString = "delectus aut autem"

// Sample Model struct for testing
struct MockModel: Codable, Equatable {
    let id: Int
    let name: String
}

struct TestURLSession: URLSessionAsyncProtocol, Sendable {
    static let model = MockModel(id: modelId, name: modelString)
    var data = try! JSONEncoder().encode(model)
    static let url = URL(string: "u2.com")! // unused
    static let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
    
    func data(for request: URLRequest, delegate: (any URLSessionTaskDelegate)?) async throws -> (Data, URLResponse) {
        return (data, TestURLSession.response)
    }
}

class URLCombineProtocol: URLProtocol {
    @MainActor static var response: URLResponse? = TestURLSession.response
    @MainActor static var error: Error?
    
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canInit(with task: URLSessionTask) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    
    override func startLoading() {
        let session = TestURLSession()
        
        self.client?.urlProtocol(self, didLoad: session.data)
        self.client?.urlProtocol(self,
                                 didReceive: TestURLSession.response,
                                 cacheStoragePolicy: .notAllowed)
        self.client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() { }
}









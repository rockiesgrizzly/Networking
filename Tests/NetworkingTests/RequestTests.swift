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


@Suite("Concurrency Tests")
struct ConcurrencyTests {
    static let url = URL(string: "https://jsonplaceholder.typicode.com/todos/1")!
    static let request = URLRequest(url: url)
    static let session = TestURLSession()

    @Test("Request.asyncGet Success")
    func asyncGetSuccess() async throws {
        let model: MockModel? = try await Request<MockModel>.asyncGet(Self.request, session: Self.session)
        #expect(model != nil)
        #expect(model?.id == 1)
        #expect(model?.name == "delectus aut autem")
    }

    @Test("Request.asyncGet Failure")
    func asyncGetFailure() async throws {
        let model: MockModel? = try await Request<MockModel>.asyncGet(Self.request, session: Self.session)
        #expect(model?.id != 2)
        #expect(model?.name != "lorum ipsum")
    }

    @Test("Request.asyncStream Success")
    func asyncStreamSuccess() async throws {
        let stream = Request<MockModel>.asyncStream(Self.request, interval: .milliseconds(100), session: Self.session)
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
    func asyncStreamCancellation() async throws {
        let stream = Request<MockModel>.asyncStream(Self.request, interval: .milliseconds(100), session: Self.session)

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

@Suite("Combine Tests")
struct CombineTests {
    static let url = URL(string: "https://jsonplaceholder.typicode.com/todos/1")!
    static let request = URLRequest(url: url)

    static var mockSession: URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLCombineProtocol.self]
        return URLSession(configuration: config)
    }

    @Test("Request.publisher Success")
    func publisherSuccess() async throws {
        await withCheckedContinuation { continuation in
            var cancellables = Set<AnyCancellable>()
            var receivedModels: [MockModel] = []

            let publisher = Request<MockModel>.publisher(Self.request, interval: 0.1, session: Self.mockSession)

            publisher
                .sink(
                    receiveCompletion: { _ in },
                    receiveValue: { model in
                        receivedModels.append(model)
                        if receivedModels.count == 3 {
                            #expect(receivedModels.allSatisfy { $0.id == 1 && $0.name == "delectus aut autem" })
                            cancellables.removeAll()
                            continuation.resume()
                        }
                    }
                )
                .store(in: &cancellables)
        }
    }

    @Test("Request.publisher Cancellation")
    func publisherCancellation() async throws {
        var cancellables = Set<AnyCancellable>()
        var count = 0

        let publisher = Request<MockModel>.publisher(Self.request, interval: 0.1, session: Self.mockSession)

        publisher
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { _ in
                    count += 1
                }
            )
            .store(in: &cancellables)

        try await Task.sleep(for: .milliseconds(350))
        cancellables.removeAll()

        let finalCount = count
        try await Task.sleep(for: .milliseconds(150))

        #expect(count == finalCount)
        #expect(count >= 1)
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









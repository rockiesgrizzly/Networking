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
        // GIVEN: A URLRequest configured with test session
        // (using static request and session)

        // WHEN: Making an async GET request
        let model: MockModel? = try await Request<MockModel>.asyncGet(Self.request, session: Self.session)

        // THEN: The model is decoded successfully with expected values
        #expect(model != nil)
        #expect(model?.id == 1)
        #expect(model?.name == "delectus aut autem")
    }

    @Test("Request.asyncGet Failure")
    func asyncGetFailure() async throws {
        // GIVEN: A URLRequest configured with test session
        // (using static request and session)

        // WHEN: Making an async GET request
        let model: MockModel? = try await Request<MockModel>.asyncGet(Self.request, session: Self.session)

        // THEN: The model does not contain incorrect values
        #expect(model?.id != 2)
        #expect(model?.name != "lorum ipsum")
    }

    @Test("Request.asyncStream Success")
    func asyncStreamSuccess() async throws {
        // GIVEN: An AsyncStream configured to poll every 100ms
        let stream = Request<MockModel>.asyncStream(Self.request, interval: .milliseconds(100), session: Self.session)
        var count = 0

        // WHEN: Iterating over the stream and collecting 3 values
        for await model in stream {
            #expect(model.id == 1)
            #expect(model.name == "delectus aut autem")
            count += 1
            if count >= 3 {
                break
            }
        }

        // THEN: Exactly 3 values were received with correct data
        #expect(count == 3)
    }

    @Test("Request.asyncStream Cancellation")
    func asyncStreamCancellation() async throws {
        // GIVEN: An AsyncStream configured to poll every 100ms
        let stream = Request<MockModel>.asyncStream(Self.request, interval: .milliseconds(100), session: Self.session)

        // WHEN: Starting a task that iterates over the stream
        let task = Task {
            var count = 0
            for await _ in stream {
                count += 1
            }
            return count
        }

        // AND: Cancelling the task after 250ms
        try await Task.sleep(for: .milliseconds(250))
        task.cancel()

        // THEN: The stream stops and received 2-3 values before cancellation
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
        // GIVEN: A Combine publisher configured to poll every 0.1s
        await withCheckedContinuation { continuation in
            var cancellables = Set<AnyCancellable>()
            var receivedModels: [MockModel] = []

            let publisher = Request<MockModel>.publisher(Self.request, interval: 0.1, session: Self.mockSession)

            // WHEN: Subscribing to the publisher and collecting values
            publisher
                .sink(
                    receiveCompletion: { _ in },
                    receiveValue: { model in
                        receivedModels.append(model)

                        // THEN: After receiving 3 values, all have correct data
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
        // GIVEN: A Combine publisher configured to poll every 0.1s
        var cancellables = Set<AnyCancellable>()
        var count = 0

        let publisher = Request<MockModel>.publisher(Self.request, interval: 0.1, session: Self.mockSession)

        // WHEN: Subscribing to the publisher
        publisher
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { _ in
                    count += 1
                }
            )
            .store(in: &cancellables)

        // AND: Cancelling after 350ms by removing all cancellables
        try await Task.sleep(for: .milliseconds(350))
        cancellables.removeAll()

        let finalCount = count
        try await Task.sleep(for: .milliseconds(150))

        // THEN: No new values are received after cancellation
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









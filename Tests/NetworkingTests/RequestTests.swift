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
    let url = URL(string: "https://jsonplaceholder.typicode.com/todos/1")!
    let session = TestURLSession()
    
    @Test("Request.asyncGet Success")
    func asyncGetSuccess() async throws {
        let model: MockModel? = try await Request<MockModel>.asyncGet(from: url, session: session)
        #expect(model != nil)
        #expect(model?.id == 1)
        #expect(model?.name == "delectus aut autem")
    }
    
    @Test("Request.asyncGet Failure")
    func asyncGetFailure() async throws {
        let model: MockModel? = try await Request<MockModel>.asyncGet(from: url, session: session)
        #expect(model?.id != 2)
        #expect(model?.name != "lorum ipsum")
    }
    
    @Test("Request.asyncThrowingStream Success")
    func testAsyncThrowingStreamSuccess() async throws {
        let stream = try #require(await Request<MockModel>().asyncThrowingStream(from: url, repeatTimeInterval: 0.1, session: session))
        
        var receivedMocks = [MockModel]()
        try await confirmation(expectedCount: 1) { confirmation in
            for try await mockModel in stream {
                receivedMocks.append(mockModel)
                
                if receivedMocks.count == 2  {
                    confirmation()
                    break
                }
            }
        }
    }
    
    // TODO: Test stream cancellation. Fairly impossible in XCTest do to a Task not allowing an outside parameter. To cancel a task, one would need some way to see the results. Explore Swift Testing in next Xcode for expanded concurrenncy testing options
    
    private var cancellables: Set<AnyCancellable> = []
    
    //    @Test("RepeatingPublisher produces correct value")
    //    func repeatingPublisherProducesCorrectValue() {
    //        let interval: TimeInterval = 0.1
    //        let expectation = expectation(description: "Publisher emits values")
    //
    //        var receivedModels = [MockModel]()
    //        Request<MockModel>.repeatingPublisher(from: url, interval: interval, session: session)
    //            .collect(2) // Collect first 2 emissions
    //            .sink(receiveCompletion: { _ in }, receiveValue: { models in
    //                receivedModels = models
    //                expectation.fulfill()
    //            })
    //            .store(in: &cancellables)
    //
    //        wait(for: [expectation], timeout: 0.5)
    //
    //        // Assertions using #expect from the Testing framework
    //        #expect(receivedModels.count == 2)
    //        #expect(receivedModels[0] == MockModel(id: modelId, name: modelString))
    //        #expect(receivedModels[1] == MockModel(id: modelId, name: modelString))
    //    }
}

private let modelId = 1
private let modelString = "delectus aut autem"


// Sample Model struct for testing
struct MockModel: Codable, Equatable {
    let id: Int
    let name: String
}

struct TestURLSession: URLSessionProtocol {
    static let model = MockModel(id: modelId, name: modelString)
    let data = try! JSONEncoder().encode(model)
    static let url = URL(string: "u2.com")!
    let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
    
    func data(from url: URL, delegate: (any URLSessionTaskDelegate)?) async throws -> (Data, URLResponse) {
        return (data, response)
    }
}








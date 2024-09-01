import XCTest
@testable import Networking

final class NetworkingTests: XCTestCase {
    let url = URL(string: "https://jsonplaceholder.typicode.com/todos/1")!
    
    struct MockModel: Codable {
        let id: Int
        let title: String
    }
    
    func testAsyncGetSuccess() async throws {
        let model: MockModel? = try await Request<MockModel>.asyncGet(from: url)
        XCTAssertNotNil(model)
        XCTAssert(model?.id == 1)
        XCTAssert(model?.title == "delectus aut autem")
    }
    
    func testWrongUrlFails() async throws {
        let failedURL = URL(string: "https://www.u2.com")!
        let model: MockModel? = try? await Request<MockModel>.asyncGet(from: failedURL)
        XCTAssertNil(model)
    }
    
    func testAsyncThrowingStreamSuccess() async throws {
        let expectation = XCTestExpectation(description: "Successful async fetch")
        let stream = await Request<MockModel>().asyncThrowingStream(from: url, repeatTimeInterval: 0.1)
        
        var receivedMocks = [MockModel]()
        for try await mockModel in stream {
            receivedMocks.append(mockModel)
            
            if receivedMocks.count == 2  {
                expectation.fulfill()
                break
            }
        }
        
        await fulfillment(of: [expectation], timeout: 1)
    }
    
    // TODO: Test stream cancellation. Fairly impossible in XCTest do to a Task not allowing an outside parameter. To cancel a task, one would need some way to see the results. Explore Swift Testing in next Xcode for expanded concurrenncy testing options
}

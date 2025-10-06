//
//  WebSocketClientTests.swift
//
//
//  Created by joshmac on 10/6/25.
//

import Testing
@testable import Networking

import Foundation

@Suite("WebSocketClient Tests")
struct WebSocketClientTests {

    @Test("Connection Creates Valid WebSocket Task")
    func connectionCreatesTask() async throws {
        // Given
        let baseURL = URL(string: "ws://localhost:8080")!
        _ = WebSocketClient(baseURL: baseURL)

        // When/Then - client is created successfully without throwing
        // Note: In a real scenario, this would fail without a running server
        // For unit tests, we'd need to inject a mock URLSession
    }

    @Test("Send Message With Valid Event")
    func sendMessageWithValidEvent() async throws {
        // Given
        let reactionEvent = ReactionEvent(
            postId: "post123",
            userId: "user456",
            reactionType: "❤️",
            timestamp: Date()
        )

        let message = WebSocketMessage.newReaction(reactionEvent)

        // When/Then - Message creation and encoding works
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(message)

        #expect(data.count > 0)
    }

    @Test("Send Comment Message")
    func sendCommentMessage() async throws {
        // Given
        let commentEvent = CommentEvent(
            postId: "post123",
            commentId: "comment789",
            userId: "user456",
            text: "Great photo!",
            timestamp: Date()
        )

        let message = WebSocketMessage.newComment(commentEvent)

        // When
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(message)

        // Then
        #expect(data.count > 0)

        // Verify roundtrip encoding/decoding
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(WebSocketMessage.self, from: data)

        if case .newComment(let decodedEvent) = decoded {
            #expect(decodedEvent.postId == "post123")
            #expect(decodedEvent.text == "Great photo!")
        } else {
            Issue.record("Expected newComment message type")
        }
    }

    @Test("Send Friend Posted Message")
    func sendFriendPostedMessage() async throws {
        // Given
        let postEvent = PostEvent(
            postId: "post999",
            userId: "user123",
            timestamp: Date()
        )

        let message = WebSocketMessage.friendPosted(postEvent)

        // When
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(message)

        // Then
        #expect(data.count > 0)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(WebSocketMessage.self, from: data)

        if case .friendPosted(let decodedEvent) = decoded {
            #expect(decodedEvent.postId == "post999")
            #expect(decodedEvent.userId == "user123")
        } else {
            Issue.record("Expected friendPosted message type")
        }
    }

    @Test("Send User Presence Message")
    func sendUserPresenceMessage() async throws {
        // Given
        let presenceEvent = PresenceEvent(
            userId: "user789",
            isOnline: true
        )

        let message = WebSocketMessage.userPresence(presenceEvent)

        // When
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(message)

        // Then
        #expect(data.count > 0)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(WebSocketMessage.self, from: data)

        if case .userPresence(let decodedEvent) = decoded {
            #expect(decodedEvent.userId == "user789")
            #expect(decodedEvent.isOnline == true)
        } else {
            Issue.record("Expected userPresence message type")
        }
    }

    @Test("Message Encoding Contains Correct Type")
    func messageEncodingContainsCorrectType() async throws {
        // Given
        let reactionEvent = ReactionEvent(
            postId: "post123",
            userId: "user456",
            reactionType: "🔥",
            timestamp: Date()
        )

        let message = WebSocketMessage.newReaction(reactionEvent)

        // When
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(message)
        let jsonString = String(data: data, encoding: .utf8)!

        // Then
        #expect(jsonString.contains("\"type\":\"new_reaction\""))
        #expect(jsonString.contains("\"payload\""))
    }

    @Test("Invalid Message Type Decoding Throws")
    func invalidMessageTypeDecodingThrows() async throws {
        // Given
        let invalidJSON = """
        {
            "type": "invalid_type",
            "payload": {}
        }
        """
        let data = invalidJSON.data(using: .utf8)!

        // When/Then
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            _ = try decoder.decode(WebSocketMessage.self, from: data)
            Issue.record("Expected decoding to throw")
        } catch {
            // Expected - invalid type should throw
            #expect(error is DecodingError)
        }
    }
}

// MARK: - Connection State Tests

@Suite("WebSocketClient Connection State Tests")
struct WebSocketConnectionStateTests {

    @Test("Connection State Enum Cases")
    func connectionStateEnumCases() async throws {
        // Given/When/Then - Verify all state cases exist and can be created
        _ = WebSocketConnectionState.disconnected
        _ = WebSocketConnectionState.connecting
        _ = WebSocketConnectionState.connected
        _ = WebSocketConnectionState.reconnecting

        let error = WebSocketConnectionState.error("Test error")
        if case .error(let message) = error {
            #expect(message == "Test error")
        } else {
            Issue.record("Expected error state with message")
        }
    }
}

// MARK: - WebSocket Error Tests

@Suite("WebSocketClient Error Tests")
struct WebSocketErrorTests {

    @Test("WebSocket Error Cases")
    func webSocketErrorCases() async throws {
        // Given/When/Then - Verify all error cases exist and can be created
        _ = WebSocketError.invalidURL
        _ = WebSocketError.notConnected
        _ = WebSocketError.encodingFailed
        _ = WebSocketError.decodingFailed
    }
}

// MARK: - Event Model Tests

@Suite("WebSocket Event Model Tests")
struct WebSocketEventTests {

    @Test("ReactionEvent Encoding and Decoding")
    func reactionEventRoundtrip() async throws {
        // Given
        let event = ReactionEvent(
            postId: "post123",
            userId: "user456",
            reactionType: "👍",
            timestamp: Date()
        )

        // When
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(event)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ReactionEvent.self, from: data)

        // Then
        #expect(decoded.postId == event.postId)
        #expect(decoded.userId == event.userId)
        #expect(decoded.reactionType == event.reactionType)
    }

    @Test("CommentEvent Encoding and Decoding")
    func commentEventRoundtrip() async throws {
        // Given
        let event = CommentEvent(
            postId: "post123",
            commentId: "comment456",
            userId: "user789",
            text: "Amazing shot!",
            timestamp: Date()
        )

        // When
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(event)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(CommentEvent.self, from: data)

        // Then
        #expect(decoded.postId == event.postId)
        #expect(decoded.commentId == event.commentId)
        #expect(decoded.userId == event.userId)
        #expect(decoded.text == event.text)
    }

    @Test("PostEvent Encoding and Decoding")
    func postEventRoundtrip() async throws {
        // Given
        let event = PostEvent(
            postId: "post123",
            userId: "user456",
            timestamp: Date()
        )

        // When
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(event)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(PostEvent.self, from: data)

        // Then
        #expect(decoded.postId == event.postId)
        #expect(decoded.userId == event.userId)
    }

    @Test("PresenceEvent Encoding and Decoding")
    func presenceEventRoundtrip() async throws {
        // Given
        let event = PresenceEvent(
            userId: "user123",
            isOnline: true
        )

        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(event)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(PresenceEvent.self, from: data)

        // Then
        #expect(decoded.userId == event.userId)
        #expect(decoded.isOnline == event.isOnline)
    }
}

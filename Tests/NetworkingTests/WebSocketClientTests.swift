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
        // GIVEN: A base URL for WebSocket connection
        let baseURL = URL(string: "ws://localhost:8080")!

        // WHEN: Creating a WebSocketClient
        _ = WebSocketClient(baseURL: baseURL)

        // THEN: Client is created successfully without throwing
        // Note: In a real scenario, this would fail without a running server
        // For unit tests, we'd need to inject a mock URLSession
    }

    @Test("Send Message With Valid Event")
    func sendMessageWithValidEvent() async throws {
        // GIVEN: A reaction event with valid data
        let reactionEvent = ReactionEvent(
            postId: "post123",
            userId: "user456",
            reactionType: "❤️",
            timestamp: Date()
        )
        let message = WebSocketMessage.newReaction(reactionEvent)

        // WHEN: Encoding the message
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(message)

        // THEN: Message is encoded successfully
        #expect(data.count > 0)
    }

    @Test("Send Comment Message")
    func sendCommentMessage() async throws {
        // GIVEN: A comment event with valid data
        let commentEvent = CommentEvent(
            postId: "post123",
            commentId: "comment789",
            userId: "user456",
            text: "Great photo!",
            timestamp: Date()
        )
        let message = WebSocketMessage.newComment(commentEvent)

        // WHEN: Encoding then decoding the message (roundtrip)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(message)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(WebSocketMessage.self, from: data)

        // THEN: Message encodes/decodes successfully with correct values
        #expect(data.count > 0)

        if case .newComment(let decodedEvent) = decoded {
            #expect(decodedEvent.postId == "post123")
            #expect(decodedEvent.text == "Great photo!")
        } else {
            Issue.record("Expected newComment message type")
        }
    }

    @Test("Send Friend Posted Message")
    func sendFriendPostedMessage() async throws {
        // GIVEN: A post event with valid data
        let postEvent = PostEvent(
            postId: "post999",
            userId: "user123",
            timestamp: Date()
        )
        let message = WebSocketMessage.friendPosted(postEvent)

        // WHEN: Encoding then decoding the message (roundtrip)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(message)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(WebSocketMessage.self, from: data)

        // THEN: Message encodes/decodes successfully with correct values
        #expect(data.count > 0)

        if case .friendPosted(let decodedEvent) = decoded {
            #expect(decodedEvent.postId == "post999")
            #expect(decodedEvent.userId == "user123")
        } else {
            Issue.record("Expected friendPosted message type")
        }
    }

    @Test("Send User Presence Message")
    func sendUserPresenceMessage() async throws {
        // GIVEN: A presence event with valid data
        let presenceEvent = PresenceEvent(
            userId: "user789",
            isOnline: true
        )
        let message = WebSocketMessage.userPresence(presenceEvent)

        // WHEN: Encoding then decoding the message (roundtrip)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(message)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(WebSocketMessage.self, from: data)

        // THEN: Message encodes/decodes successfully with correct values
        #expect(data.count > 0)

        if case .userPresence(let decodedEvent) = decoded {
            #expect(decodedEvent.userId == "user789")
            #expect(decodedEvent.isOnline == true)
        } else {
            Issue.record("Expected userPresence message type")
        }
    }

    @Test("Message Encoding Contains Correct Type")
    func messageEncodingContainsCorrectType() async throws {
        // GIVEN: A reaction event message
        let reactionEvent = ReactionEvent(
            postId: "post123",
            userId: "user456",
            reactionType: "🔥",
            timestamp: Date()
        )
        let message = WebSocketMessage.newReaction(reactionEvent)

        // WHEN: Encoding the message to JSON
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(message)
        let jsonString = String(data: data, encoding: .utf8)!

        // THEN: JSON contains correct type and payload fields
        #expect(jsonString.contains("\"type\":\"new_reaction\""))
        #expect(jsonString.contains("\"payload\""))
    }

    @Test("Invalid Message Type Decoding Throws")
    func invalidMessageTypeDecodingThrows() async throws {
        // GIVEN: JSON with an invalid message type
        let invalidJSON = """
        {
            "type": "invalid_type",
            "payload": {}
        }
        """
        let data = invalidJSON.data(using: .utf8)!

        // WHEN: Attempting to decode the invalid message
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            _ = try decoder.decode(WebSocketMessage.self, from: data)
            Issue.record("Expected decoding to throw")
        } catch {
            // THEN: Decoding throws a DecodingError
            #expect(error is DecodingError)
        }
    }
}

// MARK: - Connection State Tests

@Suite("WebSocketClient Connection State Tests")
struct WebSocketConnectionStateTests {

    @Test("Connection State Enum Cases")
    func connectionStateEnumCases() async throws {
        // GIVEN/WHEN: Creating all connection state enum cases
        _ = WebSocketConnectionState.disconnected
        _ = WebSocketConnectionState.connecting
        _ = WebSocketConnectionState.connected
        _ = WebSocketConnectionState.reconnecting

        let error = WebSocketConnectionState.error("Test error")

        // THEN: Error state contains the correct message
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
        // GIVEN/WHEN: Creating all WebSocketError enum cases
        _ = WebSocketError.invalidURL
        _ = WebSocketError.notConnected
        _ = WebSocketError.encodingFailed
        _ = WebSocketError.decodingFailed

        // THEN: All error cases can be created without throwing
    }
}

// MARK: - Event Model Tests

@Suite("WebSocket Event Model Tests")
struct WebSocketEventTests {

    @Test("ReactionEvent Encoding and Decoding")
    func reactionEventRoundtrip() async throws {
        // GIVEN: A reaction event with valid data
        let event = ReactionEvent(
            postId: "post123",
            userId: "user456",
            reactionType: "👍",
            timestamp: Date()
        )

        // WHEN: Encoding then decoding the event (roundtrip)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(event)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ReactionEvent.self, from: data)

        // THEN: Decoded event matches original values
        #expect(decoded.postId == event.postId)
        #expect(decoded.userId == event.userId)
        #expect(decoded.reactionType == event.reactionType)
    }

    @Test("CommentEvent Encoding and Decoding")
    func commentEventRoundtrip() async throws {
        // GIVEN: A comment event with valid data
        let event = CommentEvent(
            postId: "post123",
            commentId: "comment456",
            userId: "user789",
            text: "Amazing shot!",
            timestamp: Date()
        )

        // WHEN: Encoding then decoding the event (roundtrip)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(event)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(CommentEvent.self, from: data)

        // THEN: Decoded event matches original values
        #expect(decoded.postId == event.postId)
        #expect(decoded.commentId == event.commentId)
        #expect(decoded.userId == event.userId)
        #expect(decoded.text == event.text)
    }

    @Test("PostEvent Encoding and Decoding")
    func postEventRoundtrip() async throws {
        // GIVEN: A post event with valid data
        let event = PostEvent(
            postId: "post123",
            userId: "user456",
            timestamp: Date()
        )

        // WHEN: Encoding then decoding the event (roundtrip)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(event)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(PostEvent.self, from: data)

        // THEN: Decoded event matches original values
        #expect(decoded.postId == event.postId)
        #expect(decoded.userId == event.userId)
    }

    @Test("PresenceEvent Encoding and Decoding")
    func presenceEventRoundtrip() async throws {
        // GIVEN: A presence event with valid data
        let event = PresenceEvent(
            userId: "user123",
            isOnline: true
        )

        // WHEN: Encoding then decoding the event (roundtrip)
        let encoder = JSONEncoder()
        let data = try encoder.encode(event)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(PresenceEvent.self, from: data)

        // THEN: Decoded event matches original values
        #expect(decoded.userId == event.userId)
        #expect(decoded.isOnline == event.isOnline)
    }
}

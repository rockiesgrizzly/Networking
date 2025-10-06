//
//  WebSocketMessage.swift
//  Networking
//
//  Created by Josh MacDonald on 10/5/25.
//

import Foundation

enum WebSocketMessage: Codable, Sendable {
    case newReaction(ReactionEvent)
    case newComment(CommentEvent)
    case friendPosted(PostEvent)
    case userPresence(PresenceEvent)
    
    enum CodingKeys: String, CodingKey {
        case type, payload
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "new_reaction":
            let event = try container.decode(ReactionEvent.self, forKey: .payload)
            self = .newReaction(event)
        case "new_comment":
            let event = try container.decode(CommentEvent.self, forKey: .payload)
            self = .newComment(event)
        case "friend_posted":
            let event = try container.decode(PostEvent.self, forKey: .payload)
            self = .friendPosted(event)
        case "user_presence":
            let event = try container.decode(PresenceEvent.self, forKey: .payload)
            self = .userPresence(event)
        default:
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: decoder.codingPath,
                                     debugDescription: "Unknown message type: \(type)")
            )
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .newReaction(let event):
            try container.encode("new_reaction", forKey: .type)
            try container.encode(event, forKey: .payload)
            
        case .newComment(let event):
            try container.encode("new_comment", forKey: .type)
            try container.encode(event, forKey: .payload)
            
        case .friendPosted(let event):
            try container.encode("friend_posted", forKey: .type)
            try container.encode(event, forKey: .payload)
            
        case .userPresence(let event):
            try container.encode("user_presence", forKey: .type)
            try container.encode(event, forKey: .payload)
        }
    }
}

struct ReactionEvent: Codable, Sendable {
    let postId: String
    let userId: String
    let reactionType: String
    let timestamp: Date
}

struct CommentEvent: Codable, Sendable {
    let postId: String
    let commentId: String
    let userId: String
    let text: String
    let timestamp: Date
}

struct PostEvent: Codable, Sendable {
    let postId: String
    let userId: String
    let timestamp: Date
}

struct PresenceEvent: Codable, Sendable {
    let userId: String
    let isOnline: Bool
}

// MARK: - Connection State
enum WebSocketConnectionState: Sendable {
    case disconnected
    case connecting
    case connected
    case reconnecting
    case error(String)
}

// MARK: - WebSocket Error
enum WebSocketError: Error {
    case invalidURL
    case notConnected
    case encodingFailed
    case decodingFailed
}

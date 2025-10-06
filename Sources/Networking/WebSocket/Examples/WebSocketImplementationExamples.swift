//
//  WebSocketImplementationExamples.swift
//  Networking
//
//  Created by Josh MacDonald on 10/5/25.
//

import Foundation

// MARK: - Implementation Examples. Not to be Used.

@MainActor
@Observable
private final class FeedViewModel {
    var posts: [Post] = []
    var connectionStatus: String = "Disconnected"
    
    private let webSocketClient: WebSocketClient
    private var connectionTask: Task<Void, Never>?
    private var messageTask: Task<Void, Never>?
    
    init(webSocketClient: WebSocketClient) {
        self.webSocketClient = webSocketClient
        startListening()
    }
    
    private func startListening() {
        // Listen to connection state changes using AsyncStream
        connectionTask = Task { [weak self] in
            guard let self = self else { return }
            
            for await state in self.webSocketClient.connectionState {
                await MainActor.run {
                    switch state {
                    case .connected:
                        self.connectionStatus = "Connected 🟢"
                    case .connecting:
                        self.connectionStatus = "Connecting..."
                    case .reconnecting:
                        self.connectionStatus = "Reconnecting..."
                    case .disconnected:
                        self.connectionStatus = "Disconnected 🔴"
                    case .error(let message):
                        self.connectionStatus = "Error: \(message)"
                    }
                }
            }
        }
        
        // Listen to incoming messages using AsyncStream
        messageTask = Task { [weak self] in
            guard let self = self else { return }
            
            for await message in self.webSocketClient.messages {
                await self.handleWebSocketMessage(message)
            }
        }
    }
    
    private func handleWebSocketMessage(_ message: WebSocketMessage) async {
        switch message {
        case .newReaction(let event):
            handleNewReaction(event)
            
        case .newComment(let event):
            handleNewComment(event)
            
        case .friendPosted(let event):
            handleFriendPosted(event)
            
        case .userPresence(let event):
            handleUserPresence(event)
        }
    }
    
    private func handleNewReaction(_ event: ReactionEvent) {
        print("✨ New reaction on post \(event.postId): \(event.reactionType)")
        // Update UI - already on MainActor
        if let index = posts.firstIndex(where: { $0.id == event.postId }) {
            posts[index].reactions[event.reactionType, default: 0] += 1
        }
    }
    
    private func handleNewComment(_ event: CommentEvent) {
        print("💬 New comment on post \(event.postId): \(event.text)")
        if let index = posts.firstIndex(where: { $0.id == event.postId }) {
            let comment = Comment(id: event.commentId, userId: event.userId, text: event.text, timestamp: event.timestamp)
            posts[index].comments.append(comment)
        }
    }
    
    private func handleFriendPosted(_ event: PostEvent) {
        print("📸 Friend posted! Post ID: \(event.postId)")
        // Show banner notification
    }
    
    private func handleUserPresence(_ event: PresenceEvent) {
        print("👤 User \(event.userId) is now \(event.isOnline ? "online" : "offline")")
    }
    
    // MARK: - Actions
    func sendReaction(postId: String, reactionType: String) async {
        let event = ReactionEvent(
            postId: postId,
            userId: "current_user_id",
            reactionType: reactionType,
            timestamp: Date()
        )
        
        let message = WebSocketMessage.newReaction(event)
        
        do {
            // Optimistic update first
            if let index = posts.firstIndex(where: { $0.id == postId }) {
                posts[index].reactions[reactionType, default: 0] += 1
            }
            
            try await webSocketClient.send(message: message)
        } catch {
            print("❌ Failed to send reaction: \(error)")
            // Rollback optimistic update
            if let index = posts.firstIndex(where: { $0.id == postId }) {
                posts[index].reactions[reactionType, default: 1] -= 1
            }
        }
    }
    
    func connect(token: String) async {
        do {
            try await webSocketClient.connect(token: token)
        } catch {
            print("❌ Connection failed: \(error)")
            connectionStatus = "Connection failed"
        }
    }
    
    func disconnect() async {
        await webSocketClient.disconnect()
    }
    
//    deinit {
//        connectionTask?.cancel()
//        messageTask?.cancel()
//    }
}
// MARK: - Mock Post Model
struct Post: Identifiable, Codable, Sendable {
    let id: String
    let userId: String
    let imageUrl: String
    var reactions: [String: Int] = [:]
    var comments: [Comment] = []
}

struct Comment: Identifiable, Codable, Sendable {
    let id: String
    let userId: String
    let text: String
    let timestamp: Date
}

// MARK: - SwiftUI View Example
import SwiftUI

struct FeedView: View {
    @State private var viewModel: FeedViewModel
    
    init() {
        let client = WebSocketClient(baseURL: URL(string: "wss://bereal.example.com/ws")!)
        _viewModel = State(wrappedValue: FeedViewModel(webSocketClient: client))
    }
    
    var body: some View {
        VStack {
            Text(viewModel.connectionStatus)
                .padding()
            
            List(viewModel.posts) { post in
                PostRow(post: post) { reactionType in
                    Task {
                        await viewModel.sendReaction(postId: post.id, reactionType: reactionType)
                    }
                }
            }
        }
        .task {
            await viewModel.connect(token: "user_auth_token")
        }
        .onDisappear {
            Task {
                await viewModel.disconnect()
            }
        }
    }
}

private struct PostRow: View {
    let post: Post
    let onReaction: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Post Image
            AsyncImage(url: URL(string: post.imageUrl)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
            }
            .frame(height: 300)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Reactions Row
            HStack(spacing: 16) {
                ForEach(["❤️", "🔥", "😂", "😮", "👍"], id: \.self) { emoji in
                    Button {
                        onReaction(emoji)
                    } label: {
                        HStack(spacing: 4) {
                            Text(emoji)
                                .font(.title2)
                            
                            if let count = post.reactions[emoji], count > 0 {
                                Text("\(count)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
            
            // Comments Section
            if !post.comments.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Comments")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    
                    ForEach(post.comments.prefix(3)) { comment in
                        HStack(alignment: .top, spacing: 8) {
                            Text(comment.userId)
                                .font(.caption)
                                .fontWeight(.semibold)
                            
                            Text(comment.text)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    if post.comments.count > 3 {
                        Text("View all \(post.comments.count) comments")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Preview
#Preview {
    FeedView()
}


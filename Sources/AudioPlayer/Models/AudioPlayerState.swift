//
//  AudioPlayerState.swift
//  AudioPlayer
//
//  Created by Kevin DELANNOY on 11/03/16.
//  Copyright © 2016 Kevin Delannoy. All rights reserved.
//

import Foundation

/// The possible errors an `AudioPlayer` can fail with.
public enum AudioPlayerError: Error {
    
    /// The player hit the maximum retry count.
    case maxRetryCountHit
    
    /// The `AVPlayer` failed to play.
    case foundationError(Error)
    
    /// The current item that should be played is considered unplayable
    case itemNotConsideredPlayable
    
    ///  The queue doesn't contain any item that is considered playable
    case noItemsConsideredPlayable
}


public enum AudioPlayerState {
    
    /// The player is buffering data before playing them.
    case buffering
    case playing
    case paused
    case stopped
    
    /// The player is waiting for internet connection.
    case waitingForConnection
    
    /// An error occured, contains AVPlayer's error if any.
    case failed(AudioPlayerError)
}

public extension AudioPlayerState {
    
    var isBuffering: Bool {
        return self == .buffering
    }
    var isPlaying: Bool {
        return self == .playing
    }
    var isPaused: Bool {
        return self == .paused
    }
    var isStopped: Bool {
        return self == .stopped
    }
    var isWaitingForConnection: Bool {
        return self == .waitingForConnection
    }
    var isFailed: Bool {
        if case .failed = self {
            return true
        }
        return false
    }
    
    /// The error if self = `failed`.
    var error: AudioPlayerError? {
        if case .failed(let error) = self {
            return error
        }
        return nil
    }
}

// MARK: - Equatable

extension AudioPlayerState: Equatable {}

public func == (lhs: AudioPlayerState,
                rhs: AudioPlayerState) -> Bool {
        
    switch (lhs,rhs) {
    case (.buffering, .buffering),
         (.paused, .paused),
         (.playing, .playing),
         (.stopped, .stopped),
         (.waitingForConnection, .waitingForConnection):
        return true
        
    case (.failed(let e1), .failed(let e2)):
        
        switch (e1, e2) {
        case (.maxRetryCountHit, .maxRetryCountHit):
            return true
        case (.foundationError, .foundationError):
            return true
        default:
            return false
        }
        
    default:
        return false
    }
}

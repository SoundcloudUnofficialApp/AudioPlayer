//
//  AudioPlayerDelegate.swift
//  AudioPlayer
//
//  Created by Kevin DELANNOY on 09/03/16.
//  Copyright © 2016 Kevin Delannoy. All rights reserved.
//

import AVFoundation

/// This typealias only serves the purpose of saving user to `import AVFoundation`.
public typealias Metadata = [AVMetadataItem]


public protocol AudioPlayerDelegate: class {
    
    /// This method is called when the audio player changes its state. A fresh created audioPlayer starts in `.stopped`
    /// mode.
    func audioPlayer(_ player: AudioPlayer,
                     didChangeStateFrom oldState: AudioPlayerState,
                     to newState: AudioPlayerState)
    
    /// This method is called to ensure an item should be played or not. Default implementation returns `true`.
    ///
    /// - Parameters:
    ///   - item: The item that is waiting to be played.
    /// - Returns: A boolean value indicating whether the player should start playing the item or not.
    func audioPlayer(_ player: AudioPlayer,
                     shouldStartPlaying item: AudioItem) -> Bool
    
    /// This method is called when the audio player is about to start playing a new item.
    ///
    /// - Parameters:
    ///   - item: The item that is about to start being played.
    func audioPlayer(_ player: AudioPlayer,
                     willStartPlaying item: AudioItem)
    
    /// This method is called a regular time interval while playing. It notifies the delegate that the current playing
    /// progression changed.
    ///
    /// - Parameters:
    ///   - time: The current progression.
    ///   - percentageRead: The percentage of the file that has been read. It's a Float value between 0 & 100 so that
    ///         you can easily update an `UISlider` for example.
    func audioPlayer(_ player: AudioPlayer,
                     didUpdateProgressionTo time: TimeInterval,
                     percentageRead: Float)
    
    /// called when the current item duration has been found.
    ///
    /// - Parameters:
    ///   - duration: Current item's duration.
    ///   - item: Current item.
    func audioPlayer(_ player: AudioPlayer,
                     didFindDuration duration: TimeInterval,
                     for item: AudioItem)
    
    /// called before duration gets updated with discovered metadata.
    ///
    /// - Parameters:
    ///   - item: Current item.
    ///   - data: Found metadata.
    func audioPlayer(_ player: AudioPlayer,
                     didUpdateEmptyMetadataOn item: AudioItem,
                     withData data: Metadata)
    
    /// called while the audio player is loading the file (over the network or locally). It lets the
    /// delegate know what time range has already been loaded.
    ///
    /// - Parameters:
    ///   - range: The time range that the audio player loaded.
    ///   - item: Current item.
    func audioPlayer(_ player: AudioPlayer,
                     didLoad range: TimeRange,
                     for item: AudioItem)
}

/// all are optional
public extension AudioPlayerDelegate {
    
    func audioPlayer(_ player: AudioPlayer,
                     didChangeStateFrom oldState: AudioPlayerState,
                     to newState: AudioPlayerState) {}
    
    func audioPlayer(_ player: AudioPlayer,
                     shouldStartPlaying item: AudioItem) -> Bool {
        return true
    }
    
    func audioPlayer(_ player: AudioPlayer,
                     willStartPlaying item: AudioItem) {}
    
    func audioPlayer(_ player: AudioPlayer,
                     didUpdateProgressionTo time: TimeInterval,
                     percentageRead: Float) {}
    
    func audioPlayer(_ player: AudioPlayer,
                     didFindDuration duration: TimeInterval,
                     for item: AudioItem) {}
    
    func audioPlayer(_ player: AudioPlayer,
                     didUpdateEmptyMetadataOn item: AudioItem,
                     withData data: Metadata) {}
    
    func audioPlayer(_ player: AudioPlayer,
                     didLoad range: TimeRange,
                     for item: AudioItem) {}
}

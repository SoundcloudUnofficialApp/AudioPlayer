//
//  AudioPlayer+CurrentItem.swift
//  AudioPlayer
//
//  Created by Kevin DELANNOY on 29/03/16.
//  Copyright © 2016 Kevin Delannoy. All rights reserved.
//

import Foundation
import AVFoundation


public extension AudioPlayer {
    
    var curAVPlayerItem: AVPlayerItem? {
        return player?.currentItem
    }
    
    /// The current item progression or nil if no item.
    var currentItemProgression: TimeInterval? {
        return curAVPlayerItem?.currentTime().ap_timeIntervalValue
    }
    
    /// The current item duration or nil if no item or unknown duration.
    var currentItemDuration: TimeInterval? {
        return curAVPlayerItem?.duration.ap_timeIntervalValue
    }
    
    /// The current seekable range.
    var currentItemSeekableRange: TimeRange? {
        
        guard let rng = curAVPlayerItem?.seekableTimeRanges.last?.timeRangeValue else {
            return nil
        }
        
        if let start = rng.start.ap_timeIntervalValue,
            let end = rng.end.ap_timeIntervalValue {
            return TimeRange(start, end)
            
        } else if let progress = currentItemProgression {
            // if there is no start and end point of seekable range
            // return the current time, so no seeking possible
            return TimeRange(progress, progress)
        }
        // cannot seek at all, so return nil
        return nil
    }
    
    /// The current loaded range.
    var currentItemLoadedRange: TimeRange? {
        
        guard let rng = curAVPlayerItem?.loadedTimeRanges.last?.timeRangeValue else {
            return nil
        }
        
        if let start = rng.start.ap_timeIntervalValue,
            let end = rng.end.ap_timeIntervalValue {
            return TimeRange(start, end)
        }
        return nil
    }
    
    var currentItemLoadedAhead: TimeInterval? {
        
        if  let loadedRange = currentItemLoadedRange,
            let currentTime = player?.currentTime(),
            loadedRange.earliest <= currentTime.seconds {
            return loadedRange.latest - currentTime.seconds
        }
        return nil
    }
}

public struct TimeRange {
    
    public var earliest: TimeInterval
    public var latest: TimeInterval
    
    public init(_ earliest: TimeInterval,
                _ latest: TimeInterval) {
        self.earliest = earliest
        self.latest = latest
    }
}

//
//  AudioPlayer+Control.swift
//  AudioPlayer
//
//  Created by Kevin DELANNOY on 29/03/16.
//  Copyright © 2016 Kevin Delannoy. All rights reserved.
//

import CoreMedia
import UIKit

public extension AudioPlayer {
    
    /// Resumes the player.
    func resume() {
        //Ensure pause flag is no longer set
        pausedForInterruption = false
        
        player?.rate = rate
        
        //We don't wan't to change the state to Playing in case it's Buffering. That
        //would be a lie.
        if !state.isPlaying && !state.isBuffering {
            state = .playing
        }
        retryEventProducer.startProducing()
    }
    
    /// Pauses the player.
    func pause() {
        //We ensure the player actually pauses
        player?.rate = 0
        state = .paused
        
        retryEventProducer.stopProducing()
        
        //Let's begin a background task for the player to keep buffering if the app is in
        //background. This will mimic the default behavior of `AVPlayer` when pausing while the
        //app is in foreground.
        backgroundHandler.beginBackgroundTask()
    }
    
    func playImmediately() {
        self.state = .playing
        player?.playImmediately(atRate: rate)
        
        retryEventProducer.stopProducing()
        backgroundHandler.endBackgroundTask()
        
    }
    
    /// Plays previous item in the queue or rewind current item.
    func previous() {
        if let previousItem = queue?.previousItem() {
            currentItem = previousItem
        } else {
            seek(to: 0)
        }
    }
    
    /// Plays next item in the queue.
    func next() {
        if let nextItem = queue?.nextItem() {
            currentItem = nextItem
        }
    }
    
    /// Plays the next item in the queue and if there isn't, the player will stop.
    func nextOrStop() {
        if let nextItem = queue?.nextItem() {
            currentItem = nextItem
        } else {
            stop()
        }
    }
    
    /// Stops the player and clear the queue.
    func stop() {
        retryEventProducer.stopProducing()
        
        if let _ = player {
            player?.rate = 0
            player = nil
        }
        if let _ = currentItem {
            currentItem = nil
        }
        if let _ = queue {
            queue = nil
        }
        
        setAudioSession(active: false)
        state = .stopped
    }
    
    /// Seeks to a specific time.
    ///
    /// - Parameters:
    ///   - time: The time to seek to.
    ///   - byAdaptingTimeToFitSeekableRanges: A boolean value indicating whether the time should be adapted to current
    ///         seekable ranges in order to be bufferless.
    ///   - toleranceBefore: The tolerance allowed before time.
    ///   - toleranceAfter: The tolerance allowed after time.
    ///   - completionHandler: The optional callback that gets executed upon completion with a boolean param indicating
    ///         if the operation has finished.
    func seek(to time: TimeInterval,
              byAdaptingTimeToFitSeekableRanges: Bool = false,
              toleranceBefore: CMTime = CMTime.positiveInfinity,
              toleranceAfter: CMTime = CMTime.positiveInfinity,
              _ completion: ((Bool) -> Void)? = nil) {
        
        guard let rng = currentItemSeekableRange else {
                //In case we don't have a valid `seekableRange`, although this *shouldn't* happen
                //let's just call `AVPlayer.seek(to:)` with given values.
                seekSafely(to: time, toleranceBefore: toleranceBefore, toleranceAfter: toleranceAfter, completion)
                return
        }
        
        let earliest = rng.earliest
        let latest = rng.latest
        
        if !byAdaptingTimeToFitSeekableRanges ||
            (time >= earliest && time <= latest) {
            
            //Time is in seekable range, there's no problem here.
            seekSafely(to: time, toleranceBefore: toleranceBefore, toleranceAfter: toleranceAfter,
                       completion)
            
        } else if time < earliest {
            
            //Time is before seekable start, so just move to the most early position as possible.
            seekToSeekableRangeStart(padding: 1, completion)
            
        } else if time > latest {
            //Time is larger than possibly, so just move forward as far as possible.
            seekToSeekableRangeEnd(padding: 1, completion)
        }
    }
    
    /// Seeks backwards as far as possible.
    ///
    /// - Parameter padding: The padding to apply if any.
    /// - completionHandler: The optional callback that gets executed upon completion with a boolean param indicating
    ///     if the operation has finished.
    func seekToSeekableRangeStart(padding: TimeInterval,
                                  _ completion: ((Bool) -> Void)? = nil) {
        guard let range = currentItemSeekableRange else {
            completion?(false)
            return
        }
        let position = min(range.latest, range.earliest + padding)
        seekSafely(to: position, completion)
    }
    
    /// Seeks forward as far as possible.
    ///
    /// - Parameter padding: The padding to apply if any.
    /// - completionHandler: The optional callback that gets executed upon completion with a boolean param indicating
    ///     if the operation has finished.
    func seekToSeekableRangeEnd(padding: TimeInterval,
                                _ completion: ((Bool) -> Void)? = nil) {
        guard let range = currentItemSeekableRange else {
            completion?(false)
            return
        }
        let position = max(range.earliest, range.latest - padding)
        seekSafely(to: position, completion)
    }
    
    //swiftlint:disable cyclomatic_complexity
    /// Handle events received from Control Center/Lock screen/Other in UIApplicationDelegate.
    ///
    /// - Parameter event: The event received.
    func remoteControlReceived(with event: UIEvent) {
        guard event.type == .remoteControl else {
            return
        }
        
        switch event.subtype {
        case .remoteControlBeginSeekingBackward:
            seekingBehavior.handleSeekingStart(self, forward: false)
        case .remoteControlBeginSeekingForward:
            seekingBehavior.handleSeekingStart(self, forward: true)
        case .remoteControlEndSeekingBackward:
            seekingBehavior.handleSeekingEnd(self, forward: false)
        case .remoteControlEndSeekingForward:
            seekingBehavior.handleSeekingEnd(self, forward: true)
        case .remoteControlNextTrack:
            next()
        case .remoteControlPause,
             .remoteControlTogglePlayPause where state.isPlaying:
            pause()
        case .remoteControlPlay,
             .remoteControlTogglePlayPause where state.isPaused:
            resume()
        case .remoteControlPreviousTrack:
            previous()
        case .remoteControlStop:
            stop()
        default:
            break
        }
    }
    
    
    fileprivate func seekSafely(to time: TimeInterval,
                                toleranceBefore: CMTime = CMTime.positiveInfinity,
                                toleranceAfter: CMTime = CMTime.positiveInfinity,
                                _ completion: ((Bool) -> Void)?) {
        
        guard let completion = completion else {
            player?.seek(to: CMTime(timeInterval: time), toleranceBefore: toleranceBefore,
                         toleranceAfter: toleranceAfter)
            updateNowPlayingInfoCenter()
            return
        }
        guard curAVPlayerItem?.status == .readyToPlay else {
            completion(false)
            return
        }
        player?.seek(to: CMTime(timeInterval: time),
                     toleranceBefore: toleranceBefore,
                     toleranceAfter: toleranceAfter,
                     completionHandler: { [weak self] finished in
                        completion(finished)
                        self?.updateNowPlayingInfoCenter()
        })
    }
}

//
//  AudioPlayer+PlayerEvent.swift
//  AudioPlayer
//
//  Created by Kevin DELANNOY on 03/04/16.
//  Copyright © 2016 Kevin Delannoy. All rights reserved.
//

extension AudioPlayer {
    
    func handle(_ event: PlayerEventProducer.PlayerEvent,
                from producer: EventProducerP) {
        
        switch event {
        case .endedPlaying(let error):
            if let error = error {
                state = .failed(.foundationError(error))
            } else {
                nextOrStop()
            }
            
        case .interruptionBegan where state.isPlaying || state.isBuffering:
            //We pause the player when an interruption is detected
            backgroundHandler.beginBackgroundTask()
            pausedForInterruption = true
            pause()
            
        case .interruptionEnded(let shouldResume) where pausedForInterruption:
            if resumeAfterInterruption && shouldResume {
                resume()
            }
            pausedForInterruption = false
            backgroundHandler.endBackgroundTask()
            
        case .loadedDuration(let time):
            guard let currentItem = currentItem,
                let time = time.ap_timeIntervalValue else {
                    break
            }
            
            updateNowPlayingInfoCenter()
            delegate?.audioPlayer(self, didFindDuration: time, for: currentItem)
            
            
        case .loadedMetadata(let metadata):
            guard let currentItem = currentItem,
                !metadata.isEmpty else {
                    break
            }
            
            currentItem.parseMetadata(metadata)
            delegate?.audioPlayer(self, didUpdateEmptyMetadataOn: currentItem, withData: metadata)
            
        case .loadedMoreRange:
            
            guard let currentItem = currentItem,
                let rng = currentItemLoadedRange else {
                    break
            }
            delegate?.audioPlayer(self, didLoad: rng, for: currentItem)
            
            if bufferingStrategy == .playWhenPreferredBufferDurationFull,
                state == .buffering,
                let item = currentItemLoadedAhead,
                item.isNormal,
                item >= preferredBufferDurationBeforePlayback {
                
                playImmediately()
            }
            
        case .progressedPlaying(let time):
            guard let progress = time.ap_timeIntervalValue,
                let item = player?.currentItem,
                item.status == .readyToPlay else {
                    break
            }
            //This fixes the behavior where sometimes the `playbackLikelyToKeepUp` isn't
            //changed even though it's playing (happens mostly at the first play though).
            if state.isBuffering || state.isPaused {
                if shouldResumePlaying {
                    stateBeforeBuffering = nil
                    state = .playing
                    player?.rate = rate
                } else {
                    player?.rate = 0
                    state = .paused
                }
                backgroundHandler.endBackgroundTask()
            }
            
            //Then we can call the didUpdateProgressionTo: delegate method
            let itemDuration = currentItemDuration ?? 0
            let percentage = (itemDuration > 0 ? Float(progress / itemDuration) * 100 : 0)
            delegate?.audioPlayer(self, didUpdateProgressionTo: progress, percentageRead: percentage)
            
        case .readyToPlay:
            
            //There is enough data in the buffer
            if shouldResumePlaying {
                stateBeforeBuffering = nil
                state = .playing
                player?.rate = rate
            } else {
                player?.rate = 0
                state = .paused
            }
            
            //TODO: where to start?
            retryEventProducer.stopProducing()
            backgroundHandler.endBackgroundTask()
            
        case .routeChanged:
            //In some route changes, the player pause automatically
            //TODO: there should be a check if state == playing
            if let player = player, player.rate == 0 {
                state = .paused
            }
            
        case .sessionMessedUp:
            //We re-enable the audio session directly in case we're in background
            setAudioSession(active: true)
            
            //Aaaaand we: restart playing/go to next
            state = .stopped
            qualityAdjProducer.interruptionCount += 1
            retryOrPlayNext()
            
        case .startedBuffering:
            
            //The buffer is empty and player is loading
            if case .playing = state, !qualityIsBeingChanged {
                qualityAdjProducer.interruptionCount += 1
            }
            
            stateBeforeBuffering = state
            
            if isReachable || currentItem?.soundURLs[currentQuality]?.ap_isOfflineURL == true {
                
                state = .buffering
            } else {
                state = .waitingForConnection
            }
            backgroundHandler.beginBackgroundTask()
            
        default:
            break
        }
    }
}

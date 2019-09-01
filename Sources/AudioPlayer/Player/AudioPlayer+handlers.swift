//
//  AudioPlayer+RetryEvent.swift
//  AudioPlayer
//
//  Created by Kevin DELANNOY on 15/04/16.
//  Copyright © 2016 Kevin Delannoy. All rights reserved.
//

import Foundation


extension AudioPlayer {
    
    func handle(_ event: AudioItemEventProducer.AudioItemEvent,
                from producer: EventProducerP) {
        updateNowPlayingInfoCenter()
    }
    
    func handle(_ event: SeekEventProducer.SeekEvent,
                from producer: EventProducerP) {
        
        guard let currentItemProgression = currentItemProgression,
            case .changeTime(_, let delta) = seekingBehavior else {
                return }
        
        switch event {
        case .seekBackward:
            seek(to: currentItemProgression - delta)
            
        case .seekForward:
            seek(to: currentItemProgression + delta)
        }
    }
    
    func handle(_ event: RetryEventProducer.RetryEvent,
                from producer: EventProducerP) {
        switch event {
        case .retryAvailable:
            retryOrPlayNext()
            
        case .retryFailed:
            state = .failed(.maxRetryCountHit)
            producer.stopProducing()
        }
    }
    
    func handle(_ event: NetEventProducer.NetEvent,
                from producer: EventProducerP) {
        switch event {
        case .connectionLost:
            //the state prevents us to handle connection loss
            guard let currentItem = currentItem, !state.isWaitingForConnection else {
                return
            }
            
            //In case we're not playing offline file
            guard !(currentItem.soundURLs[currentQuality]?.ap_isOfflineURL == true) else {
                return
            }
            stateWhenConnectionLost = state
            
            guard let item = curAVPlayerItem, item.isPlaybackBufferEmpty else {
                return
            }
            if case .playing = state {
                qualityAdjProducer.interruptionCount += 1
            }
            
            state = .waitingForConnection
            backgroundHandler.beginBackgroundTask()
            
        case .connectionRetrieved:
            //Early exit if connection wasn't lost during playing or `resumeAfterConnectionLoss` isn't enabled.
            guard let lossDate = netEventProducer.connectionLossDate,
                let stateWhenLost = stateWhenConnectionLost, resumeAfterConnectionLoss else {
                    return
            }
            
            let isAllowedToRestart = lossDate.timeIntervalSinceNow < maxConnectionLossTime
            let wasPlayingBeforeLoss = !stateWhenLost.isStopped
            
            if isAllowedToRestart && wasPlayingBeforeLoss {
                retryOrPlayNext()
            }
            
            stateWhenConnectionLost = nil
            
        case .networkChanged:
            break
        }
    }
}

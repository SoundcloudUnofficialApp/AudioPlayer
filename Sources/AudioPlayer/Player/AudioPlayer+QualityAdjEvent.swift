//
//  AudioPlayer+QualityAdjEvent.swift
//  AudioPlayer
//
//  Created by Kevin DELANNOY on 03/04/16.
//  Copyright © 2016 Kevin Delannoy. All rights reserved.
//

import AVFoundation

extension AudioPlayer {
    
    /// Handles quality adjustment events.
    func handle(_ event: QualityAdjEventProducer.QualityAdjEvent,
                from producer: EventProducerP) {
        //user doesn't want to adjust quality
        guard autoAdjustQuality else {
            return
        }
        
        let adjustment: Int
        switch event {
        case .goDown:
            adjustment = -1
        case .goUp:
            adjustment = 1
        }
        let val = currentQuality.rawValue + adjustment
        guard let quality = AudioQuality(rawValue: val) else {
            return
        }
        changeQuality(to: quality)
    }


    /// Changes quality of the stream if possible.
    private func changeQuality(to newQuality: AudioQuality) {
        
        guard let url = currentItem?.soundURLs[newQuality] else {
            return
        }

        let itemProgress = currentItemProgression
        let item = AVPlayerItem(url: url)
        updatePlayerItemForBufferingStrategy(item)

        qualityIsBeingChanged = true
        player?.replaceCurrentItem(with: item)
        if let itemProgress = itemProgress {
            //We can't call self.seek(to:) in here since the player is loading a new
            //item and `itemProgress` is probably not in the seekableTimeRanges.
            player?.seek(to: CMTime(timeInterval: itemProgress))
        }
        qualityIsBeingChanged = false

        currentQuality = newQuality
    }
}

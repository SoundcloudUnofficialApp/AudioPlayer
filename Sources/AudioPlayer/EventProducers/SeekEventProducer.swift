//
//  SeekEventProducer.swift
//  AudioPlayer
//
//  Created by Kevin DELANNOY on 2016-10-27.
//  Copyright © 2016 Kevin Delannoy. All rights reserved.
//

import Foundation

private extension Selector {
    /// The selector to call when the timer ticks.
    static let timerTicked = #selector(SeekEventProducer.timerTicked(_:))
}

/// A `SeekEventProducer` generates `SeekEvent`s when it's time to seek on the stream.
class SeekEventProducer: NSObject, EventProducerP {
    
    enum SeekEvent: EventP {
        case seekBackward
        case seekForward
    }

    private var timer: Timer?

    weak var eventListener: EventListenerP?
    
    private var listening = false

    /// The delay to wait before cancelling last retry and retrying. Default value is 10 seconds.
    var intervalBetweenEvents = TimeInterval(10)

    /// A boolean value indicating whether the producer should generate backward or forward events.
    var isBackward = false
    
    
    //MARK: -

    /// Starts listening to the player events.
    func startProducing() {
        guard !listening else {
            return
        }

        //Creates a new timer for next retry
        restartTimer()
        listening = true
    }

    /// Stops listening to the player events.
    func stopProducing() {
        guard listening else {
            return
        }

        timer?.invalidate()
        timer = nil
        listening = false
    }

    /// Stops the current timer if any and restart a new one.
    private func restartTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(
            timeInterval: intervalBetweenEvents,
            target: self,
            selector: .timerTicked,
            userInfo: nil,
            repeats: false)
    }

    /// The retry timer ticked.
    ///
    /// - Parameter _: The timer.
    @objc fileprivate func timerTicked(_: AnyObject) {
        eventListener?.onEvent(isBackward ? SeekEvent.seekBackward : .seekForward, generetedBy: self)
        restartTimer()
    }
    
    deinit {
        stopProducing()
    }
}

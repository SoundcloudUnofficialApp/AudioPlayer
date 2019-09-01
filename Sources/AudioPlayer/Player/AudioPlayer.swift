//
//  AudioPlayer.swift
//  AudioPlayer
//
//  Created by Kevin DELANNOY on 26/04/15.
//  Copyright (c) 2015 Kevin Delannoy. All rights reserved.
//

import AVFoundation
import MediaPlayer


/// An `AudioPlayer` instance is used to play `AudioPlayerItem`. It's an easy to use AVPlayer with simple methods to
/// handle the whole playing audio process.
/// You can get events (such as state change or time observation) by registering a delegate.
public class AudioPlayer: NSObject {
    
    let backgroundHandler = BackgroundHandler()
    
    let reachability = Reachability()
    
    /// Reachability.isReachable()
    var isReachable: Bool {
        reachability.isReachable
    }
    
    // MARK: EventP producers
    
    lazy var netEventProducer: NetEventProducer = {
        NetEventProducer(self.reachability)
    }()
    
    let playerEventProducer = PlayerEventProducer()
    
    let seekEventProducer = SeekEventProducer()
    
    var qualityAdjProducer = QualityAdjEventProducer()
    
    var audioItemEventProducer = AudioItemEventProducer()
    
    var retryEventProducer = RetryEventProducer()
    
    
    // MARK: Player
    
    /// The queue containing items to play.
    var queue: AudioItemQueue?
    
    var player: AVPlayer? {
        didSet {
            player?.allowsExternalPlayback = false
            player?.volume = volume
            player?.rate = rate
            updatePlayerForBufferingStrategy()
            
            if let player = player {
                playerEventProducer.player = player
                audioItemEventProducer.item = currentItem
                playerEventProducer.startProducing()
                netEventProducer.startProducing()
                audioItemEventProducer.startProducing()
                qualityAdjProducer.startProducing()
            } else {
                playerEventProducer.player = nil
                audioItemEventProducer.item = nil
                playerEventProducer.stopProducing()
                netEventProducer.stopProducing()
                audioItemEventProducer.stopProducing()
                qualityAdjProducer.stopProducing()
            }
        }
    }
    
    /// The current item being played.
    public internal(set) var currentItem: AudioItem? {
        didSet {
            guard let item = currentItem else {
                stop()
                return
            }
            //Stops the current player
            player?.rate = 0
            player = nil
            
            //Ensures the audio session got started
            setAudioSession(active: true)
            
            //Set new state
            
            let info = item.url(for: currentQuality)
            guard isReachable || info.url.ap_isOfflineURL else {
                stateWhenConnectionLost = .buffering
                state = .waitingForConnection
                backgroundHandler.beginBackgroundTask()
                return
            }
            state = .buffering
            backgroundHandler.beginBackgroundTask()
            pausedForInterruption = false
            
            let playerItem = AVPlayerItem(url: info.url)
            playerItem.preferredForwardBufferDuration = self.preferredForwardBufferDuration
            
            
            player = AVPlayer(playerItem: playerItem)
            currentQuality = info.quality
            
            updateNowPlayingInfoCenter()
            
            if oldValue != currentItem {
                delegate?.audioPlayer(self, willStartPlaying: item)
            }
            player?.rate = rate
        }
    }
    
    // MARK: - 
    
    /// The delegate that will be called upon events.
    public weak var delegate: AudioPlayerDelegate?
    
    /// Max to wait after a connection loss before putting the player to Stopped mode and cancelling
    /// the resume. Default value is 60 seconds.
    public var maxConnectionLossTime = TimeInterval(60)
    
    /// Whether the player should automatically adjust sound quality based on the number of interruption before
    /// a delay and the maximum number of interruption whithin this delay. Default value is `true`.
    public var autoAdjustQuality = true
    
    /// The default quality used to play. Default value is `.medium`
    public var defaultQuality: AudioQuality = .medium
    
    
    /// Whether the player should resume after a system interruption or not. Default value is `true`.
    public var resumeAfterInterruption = true
    
    /// Whether the player should resume after a connection loss or not. Default value is `true`.
    public var resumeAfterConnectionLoss = true
    
    /// Mode of the player. Default is `.Normal`.
    public var mode = AudioPlayerMode.normal {
        didSet {
            queue?.mode = mode
        }
    }
    
    /// Volume of the player. `1.0` means 100% and `0.0` is 0%.
    public var volume = Float(1) {
        didSet {
            player?.volume = volume
        }
    }
    
    /// Rate of the player. Default value is 1.
    public var rate = Float(1) {
        didSet {
            if case .playing = state {
                player?.rate = rate
                updateNowPlayingInfoCenter()
            }
        }
    }
    
    /// Defines the buffering strategy used to determine how much to buffer before starting playback
    public var bufferingStrategy: BufferingStrategy = .defaultBuffering {
        didSet {
            updatePlayerForBufferingStrategy()
        }
    }
    
    /// Defines the preferred buffer duration in seconds before playback begins. Defaults to 60.
    /// Works when `bufferingStrategy` is `.playWhenPreferredBufferDurationFull`.
    public var preferredBufferDurationBeforePlayback = TimeInterval(60)
    
    /// Defines the preferred size of the forward buffer for the underlying `AVPlayerItem`.
    /// default is 0, which lets `AVPlayer` decide.
    public var preferredForwardBufferDuration = TimeInterval(0)
    
    
    /// Defines the rate behavior of the player when the backward/forward buttons are pressed. Default value
    /// is `multiplyRate(2)`.
    public var seekingBehavior: SeekingBehavior = .multiplyRate(2) {
        didSet {
            if case .changeTime(let timerInterval, _) = seekingBehavior {
                seekEventProducer.intervalBetweenEvents = timerInterval
            }
        }
    }
    
    // MARK: Readonly properties
    
    /// The current state of the player.
    public internal(set) var state: AudioPlayerState = .stopped {
        didSet {
            updateNowPlayingInfoCenter()
            
            guard state != oldValue else {
                return
            }
            if case .buffering = state {
                backgroundHandler.beginBackgroundTask()
                
            } else if case .buffering = oldValue {
                backgroundHandler.endBackgroundTask()
            }
            
            delegate?.audioPlayer(self, didChangeStateFrom: oldValue, to: state)
        }
    }
    
    public internal(set) var currentQuality: AudioQuality
    
    
    // MARK: Private properties
    
    /// A boolean value indicating whether the player has been paused because of a system interruption.
    var pausedForInterruption = false
    
    /// A boolean value indicating if quality is being changed. It's necessary for the interruption count to not be
    /// incremented while new quality is buffering.
    var qualityIsBeingChanged = false
    
    /// The state before the player went into .Buffering. It helps to know whether to restart or not the player.
    var stateBeforeBuffering: AudioPlayerState?
    
    /// The state of the player when the connection was lost
    var stateWhenConnectionLost: AudioPlayerState?
    
    //MARK: producers
    
    
    /// Delay within which the player wait for an interruption before upgrading the quality. Default value
    /// is 10 minutes.
    public var adjQualityInternal: TimeInterval {
        get {
            return qualityAdjProducer.adjQualityInternal
        }
        set {
            qualityAdjProducer.adjQualityInternal = newValue
        }
    }
    
    /// Maximum number of interruption to have within the `adjustQualityTimeInterval` delay before
    /// downgrading the quality. Default value is 5.
    public var adjustQualityAfterInterruptionCount: Int {
        get {
            return qualityAdjProducer.adjustQualityAfterInterruptionCount
        }
        set {
            qualityAdjProducer.adjustQualityAfterInterruptionCount = newValue
        }
    }
    
    /// The maximum number of interruption before putting the player to Stopped mode. Default value is 10.
    public var maxRetryCount: Int {
        get {
            return retryEventProducer.maxRetryCount
        }
        set {
            retryEventProducer.maxRetryCount = newValue
        }
    }
    
    /// The delay to wait before cancelling last retry and retrying. Default value is 10 seconds.
    public var retryTimeout: TimeInterval {
        get {
            return retryEventProducer.retryTimeout
        }
        set {
            retryEventProducer.retryTimeout = newValue
        }
    }
    
    // MARK: -
    
    public override init() {
        currentQuality = defaultQuality
        super.init()
        
        playerEventProducer.eventListener = self
        netEventProducer.eventListener = self
        audioItemEventProducer.eventListener = self
        qualityAdjProducer.eventListener = self
    }
    
    // MARK: Utilities
    
    /// Updates the MPNowPlayingInfoCenter with current item's info.
    func updateNowPlayingInfoCenter() {
        let center = MPNowPlayingInfoCenter.default()
        
        guard let item = currentItem else {
            center.nowPlayingInfo = nil
            return
        }
        center.ap_update(with: item,
                         duration: currentItemDuration,
                         progression: currentItemProgression,
                         playbackRate: player?.rate ?? 0)
    }
    
    /// Enables or disables the `AVAudioSession` and sets the right category.
    ///
    /// - Parameter active: A boolean value indicating whether the audio session should be set to active or not.
    func setAudioSession(active: Bool) {
        
        let s = AVAudioSession.sharedInstance()
        do {
            _ = try s.setCategory(.playback)
            _ = try s.setActive(active)
            
        } catch let error {
            print(error.localizedDescription)
        }
    }
    
    // MARK: Public computed properties
    
    /// Boolean value indicating whether the player should resume playing (after buffering)
    var shouldResumePlaying: Bool {
        return !state.isPaused &&
            stateWhenConnectionLost?.isPaused == true &&
            stateBeforeBuffering?.isPaused == true
    }
    
    // MARK: Retrying
    
    /// This will retry to play current item and seek back at the correct position if possible (or enabled).
    /// If not, it'll just play the next item in queue.
    func retryOrPlayNext() {
        guard !state.isPlaying else {
            retryEventProducer.stopProducing()
            return
        }
        //?
        let itemProgress = currentItemProgression
        let item = currentItem
        currentItem = item
        if let progress = itemProgress {
            //We can't call self.seek(to:) in here since the player is new
            //and `itemProgress` is probably not in the seekableTimeRanges.
            player?.seek(to: CMTime(timeInterval: progress))
        }
    }
    
    /// Updates the current player based on the current buffering strategy.
    func updatePlayerForBufferingStrategy() {
        let r = bufferingStrategy != .playWhenBufferNotEmpty
        player?.automaticallyWaitsToMinimizeStalling = r
    }
    
    /// Updates a given player item based on the `preferredForwardBufferDuration` set.
    func updatePlayerItemForBufferingStrategy(_ playerItem: AVPlayerItem) {
        //Nothing strategy-specific yet
        playerItem.preferredForwardBufferDuration = self.preferredForwardBufferDuration
    }
    
    deinit {
        stop()
    }
}

//MARK: state conveniences

public extension AudioPlayer {
    
    var isBuffering: Bool {
        return state.isBuffering
    }
    var isPlaying: Bool {
        return state.isPlaying
    }
    var isPaused: Bool {
        return state.isPaused
    }
    var isStopped: Bool {
        return state.isStopped
    }
    var isWaitingForConnection: Bool {
        return state.isWaitingForConnection
    }
    var isFailed: Bool {
        return state.isFailed
    }
    
    /// The error if self = `failed`.
    var error: AudioPlayerError? {
        return state.error
    }
}


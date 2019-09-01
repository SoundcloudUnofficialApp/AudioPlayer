

/// Strategy used for buffering of items before playback is started
public enum BufferingStrategy: Int {
    
    /// Uses the default AVPlayer buffering strategy, which buffers very aggressively before starting playback.
    /// This often leads to start of playback being delayed more than necessary.
    case defaultBuffering
    
    /// Uses a strategy better at quickly starting playback. Duration to buffer before playback is customizable through
    /// the `preferredBufferDurationBeforePlayback` variable.
    case playWhenPreferredBufferDurationFull
    
    /// Uses a strategy that simply starts playback whenever the AVPlayerItem buffer is non-empty
    case playWhenBufferNotEmpty
}


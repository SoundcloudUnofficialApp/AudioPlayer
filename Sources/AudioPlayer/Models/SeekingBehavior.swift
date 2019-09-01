
import Foundation

/// Defines how to behave when the user is seeking through the lockscreen or the control center.
public enum SeekingBehavior {
    
    /// Multiples the rate by a factor.
    case multiplyRate(Float)
    
    /// Changes the current position by adding/substracting a time interval.
    case changeTime(every: TimeInterval, delta: TimeInterval)
    
    
    //MARK: funcs
    
    func handleSeekingStart(_ player: AudioPlayer,
                            forward: Bool) {
        switch self {
        case .multiplyRate(let rateMultiplier):
            let rate = player.rate * rateMultiplier
            player.rate = forward ? rate : -rate

        case .changeTime:
            player.seekEventProducer.isBackward = !forward
            player.seekEventProducer.startProducing()
        }
    }
    
    func handleSeekingEnd(_ player: AudioPlayer,
                          forward: Bool) {
        switch self {
        case .multiplyRate(let rateMultiplier):
            let rate = player.rate / rateMultiplier
            player.rate = forward ? rate : -rate
        
        case .changeTime:
            player.seekEventProducer.stopProducing()
        }
    }
}

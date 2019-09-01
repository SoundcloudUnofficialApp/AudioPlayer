

extension AudioPlayer: EventListenerP {
    
    /// The implementation of `EventListenerP`.
    /// It handles network events, player events, audio item events, quality adjustment events, retry events and seek events.
    func onEvent(_ event: EventP,
                 generetedBy eventProducer: EventProducerP) {
        
        if let event = event as? NetEventProducer.NetEvent {
            handle(event, from: eventProducer)
            
        } else if let event = event as? PlayerEventProducer.PlayerEvent {
            handle(event, from: eventProducer)
            
        } else if let event = event as? AudioItemEventProducer.AudioItemEvent {
            handle(event, from: eventProducer)
            
        } else if let event = event as? QualityAdjEventProducer.QualityAdjEvent {
            handle(event, from: eventProducer)
            
        } else if let event = event as? RetryEventProducer.RetryEvent {
            handle(event, from: eventProducer)
            
        } else if let event = event as? SeekEventProducer.SeekEvent {
            handle(event, from: eventProducer)
        }
    }
}


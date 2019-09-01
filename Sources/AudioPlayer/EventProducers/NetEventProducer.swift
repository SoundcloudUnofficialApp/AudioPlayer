//
//  NetEventProducer.swift
//  AudioPlayer
//
//  Created by Kevin DELANNOY on 08/03/16.
//  Copyright © 2016 Kevin Delannoy. All rights reserved.
//

import Foundation

private extension Selector {
    /// The selector to call when reachability status changes.
    static let reachabilityStatusChanged =
        #selector(NetEventProducer.reachabilityStatusChanged(note:))
}

/// A `NetEventProducer` generates `NetEvent`s when there is changes on the network.
class NetEventProducer: NSObject, EventProducerP {
    
    enum NetEvent: EventP {
        case networkChanged
        /// The connection is now up.
        case connectionRetrieved
        case connectionLost
    }
    
    let reachability: Reachability
    
    /// The date at which connection was lost.
    private(set) var connectionLossDate: NSDate?
    
    
    weak var eventListener: EventListenerP?
    
    
    private var listening = false
    
    private var lastStatus: Reachability.NetworkStatus
    
    /// Initializes a `NetEventProducer` with a reachability.
    ///
    /// - Parameter reachability: The reachability to work with.
    init(_ reachability: Reachability) {
        lastStatus = reachability.currentReachabilityStatus
        self.reachability = reachability
        
        if lastStatus == .notReachable {
            connectionLossDate = NSDate()
        }
    }
    
    //MARK: -
    
    /// Starts listening to the player events.
    func startProducing() {
        guard !listening else {
            return
        }
        
        //Saving current status
        lastStatus = reachability.currentReachabilityStatus
        
        //Starting to listen to events
        NotificationCenter.default.addObserver(
            self,
            selector: .reachabilityStatusChanged,
            name: .ReachabilityChanged,
            object: reachability)
        reachability.startNotifier()
        
        listening = true
    }
    
    /// Stops listening to the player events.
    func stopProducing() {
        guard listening else {
            return
        }
        NotificationCenter.default.removeObserver(
            self, name: .ReachabilityChanged, object: reachability)
        reachability.stopNotifier()
        listening = false
    }
    
    /// The method that will be called when Reachability generates an event.
    ///
    /// - Parameter note: The notification information.
    @objc fileprivate func reachabilityStatusChanged(note: NSNotification) {
        let newStatus = reachability.currentReachabilityStatus
        guard newStatus != lastStatus else {
            return
        }
        if newStatus == .notReachable {
            connectionLossDate = NSDate()
            eventListener?.onEvent(NetEvent.connectionLost, generetedBy: self)
            
        } else if lastStatus == .notReachable {
            eventListener?.onEvent(NetEvent.connectionRetrieved, generetedBy: self)
            connectionLossDate = nil
            
        } else {
            eventListener?.onEvent(NetEvent.networkChanged, generetedBy: self)
        }
        lastStatus = newStatus
    }
    
    deinit {
        stopProducing()
    }
}

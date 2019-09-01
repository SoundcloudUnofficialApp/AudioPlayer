//
//  AudioPlayerMode.swift
//  AudioPlayer
//
//  Created by Kevin DELANNOY on 19/03/16.
//  Copyright © 2016 Kevin Delannoy. All rights reserved.
//

import Foundation

/// Represents the mode in which the player should play.
/// Modes can be used as masks so that you can play in `.shuffle` mode and still `.repeatAll`.
public struct AudioPlayerMode: OptionSet {
    
    public let rawValue: UInt
    
    public init(rawValue: UInt) {
        self.rawValue = rawValue
    }
}
public extension AudioPlayerMode {

    /// In this mode, player's queue will be played as given.
    static let normal = AudioPlayerMode(rawValue: 0)
    
    /// In this mode, player's queue is shuffled randomly.
    static let shuffle = AudioPlayerMode(rawValue: 0b001)
    
    /// In this mode, the player will continuously play the same item over and over.
    static let `repeat` = AudioPlayerMode(rawValue: 0b010)
    
    /// In this mode, the player will continuously play the same queue over and over.
    static let repeatAll = AudioPlayerMode(rawValue: 0b100)
}

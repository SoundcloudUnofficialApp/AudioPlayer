//
//  AudioPlayer+Queue.swift
//  AudioPlayer
//
//  Created by Kevin DELANNOY on 29/03/16.
//  Copyright © 2016 Kevin Delannoy. All rights reserved.
//

public extension AudioPlayer {
    
    var items: [AudioItem]? {
        return queue?.queue
    }
    var currentItemIndexInQueue: Int? {
        return currentItem.flatMap {
            queue?.items.firstIndex(of: $0)
        }
    }
    
    var hasNext: Bool {
        return queue?.hasNextItem == true
    }
    
    var hasPrevious: Bool {
        return queue?.hasPreviousItem == true
    }
    
    func play(_ item: AudioItem) {
        play([item])
    }
    
    /// Creates a queue according to the current mode and plays it.
    func play(_ items: [AudioItem],
              startAtIndex index: Int = 0) {
        
        guard !items.isEmpty else {
            stop()
            queue = nil
            return
        }
        queue = AudioItemQueue(items, mode)
        queue?.delegate = self
        
        if let realIndex = queue?.queue.firstIndex(of: items[index]) {
            queue?.nextPosition = realIndex
        }
        currentItem = queue?.nextItem()
    }
    
    /// Adds an item at the end of the queue. If queue is empty and player isn't playing, the behaviour will be similar
    /// to `play(item:)`.
    func add(_ item: AudioItem) {
        add([item])
    }
    
    /// Adds items at the end of the queue. If the queue is empty and player isn't playing, the behaviour will be
    /// similar to `play(items:)`.
    func add(_ items: [AudioItem]) {
        if let queue = queue {
            queue.add(items)
        } else {
            play(items)
        }
    }
    
    func removeItem(at index: Int) {
        queue?.remove(at: index)
    }
}

extension AudioPlayer: AudioItemQueueDelegate {
    
    ///  whether an item should be consider playable in the queue.
    func audioItemQueue(_ queue: AudioItemQueue,
                        shouldConsider item: AudioItem) -> Bool {
        guard let should = delegate?.audioPlayer(self, shouldStartPlaying: item) else {
            return true
        }
        return should
    }
}

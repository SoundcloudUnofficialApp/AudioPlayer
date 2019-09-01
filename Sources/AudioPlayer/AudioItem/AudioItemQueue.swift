//
//  AudioItemQueue.swift
//  AudioPlayer
//
//  Created by Kevin DELANNOY on 11/03/16.
//  Copyright © 2016 Kevin Delannoy. All rights reserved.
//

import Foundation


/// `AudioItemQueueDelegate` defines the behavior of `AudioItem` in certain circumstances and is notified upon notable 
/// events.
protocol AudioItemQueueDelegate: class {
    /// Returns a boolean value indicating whether an item should be consider playable in the queue.
    ///
    /// - Parameters:
    ///   - item: The item we ask the information for.
    /// - Returns: A boolean value indicating whether an item should be consider playable in the queue.
    func audioItemQueue(_ queue: AudioItemQueue,
                        shouldConsider item: AudioItem) -> Bool
}


/// `AudioItemQueue` handles queueing items with a playing mode.
class AudioItemQueue {
    
    /// The original items, keeping the same order.
    private(set) var items: [AudioItem]

    /// The items stored in the way the mode requires.
    private(set) var queue: [AudioItem]

    /// The historic of items played in the queue.
    private(set) var historic: [AudioItem]

    /// The current position in the queue.
    var nextPosition = 0

    var mode: AudioPlayerMode {
        didSet {
            adapt(to: oldValue)
        }
    }

    /// The queue delegate.
    weak var delegate: AudioItemQueueDelegate?

    /// Initializes a queue with a list of items and the mode.
    init(_ items: [AudioItem],
         _ mode: AudioPlayerMode) {
        self.items = items
        self.mode = mode
        
        if mode.contains(.shuffle) {
            queue =  items.ap_shuffled()
        } else {
            queue = items
        }
        historic = []
    }

    /// Adapts the queue to the new mode.
    ///
    /// Behaviour is:
    /// - `oldMode` contains .Repeat, `mode` doesn't and last item played == nextItem, we increment position.
    /// - `oldMode` contains .Shuffle, `mode` doesnt. We should set the queue to `items` and set current position to the
    ///     current item index in the new queue.
    /// - `mode` contains .Shuffle, `oldMode` doesn't. We should shuffle the leftover items in queue.
    ///
    /// Also, the items already played should also be shuffled. Current implementation has a limitation which is that
    /// the "already played items" will be shuffled at the begining of the queue while the leftovers will be shuffled at
    /// the end of the array.
    ///
    /// - Parameter oldMode: The mode before it changed.
    private func adapt(to oldMode: AudioPlayerMode) {

        guard !queue.isEmpty else {
            return
        }
        
        // repeatAll
        if !oldMode.contains(.repeatAll),
            mode.contains(.repeatAll) {
            
            nextPosition = nextPosition % queue.count
        }
    
        // repeat
        if oldMode.contains(.repeat),
            !mode.contains(.repeat),
            historic.last == queue[nextPosition] {
            
            nextPosition += 1
            
        } else if !oldMode.contains(.repeat),
            mode.contains(.repeat),
            nextPosition == queue.count {
            
            nextPosition -= 1
        }

        // shuffle
        if oldMode.contains(.shuffle),
            !mode.contains(.shuffle) {
            
            queue = items
            if let last = historic.last,
                let i = queue.firstIndex(of: last) {
                nextPosition = i + 1
            }
            
        } else if mode.contains(.shuffle),
            !oldMode.contains(.shuffle) {
            
            let alreadyPlayed = queue.prefix(upTo: nextPosition)
            let leftovers = queue.suffix(from: nextPosition)
            queue = Array(alreadyPlayed).ap_shuffled() + Array(leftovers).ap_shuffled()
        }
    }

    func nextItem() -> AudioItem? {
        guard !queue.isEmpty else {
            return nil
        }

        guard !mode.contains(.repeat) else {
            //No matter if we should still consider this item, the repeat mode will return the current item.
            let item = queue[nextPosition]
            historic.append(item)
            return item
        }

        if mode.contains(.repeatAll),
            nextPosition >= queue.count {
            nextPosition = 0
        }

        while nextPosition < queue.count {
            let item = queue[nextPosition]
            nextPosition += 1

            guard !shouldConsider(item) else{
                historic.append(item)
                return item
            }
        }

        if mode.contains(.repeatAll),
            nextPosition >= queue.count {
            nextPosition = 0
        }
        return nil
    }


    var hasNextItem: Bool {
        return !queue.isEmpty &&
        (queue.count > nextPosition ||
            mode.contains(.repeat) ||
            mode.contains(.repeatAll))
    }

    func previousItem() -> AudioItem? {

        guard !queue.isEmpty else {
            return nil
        }
        guard !mode.contains(.repeat) else {
            //No matter if we should still consider this item, the repeat mode will return the current item.
            let item = queue[max(0, nextPosition - 1)]
            historic.append(item)
            return item
        }

        if mode.contains(.repeatAll),
            nextPosition <= 0 {
            nextPosition = queue.count
        }

        while nextPosition > 0 {
            let prevPos = nextPosition - 1
            nextPosition = prevPos
            let item = queue[prevPos]

            if shouldConsider(item) {
                historic.append(item)
                return item
            }
        }
        if mode.contains(.repeatAll),
            nextPosition <= 0 {
            nextPosition = queue.count
        }
        return nil
    }

    var hasPreviousItem: Bool {
        return !queue.isEmpty &&
        (nextPosition > 0 ||
            mode.contains(.repeat) ||
            mode.contains(.repeatAll))
    }

    func add(_ newItems: [AudioItem]) {
        items.append(contentsOf: newItems)
        queue.append(contentsOf: newItems)
    }

    func remove(at index: Int) {
        let item = queue.remove(at: index)
        if let i = items.firstIndex(of: item) {
            items.remove(at: i)
        }
    }

    /// whether an item should be consider playable in the queue.
    ///
    /// - Returns: A boolean value indicating whether an item should be consider playable in the queue.
    private func shouldConsider(_ item: AudioItem) -> Bool {
        
        guard let should = delegate?.audioItemQueue(self, shouldConsider: item) else {
            return true
        }
        return should
    }
}

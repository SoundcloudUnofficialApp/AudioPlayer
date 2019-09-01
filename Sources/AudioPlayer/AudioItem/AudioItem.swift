//
//  AudioItem.swift
//  AudioPlayer
//
//  Created by Kevin DELANNOY on 12/03/16.
//  Copyright © 2016 Kevin Delannoy. All rights reserved.
//

import AVFoundation
import MediaPlayer


public enum AudioQuality: Int {
    case low
    case medium
    case high
}

// MARK: - AudioItemURL

/// `AudioItemURL` contains information about an Item URL such as its quality.
public struct AudioItemURL {
    
    public let quality: AudioQuality
    
    public let url: URL

    /// - Parameters:
    ///   - quality: The quality of the stream.
    ///   - url: The url of the stream.
    public init?(_ quality: AudioQuality,
                 _ url: URL?) {
        guard let url = url else { return nil }
        
        self.quality = quality
        self.url = url
    }
}

// MARK: - AudioItem

/// An `AudioItem` instance contains every piece of information needed for an `AudioPlayer` to play.
/// urls can be remote or local.
open class AudioItem: NSObject {
    
    /// Returns the available qualities.
    public let soundURLs: [AudioQuality: URL]
    
    // MARK: Initialization
    
    /// - Parameter soundURLs: The urls of the sound associated with its quality wrapped in a `Dictionary`.
    public init?(soundURLs: [AudioQuality: URL]) {
        self.soundURLs = soundURLs
        super.init()
        
        if soundURLs.isEmpty {
            return nil
        }
    }
    
    /// Initializes an AudioItem. Fails if every urls are nil.
    ///
    /// - Parameters:
    ///   - highQualitySoundURL: The URL for the high quality sound.
    ///   - mediumQualitySoundURL: The URL for the medium quality sound.
    ///   - lowQualitySoundURL: The URL for the low quality sound.
    public convenience init?(highQualitySoundURL: URL? = nil,
                             mediumQualitySoundURL: URL? = nil,
                             lowQualitySoundURL: URL? = nil) {
        var urls = [AudioQuality: URL]()
        urls[.high] = highQualitySoundURL
        urls[.medium] = mediumQualitySoundURL
        urls[.low] = lowQualitySoundURL
        self.init(soundURLs: urls)
    }
    
    public convenience init?(_ url: URL) {
        var urls = [AudioQuality: URL]()
        urls[.high] = url
        self.init(soundURLs: urls)
    }
    
    // MARK: Quality selection
    
    /// Returns the highest quality URL found or nil if no urls are available
    open var highestQualityURL: AudioItemURL {
        //swiftlint:disable force_unwrapping
        return (AudioItemURL(.high, soundURLs[.high]) ??
            AudioItemURL(.medium, soundURLs[.medium]) ??
            AudioItemURL(.low, soundURLs[.low]))!
    }
    
    /// Returns the medium quality URL found or nil if no urls are available
    open var mediumQualityURL: AudioItemURL {
        //swiftlint:disable force_unwrapping
        return (AudioItemURL(.medium, soundURLs[.medium]) ??
            AudioItemURL(.low, soundURLs[.low]) ??
            AudioItemURL(.high, soundURLs[.high]))!
    }
    
    /// Returns the lowest quality URL found or nil if no urls are available
    open var lowestQualityURL: AudioItemURL {
        //swiftlint:disable force_unwrapping
        return (AudioItemURL(.low, soundURLs[.low]) ??
            AudioItemURL(.medium, soundURLs[.medium]) ??
            AudioItemURL(.high, soundURLs[.high]))!
    }
    
    /// Returns an URL that best fits a given quality.
    ///
    /// - Parameter quality: The quality for the requested URL.
    /// - Returns: The URL that best fits the given quality.
    func url(for quality: AudioQuality) -> AudioItemURL {
        switch quality {
        case .high:
            return highestQualityURL
        case .medium:
            return mediumQualityURL
        default:
            return lowestQualityURL
        }
    }
    
    // MARK: Additional properties
    
    /// The artist of the item.
    ///
    /// This can change over time which is why the property is dynamic. It enables KVO on the property.
    @objc open dynamic var artist: String?
    
    /// The title of the item.
    ///
    /// This can change over time which is why the property is dynamic. It enables KVO on the property.
    @objc open dynamic var title: String?
    
    /// The album of the item.
    ///
    /// This can change over time which is why the property is dynamic. It enables KVO on the property.
    @objc open dynamic var album: String?
    
    ///The track count of the item's album.
    ///
    /// This can change over time which is why the property is dynamic. It enables KVO on the property.
    @objc open dynamic var trackCount: NSNumber?
    
    /// The track number of the item in its album.
    ///
    /// This can change over time which is why the property is dynamic. It enables KVO on the property.
    @objc open dynamic var trackNumber: NSNumber?
    
    /// The artwork image of the item.
    open var artworkImage: UIImage? {
        get {
            return artwork?.image(at: imageSize ?? CGSize(width: 512, height: 512))
        }
        set {
            imageSize = newValue?.size
            artwork = newValue.map { image in
                MPMediaItemArtwork(boundsSize: image.size) { _ in image }
            }
        }
    }
    
    /// The artwork image of the item.
    /// This can change over time which is why the property is dynamic. It enables KVO on the property.
    @objc open dynamic var artwork: MPMediaItemArtwork?
    
    private var imageSize: CGSize?
    
    // MARK: Metadata
    
    /// Parses the metadata coming from the stream/file specified in the URL's. The default behavior is to set values
    /// for every property that is nil. Customization is available through subclassing.
    open func parseMetadata(_ items: [AVMetadataItem]) {
        
        for item in items {
            guard let key = item.commonKey else {
                continue
            }
            
            typealias K = AVMetadataKey
            switch key {
            case K.commonKeyTitle where title == nil:
                title = item.value as? String
                
            case K.commonKeyArtist where artist == nil:
                artist = item.value as? String
                
            case K.commonKeyAlbumName where album == nil:
                album = item.value as? String
                
            case K.id3MetadataKeyTrackNumber where trackNumber == nil:
                trackNumber = item.value as? NSNumber
                
            case K.commonKeyArtwork where artwork == nil:
                artworkImage = (item.value as? Data).flatMap { UIImage(data: $0) }
                
            default:
                break
            }
        }
    }
}

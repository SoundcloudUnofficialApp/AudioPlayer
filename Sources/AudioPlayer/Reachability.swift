/*
 Copyright (c) 2014, Ashley Mills
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 
 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.
 
 2. Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
 LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.
 */

import SystemConfiguration
import Foundation

extension NSNotification.Name {
    static let ReachabilityChanged = NSNotification.Name(rawValue: "ReachabilityChanged")
}

func callback(_ reachability: SCNetworkReachability,
              _ flags: SCNetworkReachabilityFlags,
              _ info: UnsafeMutableRawPointer?) {
    
    guard let info = info else { return }
    
    let reachability = Unmanaged<Reachability>.fromOpaque(info).takeUnretainedValue()
    DispatchQueue.main.async {
        reachability.reachabilityChanged(flags)
    }
}

public class Reachability: NSObject {
    
    enum NetworkStatus {
        case notReachable, reachableViaWiFi, reachableViaWWAN
    }
        
    var reachableOnWWAN: Bool
    
    var notificationCenter = NotificationCenter.default
    
    var currentReachabilityStatus: NetworkStatus {
        if isReachable {
            if isReachableViaWiFi {
                return .reachableViaWiFi
            }
            if isRunningOnDevice {
                return .reachableViaWWAN
            }
        }
        return .notReachable
    }
    
    // MARK: inits
    
    required init(reachabilityRef: SCNetworkReachability?) {
        reachableOnWWAN = true
        self.reachabilityRef = reachabilityRef
    }
    
    convenience override init() {
        var zeroAddress = sockaddr()
        zeroAddress.sa_len = UInt8(MemoryLayout<sockaddr>.size)
        zeroAddress.sa_family = sa_family_t(AF_INET)
        
        let ref = withUnsafePointer(to: &zeroAddress) {
            SCNetworkReachabilityCreateWithAddress(nil, UnsafePointer($0))
        }
        self.init(reachabilityRef: ref)
    }
    
    // MARK: Notifier
    
    @discardableResult
    func startNotifier() -> Bool {
        guard !notifierRunning else {
            return true
        }
        guard let ref = reachabilityRef else {
            return false
        }
        
        var context = SCNetworkReachabilityContext(version: 0, info: nil, retain: nil, release: nil,copyDescription: nil)
        
        context.info = UnsafeMutableRawPointer(
            Unmanaged<Reachability>.passUnretained(self).toOpaque())
        
        if SCNetworkReachabilitySetCallback(ref, callback, &context),
            SCNetworkReachabilitySetDispatchQueue(ref, reachabilitySerialQueue) {
            
            notifierRunning = true
            return true
        }
        
        stopNotifier()
        return false
    }
    
    func stopNotifier() {
        if let ref = reachabilityRef {
            SCNetworkReachabilitySetCallback(ref, nil, nil)
        }
        notifierRunning = false
    }
    
    // MARK: Connection test
    
    var isReachable: Bool {
        return isReachableWithTest{ flags in
            return isReachable(with: flags)
        }
    }
    
    var isReachableViaWiFi: Bool {
        return isReachableWithTest() { flags in
            guard isReachable(flags) else {
                return false
            }
            if isRunningOnDevice,
                isOnWWAN(flags) {
                // Check we're NOT on WWAN
                return false
            }
            return true
        }
    }
    
    deinit {
        stopNotifier()
        reachabilityRef = nil
    }
    
    // MARK: Private
    
    #if targetEnvironment(simulator)
    private let isRunningOnDevice = false
    #else
    private let isRunningOnDevice = true
    #endif
    
    private var notifierRunning = false
    
    private var reachabilityRef: SCNetworkReachability?
    
    private let reachabilitySerialQueue = DispatchQueue(label: "uk.co.ashleymills.reachability")
}

fileprivate extension Reachability {
    
    typealias Flags = SCNetworkReachabilityFlags
    
    func reachabilityChanged(_ flags: Flags) {
        notificationCenter.post(name: .ReachabilityChanged, object: self)
    }
    
    func isReachable(with flags: Flags) -> Bool {
        return isReachable(flags) ||
            !isConnectionRequiredOrTransient(flags)
        
        //        if isRunningOnDevice,
        //            isOnWWAN(flags: flags),
        //            !reachableOnWWAN {
        //            // We don't want to connect when on 3G.
        //            return false
        //        }
    }
    
    func isReachableWithTest(_ test: (Flags) -> (Bool)) -> Bool {
        guard let ref = reachabilityRef else {
            return false
        }
        var flags = Flags(rawValue: 0)
        let gotFlags = withUnsafeMutablePointer(to: &flags) {
            SCNetworkReachabilityGetFlags(ref, UnsafeMutablePointer($0))
        }
        return gotFlags ? test(flags) : false
    }
    
    // WWAN may be available, but not active until a connection has been established.
    // WiFi may require a connection for VPN on Demand.
    
    func isOnWWAN(_ flags: Flags) -> Bool {
        return flags.contains(.isWWAN)
    }
    
    func isReachable(_ flags: Flags) -> Bool {
        return flags.contains(.reachable)
    }
    
    func isConnectionRequiredOrTransient(_ flags: Flags) -> Bool {
        let testcase: Flags = [.connectionRequired, .transientConnection]
        return flags.intersection(testcase) == testcase
    }
    
    var reachabilityFlags: Flags {
        
        guard let ref = reachabilityRef else {
            return []
        }
        var flags = Flags(rawValue: 0)
        let gotFlags = withUnsafeMutablePointer(to: &flags) {
            SCNetworkReachabilityGetFlags(ref, UnsafeMutablePointer($0))
        }
        
        return gotFlags ? flags : []
    }
}

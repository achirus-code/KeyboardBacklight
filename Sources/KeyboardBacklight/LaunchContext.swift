import AppKit

/// Tells a launch at login (login/restart) apart from a manual launch.
enum LaunchContext {
    /// Only call from `applicationDidFinishLaunching` – that's where the launch event is still current.
    static func launchedAtLogin() -> Bool {
        // Classic marker in the "open application" event
        if let event = NSAppleEventManager.shared().currentAppleEvent,
           event.eventID == kAEOpenApplication,
           event.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem {
            return true
        }
        // SMAppService doesn't set the marker reliably → shortly after the session starts counts as launch at login
        let sessionAge = sessionStart().map { Date().timeIntervalSince($0) } ?? ProcessInfo.processInfo.systemUptime
        return sessionAge < 180
    }

    /// Start time of the current user's loginwindow process = start of the session.
    private static func sessionStart() -> Date? {
        let uid = getuid()
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_UID, Int32(uid)]
        var size = 0
        guard sysctl(&mib, UInt32(mib.count), nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var procs = [kinfo_proc](repeating: kinfo_proc(), count: size / MemoryLayout<kinfo_proc>.stride)
        guard sysctl(&mib, UInt32(mib.count), &procs, &size, nil, 0) == 0 else { return nil }
        procs = Array(procs.prefix(size / MemoryLayout<kinfo_proc>.stride))

        for var proc in procs {
            let name = withUnsafeBytes(of: &proc.kp_proc.p_comm) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) }
            guard name == "loginwindow" else { continue }
            let tv = proc.kp_proc.p_starttime
            return Date(timeIntervalSince1970: Double(tv.tv_sec) + Double(tv.tv_usec) / 1_000_000)
        }
        return nil
    }
}

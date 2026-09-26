import AppKit

/// Unterscheidet einen Autostart (Anmelden/Neustart) von einem manuellen Start.
enum LaunchContext {
    /// Nur in `applicationDidFinishLaunching` aufrufen – dort ist das Start-Event noch aktuell.
    static func launchedAtLogin() -> Bool {
        // Klassisches Kennzeichen im „open application“-Event
        if let event = NSAppleEventManager.shared().currentAppleEvent,
           event.eventID == kAEOpenApplication,
           event.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem {
            return true
        }
        // SMAppService setzt das Kennzeichen nicht zuverlässig → kurz nach Sitzungsbeginn gilt als Autostart
        let sessionAge = sessionStart().map { Date().timeIntervalSince($0) } ?? ProcessInfo.processInfo.systemUptime
        return sessionAge < 180
    }

    /// Startzeit des loginwindow-Prozesses des aktuellen Benutzers = Beginn der Sitzung.
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

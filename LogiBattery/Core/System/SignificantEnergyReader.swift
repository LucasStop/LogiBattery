import AppKit
import CoreGraphics
import Darwin
import Foundation
import IOKit

/// Lê itens em "Usando energia significativa" (brilho da tela interna + apps do usuário via `proc_pid_rusage`).
/// Só roda enquanto o popover está aberto (US-17, ADR 0009).
actor SignificantEnergyReader: SignificantEnergyReading {
    private var previousSamples: [Int32: ProcessEnergySample] = [:]
    private var previousDate: Date?

    func reset() async {
        previousSamples = [:]
        previousDate = nil
    }

    func sample() async -> [SignificantEnergyItem] {
        var items: [SignificantEnergyItem] = []
        if let brightness = DisplayBrightnessReader.builtInBrightness(),
           brightness >= ProcessEnergyCalculator.defaultBrightnessThreshold {
            items.append(.displayBrightness)
        }

        let now = Date.now
        let current = await collectProcessSamples()
        if let previousDate {
            let elapsed = now.timeIntervalSince(previousDate)
            let apps = ProcessEnergyCalculator.significantApps(
                previous: previousSamples,
                current: current,
                elapsedSeconds: elapsed
            )
            items.append(contentsOf: apps)
        }
        previousSamples = Dictionary(uniqueKeysWithValues: current.map { ($0.pid, $0) })
        previousDate = now
        return items
    }

    private struct RunningAppInfo: Sendable {
        let pid: Int32
        let name: String
        let bundleId: String?
    }

    private func collectProcessSamples() async -> [ProcessEnergySample] {
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let apps: [RunningAppInfo] = await MainActor.run {
            NSWorkspace.shared.runningApplications.compactMap { app in
                guard app.activationPolicy == .regular,
                      !app.isTerminated,
                      app.processIdentifier != ownPID,
                      let name = app.localizedName, !name.isEmpty else { return nil }
                return RunningAppInfo(pid: app.processIdentifier, name: name, bundleId: app.bundleIdentifier)
            }
        }
        return apps.compactMap { app in
            guard let usage = readResourceUsage(pid: app.pid) else { return nil }
            return ProcessEnergySample(
                pid: app.pid,
                name: app.name,
                bundleIdentifier: app.bundleId,
                cpuTimeNs: usage.cpuTimeNs,
                wakeups: usage.wakeups
            )
        }
    }

    private func readResourceUsage(pid: Int32) -> (cpuTimeNs: UInt64, wakeups: UInt64)? {
        var info = rusage_info_v4()
        let result = withUnsafeMutablePointer(to: &info) { ptr in
            ptr.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { rebound in
                proc_pid_rusage(pid, RUSAGE_INFO_V4, rebound)
            }
        }
        guard result == 0 else { return nil }
        return (
            cpuTimeNs: info.ri_user_time + info.ri_system_time,
            wakeups: info.ri_interrupt_wkups + info.ri_pkg_idle_wkups
        )
    }
}

/// Lê o brilho atual do display interno do MacBook (0.0...1.0).
enum DisplayBrightnessReader {
    private typealias GetBrightnessFn = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32

    static func builtInBrightness() -> Float? {
        if let value = brightnessViaDisplayServices() { return value }
        return brightnessViaIORegistry()
    }

    private static func brightnessViaDisplayServices() -> Float? {
        let path = "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices"
        guard let handle = dlopen(path, RTLD_LAZY) else { return nil }
        defer { dlclose(handle) }
        guard let symbol = dlsym(handle, "DisplayServicesGetBrightness") else { return nil }
        let getBrightness = unsafeBitCast(symbol, to: GetBrightnessFn.self)

        var displayCount: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &displayCount) == .success, displayCount > 0 else { return nil }
        var displays = Array(repeating: CGDirectDisplayID(), count: Int(displayCount))
        guard CGGetActiveDisplayList(displayCount, &displays, &displayCount) == .success else { return nil }

        for display in displays where CGDisplayIsBuiltin(display) != 0 {
            var level: Float = 0
            if getBrightness(display, &level) == 0, level >= 0, level <= 1 {
                return level
            }
        }
        return nil
    }

    private static func brightnessViaIORegistry() -> Float? {
        var iterator: io_iterator_t = 0
        let matching = IOServiceMatching("IOMobileFramebuffer")
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(iterator) }

        while case let entry = IOIteratorNext(iterator), entry != 0 {
            defer { IOObjectRelease(entry) }
            var unmanaged: Unmanaged<CFMutableDictionary>?
            guard IORegistryEntryCreateCFProperties(entry, &unmanaged, kCFAllocatorDefault, 0) == KERN_SUCCESS,
                  let props = unmanaged?.takeRetainedValue() as? [String: Any],
                  let level = props["IOMFBBrightnessLevel"] as? Int,
                  let limit = props["limit_max_physical_brightness"] as? Int,
                  level >= 0, limit > 0 else { continue }
            return min(max(Float(level) / Float(limit), 0), 1)
        }
        return nil
    }
}

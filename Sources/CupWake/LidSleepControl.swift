// SPDX-License-Identifier: GPL-3.0-only
import IOKit
import IOKit.pwr_mgt

enum LidSleepControl {
    // Apple defines this selector in IOPMLibDefs.h. It is not a supported app API.
    // It changes lid sleep only. It does not change display or manual sleep.
    static func setDisabled(_ disabled: Bool) throws {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        guard service != 0 else { throw PowerError.unavailable }
        defer { IOObjectRelease(service) }
        var connection: io_connect_t = 0
        let opened = IOServiceOpen(service, mach_task_self_, 0, &connection)
        guard opened == kIOReturnSuccess else { throw PowerError.ioKit(opened) }
        defer { IOServiceClose(connection) }
        var input: UInt64 = disabled ? 1 : 0
        let result = IOConnectCallScalarMethod(connection, UInt32(kPMSetClamshellSleepState), &input, 1, nil, nil)
        guard result == kIOReturnSuccess else { throw PowerError.ioKit(result) }
    }
}

enum PowerError: Error {
    case unavailable
    case ioKit(IOReturn)
    case startFailed
}

final class AwakeSession {
    private var assertion: IOPMAssertionID?
    private var ownsLidControl = false
    private let setLid: (Bool) throws -> Void
    private let createAssertion: () throws -> IOPMAssertionID
    private let releaseAssertion: (IOPMAssertionID) -> Void

    init(
        setLid: @escaping (Bool) throws -> Void = LidSleepControl.setDisabled,
        createAssertion: @escaping () throws -> IOPMAssertionID = AwakeSession.createIdleAssertion,
        releaseAssertion: @escaping (IOPMAssertionID) -> Void = { _ = IOPMAssertionRelease($0) }
    ) {
        self.setLid = setLid
        self.createAssertion = createAssertion
        self.releaseAssertion = releaseAssertion
    }

    func start() throws {
        guard assertion == nil else { return }
        assertion = try createAssertion()
        do {
            try setLid(true)
            ownsLidControl = true
        } catch {
            if let assertion { releaseAssertion(assertion) }
            assertion = nil
            throw error
        }
    }

    func refresh() throws {
        guard ownsLidControl else { return }
        // macOS can reset this control after a power or wake change.
        try setLid(true)
    }

    func stop() throws {
        if ownsLidControl {
            try setLid(false)
            ownsLidControl = false
        }
        if let assertion { releaseAssertion(assertion) }
        assertion = nil
    }

    private static func createIdleAssertion() throws -> IOPMAssertionID {
        var identifier: IOPMAssertionID = 0
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "CupWake agents" as CFString,
            &identifier
        )
        guard result == kIOReturnSuccess else { throw PowerError.ioKit(result) }
        return identifier
    }
}

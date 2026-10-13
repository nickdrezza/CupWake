// SPDX-License-Identifier: GPL-3.0-only
import Foundation
import Darwin

@MainActor final class AwakeController {
    private let executableURL: URL
    private let restoreLid: () throws -> Void
    private var input: FileHandle?
    private var heartbeat: Timer?
    private var activity: NSObjectProtocol?
    private var isStarting = false
    private(set) var process: Process?
    private(set) var isOn = false
    var onChange: (() -> Void)?
    var onFailure: (() -> Void)?

    init(executableURL: URL? = Bundle.main.executableURL,
         restoreLid: @escaping () throws -> Void = { try LidSleepControl.setDisabled(false) }) {
        self.executableURL = executableURL ?? URL(fileURLWithPath: CommandLine.arguments[0])
        self.restoreLid = restoreLid
    }

    func start() async throws {
        guard process == nil && !isStarting else { return }
        isStarting = true
        defer {
            isStarting = false
            if !isOn { stop() }
        }
        let child = Process()
        let commands = Pipe()
        let status = Pipe()
        child.executableURL = executableURL
        child.arguments = ["--awake-worker"]
        child.standardInput = commands
        child.standardOutput = status
        child.terminationHandler = { [weak self] child in
            DispatchQueue.main.async { [weak self] in
                guard let self, self.process === child else { return }
                Task { await self.finish(child) }
            }
        }
        try child.run()
        process = child
        input = commands.fileHandleForWriting
        // Prevent App Nap from delaying the guard heartbeat. Let the display sleep.
        activity = ProcessInfo.processInfo.beginActivity(
            options: .userInitiatedAllowingIdleSystemSleep, reason: "Keep agents running"
        )
        // Only the guard owns the read end. Parent exit must cause EOF.
        try commands.fileHandleForReading.close()
        try status.fileHandleForWriting.close()
        defer { try? status.fileHandleForReading.close() }
        let descriptor = status.fileHandleForReading.fileDescriptor
        _ = fcntl(descriptor, F_SETFL, O_NONBLOCK)
        var bytes = [UInt8](repeating: 0, count: 64)
        var message = Data()
        let deadline = ProcessInfo.processInfo.systemUptime + 5
        while process === child && child.isRunning && ProcessInfo.processInfo.systemUptime < deadline {
            let count = read(descriptor, &bytes, bytes.count)
            if count > 0 { message.append(contentsOf: bytes.prefix(count)) }
            if message == Data("ready\n".utf8) {
                isOn = true
                let timer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in
                    MainActor.assumeIsolated { self?.sendHeartbeat() }
                }
                RunLoop.main.add(timer, forMode: .common)
                heartbeat = timer
                onChange?()
                return
            }
            try await Task.sleep(for: .milliseconds(20))
        }
        stop()
        throw PowerError.startFailed
    }

    func stop() {
        heartbeat?.invalidate()
        heartbeat = nil
        // EOF lets the guard restore lid sleep before it exits.
        try? input?.close()
        input = nil
    }

    private func sendHeartbeat() {
        do { try input?.write(contentsOf: Data([1])) }
        catch { stop(); onFailure?() }
    }

    private func finish(_ child: Process) async {
        guard process === child else { return }
        stop()
        // A killed guard cannot restore its own lid control. Retry before showing Off.
        if child.terminationReason == .uncaughtSignal {
            var reported = false
            while process === child {
                do { try restoreLid(); break }
                catch {
                    if !reported { onFailure?(); reported = true }
                    try? await Task.sleep(for: .seconds(1))
                }
            }
        }
        guard process === child else { return }
        process = nil
        isOn = false
        if let activity { ProcessInfo.processInfo.endActivity(activity) }
        activity = nil
        onChange?()
    }
}

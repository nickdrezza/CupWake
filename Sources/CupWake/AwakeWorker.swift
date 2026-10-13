// SPDX-License-Identifier: GPL-3.0-only
import Foundation
import Darwin

enum AwakeWorker {
    static func run() -> Int32 {
        signal(SIGPIPE, SIG_IGN)
        // Permit one CupWake guard for this user. The lock ends when the guard exits.
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CupWake", isDirectory: true)
        do { try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true) }
        catch { return 1 }
        let lock = open(directory.appendingPathComponent("awake.lock").path,
                        O_CREAT | O_RDWR | O_CLOEXEC | O_NOFOLLOW, 0o600)
        guard lock >= 0 else { return 1 }
        defer { close(lock) }
        guard flock(lock, LOCK_EX | LOCK_NB) == 0 else { return 1 }
        let session = AwakeSession()
        do { try session.start() }
        catch { return 1 }
        // The parent shows On only after this message.
        do { try FileHandle.standardOutput.write(contentsOf: Data("ready\n".utf8)) }
        catch { return restore(session) }
        var lastHeartbeat = ProcessInfo.processInfo.systemUptime
        var descriptor = pollfd(fd: STDIN_FILENO, events: Int16(POLLIN | POLLHUP), revents: 0)
        var buffer = [UInt8](repeating: 0, count: 64)
        var running = true
        while running {
            let result = poll(&descriptor, 1, 1_000)
            if result > 0 {
                let count = read(STDIN_FILENO, &buffer, buffer.count)
                if count <= 0 { break }
                lastHeartbeat = ProcessInfo.processInfo.systemUptime
            } else if result < 0 && errno != EINTR {
                break
            }
            // A closed pipe catches parent exit. The timeout catches a stalled parent.
            if ProcessInfo.processInfo.systemUptime - lastHeartbeat > 15 { break }
            do { try session.refresh() }
            catch { running = false }
        }
        return restore(session)
    }

    private static func restore(_ session: AwakeSession) -> Int32 {
        // Keep the guard alive until it restores lid sleep.
        while true {
            do { try session.stop(); return 0 }
            catch { Thread.sleep(forTimeInterval: 1) }
        }
    }
}

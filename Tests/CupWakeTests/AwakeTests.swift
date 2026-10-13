// SPDX-License-Identifier: GPL-3.0-only
import Foundation
import Testing
import Darwin
@testable import CupWake

@Suite("Sleep control") struct AwakeSessionTests {
    @Test func sessionRestoresLidSleepBeforeItReleasesIdleSleep() throws {
        var actions: [String] = []
        let session = AwakeSession(
            setLid: { actions.append($0 ? "lid off" : "lid on") },
            createAssertion: { actions.append("idle off"); return 42 },
            releaseAssertion: { actions.append("release \($0)") }
        )
        try session.start()
        try session.start()
        try session.refresh()
        try session.stop()
        try session.stop()
        try session.refresh()
        #expect(actions == ["idle off", "lid off", "lid off", "lid on", "release 42"])
    }

    @Test func assertionFailureDoesNotChangeLidSleep() {
        var changedLid = false
        let session = AwakeSession(
            setLid: { _ in changedLid = true },
            createAssertion: { throw PowerError.unavailable }, releaseAssertion: { _ in }
        )
        #expect(throws: PowerError.self) { try session.start() }
        #expect(!changedLid)
    }

    @Test func lidFailureReleasesTheIdleAssertion() {
        var released: UInt32?
        let session = AwakeSession(
            setLid: { _ in throw PowerError.unavailable },
            createAssertion: { 42 }, releaseAssertion: { released = $0 }
        )
        #expect(throws: PowerError.self) { try session.start() }
        #expect(released == 42)
    }

    @Test func restoreFailureKeepsTheAssertionUntilRetrySucceeds() throws {
        var failRestore = true
        var released = false
        let session = AwakeSession(
            setLid: { if !$0 && failRestore { throw PowerError.unavailable } },
            createAssertion: { 42 }, releaseAssertion: { _ in released = true }
        )
        try session.start()
        #expect(throws: PowerError.self) { try session.stop() }
        #expect(!released)
        failRestore = false
        try session.stop()
        #expect(released)
    }
}

@Suite("Guard process", .serialized) @MainActor struct AwakeControllerTests {
    @Test func oneGuardStartsOnlyAfterReadyAndStopsAfterEOF() async throws {
        let fixture = try script("printf 'ready\\n'\ncat >/dev/null\n")
        defer { try? FileManager.default.removeItem(at: fixture) }
        let controller = AwakeController(executableURL: fixture, restoreLid: {})
        #expect(!controller.isOn)
        try await controller.start()
        defer { controller.stop() }
        let first = try #require(controller.process)
        #expect(controller.isOn)
        try await controller.start()
        #expect(controller.process === first)
        controller.stop()
        try await waitUntilOff(controller)
        #expect(!first.isRunning)
        try await controller.start()
        #expect(controller.isOn)
        #expect(controller.process !== first)
        controller.stop()
        try await waitUntilOff(controller)
    }

    @Test func failedLaunchLeavesTheCupOff() async {
        let controller = AwakeController(executableURL: URL(fileURLWithPath: "/CupWake-missing-executable"))
        await #expect(throws: (any Error).self) { try await controller.start() }
        #expect(!controller.isOn)
        #expect(controller.process == nil)
    }

    @Test func guardFailureBeforeReadyLeavesTheCupOff() async throws {
        let fixture = try script("exit 1\n")
        defer { try? FileManager.default.removeItem(at: fixture) }
        let controller = AwakeController(executableURL: fixture, restoreLid: {})
        await #expect(throws: (any Error).self) { try await controller.start() }
        try await waitUntilOff(controller)
        #expect(!controller.isOn)
    }

    @Test func killedGuardRestoresLidSleepBeforeTheCupTurnsOff() async throws {
        // Keep this fixture in one process so a child cannot retain the pipe.
        let fixture = try script("printf 'ready\\n'\nwhile :; do :; done\n")
        defer { try? FileManager.default.removeItem(at: fixture) }
        var restored = false
        let controller = AwakeController(executableURL: fixture, restoreLid: { restored = true })
        try await controller.start()
        let child = try #require(controller.process)
        kill(child.processIdentifier, SIGKILL)
        try await waitUntilOff(controller)
        #expect(restored)
    }

    @Test func cancelledStartupClosesTheGuardPipe() async throws {
        let fixture = try script("cat >/dev/null\n")
        defer { try? FileManager.default.removeItem(at: fixture) }
        let controller = AwakeController(executableURL: fixture, restoreLid: {})
        let task = Task { try await controller.start() }
        try await Task.sleep(for: .milliseconds(100))
        task.cancel()
        _ = await task.result
        try await waitUntilOff(controller)
        #expect(!controller.isOn)
    }

    private func script(_ body: String) throws -> URL {
        let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent(".build/guard-tests")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent(UUID().uuidString + ".sh")
        try ("#!/bin/sh\n" + body).write(to: file, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: file.path)
        return file
    }

    private func waitUntilOff(_ controller: AwakeController) async throws {
        for _ in 0..<100 {
            if controller.process == nil { return }
            try await Task.sleep(for: .milliseconds(50))
        }
        #expect(controller.process == nil)
    }
}

// SPDX-License-Identifier: GPL-3.0-only
import Foundation
import Testing
@testable import CupWake

@Suite("Caffeinate process", .serialized) @MainActor struct CaffeinateTests {
    @Test func toggleOwnsOneProcessAndReleasesItsAssertion() async throws {
        let controller = CaffeinateController()
        #expect(!controller.isOn)
        try controller.start()
        defer { controller.stop() }
        let child = try #require(controller.process)
        #expect(controller.isOn)
        try controller.start()
        #expect(controller.process === child)
        let owner = "pid \(child.processIdentifier)(caffeinate)"
        var hasAssertion = false
        for _ in 0..<50 {
            let output = try assertions()
            if let line = output.split(separator: "\n").first(where: { $0.contains(owner) }) {
                #expect(line.contains("PreventUserIdleSystemSleep"))
                hasAssertion = true
                break
            }
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(hasAssertion)
        controller.stop()
        try await waitUntilOff(controller)
        #expect(!child.isRunning)
        #expect(!controller.isOn)
        #expect(controller.process == nil)
        #expect(try !assertions().contains(owner))
        controller.stop()
    }

    @Test func launchFailureLeavesTheCupOff() throws {
        let controller = CaffeinateController(executableURL: URL(fileURLWithPath: "/CupWake-missing-executable"))
        var changes = 0
        controller.onChange = { changes += 1 }
        #expect(throws: (any Error).self) { try controller.start() }
        #expect(!controller.isOn)
        #expect(controller.process == nil)
        #expect(changes == 0)
    }

    @Test func oldExitDoesNotClearANewProcess() async throws {
        let controller = CaffeinateController()
        try controller.start()
        defer { controller.stop() }
        let first = try #require(controller.process)
        controller.stop()
        // Keep the old callback queued until the new child has started.
        first.waitUntilExit()
        try controller.start()
        let second = try #require(controller.process)
        #expect(second !== first)
        try await Task.sleep(for: .milliseconds(100))
        #expect(controller.process === second)
        #expect(controller.isOn)
        controller.stop()
        try await waitUntilOff(controller)
    }

    @Test func unexpectedExitUpdatesTheIconState() async throws {
        let controller = CaffeinateController()
        var changes = 0
        controller.onChange = { changes += 1 }
        try controller.start()
        defer { controller.stop() }
        let child = try #require(controller.process)
        child.terminate()
        try await waitUntilOff(controller)
        #expect(controller.process == nil)
        #expect(!controller.isOn)
        #expect(changes == 2)
        try controller.start()
        #expect(controller.isOn)
        controller.stop()
        try await waitUntilOff(controller)
    }

    @Test func caffeinateExitsWhenItsWatchedProcessExits() async throws {
        let parent = Process()
        parent.executableURL = URL(fileURLWithPath: "/bin/sleep")
        parent.arguments = ["10"]
        try parent.run()
        defer { if parent.isRunning { parent.terminate(); parent.waitUntilExit() } }
        let child = Process()
        child.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
        child.arguments = ["-w", String(parent.processIdentifier)]
        try child.run()
        defer { if child.isRunning { child.terminate(); child.waitUntilExit() } }
        try await Task.sleep(for: .milliseconds(100))
        #expect(child.isRunning)
        parent.terminate()
        parent.waitUntilExit()
        for _ in 0..<50 {
            if !child.isRunning { break }
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(!child.isRunning)
    }

    private func assertions() throws -> String {
        let reader = Process()
        let output = Pipe()
        reader.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        reader.arguments = ["-g", "assertions"]
        reader.standardOutput = output
        try reader.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        reader.waitUntilExit()
        return String(decoding: data, as: UTF8.self)
    }

    private func waitUntilOff(_ controller: CaffeinateController) async throws {
        for _ in 0..<60 {
            if controller.process == nil { return }
            try await Task.sleep(for: .milliseconds(50))
        }
        #expect(controller.process == nil)
    }
}

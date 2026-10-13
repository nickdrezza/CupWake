// SPDX-License-Identifier: GPL-3.0-only
import Foundation

@MainActor final class CaffeinateController {
    private let executableURL: URL
    private(set) var process: Process?
    var onChange: (() -> Void)?
    var isOn: Bool { process?.isRunning == true }

    init(executableURL: URL = URL(fileURLWithPath: "/usr/bin/caffeinate")) {
        self.executableURL = executableURL
    }

    func start() throws {
        guard !isOn else { return }
        let child = Process()
        child.executableURL = executableURL
        // Use the default assertion. Exit if this app exits, even after a crash.
        child.arguments = ["-w", String(ProcessInfo.processInfo.processIdentifier)]
        child.terminationHandler = { [weak self] child in
            DispatchQueue.main.async { [weak self] in
                guard let self, self.process === child else { return }
                self.process = nil
                self.onChange?()
            }
        }
        try child.run()
        process = child
        onChange?()
    }

    func stop() {
        guard let child = process else { return }
        if child.isRunning {
            child.terminate()
        } else {
            process = nil
            onChange?()
        }
    }
}

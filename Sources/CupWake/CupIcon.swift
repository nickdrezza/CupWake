// SPDX-License-Identifier: GPL-3.0-only
import AppKit

@MainActor enum CupIcon {
    static func image(isOn: Bool) -> NSImage {
        let name = isOn ? "mug.fill" : "mug"
        // Use native symbol weight, size, and tint in the menu bar.
        let configuration = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        let symbol = NSImage(systemSymbolName: name, accessibilityDescription: nil)
            ?? NSImage(systemSymbolName: isOn ? "cup.and.saucer.fill" : "cup.and.saucer",
                       accessibilityDescription: nil)!
        let image = symbol.withSymbolConfiguration(configuration) ?? symbol
        image.isTemplate = true
        return image
    }
}

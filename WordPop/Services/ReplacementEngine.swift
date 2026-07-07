//
//  ReplacementEngine.swift
//  WordPop
//

import ApplicationServices
import CoreGraphics
import Foundation

final class ReplacementEngine {
    static let shared = ReplacementEngine()

    // Marks synthetic events so our own event tap ignores them.
    static let syntheticEventMarker: Int64 = 0x574F5244 // "WORD"

    func replace(oldWord: String, boundary: String, with newWord: String, target: AccessibilityTextTarget?, bubbleId: UUID? = nil) {
        WordPopLogger.log("Replacing '\(oldWord)' with '\(newWord)'.")
        let pending = bubbleId.flatMap { KeyboardMonitorService.shared.consumePendingCorrection(id: $0) }

        if let target, replaceUsingAccessibility(target: target, oldWord: oldWord, with: newWord) {
            WordPopLogger.log("Replacement completed via Accessibility range.")
            KeyboardMonitorService.shared.adjustPendingTails(oldWord: oldWord, newWord: newWord)
            return
        }

        if let pending {
            WordPopLogger.log("Falling back to keystroke replacement (tail: \(pending.tail.count) chars).")
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.replaceViaKeystrokes(pending, with: newWord)
                DispatchQueue.main.async {
                    KeyboardMonitorService.shared.adjustPendingTails(oldWord: oldWord, newWord: newWord)
                }
            }
            return
        }

        WordPopLogger.log("Replacement skipped: no safe target and no pending keystroke record.")
    }

    func replace(oldWord: String, boundary: String, with newWord: String) {
        replace(oldWord: oldWord, boundary: boundary, with: newWord, target: nil)
    }

    private func replaceViaKeystrokes(_ pending: PendingCorrection, with newWord: String) {
        guard let source = CGEventSource(stateID: .hidSystemState) else { return }
        let deleteCount = pending.oldWord.count + pending.boundary.count + pending.tail.count

        for _ in 0..<deleteCount {
            for keyDown in [true, false] {
                let event = CGEvent(keyboardEventSource: source, virtualKey: 51, keyDown: keyDown)
                event?.setIntegerValueField(.eventSourceUserData, value: Self.syntheticEventMarker)
                event?.post(tap: .cghidEventTap)
            }
            usleep(2000)
        }

        insertText(newWord + pending.boundary + pending.tail)
        WordPopLogger.log("Replacement completed via keystrokes (\(deleteCount) backspaces).")
    }

    private func insertText(_ text: String) {
        guard let source = CGEventSource(stateID: .hidSystemState) else { return }
        let utf16Chars = Array(text.utf16)

        // keyboardSetUnicodeString drops long strings in some apps; type in small chunks.
        var index = 0
        while index < utf16Chars.count {
            let chunk = Array(utf16Chars[index..<min(index + 16, utf16Chars.count)])
            for keyDown in [true, false] {
                let event = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: keyDown)
                event?.keyboardSetUnicodeString(stringLength: chunk.count, unicodeString: chunk)
                event?.setIntegerValueField(.eventSourceUserData, value: Self.syntheticEventMarker)
                event?.post(tap: .cghidEventTap)
            }
            index += 16
            usleep(2000)
        }
    }

    private func replaceUsingAccessibility(target: AccessibilityTextTarget, oldWord: String, with newWord: String) -> Bool {
        guard var range = validatedRange(target: target, oldWord: oldWord) else {
            return false
        }
        guard let rangeValue = AXValueCreate(.cfRange, &range) else {
            WordPopLogger.log("Accessibility replacement failed: could not create range value.")
            return false
        }

        let setResult = AXUIElementSetAttributeValue(
            target.element,
            kAXSelectedTextRangeAttribute as CFString,
            rangeValue
        )

        guard setResult == .success else {
            WordPopLogger.log("Accessibility replacement failed: set selected range returned \(setResult.rawValue).")
            return false
        }

        Thread.sleep(forTimeInterval: 0.03)
        insertText(newWord)
        return true
    }

    private func validatedRange(target: AccessibilityTextTarget, oldWord: String) -> CFRange? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(target.element, kAXValueAttribute as CFString, &value) == .success,
              let text = value as? String else {
            WordPopLogger.log("Replacement target has no readable text value; trying saved AX range.")
            return target.range
        }

        let nsText = text as NSString
        let proposed = NSRange(location: target.range.location, length: target.range.length)
        if proposed.location >= 0,
           NSMaxRange(proposed) <= nsText.length,
           nsText.substring(with: proposed) == oldWord {
            return target.range
        }

        let found = nsText.range(of: oldWord, options: [.backwards])
        if found.location != NSNotFound {
            WordPopLogger.log("Replacement target range adjusted by searching for '\(oldWord)' at {\(found.location), \(found.length)}.")
            return CFRange(location: found.location, length: found.length)
        }

        WordPopLogger.log("Replacement target validation could not find '\(oldWord)'.")
        return nil
    }
}

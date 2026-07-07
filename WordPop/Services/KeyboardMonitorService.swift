//
//  KeyboardMonitorService.swift
//  WordPop
//

import Cocoa
import ApplicationServices
import CoreGraphics
import SwiftUI

// C-function callback for the event tap
func cgEventCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
    let service = Unmanaged<KeyboardMonitorService>.fromOpaque(refcon).takeUnretainedValue()
    return service.handleEvent(proxy: proxy, type: type, event: event)
}

struct PendingCorrection {
    let oldWord: String
    let boundary: String
    var tail: String
    let pid: pid_t
}

final class KeyboardMonitorService {
    static let shared = KeyboardMonitorService()

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var hasStarted = false
    private var currentWordTarget: AccessibilityTextTarget?
    private var pendingCorrections: [UUID: PendingCorrection] = [:]
    private var mouseMonitor: Any?
    // Keys that move the caret or change focus: correction-by-backspace is no longer safe.
    private let caretInvalidatingKeyCodes: Set<UInt16> = [36, 76, 48, 115, 116, 117, 119, 121, 123, 124, 125, 126]

    private let wordBuffer = WordBufferService()
    @AppStorage("isWordPopEnabled") private var isWordPopEnabled = true

    private init() {}
    
    func start() {
        guard !hasStarted else {
            WordPopLogger.log("Keyboard monitor already started.")
            return
        }

        guard AccessibilityManager.shared.isTrusted else {
            WordPopLogger.log("Cannot start keyboard monitor: Accessibility permissions missing.")
            return
        }
        
        let eventMask = (1 << CGEventType.keyDown.rawValue)
        let userInfo = Unmanaged.passUnretained(self).toOpaque()
        
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly, // never modifies events; keeps typing latency at zero
            eventsOfInterest: CGEventMask(eventMask),
            callback: cgEventCallback,
            userInfo: userInfo
        )
        
        guard let eventTap = eventTap else {
            WordPopLogger.log("Failed to create CGEventTap.")
            return
        }
        
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        hasStarted = true

        // A click can move the caret — but only in the app the words were typed in.
        // Clicks on other apps/desktop leave pending corrections usable.
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] event in
            guard let self else { return }
            if let clickedPid = Self.ownerPid(ofWindowNumber: event.windowNumber) {
                self.pendingCorrections = self.pendingCorrections.filter { $0.value.pid != clickedPid }
            } else {
                self.pendingCorrections.removeAll()
            }
        }

        WordPopLogger.log("Keyboard monitor started successfully.")
    }
    
    func stop() {
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            if let runLoopSource = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            }
            self.eventTap = nil
            self.runLoopSource = nil
            self.hasStarted = false
            if let mouseMonitor {
                NSEvent.removeMonitor(mouseMonitor)
                self.mouseMonitor = nil
            }
            pendingCorrections.removeAll()
            WordPopLogger.log("Keyboard monitor stopped.")
        }
    }
    
    func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap = eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
                WordPopLogger.log("Keyboard event tap was disabled and has been re-enabled.")
            }
            return Unmanaged.passUnretained(event)
        }

        // Ignore our own synthetic correction keystrokes.
        if event.getIntegerValueField(.eventSourceUserData) == ReplacementEngine.syntheticEventMarker {
            return Unmanaged.passUnretained(event)
        }

        guard isWordPopEnabled else { return Unmanaged.passUnretained(event) }

        if type == .keyDown {
            let flags = event.flags
            if flags.contains(.maskCommand) || flags.contains(.maskControl) {
                wordBuffer.clear()
                currentWordTarget = nil
                pendingCorrections.removeAll()
                return Unmanaged.passUnretained(event)
            }

            if AccessibilityManager.shared.isPasswordFieldFocused() {
                wordBuffer.clear()
                currentWordTarget = nil
                pendingCorrections.removeAll()
                return Unmanaged.passUnretained(event)
            }

            if let nsEvent = NSEvent(cgEvent: event), let chars = nsEvent.charactersIgnoringModifiers {
                if caretInvalidatingKeyCodes.contains(nsEvent.keyCode) {
                    pendingCorrections.removeAll()
                }

                if nsEvent.keyCode == 51 { // Backspace
                    wordBuffer.backspace()
                    if wordBuffer.currentWord.isEmpty {
                        currentWordTarget = nil
                    }
                    for (id, var pending) in pendingCorrections {
                        if pending.tail.isEmpty {
                            // Backspaced into the boundary/word itself; no longer safe.
                            pendingCorrections[id] = nil
                        } else {
                            pending.tail.removeLast()
                            pendingCorrections[id] = pending
                        }
                    }
                } else if wordBuffer.isBoundary(chars) {
                    appendToPendingTails(chars)
                    let current = wordBuffer.currentWord
                    if !current.isEmpty {
                        if let suggestions = SpellCheckerService.shared.check(word: current), let best = suggestions.first {
                            let point = AccessibilityManager.shared.getCaretPosition() ?? BubbleManager.shared.fallbackPoint
                            let target = replacementTarget(for: current, boundary: chars)
                            let bubbleId = UUID()
                            registerPendingCorrection(id: bubbleId, word: current, boundary: chars)
                            WordPopLogger.log("Misspelled word '\(current)' suggestion '\(best)'.")
                            BubbleManager.shared.show(suggestion: best, at: point, oldWord: current, boundary: chars, target: target, id: bubbleId)
                        } else {
                            WordPopLogger.log("Word '\(current)' has no spelling suggestion.")
                        }
                    }
                    wordBuffer.clear()
                    currentWordTarget = nil
                } else {
                    let printable = chars.filter { $0.isASCII && $0.isPrintable || !$0.isASCII }
                    if !printable.isEmpty {
                        appendToPendingTails(printable)
                        if wordBuffer.currentWord.isEmpty {
                            currentWordTarget = AccessibilityManager.shared.currentInsertionTarget()
                        }
                        wordBuffer.append(printable)
                    }
                }
            }
        }
        return Unmanaged.passUnretained(event)
    }

    private static func ownerPid(ofWindowNumber windowNumber: Int) -> pid_t? {
        guard windowNumber > 0,
              let info = CGWindowListCopyWindowInfo(.optionIncludingWindow, CGWindowID(windowNumber)) as? [[String: Any]],
              let pid = info.first?[kCGWindowOwnerPID as String] as? pid_t else {
            return nil
        }
        return pid
    }

    private func registerPendingCorrection(id: UUID, word: String, boundary: String) {
        // Retyping a newline/tab could submit a chat message or move focus — skip those.
        guard boundary.rangeOfCharacter(from: .newlines) == nil, !boundary.contains("\t") else { return }
        let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier ?? -1
        pendingCorrections[id] = PendingCorrection(oldWord: word, boundary: boundary, tail: "", pid: pid)
    }

    private func appendToPendingTails(_ text: String) {
        for (id, var pending) in pendingCorrections {
            pending.tail += text
            // ponytail: >120 chars past the typo means too many backspaces to replay safely — drop it.
            pendingCorrections[id] = pending.tail.count > 120 ? nil : pending
        }
    }

    func consumePendingCorrection(id: UUID) -> PendingCorrection? {
        defer { pendingCorrections[id] = nil }
        guard let pending = pendingCorrections[id] else { return nil }
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == pending.pid else {
            WordPopLogger.log("Pending correction dropped: focused app changed since the word was typed.")
            return nil
        }
        return pending
    }

    func adjustPendingTails(oldWord: String, newWord: String) {
        // ponytail: fixes first occurrence only; good enough to keep sibling bubbles clickable after one correction.
        for (id, var pending) in pendingCorrections {
            if let range = pending.tail.range(of: oldWord) {
                pending.tail.replaceSubrange(range, with: newWord)
                pendingCorrections[id] = pending
            }
        }
    }

    private func replacementTarget(for word: String, boundary: String) -> AccessibilityTextTarget? {
        if let currentWordTarget {
            let target = AccessibilityTextTarget(
                element: currentWordTarget.element,
                range: CFRange(location: currentWordTarget.range.location, length: word.utf16.count)
            )
            WordPopLogger.log("Replacement target captured from word start for '\(word)' at range {\(target.range.location), \(target.range.length)}.")
            return target
        }

        return AccessibilityManager.shared.replacementTarget(oldWord: word, boundary: boundary)
    }
}

fileprivate extension Character {
    var isPrintable: Bool {
        guard let scalar = unicodeScalars.first else { return false }
        return !CharacterSet.controlCharacters.contains(scalar)
    }
}

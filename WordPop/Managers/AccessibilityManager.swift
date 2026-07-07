//
//  AccessibilityManager.swift
//  WordPop
//

import Cocoa
import ApplicationServices

struct AccessibilityTextTarget {
    let element: AXUIElement
    let range: CFRange
}

final class AccessibilityManager {
    static let shared = AccessibilityManager()
    
    var isTrusted: Bool = false
    
    private init() {
        checkPermissions(prompt: false)
        // Setting the timeout on the system-wide element bounds ALL AX calls from this
        // process; without it an AX-less/unresponsive app can stall lookups for seconds.
        AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), 0.1)
    }
    
    @discardableResult
    func checkPermissions(prompt: Bool = true) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        self.isTrusted = trusted
        WordPopLogger.log("Accessibility check prompt=\(prompt) trusted=\(trusted)")
        return trusted
    }
    
    func isPasswordFieldFocused() -> Bool {
        guard let axElement = focusedElement() else {
            return false
        }

        var subroleValue: CFTypeRef?
        
        let subroleResult = AXUIElementCopyAttributeValue(axElement, kAXSubroleAttribute as CFString, &subroleValue)
        if subroleResult == .success, let subrole = subroleValue as? String {
            return subrole == "AXSecureTextField"
        }
        
        return false
    }
    
    func getCaretPosition() -> CGPoint? {
        guard let axElement = focusedElement() else {
            WordPopLogger.log("Caret lookup failed: no focused element.")
            return nil
        }
        var selectedRangeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axElement, kAXSelectedTextRangeAttribute as CFString, &selectedRangeValue) == .success else {
            WordPopLogger.log("Caret lookup failed: no selected text range.")
            return nil
        }

        var selectedRange: CFRange = CFRange()
        guard AXValueGetValue(selectedRangeValue as! AXValue, .cfRange, &selectedRange) else {
            WordPopLogger.log("Caret lookup failed: selected range is not a CFRange.")
            return nil
        }

        var boundsValue: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(axElement, kAXBoundsForRangeParameterizedAttribute as CFString, selectedRangeValue!, &boundsValue) == .success else {
            WordPopLogger.log("Caret lookup failed: focused app did not return bounds for range \(selectedRange.location).")
            return nil
        }

        var bounds: CGRect = .zero
        guard AXValueGetValue(boundsValue as! AXValue, .cgRect, &bounds) else {
            WordPopLogger.log("Caret lookup failed: bounds value is not a CGRect.")
            return nil
        }

        return bounds.origin
    }

    func replacementTarget(oldWord: String, boundary: String) -> AccessibilityTextTarget? {
        guard let axElement = focusedElement() else {
            WordPopLogger.log("Replacement target failed: no focused element.")
            return nil
        }
        var selectedRangeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axElement, kAXSelectedTextRangeAttribute as CFString, &selectedRangeValue) == .success,
              let selectedRangeValue else {
            WordPopLogger.log("Replacement target failed: no selected text range.")
            return nil
        }

        var selectedRange = CFRange()
        guard AXValueGetValue(selectedRangeValue as! AXValue, .cfRange, &selectedRange) else {
            WordPopLogger.log("Replacement target failed: invalid selected text range.")
            return nil
        }

        let wordLength = oldWord.utf16.count
        let start = selectedRange.location - wordLength
        guard start >= 0 else {
            WordPopLogger.log("Replacement target failed: calculated invalid range for '\(oldWord)' at selected location \(selectedRange.location).")
            return nil
        }

        WordPopLogger.log("Replacement target captured for '\(oldWord)' at range {\(start), \(wordLength)}.")
        return AccessibilityTextTarget(
            element: axElement,
            range: CFRange(location: start, length: wordLength)
        )
    }

    func currentInsertionTarget() -> AccessibilityTextTarget? {
        guard let axElement = focusedElement() else {
            return nil
        }

        var selectedRangeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axElement, kAXSelectedTextRangeAttribute as CFString, &selectedRangeValue) == .success,
              let selectedRangeValue else {
            return nil
        }

        var selectedRange = CFRange()
        guard AXValueGetValue(selectedRangeValue as! AXValue, .cfRange, &selectedRange) else {
            return nil
        }

        return AccessibilityTextTarget(
            element: axElement,
            range: CFRange(location: selectedRange.location, length: 0)
        )
    }

    private func focusedElement() -> AXUIElement? {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedElement: CFTypeRef?
        if AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focusedElement) == .success,
           let focusedElement {
            return (focusedElement as! AXUIElement)
        }

        var focusedApplication: CFTypeRef?
        if AXUIElementCopyAttributeValue(systemWide, kAXFocusedApplicationAttribute as CFString, &focusedApplication) == .success,
           let focusedApplication {
            let appElement = focusedApplication as! AXUIElement
            if AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedElement) == .success,
               let focusedElement {
                return (focusedElement as! AXUIElement)
            }
        }

        if let frontmost = NSWorkspace.shared.frontmostApplication {
            let appElement = AXUIElementCreateApplication(frontmost.processIdentifier)
            if AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedElement) == .success,
               let focusedElement {
                return (focusedElement as! AXUIElement)
            }
        }

        return nil
    }
}

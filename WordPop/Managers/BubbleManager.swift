//
//  BubbleManager.swift
//  WordPop
//

import Cocoa
import SwiftUI

final class BubbleManager {
    static let shared = BubbleManager()

    private var bubbles: [UUID: FloatingBubbleController] = [:]

    var fallbackPoint: CGPoint {
        guard let screen = NSScreen.main else {
            return CGPoint(x: 400, y: 120)
        }

        return CGPoint(x: screen.frame.midX, y: 120)
    }

    func show(
        suggestion: String,
        at point: CGPoint,
        oldWord: String,
        boundary: String,
        target: AccessibilityTextTarget?,
        id: UUID = UUID()
    ) {
        DispatchQueue.main.async {
            guard let screen = self.screen(containing: point) else { return }
            let controller = FloatingBubbleController(
                id: id,
                suggestion: suggestion,
                oldWord: oldWord,
                boundary: boundary,
                target: target,
                screen: screen
            ) { [weak self] id in
                self?.bubbles[id] = nil
            }

            self.bubbles[id] = controller
            controller.show()
            WordPopLogger.log("Showing floating bubble id=\(id) suggestion='\(suggestion)'.")
        }
    }

    func show(suggestion: String, at point: CGPoint, oldWord: String, boundary: String) {
        show(suggestion: suggestion, at: point, oldWord: oldWord, boundary: boundary, target: nil)
    }

    func hide() {
        DispatchQueue.main.async {
            self.bubbles.values.forEach { $0.dismiss() }
            self.bubbles.removeAll()
        }
    }

    private func screen(containing point: CGPoint) -> NSScreen? {
        NSScreen.screens.first { screen in
            screen.frame.contains(point)
        } ?? NSScreen.main
    }

    fileprivate func resolveCollisions(for controller: FloatingBubbleController) {
        guard controller.isCollidable else { return }

        for other in bubbles.values where other.bubbleID != controller.bubbleID && other.isCollidable {
            let overlap = controller.collisionFrame.intersection(other.collisionFrame)
            guard !overlap.isNull, overlap.width > 0, overlap.height > 0 else { continue }

            let delta = CGVector(
                dx: controller.center.x - other.center.x,
                dy: controller.center.y - other.center.y
            )

            let normal: CGVector
            let push: CGFloat
            if overlap.width < overlap.height {
                normal = CGVector(dx: delta.dx >= 0 ? 1 : -1, dy: 0)
                push = max(overlap.width / 2 + 5, 5)
            } else {
                normal = CGVector(dx: 0, dy: delta.dy >= 0 ? 1 : -1)
                push = max(overlap.height / 2 + 5, 5)
            }

            controller.push(by: CGVector(dx: normal.dx * push, dy: normal.dy * push))
            other.push(by: CGVector(dx: -normal.dx * push, dy: -normal.dy * push))
            controller.bounce(awayFrom: normal)
            other.bounce(awayFrom: CGVector(dx: -normal.dx, dy: -normal.dy))
        }
    }
}

fileprivate final class FloatingBubbleController {
    private let id: UUID
    private let suggestion: String
    private let oldWord: String
    private let boundary: String
    private let target: AccessibilityTextTarget?
    private let screen: NSScreen
    private let onFinish: (UUID) -> Void
    private var windowSize: CGSize {
        let size = UserDefaults.standard.object(forKey: BubbleSettings.sizeKey) as? Double ?? 1.0
        return BubbleSettings.windowSize(for: suggestion, scale: size)
    }

    private var panel: BubblePanel?
    private var displayLink: Timer?
    private var didPop = false
    private var velocity = CGVector(
        dx: CGFloat.random(in: -1.15...1.15),
        dy: CGFloat.random(in: -0.85...0.85)
    )
    private var steeringCountdown = 0

    fileprivate var bubbleID: UUID {
        id
    }

    fileprivate var isCollidable: Bool {
        !didPop && panel?.isVisible == true
    }

    fileprivate var currentFrame: NSRect {
        panel?.frame ?? .zero
    }

    fileprivate var collisionFrame: NSRect {
        currentFrame.insetBy(dx: currentFrame.width * 0.08, dy: currentFrame.height * 0.08)
    }

    fileprivate var center: CGPoint {
        CGPoint(x: currentFrame.midX, y: currentFrame.midY)
    }

    init(
        id: UUID,
        suggestion: String,
        oldWord: String,
        boundary: String,
        target: AccessibilityTextTarget?,
        screen: NSScreen,
        onFinish: @escaping (UUID) -> Void
    ) {
        self.id = id
        self.suggestion = suggestion
        self.oldWord = oldWord
        self.boundary = boundary
        self.target = target
        self.screen = screen
        self.onFinish = onFinish
    }

    func show() {
        let panel = BubblePanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.backgroundColor = .clear
        panel.isOpaque = false
        // Window shadow renders as a stale white halo + ragged outline around the
        // moving blob-shaped panel; the SwiftUI shadow inside provides depth instead.
        panel.hasShadow = false
        panel.level = .statusBar
        panel.ignoresMouseEvents = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.onClick = { [weak self] in
            self?.popAndReplace()
        }

        let view = BubbleView(suggestion: suggestion) { [weak self] in
            self?.popAndReplace()
        }

        let trackingView = BubbleTrackingView()
        trackingView.onHoverChanged = { [weak panel, weak self] isHovering in
            panel?.isPointerInside = isHovering
            self?.setHovering(isHovering)
        }

        let hostingView = NSHostingView(rootView: view)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        trackingView.addSubview(hostingView)
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: trackingView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: trackingView.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: trackingView.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: trackingView.bottomAnchor)
        ])

        panel.contentView = trackingView
        panel.setFrame(startFrame(), display: true)
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        self.panel = panel

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.22
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }

        displayLink = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            self?.step()
        }
    }

    func dismiss() {
        displayLink?.invalidate()
        displayLink = nil
        panel?.orderOut(nil)
        panel = nil
    }

    private func popAndReplace() {
        guard !didPop, let panel else { return }
        didPop = true
        displayLink?.invalidate()
        displayLink = nil

        WordPopLogger.log("Bubble tapped id=\(id) suggestion='\(suggestion)'.")

        // Correct immediately; the burst animation runs in parallel.
        ReplacementEngine.shared.replace(
            oldWord: oldWord,
            boundary: boundary,
            with: suggestion,
            target: target,
            bubbleId: id
        )

        let burstFrame = panel.frame.insetBy(dx: -22, dy: -18)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 0
            panel.animator().setFrame(burstFrame, display: true)
        } completionHandler: { [weak self] in
            guard let self else { return }
            self.panel?.orderOut(nil)
            self.panel = nil
            self.onFinish(self.id)
        }
    }

    private func step() {
        guard !didPop, let panel else { return }
        if panel.isPointerInside {
            return
        }

        steeringCountdown -= 1
        if steeringCountdown <= 0 {
            let randomness = CGFloat(BubbleSettings.randomness)
            let minTicks = Int(90 - (randomness * 42))
            let maxTicks = Int(150 - (randomness * 58))
            steeringCountdown = Int.random(in: minTicks...max(minTicks + 1, maxTicks))
            velocity.dx += CGFloat.random(in: -0.24...0.24) * (0.25 + randomness)
            velocity.dy += CGFloat.random(in: -0.18...0.18) * (0.25 + randomness)
            limitVelocity()
        }

        let visible = screen.visibleFrame
        var frame = panel.frame.offsetBy(dx: velocity.dx, dy: velocity.dy)

        if frame.minX < visible.minX + 10 {
            frame.origin.x = visible.minX + 10
            velocity.dx = abs(velocity.dx) + 0.9
        } else if frame.maxX > visible.maxX - 10 {
            frame.origin.x = visible.maxX - frame.width - 10
            velocity.dx = -abs(velocity.dx) - 0.9
        }

        if frame.minY < visible.minY + 10 {
            frame.origin.y = visible.minY + 10
            velocity.dy = abs(velocity.dy) + 1.0
        } else if frame.maxY > visible.maxY - 10 {
            frame.origin.y = visible.maxY - frame.height - 10
            velocity.dy = -abs(velocity.dy) - 0.9
        }

        limitVelocity()
        panel.setFrame(frame, display: true)
        BubbleManager.shared.resolveCollisions(for: self)
    }

    private func setHovering(_ isHovering: Bool) {
        if isHovering {
            velocity.dx *= 0.35
            velocity.dy *= 0.35
        }
    }

    private func startFrame() -> NSRect {
        let visible = screen.visibleFrame
        let x = CGFloat.random(in: visible.minX + 40...(visible.maxX - windowSize.width - 40))
        let y = CGFloat.random(in: (visible.minY + visible.height * 0.45)...(visible.maxY - windowSize.height - 40))
        return NSRect(origin: CGPoint(x: x, y: y), size: windowSize)
    }

    private func limitVelocity() {
        let speed = sqrt((velocity.dx * velocity.dx) + (velocity.dy * velocity.dy))
        let setting = CGFloat(BubbleSettings.speed)
        let minSpeed: CGFloat = 0.24 + (setting * 0.7)
        let maxSpeed: CGFloat = 0.58 + (setting * 1.15)

        if speed < minSpeed {
            let scale = minSpeed / max(speed, 0.01)
            velocity.dx *= scale
            velocity.dy *= scale
        } else if speed > maxSpeed {
            // Soft cap: let bounce impulses briefly exceed max speed, then decay back.
            let scale = max(maxSpeed / speed, 0.93)
            velocity.dx *= scale
            velocity.dy *= scale
        }
    }

    fileprivate func push(by vector: CGVector) {
        guard !didPop, let panel, !panel.isPointerInside else { return }

        let visible = screen.visibleFrame
        var frame = panel.frame.offsetBy(dx: vector.dx, dy: vector.dy)
        frame.origin.x = min(max(frame.origin.x, visible.minX + 10), visible.maxX - frame.width - 10)
        frame.origin.y = min(max(frame.origin.y, visible.minY + 10), visible.maxY - frame.height - 10)
        panel.setFrame(frame, display: true)
    }

    fileprivate func bounce(awayFrom normal: CGVector) {
        guard !didPop else { return }

        let dot = (velocity.dx * normal.dx) + (velocity.dy * normal.dy)
        if dot < 0 {
            velocity.dx -= 1.85 * dot * normal.dx
            velocity.dy -= 1.85 * dot * normal.dy
        }

        velocity.dx += normal.dx * 1.2
        velocity.dy += normal.dy * 1.2
        limitVelocity()
    }
}

private final class BubblePanel: NSPanel {
    var onClick: (() -> Void)?
    var isPointerInside = false

    override var canBecomeKey: Bool {
        false
    }

    override var canBecomeMain: Bool {
        false
    }

    override func mouseDown(with event: NSEvent) {
        onClick?()
    }
}

private final class BubbleTrackingView: NSView {
    var onHoverChanged: ((Bool) -> Void)?
    private var trackingAreaRef: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let trackingAreaRef {
            removeTrackingArea(trackingAreaRef)
        }

        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        trackingAreaRef = trackingArea
    }

    override func mouseEntered(with event: NSEvent) {
        onHoverChanged?(true)
    }

    override func mouseExited(with event: NSEvent) {
        onHoverChanged?(false)
    }
}

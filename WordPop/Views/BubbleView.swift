//
//  BubbleView.swift
//  WordPop
//

import AppKit
import SwiftUI

struct BubbleView: View {
    let suggestion: String
    let action: () -> Void

    @State private var isHovered = false
    @State private var isVisible = false
    @State private var isPopped = false
    // Each bubble gets its own blob for the "random" shape.
    @State private var shapeSeed = UInt64.random(in: 1...UInt64.max)

    @AppStorage(BubbleSettings.sizeKey) private var bubbleSize: Double = 1.0
    @AppStorage(BubbleSettings.shapeKey) private var bubbleShape = "bubble"
    @AppStorage(BubbleSettings.cropImageKey) private var cropImage = true
    @AppStorage(BubbleSettings.imageZoomKey) private var imageZoom: Double = 1.0
    @AppStorage(BubbleSettings.imageOffsetXKey) private var imageOffsetX: Double = 0.5
    @AppStorage(BubbleSettings.imageOffsetYKey) private var imageOffsetY: Double = 0.5

    var body: some View {
        ZStack {
            burstParticles

            Text(suggestion)
                .font(.system(size: 18 * bubbleSize, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.88), radius: 3, x: 0, y: 1)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(width: contentSize.width, height: contentSize.height)
                .background(background)
                .clipShape(BubbleShape(kind: bubbleShape, seed: shapeSeed))
                .shadow(color: .black.opacity(0.32), radius: 14, x: 0, y: 8)
                .scaleEffect(isPopped ? 1.35 : (isHovered ? 1.12 : 1))
                .opacity(isPopped ? 0 : 1)
                .offset(y: isVisible ? 0 : -18)
                .animation(.spring(response: 0.42, dampingFraction: 0.66), value: isVisible)
                .animation(.spring(response: 0.24, dampingFraction: 0.58), value: isHovered)
                .animation(.easeOut(duration: 0.2), value: isPopped)
        }
        .frame(
            width: contentSize.width + 52 * bubbleSize,
            height: contentSize.height + 50 * bubbleSize
        )
        .contentShape(Rectangle())
        .onAppear {
            isVisible = true
        }
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            guard !isPopped else { return }
            isPopped = true
            action() // correct immediately; the pop animation runs in parallel
        }
    }

    private var contentSize: CGSize {
        BubbleSettings.contentSize(for: suggestion, scale: bubbleSize)
    }

    @ViewBuilder
    private var background: some View {
        if let url = BubbleSettings.imageURL {
            AnimatedImage(url: url, crop: cropImage, zoom: imageZoom, offsetX: imageOffsetX, offsetY: imageOffsetY)
                .overlay(Color.black.opacity(0.2))
        } else {
            LinearGradient(
                colors: [
                    Color.cyan.opacity(0.78),
                    Color.pink.opacity(0.68),
                    Color.indigo.opacity(0.48)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var burstParticles: some View {
        ForEach(0..<12, id: \.self) { index in
            Circle()
                .fill(particleColor(for: index))
                .frame(width: 8, height: 8)
                .offset(isPopped ? particleOffset(for: index) : .zero)
                .opacity(isPopped ? 0 : 0.85)
                .scaleEffect(isPopped ? 0.25 : 1)
                .animation(.easeOut(duration: 0.32), value: isPopped)
        }
    }

    private func particleColor(for index: Int) -> Color {
        let colors: [Color] = [.cyan, .mint, .pink, .yellow, .white, .blue]
        return colors[index % colors.count].opacity(0.85)
    }

    private func particleOffset(for index: Int) -> CGSize {
        let angle = CGFloat(index) / 12.0 * .pi * 2.0
        let distance = CGFloat(54 + (index % 4) * 12)
        return CGSize(width: cos(angle) * distance, height: sin(angle) * distance)
    }
}

struct AnimatedImage: NSViewRepresentable {
    let url: URL
    let crop: Bool
    var zoom: Double = 1.0
    var offsetX: Double = 0.5
    var offsetY: Double = 0.5

    func makeNSView(context: Context) -> PannableImageView {
        PannableImageView()
    }

    func updateNSView(_ nsView: PannableImageView, context: Context) {
        nsView.configure(url: url, crop: crop, zoom: zoom, offsetX: offsetX, offsetY: offsetY)
    }
}

// Clips an oversized NSImageView so zoom shows less of the image and the
// offsets pan which part is visible. Keeps GIF animation (NSImageView.animates).
final class PannableImageView: NSView {
    private let imageView = NSImageView()
    private var zoom: CGFloat = 1
    private var offsetX: CGFloat = 0.5
    private var offsetY: CGFloat = 0.5
    private var loadedPath = ""

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.masksToBounds = true
        imageView.animates = true
        imageView.canDrawSubviewsIntoLayer = true
        addSubview(imageView)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    func configure(url: URL, crop: Bool, zoom: Double, offsetX: Double, offsetY: Double) {
        if loadedPath != url.path {
            loadedPath = url.path
            imageView.image = NSImage(contentsOf: url)
            imageView.animates = true
        }
        imageView.imageScaling = crop ? .scaleAxesIndependently : .scaleProportionallyUpOrDown
        self.zoom = max(CGFloat(zoom), 1)
        self.offsetX = CGFloat(offsetX)
        self.offsetY = CGFloat(offsetY)
        needsLayout = true
    }

    override func layout() {
        super.layout()
        let width = bounds.width * zoom
        let height = bounds.height * zoom
        imageView.frame = NSRect(
            x: -(width - bounds.width) * offsetX,
            y: -(height - bounds.height) * (1 - offsetY),
            width: width,
            height: height
        )
    }
}

struct BubbleShape: Shape {
    let kind: String
    var seed: UInt64 = 0

    func path(in rect: CGRect) -> Path {
        switch kind {
        case "circle":
            return Path(ellipseIn: rect)
        case "rounded":
            return Path(roundedRect: rect, cornerRadius: 18)
        case "diamond":
            var path = Path()
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
            path.closeSubpath()
            return path
        case "star":
            return starPath(in: rect)
        case "random":
            return randomBlobPath(in: rect)
        default:
            return Path(roundedRect: rect, cornerRadius: rect.height / 2)
        }
    }

    private func starPath(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) * 0.5
        let inner = outer * 0.56
        var path = Path()

        for index in 0..<10 {
            let radius = index.isMultiple(of: 2) ? outer : inner
            let angle = CGFloat(index) * .pi / 5 - .pi / 2
            let point = CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            )

            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }

        path.closeSubpath()
        return path
    }

    // Seeded blob: same seed always draws the same blob, each bubble passes its own seed.
    private func randomBlobPath(in rect: CGRect) -> Path {
        var rng = SplitMix64(state: seed == 0 ? 0xB10B : seed)
        let pointCount = 8
        let center = CGPoint(x: rect.midX, y: rect.midY)

        let points = (0..<pointCount).map { index -> CGPoint in
            let angle = CGFloat(index) / CGFloat(pointCount) * 2 * .pi
            let wobble = CGFloat.random(in: 0.72...0.98, using: &rng)
            return CGPoint(
                x: center.x + cos(angle) * rect.width / 2 * wobble,
                y: center.y + sin(angle) * rect.height / 2 * wobble
            )
        }

        let midpoints = (0..<pointCount).map { index in
            CGPoint(
                x: (points[index].x + points[(index + 1) % pointCount].x) / 2,
                y: (points[index].y + points[(index + 1) % pointCount].y) / 2
            )
        }

        var path = Path()
        path.move(to: midpoints[0])
        for index in 1...pointCount {
            path.addQuadCurve(to: midpoints[index % pointCount], control: points[index % pointCount])
        }
        path.closeSubpath()
        return path
    }
}

struct SplitMix64: RandomNumberGenerator {
    var state: UInt64

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4B5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

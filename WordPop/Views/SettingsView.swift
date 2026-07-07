//
//  SettingsView.swift
//  WordPop
//

import AppKit
import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @AppStorage(BubbleSettings.enabledKey) private var isWordPopEnabled = true
    @AppStorage(BubbleSettings.sizeKey) private var bubbleSize: Double = 1.0
    @AppStorage(BubbleSettings.speedKey) private var bubbleSpeed: Double = 0.35
    @AppStorage(BubbleSettings.randomnessKey) private var bubbleRandomness: Double = 0.35
    @AppStorage(BubbleSettings.imagePathKey) private var bubbleImagePath = ""
    @AppStorage(BubbleSettings.cropImageKey) private var cropImage = true
    @AppStorage(BubbleSettings.shapeKey) private var bubbleShape = "bubble"
    @AppStorage(BubbleSettings.imageZoomKey) private var imageZoom: Double = 1.0
    @AppStorage(BubbleSettings.imageOffsetXKey) private var imageOffsetX: Double = 0.5
    @AppStorage(BubbleSettings.imageOffsetYKey) private var imageOffsetY: Double = 0.5
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @State private var previewSeed = UInt64.random(in: 1...UInt64.max)

    var body: some View {
        TabView {
            controlPanel
                .tabItem {
                    Label("Control", systemImage: "slider.horizontal.3")
                }
        }
        .frame(width: 620, height: 590)
    }

    private var controlPanel: some View {
        Form {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Toggle("Enable WordPop", isOn: $isWordPopEnabled)
                        .toggleStyle(.switch)

                    Toggle("Launch at Login", isOn: Binding(
                        get: { launchAtLogin },
                        set: { newValue in
                            launchAtLogin = newValue
                            toggleLaunchAtLogin(enabled: newValue)
                        }
                    ))

                    Divider()

                    HStack(alignment: .top, spacing: 22) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Live Preview")
                                .font(.headline)

                            previewBubble
                                .frame(width: 220, height: 140)

                            Text("Size, crop, shape, image, and GIF settings update here.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Bubble Image / GIF")
                                .font(.headline)

                            Button("Upload Image or GIF...") {
                                chooseBubbleImage()
                            }

                            Button("Use Default Background") {
                                bubbleImagePath = ""
                            }
                            .disabled(bubbleImagePath.isEmpty)

                            Toggle("Crop to Shape", isOn: $cropImage)
                                .disabled(bubbleImagePath.isEmpty)

                            sliderRow(
                                title: "Image Zoom",
                                value: $imageZoom,
                                range: 1...3,
                                displayValue: String(format: "%.2f", imageZoom)
                            )
                            .disabled(bubbleImagePath.isEmpty)

                            sliderRow(
                                title: "Image Horizontal",
                                value: $imageOffsetX,
                                range: 0...1,
                                displayValue: String(format: "%.2f", imageOffsetX)
                            )
                            .disabled(bubbleImagePath.isEmpty || imageZoom <= 1)

                            sliderRow(
                                title: "Image Vertical",
                                value: $imageOffsetY,
                                range: 0...1,
                                displayValue: String(format: "%.2f", imageOffsetY)
                            )
                            .disabled(bubbleImagePath.isEmpty || imageZoom <= 1)
                        }
                    }

                    Divider()

                    HStack {
                        Picker("Shape", selection: $bubbleShape) {
                            Text("Bubble").tag("bubble")
                            Text("Circle").tag("circle")
                            Text("Rounded").tag("rounded")
                            Text("Diamond").tag("diamond")
                            Text("Star").tag("star")
                            Text("Random Curves").tag("random")
                        }
                        .pickerStyle(.segmented)

                        if bubbleShape == "random" {
                            Button {
                                previewSeed = UInt64.random(in: 1...UInt64.max)
                            } label: {
                                Image(systemName: "shuffle")
                            }
                            .help("Preview another random blob (every bubble gets its own)")
                        }
                    }

                    sliderRow(
                        title: "Bubble Size",
                        value: $bubbleSize,
                        range: 0.65...1.75,
                        displayValue: String(format: "%.2f", bubbleSize)
                    )

                    sliderRow(
                        title: "Movement Speed",
                        value: $bubbleSpeed,
                        range: 0...1,
                        displayValue: String(format: "%.2f", bubbleSpeed)
                    )

                    sliderRow(
                        title: "Randomness",
                        value: $bubbleRandomness,
                        range: 0...1,
                        displayValue: String(format: "%.2f", bubbleRandomness)
                    )

                    HStack {
                        Spacer()
                        Button("Reset to Defaults") {
                            isWordPopEnabled = true
                            bubbleSize = 1.0
                            bubbleSpeed = 0.35
                            bubbleRandomness = 0.35
                            bubbleImagePath = ""
                            cropImage = true
                            bubbleShape = "bubble"
                            imageZoom = 1.0
                            imageOffsetX = 0.5
                            imageOffsetY = 0.5
                            launchAtLogin = false
                            toggleLaunchAtLogin(enabled: false)
                        }
                    }
                }
                .padding(20)
            }
        }
    }

    private var previewBubble: some View {
        let previewWord = "tomorrow"
        let content = BubbleSettings.contentSize(for: previewWord, scale: min(bubbleSize, 1.1))

        return ZStack {
            if let url = BubbleSettings.imageURL {
                AnimatedImage(url: url, crop: cropImage, zoom: imageZoom, offsetX: imageOffsetX, offsetY: imageOffsetY)
                    .overlay(Color.black.opacity(0.2))
            } else {
                LinearGradient(
                    colors: [.cyan.opacity(0.78), .pink.opacity(0.68), .indigo.opacity(0.48)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }

            Text(previewWord)
                .font(.system(size: 18 * bubbleSize, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.88), radius: 3, x: 0, y: 1)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(.horizontal, 16)
        }
        .frame(width: content.width, height: content.height)
        .clipShape(BubbleShape(kind: bubbleShape, seed: previewSeed))
        .shadow(color: .black.opacity(0.32), radius: 14, x: 0, y: 8)
        .frame(width: 220, height: 140)
    }

    private func sliderRow(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        displayValue: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Text(displayValue)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Slider(value: value, in: range)
        }
    }

    private func chooseBubbleImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .heic, .tiff, .gif]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        if panel.runModal() == .OK, let url = panel.url {
            bubbleImagePath = url.path
        }
    }

    private func toggleLaunchAtLogin(enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            WordPopLogger.log("Failed to toggle launch at login: \(error)")
        }
    }
}

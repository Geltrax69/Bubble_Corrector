//
//  BubbleSettings.swift
//  WordPop
//

import Foundation

enum BubbleSettings {
    static let enabledKey = "isWordPopEnabled"
    static let sizeKey = "bubbleSize"
    static let speedKey = "bubbleSpeed"
    static let randomnessKey = "bubbleRandomness"
    static let imagePathKey = "bubbleImagePath"
    static let cropImageKey = "bubbleCropImage"
    static let shapeKey = "bubbleShape"
    static let imageZoomKey = "bubbleImageZoom"
    static let imageOffsetXKey = "bubbleImageOffsetX"
    static let imageOffsetYKey = "bubbleImageOffsetY"

    static var imageURL: URL? {
        guard let path = UserDefaults.standard.string(forKey: imagePathKey), !path.isEmpty else {
            return nil
        }

        return URL(fileURLWithPath: path)
    }

    static var speed: Double {
        let value = UserDefaults.standard.object(forKey: speedKey) as? Double ?? 0.35
        return min(max(value, 0), 1)
    }

    static var randomness: Double {
        let value = UserDefaults.standard.object(forKey: randomnessKey) as? Double ?? 0.35
        return min(max(value, 0), 1)
    }

    static var cropImage: Bool {
        UserDefaults.standard.object(forKey: cropImageKey) as? Bool ?? true
    }

    static var shape: String {
        UserDefaults.standard.string(forKey: shapeKey) ?? "bubble"
    }

    // Bubble content sized to the suggestion word; window adds margin around it.
    static func contentSize(for word: String, scale: Double) -> CGSize {
        let s = CGFloat(scale)
        let width = min(max(CGFloat(word.count) * 11 + 46, 86), 320) * s
        return CGSize(width: width, height: 64 * s)
    }

    static func windowSize(for word: String, scale: Double) -> CGSize {
        let content = contentSize(for: word, scale: scale)
        let s = CGFloat(scale)
        return CGSize(width: content.width + 52 * s, height: content.height + 50 * s)
    }
}

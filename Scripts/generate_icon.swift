#!/usr/bin/env swift
// Generates the Conduct app icon as an .iconset and .icns
// Also generates separate layers for IconComposer (macOS Tahoe liquid glass)
// Run: swift Scripts/generate_icon.swift

import AppKit
import Foundation

let colorSpace = CGColorSpaceCreateDeviceRGB()

// MARK: - Background Layer (for IconComposer: the back layer behind glass)

func drawBackground(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    guard let context = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    let rect = CGRect(x: 0, y: 0, width: size, height: size)
    let padding = size * 0.08
    let innerRect = rect.insetBy(dx: padding, dy: padding)
    let cornerRadius = size * 0.22
    let bgPath = NSBezierPath(roundedRect: innerRect, xRadius: cornerRadius, yRadius: cornerRadius)

    // Gradient: deep violet to rich purple with a subtle warm shift
    let gradientColors = [
        CGColor(colorSpace: colorSpace, components: [0.12, 0.06, 0.28, 1.0])!,
        CGColor(colorSpace: colorSpace, components: [0.22, 0.08, 0.42, 1.0])!,
        CGColor(colorSpace: colorSpace, components: [0.32, 0.12, 0.48, 1.0])!
    ] as CFArray
    let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: [0.0, 0.5, 1.0])!

    context.saveGState()
    bgPath.addClip()
    context.drawLinearGradient(gradient,
        start: CGPoint(x: size * 0.2, y: size * 0.95),
        end: CGPoint(x: size * 0.8, y: size * 0.05),
        options: [])

    // Subtle radial glow in center (gives depth behind glass)
    let glowColors = [
        CGColor(colorSpace: colorSpace, components: [0.45, 0.20, 0.65, 0.3])!,
        CGColor(colorSpace: colorSpace, components: [0.45, 0.20, 0.65, 0.0])!
    ] as CFArray
    let glowGradient = CGGradient(colorsSpace: colorSpace, colors: glowColors, locations: [0.0, 1.0])!
    context.drawRadialGradient(glowGradient,
        startCenter: CGPoint(x: size * 0.45, y: size * 0.55),
        startRadius: 0,
        endCenter: CGPoint(x: size * 0.45, y: size * 0.55),
        endRadius: size * 0.4,
        options: [])

    context.restoreGState()
    image.unlockFocus()
    return image
}

// MARK: - Foreground Layer (the content that sits on top / inside the glass)

func drawForeground(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    guard let context = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    let centerX = size * 0.50
    let centerY = size * 0.50

    // === Conductor's baton ===
    let batonWidth = size * 0.030
    let batonLength = size * 0.50
    let angle: CGFloat = -0.70

    let dx = sin(angle) * batonLength / 2
    let dy = cos(angle) * batonLength / 2
    let batonStart = CGPoint(x: centerX - dx, y: centerY - dy)
    let batonEnd = CGPoint(x: centerX + dx, y: centerY + dy)

    // Baton shadow (subtle depth)
    context.saveGState()
    context.setStrokeColor(CGColor(colorSpace: colorSpace, components: [0.0, 0.0, 0.0, 0.25])!)
    context.setLineWidth(batonWidth * 1.6)
    context.setLineCap(.round)
    context.move(to: CGPoint(x: batonStart.x + size * 0.008, y: batonStart.y - size * 0.008))
    context.addLine(to: CGPoint(x: batonEnd.x + size * 0.008, y: batonEnd.y - size * 0.008))
    context.strokePath()
    context.restoreGState()

    // Baton shaft - white with slight gradient feel
    context.saveGState()
    context.setStrokeColor(CGColor(colorSpace: colorSpace, components: [1.0, 1.0, 1.0, 0.97])!)
    context.setLineWidth(batonWidth)
    context.setLineCap(.round)
    context.move(to: batonStart)
    context.addLine(to: batonEnd)
    context.strokePath()
    context.restoreGState()

    // Baton highlight (thin bright line along shaft for glass refraction look)
    context.saveGState()
    context.setStrokeColor(CGColor(colorSpace: colorSpace, components: [1.0, 1.0, 1.0, 0.5])!)
    context.setLineWidth(batonWidth * 0.3)
    context.setLineCap(.round)
    let highlightOffset = size * 0.005
    context.move(to: CGPoint(x: batonStart.x - highlightOffset, y: batonStart.y + highlightOffset))
    context.addLine(to: CGPoint(x: batonEnd.x - highlightOffset, y: batonEnd.y + highlightOffset))
    context.strokePath()
    context.restoreGState()

    // Baton tip (gold, glowing)
    let tipRadius = size * 0.032
    // Glow
    context.saveGState()
    let tipGlowColors = [
        CGColor(colorSpace: colorSpace, components: [1.0, 0.80, 0.3, 0.6])!,
        CGColor(colorSpace: colorSpace, components: [1.0, 0.80, 0.3, 0.0])!
    ] as CFArray
    let tipGlow = CGGradient(colorsSpace: colorSpace, colors: tipGlowColors, locations: [0.0, 1.0])!
    context.drawRadialGradient(tipGlow,
        startCenter: batonEnd, startRadius: 0,
        endCenter: batonEnd, endRadius: tipRadius * 3,
        options: [])
    context.restoreGState()
    // Solid tip
    context.saveGState()
    context.setFillColor(CGColor(colorSpace: colorSpace, components: [1.0, 0.88, 0.45, 1.0])!)
    context.fillEllipse(in: CGRect(
        x: batonEnd.x - tipRadius, y: batonEnd.y - tipRadius,
        width: tipRadius * 2, height: tipRadius * 2))
    context.restoreGState()

    // Baton grip
    let gripRadius = size * 0.034
    context.saveGState()
    context.setFillColor(CGColor(colorSpace: colorSpace, components: [0.9, 0.9, 0.92, 0.95])!)
    context.fillEllipse(in: CGRect(
        x: batonStart.x - gripRadius, y: batonStart.y - gripRadius,
        width: gripRadius * 2, height: gripRadius * 2))
    context.restoreGState()

    // === Motion arcs ===
    let arcWidth = size * 0.016

    // Arc 1
    context.saveGState()
    context.setStrokeColor(CGColor(colorSpace: colorSpace, components: [1.0, 1.0, 1.0, 0.40])!)
    context.setLineWidth(arcWidth)
    context.setLineCap(.round)
    context.addArc(center: CGPoint(x: centerX + size * 0.06, y: centerY - size * 0.06),
        radius: size * 0.18, startAngle: .pi * 0.55, endAngle: .pi * 0.95, clockwise: false)
    context.strokePath()
    context.restoreGState()

    // Arc 2
    context.saveGState()
    context.setStrokeColor(CGColor(colorSpace: colorSpace, components: [1.0, 1.0, 1.0, 0.28])!)
    context.setLineWidth(arcWidth * 0.8)
    context.setLineCap(.round)
    context.addArc(center: CGPoint(x: centerX - size * 0.03, y: centerY + size * 0.06),
        radius: size * 0.13, startAngle: .pi * 1.6, endAngle: .pi * 2.0, clockwise: false)
    context.strokePath()
    context.restoreGState()

    // Arc 3 (subtle, adds depth)
    context.saveGState()
    context.setStrokeColor(CGColor(colorSpace: colorSpace, components: [1.0, 1.0, 1.0, 0.15])!)
    context.setLineWidth(arcWidth * 0.6)
    context.setLineCap(.round)
    context.addArc(center: CGPoint(x: centerX + size * 0.10, y: centerY - size * 0.12),
        radius: size * 0.24, startAngle: .pi * 0.65, endAngle: .pi * 0.85, clockwise: false)
    context.strokePath()
    context.restoreGState()

    image.unlockFocus()
    return image
}

// MARK: - Glass overlay (specular highlights that simulate liquid glass)

func drawGlassOverlay(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    guard let context = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    let padding = size * 0.08
    let innerRect = CGRect(x: 0, y: 0, width: size, height: size).insetBy(dx: padding, dy: padding)
    let cornerRadius = size * 0.22
    let bgPath = NSBezierPath(roundedRect: innerRect, xRadius: cornerRadius, yRadius: cornerRadius)

    context.saveGState()
    bgPath.addClip()

    // Top specular highlight (the characteristic Tahoe glass shine)
    let highlightColors = [
        CGColor(colorSpace: colorSpace, components: [1.0, 1.0, 1.0, 0.28])!,
        CGColor(colorSpace: colorSpace, components: [1.0, 1.0, 1.0, 0.08])!,
        CGColor(colorSpace: colorSpace, components: [1.0, 1.0, 1.0, 0.0])!
    ] as CFArray
    let highlightGradient = CGGradient(colorsSpace: colorSpace, colors: highlightColors, locations: [0.0, 0.3, 1.0])!
    context.drawLinearGradient(highlightGradient,
        start: CGPoint(x: size * 0.5, y: size * 0.92),
        end: CGPoint(x: size * 0.5, y: size * 0.45),
        options: [.drawsAfterEndLocation])

    // Edge highlight (rim light on top-left)
    let rimColors = [
        CGColor(colorSpace: colorSpace, components: [1.0, 1.0, 1.0, 0.20])!,
        CGColor(colorSpace: colorSpace, components: [1.0, 1.0, 1.0, 0.0])!
    ] as CFArray
    let rimGradient = CGGradient(colorsSpace: colorSpace, colors: rimColors, locations: [0.0, 1.0])!
    context.drawRadialGradient(rimGradient,
        startCenter: CGPoint(x: size * 0.30, y: size * 0.75),
        startRadius: 0,
        endCenter: CGPoint(x: size * 0.30, y: size * 0.75),
        endRadius: size * 0.35,
        options: [])

    // Bottom edge subtle reflection
    let bottomColors = [
        CGColor(colorSpace: colorSpace, components: [1.0, 1.0, 1.0, 0.0])!,
        CGColor(colorSpace: colorSpace, components: [1.0, 1.0, 1.0, 0.06])!
    ] as CFArray
    let bottomGradient = CGGradient(colorsSpace: colorSpace, colors: bottomColors, locations: [0.0, 1.0])!
    context.drawLinearGradient(bottomGradient,
        start: CGPoint(x: size * 0.5, y: size * 0.25),
        end: CGPoint(x: size * 0.5, y: size * 0.08),
        options: [.drawsAfterEndLocation])

    context.restoreGState()
    image.unlockFocus()
    return image
}

// MARK: - Composite (all layers combined for traditional .icns)

func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    let bg = drawBackground(size: size)
    bg.draw(in: NSRect(x: 0, y: 0, width: size, height: size))

    let fg = drawForeground(size: size)
    fg.draw(in: NSRect(x: 0, y: 0, width: size, height: size))

    let glass = drawGlassOverlay(size: size)
    glass.draw(in: NSRect(x: 0, y: 0, width: size, height: size))

    image.unlockFocus()
    return image
}

func savePNG(_ image: NSImage, to path: String) {
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        print("Failed to create PNG for \(path)")
        return
    }
    do {
        try pngData.write(to: URL(fileURLWithPath: path))
    } catch {
        print("Failed to write \(path): \(error)")
    }
}

// === Main ===
let projectDir = FileManager.default.currentDirectoryPath
let iconsetPath = "\(projectDir)/Resources/AppIcon.iconset"
let layersPath = "\(projectDir)/Resources/IconComposer-Layers"

// Create directories
try? FileManager.default.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)
try? FileManager.default.createDirectory(atPath: layersPath, withIntermediateDirectories: true)

// macOS icon sizes: 16, 32, 128, 256, 512 (each with @2x)
let sizes: [(name: String, size: CGFloat)] = [
    ("icon_16x16", 16),
    ("icon_16x16@2x", 32),
    ("icon_32x32", 32),
    ("icon_32x32@2x", 64),
    ("icon_128x128", 128),
    ("icon_128x128@2x", 256),
    ("icon_256x256", 256),
    ("icon_256x256@2x", 512),
    ("icon_512x512", 512),
    ("icon_512x512@2x", 1024),
]

print("Generating composite icon...")
for entry in sizes {
    let image = drawIcon(size: entry.size)
    let path = "\(iconsetPath)/\(entry.name).png"
    savePNG(image, to: path)
    print("  \(entry.name).png (\(Int(entry.size))x\(Int(entry.size)))")
}

// Export separate layers at 1024x1024 for IconComposer
print("\nExporting layers for IconComposer (1024x1024)...")
let layerSize: CGFloat = 1024

let bgLayer = drawBackground(size: layerSize)
savePNG(bgLayer, to: "\(layersPath)/background.png")
print("  background.png")

let fgLayer = drawForeground(size: layerSize)
savePNG(fgLayer, to: "\(layersPath)/foreground.png")
print("  foreground.png")

let glassLayer = drawGlassOverlay(size: layerSize)
savePNG(glassLayer, to: "\(layersPath)/glass-overlay.png")
print("  glass-overlay.png")

print("\nConverting to .icns...")
let icnsPath = "\(projectDir)/Resources/AppIcon.icns"
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetPath, "-o", icnsPath]
try process.run()
process.waitUntilExit()

if process.terminationStatus == 0 {
    print("✓ Created Resources/AppIcon.icns")
} else {
    print("✗ iconutil failed with status \(process.terminationStatus)")
}

print("""

── IconComposer (macOS Tahoe) ──────────────────────────
To create a liquid glass .icon file for macOS Tahoe:
1. Open IconComposer (Xcode 26+)
2. Import layers from Resources/IconComposer-Layers/
   • Back layer:  background.png
   • Front layer: foreground.png
3. Export as Conduct.icon
The system will apply glass refraction between layers.
────────────────────────────────────────────────────────
""")

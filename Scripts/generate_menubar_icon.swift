#!/usr/bin/env swift
import Cocoa

/// Generates a template image of a conductor's baton with orbiting circles for the menu bar.
/// Template images are black shapes that macOS automatically renders
/// in the correct color for light/dark mode.

func generateBatonTemplate(size: Int, white: Bool = false) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    let ctx = NSGraphicsContext.current!.cgContext
    let s = CGFloat(size)

    // Clear background (transparent)
    ctx.clear(CGRect(x: 0, y: 0, width: s, height: s))

    // Draw a conductor's baton facing upper-left (matching app icon)
    // In macOS coords: Y=0 is bottom. Baton goes from bottom-right (grip) to upper-left (tip)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)

    let color = white ? NSColor.white : NSColor.black
    let padding = s * 0.20

    // Grip at bottom-right
    let gripX = s - padding
    let gripY = padding
    // Tip at upper-left
    let tipX = padding
    let tipY = s - padding

    ctx.setStrokeColor(color.cgColor)
    ctx.setFillColor(color.cgColor)

    // Shaft (the stick) - bold so it reads clearly in the menu bar
    ctx.setLineWidth(s * 0.15)
    ctx.move(to: CGPoint(x: gripX, y: gripY))
    ctx.addLine(to: CGPoint(x: tipX + s * 0.06, y: tipY - s * 0.06))
    ctx.strokePath()

    // Tip (rounded knob at the upper-left end)
    let tipRadius = s * 0.11
    let tipCenter = CGPoint(x: tipX + s * 0.02, y: tipY - s * 0.02)
    ctx.fillEllipse(in: CGRect(
        x: tipCenter.x - tipRadius,
        y: tipCenter.y - tipRadius,
        width: tipRadius * 2,
        height: tipRadius * 2
    ))

    // Two accent beats (like notes coming off the baton), clearly visible
    let circleRadius = s * 0.085
    let centerX = (gripX + tipX) / 2
    let centerY = (gripY + tipY) / 2
    let orbitRadius = s * 0.30
    let circlePositions: [(CGFloat, CGFloat)] = [
        (centerX + orbitRadius * 0.95, centerY + orbitRadius * 0.45),  // upper-right beat
        (centerX - orbitRadius * 0.45, centerY - orbitRadius * 0.95),  // lower-left beat
    ]

    for (cx, cy) in circlePositions {
        ctx.fillEllipse(in: CGRect(
            x: cx - circleRadius,
            y: cy - circleRadius,
            width: circleRadius * 2,
            height: circleRadius * 2
        ))
    }

    image.unlockFocus()
    image.isTemplate = true
    return image
}

func savePNG(_ image: NSImage, to path: String) {
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        print("Error: Failed to create PNG")
        return
    }
    do {
        try pngData.write(to: URL(fileURLWithPath: path))
    } catch {
        print("Error writing \(path): \(error)")
    }
}

// Generate 18x18 (1x) and 36x36 (2x) template images, both dark and light variants
let outputDir = "Resources"

savePNG(generateBatonTemplate(size: 18),              to: "\(outputDir)/MenuBarIcon.png")
savePNG(generateBatonTemplate(size: 36),              to: "\(outputDir)/MenuBarIcon@2x.png")
savePNG(generateBatonTemplate(size: 18, white: true), to: "\(outputDir)/MenuBarIcon-light.png")
savePNG(generateBatonTemplate(size: 36, white: true), to: "\(outputDir)/MenuBarIcon-light@2x.png")

print("✓ Generated menu bar icon templates:")
print("  \(outputDir)/MenuBarIcon.png (18x18)")
print("  \(outputDir)/MenuBarIcon@2x.png (36x36)")
print("  \(outputDir)/MenuBarIcon-light.png (18x18, white)")
print("  \(outputDir)/MenuBarIcon-light@2x.png (36x36, white)")

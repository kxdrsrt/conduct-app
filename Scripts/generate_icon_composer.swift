#!/usr/bin/env swift
// Generates the Conduct .icon package for Icon Composer (macOS Tahoe Liquid Glass)
// Run: swift Scripts/generate_icon_composer.swift
// Then open: open Resources/AppIcon.icon

import AppKit
import Foundation

let colorSpace = CGColorSpaceCreateDeviceRGB()
let size: CGFloat = 1024

// MARK: - Foreground: clean baton + arcs (no shadows/glow - IC adds Liquid Glass)

func drawBaton(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    guard let context = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    let centerX = size * 0.50
    let centerY = size * 0.50
    let batonWidth = size * 0.032
    let batonLength = size * 0.50
    let angle: CGFloat = -0.70

    let dx = sin(angle) * batonLength / 2
    let dy = cos(angle) * batonLength / 2
    let batonStart = CGPoint(x: centerX - dx, y: centerY - dy)
    let batonEnd = CGPoint(x: centerX + dx, y: centerY + dy)

    // Baton shaft - solid white
    context.saveGState()
    context.setStrokeColor(CGColor(colorSpace: colorSpace, components: [1.0, 1.0, 1.0, 1.0])!)
    context.setLineWidth(batonWidth)
    context.setLineCap(.round)
    context.move(to: batonStart)
    context.addLine(to: batonEnd)
    context.strokePath()
    context.restoreGState()

    // Baton tip - gold circle
    let tipRadius = size * 0.032
    context.saveGState()
    context.setFillColor(CGColor(colorSpace: colorSpace, components: [1.0, 0.85, 0.40, 1.0])!)
    context.fillEllipse(in: CGRect(
        x: batonEnd.x - tipRadius, y: batonEnd.y - tipRadius,
        width: tipRadius * 2, height: tipRadius * 2))
    context.restoreGState()

    // Baton grip - light gray circle
    let gripRadius = size * 0.034
    context.saveGState()
    context.setFillColor(CGColor(colorSpace: colorSpace, components: [0.92, 0.92, 0.94, 1.0])!)
    context.fillEllipse(in: CGRect(
        x: batonStart.x - gripRadius, y: batonStart.y - gripRadius,
        width: gripRadius * 2, height: gripRadius * 2))
    context.restoreGState()

    image.unlockFocus()
    return image
}

// MARK: - Motion arcs layer (will get glass effect applied)

func drawArcs(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    guard let context = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    let centerX = size * 0.50
    let centerY = size * 0.50
    let arcWidth = size * 0.022

    // Arc 1
    context.saveGState()
    context.setStrokeColor(CGColor(colorSpace: colorSpace, components: [1.0, 1.0, 1.0, 0.9])!)
    context.setLineWidth(arcWidth)
    context.setLineCap(.round)
    context.addArc(center: CGPoint(x: centerX + size * 0.06, y: centerY - size * 0.06),
        radius: size * 0.18, startAngle: .pi * 0.55, endAngle: .pi * 0.95, clockwise: false)
    context.strokePath()
    context.restoreGState()

    // Arc 2
    context.saveGState()
    context.setStrokeColor(CGColor(colorSpace: colorSpace, components: [1.0, 1.0, 1.0, 0.75])!)
    context.setLineWidth(arcWidth * 0.8)
    context.setLineCap(.round)
    context.addArc(center: CGPoint(x: centerX - size * 0.03, y: centerY + size * 0.06),
        radius: size * 0.13, startAngle: .pi * 1.6, endAngle: .pi * 2.0, clockwise: false)
    context.strokePath()
    context.restoreGState()

    // Arc 3
    context.saveGState()
    context.setStrokeColor(CGColor(colorSpace: colorSpace, components: [1.0, 1.0, 1.0, 0.55])!)
    context.setLineWidth(arcWidth * 0.6)
    context.setLineCap(.round)
    context.addArc(center: CGPoint(x: centerX + size * 0.10, y: centerY - size * 0.12),
        radius: size * 0.24, startAngle: .pi * 0.65, endAngle: .pi * 0.85, clockwise: false)
    context.strokePath()
    context.restoreGState()

    image.unlockFocus()
    return image
}

// MARK: - Save helper

func savePNG(_ image: NSImage, to path: String) {
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        print("Failed to create PNG: \(path)")
        return
    }
    try! pngData.write(to: URL(fileURLWithPath: path))
}

// MARK: - Main

let projectDir = FileManager.default.currentDirectoryPath
let iconPath = "\(projectDir)/Resources/AppIcon.icon"
let assetsPath = "\(iconPath)/Assets"

// Create .icon package structure
try? FileManager.default.removeItem(atPath: iconPath)
try! FileManager.default.createDirectory(atPath: assetsPath, withIntermediateDirectories: true)

// Generate layer PNGs
print("Generating layers for Icon Composer...")
let batonImage = drawBaton(size: size)
savePNG(batonImage, to: "\(assetsPath)/Baton.png")
print("  Baton.png (foreground)")

let arcsImage = drawArcs(size: size)
savePNG(arcsImage, to: "\(assetsPath)/Arcs.png")
print("  Arcs.png (motion arcs)")

// Create icon.json
let iconJSON = """
{
    "fill": {
        "automatic-gradient": "extended-srgb:0.12000,0.06000,0.28000,1.00000"
    },
    "groups": [
        {
            "blur-material": 0.3,
            "layers": [
                {
                    "blend-mode": "normal",
                    "glass": true,
                    "image-name": "Arcs.png",
                    "name": "Arcs",
                    "position": {
                        "scale": 1.0,
                        "translation-in-points": [0, 0]
                    }
                }
            ],
            "lighting": "individual",
            "shadow": {
                "kind": "layer-color",
                "opacity": 0.3
            },
            "specular": true,
            "translucency": {
                "enabled": true,
                "value": 0.4
            }
        },
        {
            "blur-material": 0.0,
            "layers": [
                {
                    "blend-mode": "normal",
                    "glass": true,
                    "image-name": "Baton.png",
                    "name": "Baton",
                    "position": {
                        "scale": 1.0,
                        "translation-in-points": [0, 0]
                    }
                }
            ],
            "lighting": "individual",
            "shadow": {
                "kind": "layer-color",
                "opacity": 0.5
            },
            "specular": true,
            "translucency": {
                "enabled": false,
                "value": 0.0
            }
        }
    ],
    "supported-platforms": {
        "circles": ["watchOS"],
        "squares": "shared"
    }
}
"""

try! iconJSON.write(toFile: "\(iconPath)/icon.json", atomically: true, encoding: .utf8)
print("  icon.json")

print("\n✓ Created Resources/AppIcon.icon")
print("  Open with: open Resources/AppIcon.icon")

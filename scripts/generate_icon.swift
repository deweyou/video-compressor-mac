import AppKit
import Foundation

let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)

image.lockFocus()
guard let ctx = NSGraphicsContext.current?.cgContext else {
    fatalError("No graphics context")
}

let rect = CGRect(origin: .zero, size: size)
let radius: CGFloat = 220
let path = NSBezierPath(roundedRect: rect.insetBy(dx: 40, dy: 40), xRadius: radius, yRadius: radius)
path.addClip()

let gradient = CGGradient(
    colorsSpace: CGColorSpaceCreateDeviceRGB(),
    colors: [
        NSColor(calibratedRed: 0.11, green: 0.41, blue: 0.89, alpha: 1).cgColor,
        NSColor(calibratedRed: 0.03, green: 0.14, blue: 0.33, alpha: 1).cgColor
    ] as CFArray,
    locations: [0.0, 1.0]
)!
ctx.drawLinearGradient(gradient, start: CGPoint(x: 120, y: 960), end: CGPoint(x: 900, y: 80), options: [])

NSColor(calibratedWhite: 1.0, alpha: 0.20).setStroke()
path.lineWidth = 36
path.stroke()

func drawRoundedRect(_ r: CGRect, color: NSColor, alpha: CGFloat = 1.0) {
    let p = NSBezierPath(roundedRect: r, xRadius: 32, yRadius: 32)
    color.withAlphaComponent(alpha).setFill()
    p.fill()
}

let frameOuter = CGRect(x: 190, y: 240, width: 644, height: 544)
let frameInner = frameOuter.insetBy(dx: 26, dy: 26)

let outer = NSBezierPath(roundedRect: frameOuter, xRadius: 54, yRadius: 54)
NSColor(calibratedWhite: 1.0, alpha: 0.92).setStroke()
outer.lineWidth = 22
outer.stroke()

let inner = NSBezierPath(roundedRect: frameInner, xRadius: 40, yRadius: 40)
NSColor(calibratedWhite: 1.0, alpha: 0.16).setFill()
inner.fill()

drawRoundedRect(CGRect(x: 250, y: 635, width: 145, height: 38), color: .white, alpha: 0.95)
drawRoundedRect(CGRect(x: 250, y: 575, width: 230, height: 38), color: .white, alpha: 0.80)
drawRoundedRect(CGRect(x: 250, y: 515, width: 320, height: 38), color: .white, alpha: 0.65)

let leftArrow = NSBezierPath()
leftArrow.move(to: CGPoint(x: 640, y: 520))
leftArrow.line(to: CGPoint(x: 520, y: 420))
leftArrow.line(to: CGPoint(x: 520, y: 470))
leftArrow.line(to: CGPoint(x: 430, y: 470))
leftArrow.line(to: CGPoint(x: 430, y: 570))
leftArrow.line(to: CGPoint(x: 520, y: 570))
leftArrow.line(to: CGPoint(x: 520, y: 620))
leftArrow.close()
NSColor(calibratedRed: 0.31, green: 0.90, blue: 0.68, alpha: 1.0).setFill()
leftArrow.fill()

let rightArrow = NSBezierPath()
rightArrow.move(to: CGPoint(x: 388, y: 504))
rightArrow.line(to: CGPoint(x: 508, y: 604))
rightArrow.line(to: CGPoint(x: 508, y: 554))
rightArrow.line(to: CGPoint(x: 598, y: 554))
rightArrow.line(to: CGPoint(x: 598, y: 454))
rightArrow.line(to: CGPoint(x: 508, y: 454))
rightArrow.line(to: CGPoint(x: 508, y: 404))
rightArrow.close()
NSColor(calibratedRed: 0.95, green: 0.79, blue: 0.29, alpha: 1.0).setFill()
rightArrow.fill()

let badge = NSBezierPath(ovalIn: CGRect(x: 700, y: 180, width: 160, height: 160))
NSColor(calibratedRed: 0.08, green: 0.83, blue: 0.52, alpha: 0.95).setFill()
badge.fill()

let pct = NSAttributedString(
    string: "%",
    attributes: [
        .font: NSFont.systemFont(ofSize: 100, weight: .black),
        .foregroundColor: NSColor.white
    ]
)
pct.draw(at: CGPoint(x: 748, y: 201))

image.unlockFocus()

let data = image.tiffRepresentation!
let rep = NSBitmapImageRep(data: data)!
let png = rep.representation(using: .png, properties: [:])!

let output = URL(fileURLWithPath: "/Users/deweyou/Documents/codes/compression-app/VideoCompressor/Resources/AppIcon1024.png")
try png.write(to: output)
print("Generated: \(output.path)")

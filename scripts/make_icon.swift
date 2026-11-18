// Renders the app icon (a knight on a board tile) into an .iconset directory.
import AppKit
let out = CommandLine.arguments[1]
try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)
for (name, px) in [("16x16",16),("16x16@2x",32),("32x32",32),("32x32@2x",64),("128x128",128),("128x128@2x",256),("256x256",256),("256x256@2x",512),("512x512",512),("512x512@2x",1024)] {
    let s = CGFloat(px)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let inset = s * 0.1
    let rect = NSRect(x: inset, y: inset, width: s - 2*inset, height: s - 2*inset)
    let clip = NSBezierPath(roundedRect: rect, xRadius: s * 0.18, yRadius: s * 0.18)
    clip.addClip()
    let light = NSColor(red: 0.94, green: 0.85, blue: 0.71, alpha: 1), dark = NSColor(red: 0.71, green: 0.53, blue: 0.39, alpha: 1)
    let cell = rect.width / 4
    for i in 0..<4 { for j in 0..<4 {
        ((i + j) % 2 == 0 ? dark : light).setFill()
        NSRect(x: rect.minX + CGFloat(i)*cell, y: rect.minY + CGFloat(j)*cell, width: cell, height: cell).fill()
    }}
    let font = NSFont(name: "Apple Symbols", size: s * 0.78)!
    func draw(_ str: String, _ attrs: [NSAttributedString.Key: Any]) {
        var a = attrs; a[.font] = font
        let t = NSAttributedString(string: str, attributes: a); let b = t.size()
        t.draw(at: NSPoint(x: (s - b.width)/2, y: (s - b.height)/2 + s*0.03))
    }
    let shadow = NSShadow(); shadow.shadowBlurRadius = s*0.03; shadow.shadowOffset = NSSize(width: 0, height: -s*0.015); shadow.shadowColor = NSColor(white: 0, alpha: 0.5)
    shadow.set()
    draw("♞", [.foregroundColor: NSColor.white])
    draw("♘", [.foregroundColor: NSColor(white: 0.05, alpha: 1)])
    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(out)/icon_\(name).png"))
}

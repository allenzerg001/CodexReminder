import AppKit
import SwiftUI

enum MenuBarIconRenderer {
    static func render(waitingCount: Int, isPulseOn: Bool) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        image.isTemplate = false

        image.lockFocus()
        defer { image.unlockFocus() }

        NSGraphicsContext.current?.imageInterpolation = .high

        if let baseIcon = AppIconResource.image() {
            let iconAlpha: CGFloat = waitingCount > 0 && isPulseOn ? 0.62 : 1.0
            baseIcon.draw(
                in: NSRect(origin: .zero, size: size),
                from: .zero,
                operation: .sourceOver,
                fraction: iconAlpha
            )
        } else {
            drawFallbackIcon(in: size, isPulseOn: isPulseOn)
        }

        if waitingCount > 0 {
            drawBadge(count: waitingCount, in: size, isPulseOn: isPulseOn)
        }

        return image
    }

    private static func drawFallbackIcon(in size: NSSize, isPulseOn: Bool) {
        let alpha: CGFloat = isPulseOn ? 0.62 : 1.0
        NSColor.labelColor.withAlphaComponent(alpha).setStroke()

        let rect = NSRect(x: 2.5, y: 4.0, width: 13.0, height: 10.0)
        let outline = NSBezierPath(roundedRect: rect, xRadius: 1.5, yRadius: 1.5)
        outline.lineWidth = 1.7
        outline.stroke()

        NSColor.labelColor.withAlphaComponent(alpha).setFill()
        NSRect(x: 5.5, y: 5.1, width: 7.0, height: 1.7).fill()
    }

    private static func drawBadge(count: Int, in size: NSSize, isPulseOn: Bool) {
        let label = count > 99 ? "99+" : "\(count)"
        let badgeHeight: CGFloat = 8
        let badgeWidth: CGFloat = label.count > 1 ? 12 : 8
        let badgeRect = NSRect(
            x: size.width - badgeWidth,
            y: size.height - badgeHeight,
            width: badgeWidth,
            height: badgeHeight
        )

        let alpha: CGFloat = isPulseOn ? 0.55 : 1.0
        NSColor.systemOrange.withAlphaComponent(alpha).setFill()
        NSBezierPath(roundedRect: badgeRect, xRadius: badgeHeight / 2, yRadius: badgeHeight / 2).fill()

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 6, weight: .bold),
            .foregroundColor: NSColor.white,
            .paragraphStyle: paragraph
        ]
        NSString(string: label).draw(
            in: badgeRect.offsetBy(dx: 0, dy: 0.4),
            withAttributes: attributes
        )
    }
}

struct MenuBarIcon: View {
    @ObservedObject var appState: AppState
    @State private var isPulseOn = false

    var body: some View {
        Image(nsImage: renderedIcon)
            .resizable()
            .scaledToFit()
            .frame(width: 18, height: 18)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.75).repeatForever(autoreverses: true)) {
                    isPulseOn = true
                }
            }
    }

    private var waitingCount: Int {
        appState.tools.filter { $0.status.isWaiting }.count
    }

    private var renderedIcon: NSImage {
        MenuBarIconRenderer.render(waitingCount: waitingCount, isPulseOn: isPulseOn)
    }
}

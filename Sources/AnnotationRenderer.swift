import AppKit

final class AnnotationRenderer {
    static let shared = AnnotationRenderer()

    private init() {}

    func draw(_ annotation: Annotation, in context: CGContext) {
        context.saveGState()
        configureContext(annotation, in: context)

        switch annotation.tool {
        case .arrow:
            drawArrow(annotation, in: context)
        case .rectangle:
            drawRectangle(annotation, in: context)
        case .ellipse:
            drawEllipse(annotation, in: context)
        case .line:
            drawLine(annotation, in: context)
        case .text:
            drawText(annotation, in: context)
        case .freehand:
            drawFreehand(annotation, in: context)
        case .highlighter:
            drawHighlighter(annotation, in: context)
        case .pixelate:
            drawPixelate(annotation, in: context)
        case .blur:
            drawBlur(annotation, in: context)
        }

        context.restoreGState()
    }

    private func configureContext(_ annotation: Annotation, in context: CGContext) {
        context.setStrokeColor(annotation.color.cgColor)
        context.setFillColor(annotation.color.withAlphaComponent(0.1).cgColor)
        context.setLineWidth(annotation.strokeWidth)
        context.setLineCap(.round)
        context.setLineJoin(.round)
    }

    func drawArrow(_ annotation: Annotation, in context: CGContext) {
        let start = annotation.startPoint
        let end = annotation.endPoint

        context.move(to: start)
        context.addLine(to: end)
        context.strokePath()

        let angle = atan2(end.y - start.y, end.x - start.x)

        let point1 = CGPoint(
            x: end.x - Design.Geometry.arrowLength * cos(angle - Design.Geometry.arrowAngle),
            y: end.y - Design.Geometry.arrowLength * sin(angle - Design.Geometry.arrowAngle)
        )
        let point2 = CGPoint(
            x: end.x - Design.Geometry.arrowLength * cos(angle + Design.Geometry.arrowAngle),
            y: end.y - Design.Geometry.arrowLength * sin(angle + Design.Geometry.arrowAngle)
        )

        context.move(to: end)
        context.addLine(to: point1)
        context.move(to: end)
        context.addLine(to: point2)
        context.strokePath()
    }

    func drawRectangle(_ annotation: Annotation, in context: CGContext) {
        let rect = CGRect(
            x: min(annotation.startPoint.x, annotation.endPoint.x),
            y: min(annotation.startPoint.y, annotation.endPoint.y),
            width: abs(annotation.endPoint.x - annotation.startPoint.x),
            height: abs(annotation.endPoint.y - annotation.startPoint.y)
        )
        context.stroke(rect)
    }

    func drawEllipse(_ annotation: Annotation, in context: CGContext) {
        let rect = CGRect(
            x: min(annotation.startPoint.x, annotation.endPoint.x),
            y: min(annotation.startPoint.y, annotation.endPoint.y),
            width: abs(annotation.endPoint.x - annotation.startPoint.x),
            height: abs(annotation.endPoint.y - annotation.startPoint.y)
        )
        context.strokeEllipse(in: rect)
    }

    func drawLine(_ annotation: Annotation, in context: CGContext) {
        context.move(to: annotation.startPoint)
        context.addLine(to: annotation.endPoint)
        context.strokePath()
    }

    func drawBlur(_ annotation: Annotation, in context: CGContext) {
        let rect = CGRect(
            x: min(annotation.startPoint.x, annotation.endPoint.x),
            y: min(annotation.startPoint.y, annotation.endPoint.y),
            width: abs(annotation.endPoint.x - annotation.startPoint.x),
            height: abs(annotation.endPoint.y - annotation.startPoint.y)
        )

        guard rect.width > 0 && rect.height > 0 else { return }

        // Respect Reduce Motion accessibility preference
        if isReduceMotionEnabled {
            context.setFillColor(NSColor.gray.withAlphaComponent(0.3).cgColor)
            context.fill(rect)
            context.setStrokeColor(NSColor.black.withAlphaComponent(0.3).cgColor)
            context.setLineWidth(1)
            context.stroke(rect)
            return
        }

        context.saveGState()
        context.clip(to: rect)

        let blurRadius = Design.Geometry.blurRadius
        let cols = Int(rect.width / blurRadius) + 2
        let rows = Int(rect.height / blurRadius) + 2

        for row in 0..<rows {
            for col in 0..<cols {
                let x = rect.minX + CGFloat(col) * blurRadius - blurRadius
                let y = rect.minY + CGFloat(row) * blurRadius - blurRadius
                let gray = CGFloat(row + col) / CGFloat(rows + cols)
                context.setFillColor(NSColor(white: gray, alpha: 1.0).cgColor)
                context.fill(CGRect(x: x, y: y, width: blurRadius * 2, height: blurRadius * 2))
            }
        }

        context.restoreGState()

        context.setStrokeColor(NSColor.black.withAlphaComponent(0.3).cgColor)
        context.setLineWidth(2)
        context.stroke(rect)
    }

    func drawText(_ annotation: Annotation, in context: CGContext) {
        let text = annotation.text ?? ""
        guard !text.isEmpty else { return }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: annotation.strokeWidth * 8, weight: .semibold),
            .foregroundColor: annotation.color
        ]

        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let textSize = attributedString.size()

        let point = annotation.startPoint

        let bgRect = NSRect(x: point.x - 4, y: point.y - 2, width: textSize.width + 8, height: textSize.height + 4)
        context.setFillColor(annotation.color.withAlphaComponent(0.15).cgColor)
        context.fill(bgRect)

        attributedString.draw(at: point)
    }

    func drawFreehand(_ annotation: Annotation, in context: CGContext) {
        guard annotation.points.count > 1 else { return }

        context.setStrokeColor(annotation.color.cgColor)
        context.setLineWidth(annotation.strokeWidth)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        context.move(to: annotation.points[0])
        for point in annotation.points.dropFirst() {
            context.addLine(to: point)
        }
        context.strokePath()
    }

    func drawHighlighter(_ annotation: Annotation, in context: CGContext) {
        guard annotation.points.count > 1 else { return }

        context.setStrokeColor(annotation.color.withAlphaComponent(0.35).cgColor)
        context.setLineWidth(annotation.strokeWidth * 4)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        context.move(to: annotation.points[0])
        for point in annotation.points.dropFirst() {
            context.addLine(to: point)
        }
        context.strokePath()
    }

    func drawPixelate(_ annotation: Annotation, in context: CGContext) {
        let rect = CGRect(
            x: min(annotation.startPoint.x, annotation.endPoint.x),
            y: min(annotation.startPoint.y, annotation.endPoint.y),
            width: abs(annotation.endPoint.x - annotation.startPoint.x),
            height: abs(annotation.endPoint.y - annotation.startPoint.y)
        )

        guard rect.width > 0 && rect.height > 0 else { return }

        // Respect Reduce Motion accessibility preference
        if isReduceMotionEnabled {
            context.setFillColor(NSColor.gray.withAlphaComponent(0.5).cgColor)
            context.fill(rect)
            context.setStrokeColor(NSColor.black.withAlphaComponent(0.5).cgColor)
            context.setLineWidth(1)
            context.stroke(rect)
            return
        }

        context.saveGState()
        context.clip(to: rect)

        let pixelSize = Design.Geometry.pixelSize
        let cols = Int(rect.width / pixelSize) + 1
        let rows = Int(rect.height / pixelSize) + 1

        let grayLevels: [CGFloat] = [0.3, 0.4, 0.5, 0.6, 0.7]
        var grayIndex = 0

        for row in 0..<rows {
            for col in 0..<cols {
                let x = rect.minX + CGFloat(col) * pixelSize
                let y = rect.minY + CGFloat(row) * pixelSize
                grayIndex = (grayIndex + 1) % grayLevels.count
                let gray = grayLevels[grayIndex]
                context.setFillColor(CGColor(gray: gray, alpha: 1.0))
                context.fill(CGRect(x: x, y: y, width: pixelSize, height: pixelSize))
            }
        }

        context.restoreGState()
        context.setStrokeColor(NSColor.black.withAlphaComponent(0.5).cgColor)
        context.setLineWidth(1)
        context.stroke(rect)
    }
}

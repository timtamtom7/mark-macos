import AppKit

class AnnotationView: NSView {
    private let annotationService: AnnotationService
    private var trackingArea: NSTrackingArea?
    private var clickedAnnotationId: UUID?

    init(frame: NSRect, annotationService: AnnotationService) {
        self.annotationService = annotationService
        super.init(frame: frame)
        self.wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let ta = trackingArea {
            removeTrackingArea(ta)
        }
        let newArea = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseMoved, .mouseEnteredAndExited],
            owner: self,
            userInfo: nil
        )
        trackingArea = newArea
        addTrackingArea(newArea)
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.clear(bounds)

        for annotation in annotationService.annotations {
            AnnotationRenderer.shared.draw(annotation, in: context)
        }

        if let current = annotationService.currentAnnotation {
            AnnotationRenderer.shared.draw(current, in: context)
        }
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)

        if event.type == .rightMouseDown {
            if let annotationId = findAnnotation(at: point) {
                showDeleteMenu(for: annotationId, at: event)
            }
            return
        }

        annotationService.beginAnnotation(at: point)
    }

    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        annotationService.updateAnnotation(to: point)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        annotationService.endAnnotation(at: point)
        needsDisplay = true
    }

    override func rightMouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if let annotationId = findAnnotation(at: point) {
            showDeleteMenu(for: annotationId, at: event)
        }
    }

    private func findAnnotation(at point: CGPoint) -> UUID? {
        for annotation in annotationService.annotations {
            if hitTest(annotation: annotation, at: point) {
                return annotation.id
            }
        }
        return nil
    }

    private func hitTest(annotation: Annotation, at point: CGPoint) -> Bool {
        let tolerance: CGFloat = 10

        switch annotation.tool {
        case .arrow, .line:
            return pointNearLine(from: annotation.startPoint, to: annotation.endPoint, point: point, tolerance: tolerance)
        case .rectangle, .ellipse, .pixelate, .blur:
            let rect = CGRect(
                x: min(annotation.startPoint.x, annotation.endPoint.x) - tolerance,
                y: min(annotation.startPoint.y, annotation.endPoint.y) - tolerance,
                width: abs(annotation.endPoint.x - annotation.startPoint.x) + tolerance * 2,
                height: abs(annotation.endPoint.y - annotation.startPoint.y) + tolerance * 2
            )
            return rect.contains(point)
        case .text:
            let rect = CGRect(
                x: annotation.startPoint.x - tolerance,
                y: annotation.startPoint.y - tolerance,
                width: 200 + tolerance * 2,
                height: 50 + tolerance * 2
            )
            return rect.contains(point)
        case .freehand, .highlighter:
            for pts in zip(annotation.points.dropLast(), annotation.points.dropFirst()) {
                if pointNearLine(from: pts.0, to: pts.1, point: point, tolerance: tolerance) {
                    return true
                }
            }
            return false
        }
    }

    private func pointNearLine(from: CGPoint, to: CGPoint, point: CGPoint, tolerance: CGFloat) -> Bool {
        let lineLength = hypot(to.x - from.x, to.y - from.y)
        if lineLength == 0 { return hypot(point.x - from.x, point.y - from.y) < tolerance }

        let t = max(0, min(1, ((point.x - from.x) * (to.x - from.x) + (point.y - from.y) * (to.y - from.y)) / (lineLength * lineLength)))
        let projectionX = from.x + t * (to.x - from.x)
        let projectionY = from.y + t * (to.y - from.y)
        let distance = hypot(point.x - projectionX, point.y - projectionY)

        return distance < tolerance
    }

    private func showDeleteMenu(for annotationId: UUID, at event: NSEvent) {
        let menu = NSMenu()
        let deleteItem = NSMenuItem(title: "Delete", action: #selector(deleteAnnotation(_:)), keyEquivalent: "")
        deleteItem.representedObject = annotationId
        deleteItem.target = self
        deleteItem.setAccessibilityLabel("Delete this annotation")
        menu.addItem(deleteItem)

        guard let contentView = self.window?.contentView else { return }
        NSMenu.popUpContextMenu(menu, with: event, for: contentView)
    }

    @objc private func deleteAnnotation(_ sender: NSMenuItem) {
        guard let annotationId = sender.representedObject as? UUID else { return }
        annotationService.removeAnnotation(id: annotationId)
        needsDisplay = true
    }
}

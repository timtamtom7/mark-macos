import AppKit

class OnboardingViewController: NSViewController {
    private var currentPageIndex = 0

    private let pageData: [(title: String, description: String, icon: String)] = [
        (
            "Welcome to Mark",
            "Mark lets you annotate over any app on your screen. Perfect for presentations, tutorials, and demos.",
            "pencil.tip.crop.circle"
        ),
        (
            "Annotation Tools",
            "Draw arrows, rectangles, freehand strokes, highlights, and text. Pick any color and stroke width.",
            "pencil.tip"
        ),
        (
            "Capture & Export",
            "Capture screenshots, export annotated images as PNG or PDF, or copy directly to clipboard.",
            "camera.fill"
        ),
        (
            "Global Hotkeys",
            "Trigger Mark from anywhere with customizable keyboard shortcuts. Access tools from the menu bar.",
            "keyboard"
        ),
        (
            "Screen Recording Permission",
            "Mark needs Screen Recording permission to draw over other apps. We'll guide you through enabling it.",
            "lock.shield"
        )
    ]

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    private func setupUI() {
        // Header
        let headerLabel = NSTextField(labelWithString: "Welcome to Mark")
        headerLabel.font = NSFont.systemFont(ofSize: 24, weight: .bold)
        headerLabel.textColor = .labelColor
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerLabel)

        // Page indicator dots
        let dotsStack = NSStackView()
        dotsStack.orientation = .horizontal
        dotsStack.spacing = 8
        dotsStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(dotsStack)

        for i in 0..<pageData.count {
            let dot = NSView()
            dot.wantsLayer = true
            dot.layer?.cornerRadius = 4
            dot.layer?.backgroundColor = i == 0 ? Design.Color.primary.cgColor : NSColor.systemGray.cgColor
            dot.widthAnchor.constraint(equalToConstant: 8).isActive = true
            dot.heightAnchor.constraint(equalToConstant: 8).isActive = true
            dot.identifier = NSUserInterfaceItemIdentifier("dot_\(i)")
            dotsStack.addArrangedSubview(dot)
        }

        // Content area
        let contentView = NSView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.identifier = NSUserInterfaceItemIdentifier("contentView")
        view.addSubview(contentView)

        // Navigation buttons
        let prevButton = NSButton(title: "← Back", target: self, action: #selector(prevPage))
        prevButton.bezelStyle = .rounded
        prevButton.translatesAutoresizingMaskIntoConstraints = false
        prevButton.isHidden = true
        prevButton.identifier = NSUserInterfaceItemIdentifier("prevButton")
        view.addSubview(prevButton)

        let nextButton = NSButton(title: "Next →", target: self, action: #selector(nextPage))
        nextButton.bezelStyle = .rounded
        nextButton.keyEquivalent = "\r"
        nextButton.translatesAutoresizingMaskIntoConstraints = false
        nextButton.identifier = NSUserInterfaceItemIdentifier("nextButton")
        view.addSubview(nextButton)

        let skipButton = NSButton(title: "Skip", target: self, action: #selector(skipOnboarding))
        skipButton.bezelStyle = .rounded
        skipButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(skipButton)

        NSLayoutConstraint.activate([
            headerLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 40),
            headerLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            dotsStack.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 24),
            dotsStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            contentView.topAnchor.constraint(equalTo: dotsStack.bottomAnchor, constant: 32),
            contentView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            contentView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            contentView.bottomAnchor.constraint(equalTo: prevButton.topAnchor, constant: -32),

            prevButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -40),
            prevButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),

            nextButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -40),
            nextButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),

            skipButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -40),
            skipButton.trailingAnchor.constraint(equalTo: nextButton.leadingAnchor, constant: -16)
        ])

        showPage(index: 0)
    }

    private func showPage(index: Int) {
        currentPageIndex = max(0, min(index, pageData.count - 1))
        let data = pageData[currentPageIndex]

        guard let contentView = view.subviews.first(where: { $0.identifier == NSUserInterfaceItemIdentifier("contentView") }) else { return }

        // Remove old content
        contentView.subviews.forEach { $0.removeFromSuperview() }

        // Icon
        let iconView = NSImageView()
        if let image = NSImage(systemSymbolName: data.icon, accessibilityDescription: data.title) {
            iconView.image = image
            iconView.contentTintColor = Design.Color.primary
            iconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 64, weight: .light)
        }
        iconView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(iconView)

        // Title
        let titleLabel = NSTextField(labelWithString: data.title)
        titleLabel.font = Design.Typography.title
        titleLabel.textColor = .labelColor
        titleLabel.alignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)

        // Description
        let descLabel = NSTextField(wrappingLabelWithString: data.description)
        descLabel.font = Design.Typography.body
        descLabel.textColor = .secondaryLabelColor
        descLabel.alignment = .center
        descLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(descLabel)

        NSLayoutConstraint.activate([
            iconView.topAnchor.constraint(equalTo: contentView.topAnchor),
            iconView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 80),
            iconView.heightAnchor.constraint(equalToConstant: 80),

            titleLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 24),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),

            descLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            descLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            descLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            descLabel.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor)
        ])

        // Update dots
        if let dotsStack = view.subviews.compactMap({ $0 as? NSStackView }).first {
            for (i, dot) in dotsStack.arrangedSubviews.enumerated() {
                dot.layer?.backgroundColor = i == currentPageIndex
                    ? Design.Color.primary.cgColor
                    : NSColor.systemGray.cgColor
            }
        }

        // Update navigation buttons
        if let prevButton = view.subviews.first(where: { $0.identifier == NSUserInterfaceItemIdentifier("prevButton") }) as? NSButton {
            prevButton.isHidden = currentPageIndex == 0
        }
        if let nextButton = view.subviews.first(where: { $0.identifier == NSUserInterfaceItemIdentifier("nextButton") }) as? NSButton {
            nextButton.title = currentPageIndex == pageData.count - 1 ? "Get Started →" : "Next →"
        }
    }

    @objc private func prevPage() {
        showPage(index: currentPageIndex - 1)
    }

    @objc private func nextPage() {
        if currentPageIndex == pageData.count - 1 {
            completeOnboarding()
        } else {
            showPage(index: currentPageIndex + 1)
        }
    }

    @objc private func skipOnboarding() {
        completeOnboarding()
    }

    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        view.window?.close()

        // Request screen recording permission if needed
        requestScreenRecordingPermission()
    }

    private func requestScreenRecordingPermission() {
        // Trigger a test capture to prompt the permission dialog
        let testRect = CGRect(x: 0, y: 0, width: 1, height: 1)
        _ = CGWindowListCreateImage(testRect, .optionOnScreenOnly, kCGNullWindowID, .bestResolution)
    }
}

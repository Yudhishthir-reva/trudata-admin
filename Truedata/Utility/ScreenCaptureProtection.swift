//
//  ScreenCaptureProtection.swift
//  Truedata
//
//  Android FLAG_SECURE equivalent:
//  1) Host UI inside UITextField's secure canvas → screenshots blank
//  2) Extra black overlay while UIScreen.isCaptured
//
//  Canvas is reparented out of the UITextField so touches work. Keeping content
//  as a subview of a field with isUserInteractionEnabled = false blocks all taps.
//

import SwiftUI
import UIKit
import Combine

// MARK: - Secure canvas (screenshot blank)

private extension UITextField {
    /// Internal view that iOS redacts in screenshots when `isSecureTextEntry` is on.
    var secureCanvas: UIView? {
        subviews.first {
            let name = String(describing: type(of: $0))
            return name.contains("TextLayoutCanvasView") || name.contains("UITextLayoutCanvasView")
        } ?? subviews.first
    }
}

/// Full-screen container that hosts children in the secure canvas (touches work).
private final class SecureCanvasView: UIView {
    /// Kept alive so the canvas stays in secure mode after reparenting.
    private let secureField = UITextField()
    private weak var canvas: UIView?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = true
        clipsToBounds = true

        secureField.isSecureTextEntry = true
        secureField.isUserInteractionEnabled = false

        guard let secureCanvas = secureField.secureCanvas else { return }
        secureCanvas.subviews.forEach { $0.removeFromSuperview() }
        secureCanvas.isUserInteractionEnabled = true
        canvas = secureCanvas

        // Reparent canvas onto us — not under the non-interactive field.
        addSubview(secureCanvas)
        secureCanvas.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            secureCanvas.topAnchor.constraint(equalTo: topAnchor),
            secureCanvas.bottomAnchor.constraint(equalTo: bottomAnchor),
            secureCanvas.leadingAnchor.constraint(equalTo: leadingAnchor),
            secureCanvas.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func addSubview(_ view: UIView) {
        if let canvas, view !== canvas {
            canvas.addSubview(view)
        } else {
            super.addSubview(view)
        }
    }

    override func insertSubview(_ view: UIView, at index: Int) {
        if let canvas, view !== canvas {
            canvas.addSubview(view)
        } else {
            super.insertSubview(view, at: index)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        canvas?.isUserInteractionEnabled = true
        // Re-assert secure mode after layout (some iOS versions clear it).
        if !secureField.isSecureTextEntry {
            secureField.isSecureTextEntry = true
        }
    }
}

private final class SecureHostingController<Content: View>: UIViewController {
    private let canvasHost = SecureCanvasView()
    private let hostingController: UIHostingController<Content>

    init(content: Content) {
        hostingController = UIHostingController(rootView: content)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func loadView() {
        view = canvasHost
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        hostingController.view.backgroundColor = .clear
        hostingController.view.isUserInteractionEnabled = true
        addChild(hostingController)
        canvasHost.addSubview(hostingController.view)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: canvasHost.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: canvasHost.bottomAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: canvasHost.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: canvasHost.trailingAnchor)
        ])
        hostingController.didMove(toParent: self)
    }

    func update(content: Content) {
        hostingController.rootView = content
    }
}

private struct ScreenshotProtectedRepresentable<Content: View>: UIViewControllerRepresentable {
    let content: Content

    func makeUIViewController(context: Context) -> SecureHostingController<Content> {
        SecureHostingController(content: content)
    }

    func updateUIViewController(_ uiViewController: SecureHostingController<Content>, context: Context) {
        uiViewController.update(content: content)
    }
}

// MARK: - Recording overlay

final class ScreenCaptureProtectionController: ObservableObject {
    static let shared = ScreenCaptureProtectionController()

    @Published private(set) var isCaptured = UIScreen.main.isCaptured

    private var cancellables = Set<AnyCancellable>()

    private init() {
        NotificationCenter.default.publisher(for: UIScreen.capturedDidChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.isCaptured = UIScreen.main.isCaptured
            }
            .store(in: &cancellables)
    }
}

private struct ScreenRecordingCover: ViewModifier {
    @ObservedObject private var controller = ScreenCaptureProtectionController.shared

    func body(content: Content) -> some View {
        content.overlay {
            if controller.isCaptured {
                ZStack {
                    Color.black.ignoresSafeArea()
                    VStack(spacing: 12) {
                        Image(systemName: "eye.slash.fill")
                            .font(.system(size: 36, weight: .semibold))
                        Text("Screen recording is not allowed")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                }
                .allowsHitTesting(true)
            }
        }
    }
}

// MARK: - Public API

extension View {
    /// Blanks screenshots / recordings (secure canvas) + covers UI while recording.
    func preventScreenshots() -> some View {
        ScreenshotProtectedRepresentable(content: self)
            .ignoresSafeArea()
            .modifier(ScreenRecordingCover())
    }
}

extension UIWindow {
    /// No-op — window layer reparenting shrinks UI into a corner. Use `View.preventScreenshots()`.
    func enableScreenCaptureProtection() {}
}

enum ScreenCaptureProtection {
    static func enableForConnectedWindows() {}
}

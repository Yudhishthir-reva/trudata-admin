//
//  TruDataaLogo.swift
//  Truedata
//

import SwiftUI

struct TruDataaLogo: View {
    var size: CGFloat = 168

    var body: some View {
        Canvas { context, canvasSize in
            let scale = min(canvasSize.width, canvasSize.height) / 288
            let transform = CGAffineTransform(scaleX: scale, y: scale)
            context.fill(Self.whitePath.applying(transform), with: .color(.white))
            context.fill(Self.cyanPath.applying(transform), with: .color(AppTheme.logoCyan))
        }
        .frame(width: size, height: size)
        .accessibilityLabel("TruDataa")
    }

    private static var whitePath: Path {
        var path = Path()
        path.move(to: CGPoint(x: 107.546, y: 159.894))
        path.addLine(to: CGPoint(x: 107.546, y: 132.959))
        path.addLine(to: CGPoint(x: 116.001, y: 132.959))
        path.addCurve(
            to: CGPoint(x: 123.571, y: 124.38),
            control1: CGPoint(x: 118.184, y: 129.86),
            control2: CGPoint(x: 120.721, y: 126.984)
        )
        path.addCurve(
            to: CGPoint(x: 141.163, y: 113.464),
            control1: CGPoint(x: 128.8, y: 119.582),
            control2: CGPoint(x: 134.72, y: 115.909)
        )
        path.addCurve(
            to: CGPoint(x: 143.377, y: 112.681),
            control1: CGPoint(x: 141.894, y: 113.188),
            control2: CGPoint(x: 142.632, y: 112.927)
        )
        path.addLine(to: CGPoint(x: 107.546, y: 112.681))
        path.addLine(to: CGPoint(x: 107.546, y: 77))
        path.addLine(to: CGPoint(x: 85.451, y: 77))
        path.addLine(to: CGPoint(x: 85.451, y: 112.679))
        path.addLine(to: CGPoint(x: 56, y: 112.679))
        path.addLine(to: CGPoint(x: 56, y: 132.959))
        path.addLine(to: CGPoint(x: 85.451, y: 132.959))
        path.addLine(to: CGPoint(x: 85.451, y: 159.806))
        path.addCurve(
            to: CGPoint(x: 161.923, y: 230),
            control1: CGPoint(x: 85.451, y: 198.572),
            control2: CGPoint(x: 119.689, y: 230)
        )
        path.addLine(to: CGPoint(x: 161.923, y: 209.724))
        path.addCurve(
            to: CGPoint(x: 107.546, y: 159.894),
            control1: CGPoint(x: 131.945, y: 209.724),
            control2: CGPoint(x: 107.546, y: 187.413)
        )
        path.closeSubpath()
        return path
    }

    private static var cyanPath: Path {
        var path = Path()
        path.move(to: CGPoint(x: 186.815, y: 77))
        path.addLine(to: CGPoint(x: 186.815, y: 160.51))
        path.addCurve(
            to: CGPoint(x: 179.523, y: 175.995),
            control1: CGPoint(x: 186.684, y: 166.471),
            control2: CGPoint(x: 184.232, y: 171.683)
        )
        path.addCurve(
            to: CGPoint(x: 161.922, y: 182.674),
            control1: CGPoint(x: 174.684, y: 180.424),
            control2: CGPoint(x: 168.765, y: 182.674)
        )
        path.addCurve(
            to: CGPoint(x: 144.321, y: 175.995),
            control1: CGPoint(x: 155.079, y: 182.674),
            control2: CGPoint(x: 149.166, y: 180.424)
        )
        path.addCurve(
            to: CGPoint(x: 137.03, y: 159.874),
            control1: CGPoint(x: 139.476, y: 171.566),
            control2: CGPoint(x: 137.03, y: 166.141)
        )
        path.addCurve(
            to: CGPoint(x: 144.321, y: 143.752),
            control1: CGPoint(x: 137.03, y: 153.607),
            control2: CGPoint(x: 139.481, y: 148.188)
        )
        path.addCurve(
            to: CGPoint(x: 163.274, y: 136.991),
            control1: CGPoint(x: 149.161, y: 139.316),
            control2: CGPoint(x: 155.562, y: 136.698)
        )
        path.addCurve(
            to: CGPoint(x: 175.808, y: 139.932),
            control1: CGPoint(x: 167.288, y: 137.144),
            control2: CGPoint(x: 171.309, y: 137.874)
        )
        path.addCurve(
            to: CGPoint(x: 179.152, y: 141.724),
            control1: CGPoint(x: 176.959, y: 140.469),
            control2: CGPoint(x: 178.076, y: 141.068)
        )
        path.addLine(to: CGPoint(x: 179.152, y: 119.8))
        path.addCurve(
            to: CGPoint(x: 162.06, y: 116.757),
            control1: CGPoint(x: 173.711, y: 117.821),
            control2: CGPoint(x: 167.914, y: 116.789)
        )
        path.addLine(to: CGPoint(x: 161.921, y: 116.757))
        path.addCurve(
            to: CGPoint(x: 128.611, y: 129.366),
            control1: CGPoint(x: 148.958, y: 116.757),
            control2: CGPoint(x: 137.747, y: 121)
        )
        path.addCurve(
            to: CGPoint(x: 114.846, y: 159.879),
            control1: CGPoint(x: 119.475, y: 137.732),
            control2: CGPoint(x: 114.846, y: 148.006)
        )
        path.addCurve(
            to: CGPoint(x: 128.613, y: 190.39),
            control1: CGPoint(x: 114.846, y: 171.752),
            control2: CGPoint(x: 119.477, y: 182.022)
        )
        path.addCurve(
            to: CGPoint(x: 161.923, y: 203),
            control1: CGPoint(x: 137.749, y: 198.759),
            control2: CGPoint(x: 148.949, y: 203)
        )
        path.addCurve(
            to: CGPoint(x: 195.232, y: 190.39),
            control1: CGPoint(x: 174.897, y: 203),
            control2: CGPoint(x: 186.099, y: 198.752)
        )
        path.addCurve(
            to: CGPoint(x: 209, y: 159.879),
            control1: CGPoint(x: 204.365, y: 182.029),
            control2: CGPoint(x: 209, y: 171.763)
        )
        path.addLine(to: CGPoint(x: 209, y: 77))
        path.addLine(to: CGPoint(x: 186.815, y: 77))
        path.closeSubpath()
        return path
    }
}

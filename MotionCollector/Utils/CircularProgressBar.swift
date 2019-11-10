// Copyright © 2019 Brad Howes. All rights reserved.

import UIKit

/**
 Bare minimum CoreGraphics representation of a circular progress bar. The start/end part of the cirle is "north".
 Progress is represented between 0.0 and 1.0, and changes to it are through the `setProgress` method.
 */
public final class CircularProgressBar: UIView {

    /// The color of the progress bar
    public var progressTintColor: UIColor? = .systemBlue

    /// The color of the 'channel' or untinted area, or the remaining part of the circle that is not covered by the
    /// `progressTintColor`
    public var progressChannelColor: UIColor? = UIColor.lightGray.withAlphaComponent(0.5)

    /// The width of the line used to draw the circle
    public var progressLineWidth: CGFloat = 2.0

    /// The layer that shows the progress amount
    private let foregroundLayer = CAShapeLayer()

    /// The layer that shows the remaining amount
    private let backgroundLayer = CAShapeLayer()

    /// The radius of the paths based on the available height/width of the view's frame
    private lazy var radius: CGFloat = (self.bounds.height - progressLineWidth) / 2.0
    private lazy var ctr: CGPoint = CGPoint(x: self.bounds.maxX - radius, y: self.bounds.minY + radius)
    private lazy var square: CGRect = CGRect(x: ctr.x - radius, y: ctr.y - radius, width: radius * 2,
                                             height: radius * 2)

    /// Obtain a new UIBezierPath which will render as a circle.
    private var path: CGPath { UIBezierPath(roundedRect: square, cornerRadius: radius).cgPath }

    /**
     Set up the view after being restored from an IB definition.
     */
    override public func awakeFromNib() {
        super.awakeFromNib()
        setupView()
    }

    /**
     Set the new progress value for the indicator.

     - parameter progress: the new value between 0.0 and 1.0
     - parameter animated: if true, animate the drawing state changes
     */
    public func setProgress(_ progress: Float, animated: Bool) {
        wedge(progress)
    }

    override public func layoutSublayers(of layer: CALayer) {
        setupView()
    }
}

private extension CircularProgressBar {

    func wedge(_ progress: Float) {
        let path = UIBezierPath()
        path.move(to: ctr)
        path.addArc(withCenter: ctr, radius: radius, startAngle: 0.0, endAngle: CGFloat(progress * 2.0 * .pi),
                    clockwise: true)
        path.addLine(to: ctr)
        path.close()
        foregroundLayer.path = path.cgPath
    }

    func makeBackgroundLayer() {
        backgroundLayer.path = path
        backgroundLayer.lineWidth = progressLineWidth
        backgroundLayer.strokeColor = progressChannelColor?.cgColor
        backgroundLayer.strokeEnd = 1.0
        backgroundLayer.fillColor = nil
        layer.addSublayer(backgroundLayer)
    }

    func makeForegroundLayer() {
        foregroundLayer.path = nil
        foregroundLayer.lineWidth = 1.0
        foregroundLayer.strokeColor = progressTintColor?.cgColor
        foregroundLayer.strokeEnd = 0.0
        foregroundLayer.fillColor = foregroundLayer.strokeColor
        self.layer.addSublayer(foregroundLayer)
    }

    func setupView() {
        if self.layer.sublayers?.isEmpty ?? true {
            makeBackgroundLayer()
            makeForegroundLayer()
        }
    }
}

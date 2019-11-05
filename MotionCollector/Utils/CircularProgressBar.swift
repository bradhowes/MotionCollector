// Copyright © 2019 Brad Howes. All rights reserved.

import UIKit

/**
 Bare minimum CoreGraphics representation of a circular progress bar. The start/end part of the cirle is "north".
 Progress is represented between 0.0 and 1.0, and changes to it are through the `setProgress` method.
 */
public final class CircularProgressBar: UIView {

    /// The color of the progress bar
    public var progressTintColor: UIColor? = .orange

    /// The color of the 'channel' or untinted area, or the remaining part of the circle that is not covered by the
    /// `progressTintColor`
    public var progressChannelColor: UIColor? = .lightGray

    /// The width of the line used to draw the circle
    public var progressLineWidth: CGFloat = 8.0

    /// The layer that shows the progress amount
    private let foregroundLayer = CAShapeLayer()

    /// The layer that shows the remaining amount
    private let backgroundLayer = CAShapeLayer()

    /// The radius of the paths based on the available height/width of the view's frame
    private var radius: CGFloat { return (self.bounds.width - progressLineWidth) / 2.0 }

    /// Obtain a new UIBezierPath which will render as a circle.
    private var path: CGPath { return UIBezierPath(roundedRect: self.bounds, cornerRadius: radius).cgPath }

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
        if animated {
            let anim = CABasicAnimation(keyPath: "strokeEnd")
            anim.fromValue = NSNumber(value: Float(foregroundLayer.strokeEnd))
            anim.toValue = NSNumber(value: progress)
            anim.duration = 0.20
            anim.isRemovedOnCompletion = true
            foregroundLayer.add(anim, forKey: "progress")
        }

        foregroundLayer.strokeEnd = CGFloat(progress)
    }

    private func makeBackgroundLayer(){
        backgroundLayer.path = path
        backgroundLayer.lineWidth = progressLineWidth - 2.0
        backgroundLayer.strokeColor = progressChannelColor?.cgColor
        backgroundLayer.strokeEnd = 1.0
        backgroundLayer.fillColor = nil
        layer.addSublayer(backgroundLayer)
    }

    private func makeForegroundLayer(){
        foregroundLayer.path = path
        foregroundLayer.lineWidth = progressLineWidth
        foregroundLayer.strokeColor = progressTintColor?.cgColor
        foregroundLayer.strokeEnd = 0.0
        foregroundLayer.fillColor = nil
        self.layer.addSublayer(foregroundLayer)
    }

    private func setupView() {
        if self.layer.sublayers?.isEmpty ?? true {
            makeBackgroundLayer()
            makeForegroundLayer()
        }
    }

    override public func layoutSublayers(of layer: CALayer) {
        setupView()
    }
}

// Copyright © 2019 Brad Howes. All rights reserved.

import UIKit

/**
 Bare minimum CoreGraphics representation of a circular progress bar. The start/end part of the cirle is "north".
 Progress is represented between 0.0 and 1.0, and changes to it are through the `setProgress` method.
 */
public final class CircularProgressBar: UIView {

    /// The color of the progress bar
    public var progressTintColor: UIColor? = .cyan

    /// The color of the 'channel' or untinted area, or the remaining part of the circle that is not covered by the
    /// `progressTintColor`
    public var progressChannelColor: UIColor? = .darkGray

    /// The width of the line used to draw the circle
    public var progressLineWidth: CGFloat = 3.0

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

    private let foregroundLayer = CAShapeLayer()
    private let backgroundLayer = CAShapeLayer()

    private var radius: CGFloat { return (min(self.frame.width, self.frame.height) - progressLineWidth) / 2.0 }
    private var path: CGPath { return UIBezierPath(roundedRect: self.bounds, cornerRadius: radius).cgPath }

    private func makeBackgroundLayer(){
        backgroundLayer.path = path
        backgroundLayer.lineWidth = progressLineWidth
        backgroundLayer.strokeColor = progressChannelColor?.cgColor
        backgroundLayer.strokeEnd = 1.0
        layer.addSublayer(backgroundLayer)
    }

    private func makeForegroundLayer(){
        foregroundLayer.path = path
        foregroundLayer.lineWidth = progressLineWidth
        foregroundLayer.strokeColor = progressTintColor?.cgColor
        foregroundLayer.strokeEnd = 0.0
        self.layer.addSublayer(foregroundLayer)
    }

    private func setupView() {
        self.layer.sublayers = nil
        makeBackgroundLayer()
        makeForegroundLayer()
    }

    private var layoutDone = false

    override public func layoutSublayers(of layer: CALayer) {
        if !layoutDone {
            setupView()
            layoutDone = true
        }
    }
}

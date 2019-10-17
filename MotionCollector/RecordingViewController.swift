//
//  ViewController.swift
//  MotionCategorizer
//
//  Created by Brad Howes on 10/8/19.
//  Copyright © 2019 Brad Howes. All rights reserved.
//

import UIKit
import CoreMotion

public let RecordingStateChangeNotification = TypedNotification<Bool>(name: "RecordingStateChange")

/**
 The first, primary view controller that shows the start/stop button and the motion type tap buttons.
 */
class RecordingViewController: UIViewController, SegueHandler {

    /**
     Enumeration of the segues that can come from this controller.
     */
    enum SegueIdentifier: String {
        case optionsView = "OptionsView"
    }

    @IBOutlet weak var elapsed: UILabel!
    @IBOutlet weak var startStop: UIButton!
    @IBOutlet weak var walking: UIButton!
    @IBOutlet weak var turning: UIButton!
    @IBOutlet weak var status: UILabel!
    @IBOutlet weak var options: UIButton!
    
    let elapsedFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.zeroFormattingBehavior = .pad
        return formatter
    }()

    private let coreMotionController = CoreMotionController()
    private var startTime: Date?
    private var timer: Timer?
    private var recording: RecordingInfo?
    private var kvo: NSKeyValueObservation?

    /**
     Properly set up the options view.

     - parameter segue: the seque being executed
     - parameter sender: the source of the seque event
     */
    public override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch segueIdentifier(for: segue) {
        case .optionsView:
            let vc = segue.destination as! OptionsViewController
            vc.state = coreMotionController
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setElapsed(0)
        startStop.isEnabled = false

        // Allow new recordings once there is a managed context available.
        kvo = tabBarItem.observe(\.isEnabled) { _, _ in self.startStop.isEnabled = self.tabBarItem.isEnabled }

        showRecordCount(0)
        walking.isEnabled = false
        turning.isEnabled = false

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(beginWalking(_:)))
        tapGesture.numberOfTapsRequired = 1
        tapGesture.numberOfTouchesRequired = 1

        NotificationCenter.default.addObserver(forName: stopRecordingRequest, object: nil, queue: nil) { _ in
            self.stop()
        }
    }

    @IBAction func startStop(_ sender: Any) {
        if timer != nil {
            stop()
        }
        else {
            start()
        }
    }

    @IBAction func beginWalking(_ sender: Any) {
        coreMotionController.setWalking()
    }

    @IBAction func beginTurning(_ sender: Any) {
        coreMotionController.setTurning()
    }

    private func setElapsed(_ duration: TimeInterval) {
        self.elapsed.text = self.elapsedFormatter.string(from: duration)
    }

    private func start() {
        precondition(timer == nil)
        setElapsed(0)
        showRecordCount(0)
        recording = RecordingInfo.create()
        startTime = Date()
        startStop.setTitle("Stop", for: .normal)
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in self.updateView() }
        coreMotionController.start()
        RecordingStateChangeNotification.post(value: true)
        walking.isEnabled = true
        turning.isEnabled = true
    }

    private func stop() {
        guard let timer = timer else { return }
        RecordingStateChangeNotification.post(value: false)

        timer.invalidate()
        self.timer = nil

        coreMotionController.stop() { data in
            self.recording?.finishRecording(rows: data)
            self.recording = nil
        }

        startStop.setTitle("Start", for: .normal)
        walking.isEnabled = false
        turning.isEnabled = false
    }

    private func updateView() {
        let duration = Date().timeIntervalSince(startTime!)
        setElapsed(duration)
        coreMotionController.update() { count in DispatchQueue.main.async { self.showRecordCount(count) } }
    }

    private func showRecordCount(_ count: Int) {
        let formatString : String = NSLocalizedString("records count",
                                                      comment: "records count string format in Localized.stringsdict")
        status.text = String.localizedStringWithFormat(formatString, count)
        recording?.update(count: count)
    }
}


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

extension CMLogItem {
    public var when: TimeInterval { Date(timeIntervalSinceReferenceDate: self.timestamp).timeIntervalSince1970 }
}

class ViewController: UIViewController {
    @IBOutlet weak var elapsed: UILabel!
    @IBOutlet weak var startStop: UIButton!
    @IBOutlet weak var walking: UIButton!
    @IBOutlet weak var turning: UIButton!
    @IBOutlet weak var status: UILabel!

    let elapsedFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.zeroFormattingBehavior = .pad
        return formatter
    }()

    let coreMotionController = CoreMotionController()

    var startTime: Date?
    var timer: Timer?
    var recording: RecordingInfo?

    override func viewDidLoad() {
        super.viewDidLoad()
        setElapsed(0)

        status.text = ""

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(beginWalking(_:)))
        tapGesture.numberOfTapsRequired = 1
        tapGesture.numberOfTouchesRequired = 1

        NotificationCenter.default.addObserver(forName: stopRecordingRequest, object: nil, queue: nil) { _ in
            self.stop()
        }
    }

    @IBAction func startStop(_ sender: Any) {
        if self.timer != nil {
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
        self.setElapsed(0)
        recording = RecordingInfo.insert()
        startTime = Date()
        startStop.setTitle("Stop", for: .normal)
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in self.updateView() }
        status.text = ""
        coreMotionController.start()
        RecordingStateChangeNotification.post(value: true)
    }

    private func stop() {
        guard let timer = self.timer else { return }
        RecordingStateChangeNotification.post(value: false)
        timer.invalidate()
        self.timer = nil

        coreMotionController.stop() { data in
            self.recording?.finishRecording(rows: data)
            self.recording = nil
        }

        startStop.setTitle("Start", for: .normal)
    }

    private func updateView() {
        let duration = Date().timeIntervalSince(startTime!)
        setElapsed(duration)
        coreMotionController.update() { count in
            DispatchQueue.main.async {
                self.status.text = "\(count) records"
                self.recording?.update(count: count)
            }
        }
    }
}


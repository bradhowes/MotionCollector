// Copyright © 2019, 2024 Brad Howes. All rights reserved.

import os
import UIKit
import CoreMotion

public let RecordingStateChangeNotification = TypedNotification<Bool>(name: "RecordingStateChange")

/**
 The first, primary view controller that shows the start/stop button and the motion type tap buttons.
 */
final class HomeViewController: UIViewController {
  private lazy var log = Logging.logger("main")
  @IBOutlet weak var elapsed: UILabel!
  @IBOutlet weak var startStop: UIButton!
  @IBOutlet weak var turning: UIButton!
  @IBOutlet weak var status: UILabel!
  @IBOutlet weak var options: UIButton!

  private let cmm = CMMotionManager()
  private lazy var settings = Settings(cmm)
  private lazy var coreMotionController = CoreMotionController(settings, sensorManager: cmm)

  private var startTime: Date?
  private var timer: Timer?
  private var recording: RecordingInfo?
  private var kvo: NSKeyValueObservation?
  private var obs: NSObjectProtocol?

  /**
   Set view to known state.
   */
  override func viewDidLoad() {
    super.viewDidLoad()

    setElapsed(0)
    startStop.isEnabled = false

    // Allow new recordings once there is a managed context available.
    kvo = tabBarController?.tabBar.observe(\.isUserInteractionEnabled) { _, _ in
      self.startStop.isEnabled = self.tabBarController?.tabBar.isUserInteractionEnabled ?? false
      self.kvo = nil
    }

    showRecordCount(0)
    turning.isEnabled = false
    turning.isHidden = true

    obs = NotificationCenter.default.addObserver(forName: stopRecordingRequest, object: nil, queue: nil) { _ in
      self.stop()
    }
  }

  /**
   Toggle recording state.

   - parameter sender: ignored
   */
  @IBAction func startStop(_ sender: Any) {
    os_log(.info, log: log, "startStop")
    if timer != nil {
      stop()
    }
    else {
      start()
    }
  }

  /**
   Set label to indicate we are walking. This is triggered when the user stops pressing on the `turn` button.

   - parameter sender: ignored
   */
  @IBAction func beginWalking(_ sender: Any) {
    os_log(.info, log: log, "beginWalking")
    coreMotionController.setWalking()
  }

  /**
   Set label to indicate we are walking. This is triggered when the user starts pressing on the `turn` button.

   - parameter sender: ignored
   */
  @IBAction func beginTurning(_ sender: Any) {
    os_log(.info, log: log, "beginTurning")
    coreMotionController.setTurning()
  }
}

// MARK: - Option View Presentation

extension HomeViewController: UIAdaptivePresentationControllerDelegate, SegueHandler {

  /**
   Enumeration of the segues that can come from this controller.
   */
  enum SegueIdentifier: String {
    case optionsView = "OptionsView"
  }

  /**
   Properly set up the options view.

   - parameter segue: the seque being executed
   - parameter sender: the source of the seque event
   */
  public override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    switch segueIdentifier(for: segue) {
    case .optionsView:
      guard let controller = segue.destination as? OptionsViewController else { fatalError() }
      controller.state = settings
      controller.presentationController?.delegate = self
    }
  }

  /**
   Event handler when seque is unwound.

   - parameter unwindSegue: the segue being unwound
   */
  @IBAction func unwindToHere(_ unwindSegue: UIStoryboardSegue) {
    coreMotionController.updateCollector()
  }
}

// MARK: - Private methods

private extension HomeViewController {

  func setElapsed(_ duration: TimeInterval) {
    self.elapsed.text = Formatters.formatted(duration: duration)
  }

  func start() {
    precondition(timer == nil)
    setElapsed(0)
    showRecordCount(0)
    recording = RecordingInfo.create()
    startTime = Date()
    startStop.setTitle("Stop", for: .normal)
    timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in self.updateView() }
    coreMotionController.start()
    RecordingStateChangeNotification.post(value: true)
    UIView.animate(withDuration: 0.2) {
      self.turning.alpha = 1.0
      self.turning.isHidden = false
      self.turning.isEnabled = true
    }
  }

  func stop() {
    guard let timer = timer else { return }
    RecordingStateChangeNotification.post(value: false)

    timer.invalidate()
    self.timer = nil

    coreMotionController.stop { data in
      self.recording?.finishRecording(rows: data)
      self.recording = nil
    }

    startStop.setTitle("Start", for: .normal)

    UIView.animate(withDuration: 0.2) {
      self.turning.isEnabled = false
      self.turning.isHidden = true
      self.turning.alpha = 0.0
    }
  }

  func updateView() {
    let duration = Date().timeIntervalSince(startTime!)
    setElapsed(duration)
    coreMotionController.update { count in DispatchQueue.main.async { self.showRecordCount(count) } }
  }

  func showRecordCount(_ count: Int) {
    status.text = Formatters.formatted(recordCount: count)
    recording?.update(count: count)
  }
}

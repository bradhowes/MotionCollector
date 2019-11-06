// OptionsViewController.swift
// Copyright © 2019 Brad Howes. All rights reserved.

import UIKit

/**
 A source and destination of state for the OptionsViewController.
 */
protocol OptionsViewState {
    var hasAccelerometer: Bool {get}
    var hasDeviceMotion: Bool {get}
    var hasGyro: Bool {get}
    var hasMagnetometer: Bool {get}

    var samplesPerSecond: Int {get set}
    var useAccelerometer: Bool {get set}
    var useDeviceMotion: Bool {get set}
    var useGyro: Bool {get set}
    var useMagnetometer: Bool {get set}
    var uploadToCloud: Bool {get set}
}

/**
 Simple modal view that shows the configurable settings for the app. The values are loaded before appearing, and they
 are applied after it disappears.
 */
class OptionsViewController: UIViewController {
    @IBOutlet weak var samplesPerSecond: UITextField!
    @IBOutlet weak var done: UIButton!
    @IBOutlet weak var accelerometerLabel: UILabel!
    @IBOutlet weak var accelerometer: UISwitch!
    @IBOutlet weak var deviceMotionLabel: UILabel!
    @IBOutlet weak var deviceMotion: UISwitch!
    @IBOutlet weak var gyroLabel: UILabel!
    @IBOutlet weak var gyro: UISwitch!
    @IBOutlet weak var magnetometerLabel: UILabel!
    @IBOutlet weak var magnetometer: UISwitch!
    @IBOutlet weak var uploadToCloudLabel: UILabel!
    @IBOutlet weak var uploadToCloud: UISwitch!

    var state: OptionsViewState!

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard(_:))))
    }

    override func viewWillAppear(_ animated: Bool) {
        samplesPerSecond.text = "\(state.samplesPerSecond)"

        accelerometerLabel.isEnabled = state.hasAccelerometer
        accelerometer.isEnabled = state.hasAccelerometer
        accelerometer.isOn = state.useAccelerometer

        deviceMotionLabel.isEnabled = state.hasDeviceMotion
        deviceMotion.isEnabled = state.hasDeviceMotion
        deviceMotion.isOn = state.useDeviceMotion

        gyroLabel.isEnabled = state.hasGyro
        gyro.isEnabled = state.hasGyro
        gyro.isOn = state.useGyro

        magnetometerLabel.isEnabled = state.hasMagnetometer
        magnetometer.isEnabled = state.hasMagnetometer
        magnetometer.isOn = state.useMagnetometer

        uploadToCloudLabel.isEnabled = FileManager.default.hasCloudDirectory
        uploadToCloud.isEnabled = FileManager.default.hasCloudDirectory
        uploadToCloud.isOn = state.uploadToCloud

        super.viewWillAppear(animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if let sps = validSamplesPerSecond { state.samplesPerSecond = sps }
        state.useAccelerometer = accelerometer.isOn
        state.useDeviceMotion = deviceMotion.isOn
        state.useGyro = gyro.isOn
        state.useMagnetometer = magnetometer.isOn
        state.uploadToCloud = uploadToCloud.isOn
    }

    /**
     If the samplesPerSecond field is the first responder, then resign it and validate that the contents of the
     text field is an integer value we can use.

     - parameter sender: gesture recognizer
     */
    @IBAction func dismissKeyboard(_ sender: Any) {
        if samplesPerSecond.isFirstResponder {
            let sps = validSamplesPerSecond ?? state.samplesPerSecond
            samplesPerSecond.text = "\(sps)"
            samplesPerSecond.resignFirstResponder()
        }
    }

    /// Return a valid samplesPerSecond or nil
    private var validSamplesPerSecond: Int? {
        if let sps = Int(samplesPerSecond.text ?? ""), sps > 0 { return sps }
        return nil
    }

    /**
     Dismiss the view.

     - parameter sender: sender to the event
     */
    @IBAction func dismiss(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
}

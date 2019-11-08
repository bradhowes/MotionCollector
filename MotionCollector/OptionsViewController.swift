// OptionsViewController.swift
// Copyright © 2019 Brad Howes. All rights reserved.

import UIKit

/**
 A source and destination of state for the OptionsViewController.
 */
public protocol OptionsViewState {
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
final class OptionsViewController: UIViewController {
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

    public var state: OptionsViewState!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Use a tap gesture on the view to dismiss any keyboard that is present due to the seconds text input field.
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard(_:))))
        samplesPerSecond.delegate = self
    }

    override func viewWillAppear(_ animated: Bool) {
        samplesPerSecond.text = "\(state.samplesPerSecond)"
        setSwitch(accelerometerLabel, accelerometer, enabled: state.hasAccelerometer, value: state.useAccelerometer)
        setSwitch(deviceMotionLabel, deviceMotion, enabled: state.hasDeviceMotion, value: state.useDeviceMotion)
        setSwitch(gyroLabel, gyro, enabled: state.hasGyro, value: state.useGyro)
        setSwitch(magnetometerLabel, magnetometer, enabled: state.hasMagnetometer, value: state.useMagnetometer)
        setSwitch(uploadToCloudLabel, uploadToCloud, enabled: FileManager.default.hasCloudDirectory,
                  value: state.uploadToCloud)
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
}

extension OptionsViewController: UITextFieldDelegate {

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        return textField.endEditing(false)
    }
}

extension OptionsViewController {

    /**
     If the samplesPerSecond field is the first responder, then resign it and validate that the contents of the
     text field is an integer value we can use.

     - parameter sender: gesture recognizer
     */
    @objc func dismissKeyboard(_ sender: Any) {
        if samplesPerSecond.isFirstResponder {
            if let sps = validSamplesPerSecond {
                state.samplesPerSecond = sps
                samplesPerSecond.text = "\(sps)"
            }
            samplesPerSecond.resignFirstResponder()
        }
    }

    /**
     Dismiss the view.

     - parameter sender: sender to the event
     */
    @IBAction func dismiss(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
}

private extension OptionsViewController {

    var validSamplesPerSecond: Int? {
        if let sps = Int(samplesPerSecond.text ?? ""), sps > 0 { return sps }
        return nil
    }

    func setSwitch(_ label: UILabel, _ control: UISwitch, enabled: Bool, value: Bool) {
        label.isEnabled = enabled
        control.isEnabled = enabled
        control.isOn = value
    }
}

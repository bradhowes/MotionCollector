// OptionsViewController.swift
// Copyright © 2019 Brad Howes. All rights reserved.

import UIKit


/**
 A source and destination of state for the OptionsViewController.
 */
protocol OptionsViewState {
    var samplesPerSecond: Int {get set}
    var useAccelerometer: Bool {get set}
    var useDeviceMotion: Bool {get set}
    var useGyro: Bool {get set}
    var useMagnetometer: Bool {get set}
}

/**
 Simple modal view that shows the configurable settings for the app. The values are loaded before appearing, and they
 are applied after it disappears.
 */
class OptionsViewController: UIViewController {
    @IBOutlet weak var samplesPerSecond: UITextField!
    @IBOutlet weak var done: UIButton!
    @IBOutlet weak var accelerometer: UISwitch!
    @IBOutlet weak var deviceMotion: UISwitch!
    @IBOutlet weak var gyro: UISwitch!
    @IBOutlet weak var magnetometer: UISwitch!

    var state: OptionsViewState!

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard(_:))))
    }

    override func viewWillAppear(_ animated: Bool) {
        samplesPerSecond.text = "\(state.samplesPerSecond)"
        accelerometer.isOn = state.useAccelerometer
        deviceMotion.isOn = state.useDeviceMotion
        gyro.isOn = state.useGyro
        magnetometer.isOn = state.useMagnetometer


        super.viewWillAppear(animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if let sps = validSamplesPerSecond { state.samplesPerSecond = sps }
        state.useAccelerometer = accelerometer.isOn
        state.useDeviceMotion = deviceMotion.isOn
        state.useGyro = gyro.isOn
        state.useMagnetometer = magnetometer.isOn
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

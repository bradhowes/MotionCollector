// OptionsViewController.swift
// Copyright © 2019 Brad Howes. All rights reserved.

import UIKit


protocol OptionsViewManager {
    var samplesPerSecond: Int {get set}
    var useAccelerometer: Bool {get set}
    var useDeviceMotion: Bool {get set}
    var useGyro: Bool {get set}
    var useMagnetometer: Bool {get set}
}

class OptionsViewController: UIViewController {
    @IBOutlet weak var samplesPerSecond: UITextField!
    @IBOutlet weak var done: UIButton!
    @IBOutlet weak var accelerometer: UISwitch!
    @IBOutlet weak var deviceMotion: UISwitch!
    @IBOutlet weak var gyro: UISwitch!
    @IBOutlet weak var magnetometer: UISwitch!

    var mgr: OptionsViewManager!

    override func viewDidLoad() {
        super.viewDidLoad()
        samplesPerSecond.text = "\(mgr.samplesPerSecond)"
        accelerometer.isOn = mgr.useAccelerometer
        deviceMotion.isOn = mgr.useDeviceMotion
        gyro.isOn = mgr.useGyro
        magnetometer.isOn = mgr.useMagnetometer
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if let sps = Int(self.samplesPerSecond.text ?? "") {
            mgr.samplesPerSecond = sps
            mgr.useAccelerometer = accelerometer.isOn
            mgr.useDeviceMotion = deviceMotion.isOn
            mgr.useGyro = gyro.isOn
            mgr.useMagnetometer = magnetometer.isOn
        }
    }

    @IBAction func dismiss(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
}

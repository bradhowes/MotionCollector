// Copyright © 2019 Brad Howes. All rights reserved.

import UIKit
import CoreMotion

/**
 Collection of settings that user may adjust.
 */
final class Settings: OptionsViewState {

    public enum Name: String {
        case samplesPerSecond
        case useAccelerometer
        case useDeviceMotion
        case useGyro
        case useMagnetometer
        case uploadToCloud
    }

    let hasAccelerometer: Bool
    let hasDeviceMotion: Bool
    let hasGyro: Bool
    let hasMagnetometer: Bool

    var samplesPerSecond: Int = 10

    var _useAccelerometer: Bool { didSet { updateSetting(.useAccelerometer, with: useAccelerometer) } }
    var _useDeviceMotion: Bool { didSet { updateSetting(.useDeviceMotion, with: useDeviceMotion) } }
    var _useGyro: Bool { didSet { updateSetting(.useGyro, with: useGyro) } }
    var _useMagnetometer: Bool { didSet { updateSetting(.useMagnetometer, with: useMagnetometer) } }

    var useAccelerometer: Bool {
        get { return _useAccelerometer && hasAccelerometer }
        set { _useAccelerometer = newValue }
    }

    var useDeviceMotion: Bool {
        get { return _useDeviceMotion && hasDeviceMotion }
        set { _useDeviceMotion = newValue }
    }

    var useGyro: Bool {
        get { return _useGyro && hasGyro }
        set { _useGyro = newValue }
    }

    var useMagnetometer: Bool {
        get { return _useMagnetometer && hasMagnetometer }
        set { _useMagnetometer = newValue }
    }

    var uploadToCloud: Bool {
        didSet {
            updateSetting(.uploadToCloud, with: uploadToCloud)
            CloudUploader.shared.enabled = uploadToCloud
        }
    }

    init(_ cmm: CMMotionManager) {

        let defaultSettings: [Name: Any] = [
            .samplesPerSecond: 10,
            .useAccelerometer: true,
            .useDeviceMotion: true,
            .useGyro: true,
            .useMagnetometer: true,
            .uploadToCloud: true
        ]

        let defaults = UserDefaults.standard
        defaults.register(defaults: [String: Any](uniqueKeysWithValues: defaultSettings.map { ($0.0.rawValue, $0.1) }))

        hasAccelerometer = cmm.isAccelerometerAvailable
        hasDeviceMotion = cmm.isDeviceMotionAvailable
        hasGyro = cmm.isGyroAvailable
        hasMagnetometer = cmm.isMagnetometerAvailable

        samplesPerSecond = defaults.integer(for: .samplesPerSecond)

        _useAccelerometer = defaults.enabled(for: .useAccelerometer)
        _useDeviceMotion = defaults.enabled(for: .useDeviceMotion)
        _useGyro = defaults.enabled(for: .useGyro)
        _useMagnetometer = defaults.enabled(for: .useMagnetometer)

        uploadToCloud = defaults.enabled(for: .uploadToCloud)
    }
}

private extension Settings {

    func updateSetting<T>(_ name: Name, with value: T) {
        UserDefaults.standard.set(value, forKey: name.rawValue)
    }
}

private extension UserDefaults {
    func enabled(for name: Settings.Name) -> Bool {
        let exists = self.object(forKey: name.rawValue) != nil
        return exists ? self.bool(forKey: name.rawValue) : true
    }

    func integer(for name: Settings.Name) -> Int {
        return self.integer(forKey: name.rawValue)
    }
}

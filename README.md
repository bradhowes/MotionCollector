[![CI](https://github.com/bradhowes/MotionCollector/workflows/CI/badge.svg)](https://github.com/bradhowes/MotionCollector/actions/workflows/CI.yml)
[![COV](https://img.shields.io/endpoint?url=https://gist.githubusercontent.com/bradhowes/dbe62f18182c82eb36dc1030819bc54b/raw/MotionCollector-coverage.json)](https://github.com/bradhowes/MotionCollector/blob/main/.github/workflows/CI.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-A31F34.svg)](https://opensource.org/licenses/MIT)

# About

![](https://github.com/bradhowes/MotionCollector/blob/master/MotionCollector/Resources/AppIcons/152px.png?raw=true)

This simple application records values coming from an iOS device's CoreMotion sensors (accelerometer, gyroscope,
and magnetometer) and makes them available in a CSV formatted file in iCloud or iTunes (RIP). My goal in
creating this app was to allow for quick data collection while moving with the device. After collection, the
data would be processed with Apple's CoreML application for learning and (hopefully) future categorization of
activity based on sensor data.

The code works with Xcode 11 and Swift 5. Should work without problems with earlier versions, but the current
storyboard layout uses iOS 13 features. There would be minimal adjustments to make it work on older iOS
versions.

## Using

There are three views in this app:

1. Main recording view with a _Start/Stop_ button and movement buttons.
2. Recording history list that shows active and past event recordings. Swipe on a row to (re)upload, share, or
   delete the recording.
3. Settings view reachable from the main recording view via the _gear_ icon.

Press _Start_ to begin a new recording of sensor data. Move around. When done, press _Stop_ to quit data
collect. If _iCloud_ is enabled for the device, the app will attempt to copy the file to your _iCloud Drive_,
in a folder called _MotionCollector_.

Each recording fie is named with the date/time when the recording started. They all have the suffix _.csv_ so
you should be able to open them in whatever editor or spreadsheet application you wish.

## Data File Format

The file consists of lines of comma-separated values (CSV). The first line contains column labels for the rest
of the rows.

* Source -- indicates which sensor emitted the data.
> * A = accelerometer
> * D = device motion
> * G = gyroscope
> * M = magnetometer (compass)

* Label -- indicates the current user activity, W = walking, T = turning
* When -- timestamp of the record. These are given as number of seconds since 00:00:00 UTC 1 January, 1970 or
  the Unix epoch, though the resolution of the values is much finer than a second.

All sensors emit at minimum three values, one for each of the 3 axis that define the orientation of the device
in the real world.

* X -- X axis sensor value
* Y -- Y axis sensor value
* Z -- Z axis sensor value

For the _device motion_ records (Source == 'D'), there are 9 values instead of 3.

* X -- X axis rotation rate
* Y -- Y axis rotation rate
* Z -- Z axis rotation rate
* UA_X -- X axis user acceleration
* UA_Y -- Y axis user acceleration
* UA_Z -- Z axis user acceleration
* Pitch -- device rotation about the X axis
* Roll -- device rotation about the Y axis
* Yaw -- device rotation about the Z axis

See [this
page](https://developer.apple.com/documentation/coremotion/getting_processed_device-motion_data/understanding_reference_frames_and_device_attitude)
for a discussion of the _pitch_, _roll_, and _yaw_ values and how they relate to the device.

![](https://github.com/bradhowes/MotionCollector/blob/master/images/csv.png?raw=true)

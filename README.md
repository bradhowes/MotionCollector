# About

![](https://github.com/bradhowes/MotionCollector/blob/master/MotionCollector/Resources/AppIcons/152px.png?raw=true)

This simple application records values coming from an iOS device's CoreMotion sensors (accelerometer, gyroscope,
and magnetometer) and makes them available in a CSV formatted file in iCloud or iTunes (RIP). My goal in
creating this app was to allow for quick data collection while moving with the device. After collection, the
data would be processed with Apple's CoreML application for learning and (hopefully) future categorization of
activity based on sensor input.

The code works with Xcode 11 and Swift 5. Should work without problems with earlier versions, but the current
storyboard layout uses iOS 13 features. There would be minimal adjustments to make it work on older iOS
versions.

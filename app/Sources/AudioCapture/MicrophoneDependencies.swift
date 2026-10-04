@preconcurrency import AudioToolbox
@preconcurrency import AVFoundation
@preconcurrency import CoreAudio
import Foundation
import Shared

enum MicrophonePermission: Sendable, Equatable {
    case undetermined
    case denied
    case authorized
}

protocol MicrophonePermissionProviding: Sendable {
    func currentPermission() -> MicrophonePermission
}

struct SystemMicrophonePermissionProvider: MicrophonePermissionProviding {
    func currentPermission() -> MicrophonePermission {
        switch AVAudioApplication.shared.recordPermission {
        case .undetermined:
            .undetermined
        case .denied:
            .denied
        case .granted:
            .authorized
        @unknown default:
            .denied
        }
    }
}

protocol AudioInputDeviceCatalog: Sendable {
    func devices() throws -> [AudioInputDevice]
}

struct CoreAudioInputDeviceCatalog: AudioInputDeviceCatalog {
    func devices() throws -> [AudioInputDevice] {
        let defaultID = try defaultInputDeviceID()
        return try allDeviceIDs()
            .filter(hasInputStreams)
            .map { deviceID in
                try AudioInputDevice(
                    id: String(deviceID),
                    name: deviceName(deviceID),
                    isDefault: deviceID == defaultID
                )
            }
            .sorted {
                if $0.isDefault != $1.isDefault {
                    return $0.isDefault
                }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
    }

    private func allDeviceIDs() throws -> [AudioDeviceID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var byteCount: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &byteCount
        ) == noErr else {
            throw MicrophoneCaptureError.noInputDevice
        }

        var values = [AudioDeviceID](
            repeating: kAudioObjectUnknown,
            count: Int(byteCount) / MemoryLayout<AudioDeviceID>.size
        )
        guard !values.isEmpty else { return [] }
        let status = values.withUnsafeMutableBytes { bytes in
            AudioObjectGetPropertyData(
                AudioObjectID(kAudioObjectSystemObject),
                &address,
                0,
                nil,
                &byteCount,
                bytes.baseAddress!
            )
        }
        guard status == noErr else { throw MicrophoneCaptureError.noInputDevice }
        return values
    }

    private func defaultInputDeviceID() throws -> AudioDeviceID {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID = kAudioObjectUnknown
        var byteCount = UInt32(MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &byteCount,
            &deviceID
        ) == noErr else {
            throw MicrophoneCaptureError.noInputDevice
        }
        return deviceID
    }

    private func hasInputStreams(_ deviceID: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        var byteCount: UInt32 = 0
        let status = AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &byteCount)
        return status == noErr && byteCount >= UInt32(MemoryLayout<AudioStreamID>.size)
    }

    private func deviceName(_ deviceID: AudioDeviceID) throws -> String {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: Unmanaged<CFString>?
        var byteCount = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(
            deviceID,
            &address,
            0,
            nil,
            &byteCount,
            &value
        ) == noErr else {
            throw MicrophoneCaptureError.deviceUnavailable(String(deviceID))
        }
        guard let value else {
            throw MicrophoneCaptureError.deviceUnavailable(String(deviceID))
        }
        return value.takeUnretainedValue() as String
    }
}

protocol MicrophoneEngineDriving: Sendable {
    func start(
        deviceID: String?,
        frameHandler: @escaping @Sendable (AudioFrame) -> Void,
        configurationHandler: @escaping @Sendable () -> Void
    ) throws
    func stop()
}

import Shared

public enum AudioMixerError: Error, Sendable, Equatable {
    case alreadyRunning
    case invalidSourceChannel(expected: AudioChannel, actual: AudioChannel)
    case sourceEnded(AudioChannel)
}

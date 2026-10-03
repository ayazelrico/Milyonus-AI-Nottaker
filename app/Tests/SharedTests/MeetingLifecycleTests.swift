import Shared
import Testing

struct MeetingLifecycleTests {
    @Test func consentIsRequiredBeforeRecording() {
        var meeting = MeetingLifecycle()
        #expect(throws: MeetingTransitionError.consentRequired) {
            try meeting.begin(consentConfirmed: false, audio: .ready, transcription: .ready)
        }
        #expect(meeting.state == .idle)
    }

    @Test(arguments: [ServiceAvailability.unconfigured, .unavailable(.permissionDenied), .unavailable(.offline)])
    func audioMustBeReady(availability: ServiceAvailability) {
        var meeting = MeetingLifecycle()
        #expect(throws: MeetingTransitionError.serviceUnavailable) {
            try meeting.begin(consentConfirmed: true, audio: availability, transcription: .ready)
        }
        #expect(meeting.state == .idle)
    }

    @Test func transcriptionMustBeReady() {
        var meeting = MeetingLifecycle()
        #expect(throws: MeetingTransitionError.serviceUnavailable) {
            try meeting.begin(consentConfirmed: true, audio: .ready, transcription: .unconfigured)
        }
        #expect(meeting.state == .idle)
    }

    @Test func recordingCanPauseResumeAndFinish() throws {
        var meeting = MeetingLifecycle()
        try meeting.begin(consentConfirmed: true, audio: .ready, transcription: .ready)
        #expect(meeting.state == .recording)
        try meeting.pause()
        #expect(meeting.state == .paused)
        try meeting.resume(consentConfirmed: true, audio: .ready, transcription: .ready)
        #expect(meeting.state == .recording)
        try meeting.finish()
        #expect(meeting.state == .completed)
        #expect(throws: MeetingTransitionError.invalidTransition) {
            try meeting.begin(consentConfirmed: true, audio: .ready, transcription: .ready)
        }
    }

    @Test func resumingRechecksConsentAndAvailability() throws {
        var meeting = MeetingLifecycle()
        try meeting.begin(consentConfirmed: true, audio: .ready, transcription: .ready)
        try meeting.pause()
        #expect(throws: MeetingTransitionError.consentRequired) {
            try meeting.resume(consentConfirmed: false, audio: .ready, transcription: .ready)
        }
        #expect(throws: MeetingTransitionError.serviceUnavailable) {
            try meeting.resume(consentConfirmed: true, audio: .ready, transcription: .unavailable(.offline))
        }
        #expect(meeting.state == .paused)
        try meeting.finish()
        #expect(meeting.state == .completed)
    }

    @Test func idleMeetingCannotPauseOrFinish() {
        var meeting = MeetingLifecycle()
        #expect(throws: MeetingTransitionError.invalidTransition) { try meeting.pause() }
        #expect(throws: MeetingTransitionError.invalidTransition) { try meeting.finish() }
        #expect(meeting.state == .idle)
    }

    @Test func onlyReadyServiceIsUsable() {
        #expect(ServiceAvailability.ready.isReady)
        #expect(!ServiceAvailability.unconfigured.isReady)
        #expect(!ServiceAvailability.unavailable(.signedOut).isReady)
    }
}

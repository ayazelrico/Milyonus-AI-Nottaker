import Foundation
import Shared
import Testing

struct DomainModelsTests {
    @Test func audioFrameUsesDeclaredPCMFormat() throws {
        let frame = try AudioFrame(channel: .microphone, timestampNanoseconds: 42, pcm16: Data(count: 640))
        #expect(frame.sampleCount == 320)
        #expect(frame.durationSeconds == 0.02)
        #expect(frame.durationNanoseconds == 20_000_000)
        #expect(frame.timestampNanoseconds == 42)
        #expect(frame.endTimestampNanoseconds == 20_000_042)
    }

    @Test func emptyAudioIsRejected() {
        #expect(throws: DomainValidationError.emptyAudioFrame) {
            try AudioFrame(channel: .system, timestampNanoseconds: 0, pcm16: Data())
        }
    }

    @Test func incompleteAudioSampleIsRejected() {
        #expect(throws: DomainValidationError.incompletePCM16Sample) {
            try AudioFrame(channel: .system, timestampNanoseconds: 0, pcm16: Data(count: 3))
        }
    }

    @Test(arguments: [(-1, 2), (20, 10)])
    func invalidTranscriptTimesAreRejected(times: (Int, Int)) {
        #expect(throws: DomainValidationError.invalidTranscriptRange) {
            try TranscriptSegment(
                meetingID: UUID(), channel: .microphone, text: "Fixture",
                startMilliseconds: times.0, endMilliseconds: times.1, isFinal: true
            )
        }
    }

    @Test func zeroDurationInterimTranscriptIsAllowed() throws {
        let segment = try TranscriptSegment(
            meetingID: UUID(), channel: .system, text: "",
            startMilliseconds: 0, endMilliseconds: 0, isFinal: false
        )
        #expect(!segment.isFinal)
    }

    @Test func emptyEmbeddingIsRejected() {
        #expect(throws: DomainValidationError.emptyEmbedding) {
            try EmbeddingVector(values: [])
        }
    }

    @Test(arguments: [Float.nan, Float.infinity, -Float.infinity])
    func nonFiniteEmbeddingsAreRejected(value: Float) {
        #expect(throws: DomainValidationError.nonFiniteEmbedding) {
            try EmbeddingVector(values: [0, value])
        }
    }

    @Test func overageCannotCreateNegativeAllowance() throws {
        let allowance = try UsageAllowance(usedSeconds: 120, limitSeconds: 60)
        #expect(allowance.remainingSeconds == 0)
        #expect(!allowance.canRecord)
    }

    @Test(arguments: [(-1, 60), (0, -1)])
    func negativeUsageIsRejected(usage: (Int, Int)) {
        #expect(throws: DomainValidationError.invalidUsage) {
            try UsageAllowance(usedSeconds: usage.0, limitSeconds: usage.1)
        }
    }

    @Test func sessionExpiresAtItsBoundaryAndRedactsCredentials() throws {
        let expiration = Date(timeIntervalSince1970: 1000)
        let session = try AuthSession(userID: UUID(), accessToken: "fixture-only", expiresAt: expiration)
        #expect(session.isValid(at: expiration.addingTimeInterval(-1)))
        #expect(!session.isValid(at: expiration))
        #expect(!session.isValid(at: expiration.addingTimeInterval(1)))
        #expect(!String(describing: session).contains("fixture-only"))
        #expect(!String(reflecting: session).contains("fixture-only"))
    }

    @Test func emptySessionTokenIsRejected() {
        #expect(throws: DomainValidationError.emptySessionToken) {
            try AuthSession(userID: UUID(), accessToken: " \n", expiresAt: Date())
        }
    }

    @Test func calendarEndCannotPrecedeStart() {
        let start = Date(timeIntervalSince1970: 1000)
        #expect(throws: DomainValidationError.invalidCalendarRange) {
            try CalendarMeeting(id: "fixture", title: "Fixture", startsAt: start, endsAt: start.addingTimeInterval(-1))
        }
    }
}

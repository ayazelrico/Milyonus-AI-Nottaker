# P1-07 - STT token endpoint

Status: completed on 2026-10-05. Native consent, live STT transport, and production entitlements remain
in P1-13, P1-08, and P6-04 respectively.

## Goal

Allow an authenticated macOS client to obtain a short-lived Deepgram bearer token without exposing the
permanent provider API key. Reject the request before provider work unless consent is explicitly asserted
and the entitlement boundary allows the account.

## Plan

1. Parse an optional server-only `DEEPGRAM_API_KEY` without requiring it for backend liveness.
2. Add a Deepgram adapter for the fixed `POST https://api.deepgram.com/v1/auth/grant` endpoint.
3. Request a 30-second token with the documented `ttl_seconds` field and validate the response.
4. Add the protected `POST /v1/stt/token` route with auth, consent, and entitlement ordering.
5. Add local contract tests with injected fakes and no provider network calls.
6. Document temporary boundaries and provider behavior verified from official documentation.

## Contract

The route requires exactly one bearer access token and the JSON body below:

```json
{"consentConfirmed":true}
```

After authentication, the route rejects any other body before entitlement or provider work. The Phase 1
entitlement checker allows authenticated non-anonymous users. It is isolated behind a function contract so
P6-04 can replace it. Successful responses expose the provider name, temporary bearer token, and duration.
They never expose the permanent API key or provider errors.

## Boundaries

- Consent is asserted by the client. P1-13 must connect it to the native consent sheet and meeting state.
- The entitlement implementation is a stub. It is not subscription enforcement.
- Token expiry blocks a new provider connection and does not stop an existing WebSocket.
- Rate limiting, metering, and session-duration enforcement remain required before public paid use.
- Tests never call Deepgram and use no real credentials.

## Acceptance

- Missing or rejected authentication cannot reach consent, entitlement, or provider work.
- Missing, false, malformed, or extended consent bodies cannot reach entitlement or provider work.
- A denied entitlement cannot reach Deepgram.
- The adapter uses the fixed HTTPS grant endpoint, server API-key authentication, and `ttl_seconds: 30`.
- Invalid status, network failure, malformed payload, unsafe token, and invalid TTL fail closed with a
  generic response and metadata-only operational event.
- Backend build, tests, type checking, lint, formatting, repository checks, and CI pass.

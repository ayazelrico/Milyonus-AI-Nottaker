# P0-07 - Authentication foundation

Status: application implementation complete; dashboard redirect and real sign-in acceptance pending.

## Goal

Add a native macOS sign-in flow backed by the dedicated Supabase project. The application uses PKCE,
stores access and refresh sessions in Keychain, accepts only its custom callback URL, and sends the
access token to the backend `GET /v1/me` endpoint for signed identity verification.

## Plan

1. Add an `Authentication` feature module behind protocols in `Shared`.
2. Pin the official Supabase Swift Auth package and wrap provider types inside the module.
3. Support email Magic Link plus provider-independent Apple/Google OAuth entry points using PKCE and
   native `ASWebAuthenticationSession`.
4. Store SDK session data under an application-specific Keychain service. Never use UserDefaults,
   logs, command arguments, or repository files for credentials.
5. Add strict runtime configuration, callback validation, generic user-visible errors, and a backend
   identity client for `/v1/me`.
6. Add a Settings sign-in surface, callback handling, localization, unit tests, and packaged app URL
   scheme metadata.
7. Configure the Supabase redirect allowlist and validate a real sign-in only when an owner-controlled
   email/provider account is available.

## Implemented

- `Authentication` owns the pinned Supabase Swift Auth adapter, PKCE flow, application-specific
  Keychain storage, strict callback/configuration validation, and backend identity client.
- The composition root restores one shared session, handles application callback URLs, verifies
  `/v1/me` when a backend URL is configured, and exposes sign-in/sign-out in native Settings.
- The packaged app registers `milyonus-nottaker://auth/callback`. Optional public runtime values are
  read from the ignored `app/.env.local` and embedded only in generated bundles.
- English and Turkish account states are cataloged. Errors shown to users do not include email,
  tokens, callback parameters, SDK diagnostics, or backend response bodies.

Apple and Google code paths are ready, but those providers cannot be enabled without their external
developer credentials. Magic Link is the acceptance path for this task. Supabase dashboard login is
required to add the callback allowlist entry, and an owner-controlled email is required for the final
end-to-end sign-in.

Supabase advisors were rechecked on 2026-10-04. The only security warning is
[disabled leaked-password protection](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection),
which does not affect the passwordless Magic Link acceptance path and should be enabled before
password authentication is offered. The only performance notice is an expected unused-index notice
on the newly provisioned empty schema.

## Security boundaries

- The Supabase publishable key is a public client identifier with RLS-limited access. It is runtime
  configuration and is not committed. Service-role and provider secrets remain backend-only.
- PKCE is mandatory. Callback URLs must match `milyonus-nottaker://auth/callback` exactly and may not
  contain credentials.
- The SDK logger is disabled because callback URLs and provider errors can contain sensitive data.
- UI and operational events never include email addresses, tokens, callback queries, or raw provider
  errors.
- Signing out removes the local Keychain session. Account deletion is a later end-to-end task.

## Acceptance

- Authentication configuration and callback validation have deterministic tests.
- Session storage uses Keychain through the pinned official SDK.
- Magic Link request, callback completion, OAuth entry points, refresh, and sign-out are implemented.
- `/v1/me` receives exactly one bearer token and validates the returned user ID.
- Debug and release app bundles declare the callback scheme.
- A real sign-in and provider dashboard configuration are recorded before P0-07 is marked complete.

# 10 - Calendar and pre-call briefs

Phase 5 specification, reconstructed on 2026-10-02. No calendar access occurs in the foundation.

Expose calendar providers through Shared. Request EventKit permission only when the user enables
calendar features. Google Calendar OAuth is a separate backend flow with minimal scopes and verified
redirect URIs. Tokens must be revocable and protected. Do not equate a calendar event with consent
to record. Detection prompts the user rather than silently starting capture.

Pre-call briefs use explicit event selection or an enabled preference, bounded public research,
source citations, and domain/privacy exclusions. Never invent personal facts. Notification timing
and brief lead time are preferences. Disconnecting calendar cancels future background work.

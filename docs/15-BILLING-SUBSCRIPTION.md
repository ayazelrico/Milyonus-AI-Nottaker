# 15 - Billing and subscriptions

Phase 6 specification. No checkout, charging, or invented prices are present in the foundation.

Stripe account entity, plans, limits, and pricing require owner approval. Keep entitlements behind
Shared in the app and enforce them on the server. Validate webhook signatures against raw bodies,
deduplicate event IDs, and reconcile out-of-order events. Client UI is not a security boundary.

Meter STT/LLM/embedding usage using trusted server/provider records and explicit caps. Temporary STT
tokens require abuse controls beyond their issuance TTL. Show measured usage and clear limits only
after integration. Test checkout, cancellation, grace periods, retries, and account deletion in test
mode before any live-mode action. Hosted checkout/portal URLs are backend-authorized.

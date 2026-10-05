import type { Identity } from '../auth/verify-token.js';

export type EntitlementChecker = (identity: Identity) => Promise<boolean>;

/**
 * Phase 1 stub. Billing-backed plan and usage checks replace this in P6-04.
 * Authentication remains mandatory before this checker is reached.
 */
export const allowAuthenticatedEntitlement: EntitlementChecker = () => Promise.resolve(true);

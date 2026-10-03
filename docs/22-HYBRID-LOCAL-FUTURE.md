# 22 - Hybrid-local future

Cloud inference is the initial implementation. Shared protocols keep local STT, embeddings, and
language-model adapters possible later without changing feature logic. Do not claim local/private
inference while audio or context still leaves the device.

Future evaluation must measure hardware/RAM requirements, battery use, model download integrity,
language quality, latency, fallback behavior, consent, and on-device retention. A local encrypted
cache alone is not local inference. Hybrid routing must make its actual data flow visible to users.

"""Secondary AI reasoning, visual verification, and conservative decision module."""

# ---------------------------------------------------------------------------
# LEGACY: QwenReviewer (qwen3:8b text-evidence reviewer)
# Superseded by QwenVisionVerifier below. Retained for backward compatibility
# and for tests/test_qwen_verifier.py. Do not use in new inference code.
# ---------------------------------------------------------------------------
from ml.verification.qwen_reviewer import (
    QwenReviewer,
    build_evidence_payload,
    review_screening_evidence,
)

# ---------------------------------------------------------------------------
# Production: QwenVisionVerifier (qwen3-vl:4b — inspects actual image)
# ---------------------------------------------------------------------------
from ml.verification.qwen_verifier import (
    QwenVisionVerifier,
    synthesize_final_result,
    format_final_screening_result,
)
from ml.verification.decision_engine import DecisionEngine, make_decision

__all__ = [
    "QwenReviewer",
    "build_evidence_payload",
    "review_screening_evidence",
    "QwenVisionVerifier",
    "synthesize_final_result",
    "format_final_screening_result",
    "DecisionEngine",
    "make_decision",
]

"""Conservative Deterministic Decision Engine for Pharmaceutical Screening.

Authoritative decision-synthesis path combining predictions from the primary
visual classifier (EfficientNet-B0) and secondary AI verification (Qwen Vision / Ollama).

Standardized Output Contract:
- final_result: Exactly one of:
    * 'LIKELY AUTHENTIC'
    * 'LIKELY COUNTERFEIT'
    * 'SUSPICIOUS / NEEDS VERIFICATION'
- needs_human_verification: bool

Decision policy (threshold comparisons are inclusive):
1. Invalid image quality always returns UNKNOWN and requires a retake/manual review.
2. Invalid or below-threshold primary output requires manual review.
3. Accepted primary labels are preserved when Qwen agrees, is uncertain, is skipped,
   or is unavailable. Unavailability adds a warning; a skip is not an outage.
4. A direct primary/Qwen class conflict or an explicit Qwen suspicious concern requires
   manual review. A counterfeit primary result is retained and flagged for human review.
"""

from __future__ import annotations

from typing import Any, Optional

DEFAULT_CONFIDENCE_THRESHOLD = 0.70
DEFAULT_HIGH_CONFIDENCE_THRESHOLD = 0.90

DISCLAIMER_TEXT = (
    "AI-assisted preliminary screening only. Visual and convolutional appearance "
    "analysis CANNOT certify chemical purity, active pharmaceutical ingredients (API), "
    "or bioequivalence. Laboratory chemical testing remains the sole definitive standard."
)


class DecisionEngine:
    """Conservative deterministic decision engine synthesizing visual classifier & secondary AI."""

    def __init__(
        self,
        confidence_threshold: float = DEFAULT_CONFIDENCE_THRESHOLD,
        high_confidence_threshold: float = DEFAULT_HIGH_CONFIDENCE_THRESHOLD,
    ):
        self.threshold = float(confidence_threshold)
        self.high_threshold = float(high_confidence_threshold)

    def evaluate(self, primary_result: dict[str, Any], qwen_review: Optional[dict[str, Any]] = None) -> dict[str, Any]:
        """Apply the deterministic screening policy; threshold comparison is inclusive (>=)."""
        primary_model = primary_result.get("model_name", "efficientnet_b0")
        raw_pred = str(primary_result.get("predicted_class") or primary_result.get("prediction", "UNKNOWN")).upper()
        primary_pred = "COUNTERFEIT" if "COUNTERFEIT" in raw_pred else "AUTHENTIC" if "AUTHENTIC" in raw_pred else "UNKNOWN"
        try:
            primary_conf = float(primary_result.get("confidence", 0.0))
            if not 0.0 <= primary_conf <= 1.0:
                primary_conf = 0.0
        except (TypeError, ValueError):
            primary_conf = 0.0
        quality = primary_result.get("quality") or {}
        quality_valid = quality.get("is_valid", True)
        executed = qwen_review is not None
        payload = dict(qwen_review) if qwen_review is not None else {
            "available": False, "status": "SKIPPED", "assessment": "SKIPPED", "confidence": 0.0,
            "reasoning": ["Secondary AI verification was not executed."], "needs_human_verification": False,
        }
        available = bool(payload.get("available", False) and payload.get("status") != "UNAVAILABLE")
        assessment = str(payload.get("assessment", "UNCERTAIN")).strip().upper()
        warning = None
        disagreement = False

        if not quality_valid:
            reason = f"Image quality check failed: {quality.get('reason') or 'Poor quality'}"
            payload.update({"available": False, "status": "SKIPPED", "assessment": "SKIPPED",
                            "confidence": 0.0, "reasoning": ["Skipped because image quality failed."],
                            "warning": "Skipped because image quality failed."})
            prediction, conf, primary_conf = "UNKNOWN", 0.0, 0.0
            final, needs, executed, available, assessment = "SUSPICIOUS / NEEDS VERIFICATION", True, False, False, "SKIPPED"
            warning = reason + ". Upload a clearer, focused, well-lit image."
        elif primary_conf < self.threshold or primary_pred == "UNKNOWN":
            reason = f"Primary model confidence ({primary_conf*100:.1f}%) is below screening threshold ({self.threshold*100:.1f}%), or model output was invalid."
            prediction, final, needs = primary_pred, "SUSPICIOUS / NEEDS VERIFICATION", True
            warning = reason
        elif available and assessment in ("AUTHENTIC", "COUNTERFEIT") and assessment != primary_pred:
            reason = f"Conflicting evidence: primary classifier predicts {primary_pred}, but secondary AI reviewer assessed {assessment}."
            prediction, final, needs, disagreement = primary_pred, "SUSPICIOUS / NEEDS VERIFICATION", True, True
            warning = reason
        elif available and assessment == "SUSPICIOUS":
            reason = "Secondary AI reviewer raised a suspicious visual concern; manual verification is required."
            prediction, final, needs, warning = primary_pred, "SUSPICIOUS / NEEDS VERIFICATION", True, reason
        else:
            prediction = primary_pred
            final = "LIKELY AUTHENTIC" if primary_pred == "AUTHENTIC" else "LIKELY COUNTERFEIT"
            needs = primary_pred == "COUNTERFEIT"
            if available and assessment == primary_pred:
                reason = f"Primary visual classifier and secondary AI review corroborate {primary_pred.lower()} evidence."
            else:
                reason = f"Primary classifier prediction accepted at {primary_conf*100:.1f}% confidence."
            if executed and not available:
                warning = "Secondary AI verification was attempted but unavailable; decision uses the primary classifier."
            elif available and assessment in ("UNCERTAIN", "INCONCLUSIVE"):
                reason += " Secondary review was uncertain and did not contradict it."

        return {
            "final_result": final, "final_status": "NEEDS MANUAL REVIEW" if needs else final,
            "needs_human_verification": needs, "primary_model": primary_model,
            "prediction": prediction, "primary_prediction": prediction,
            "confidence": round(conf, 4) if not quality_valid else round(primary_conf, 4),
            "primary_confidence": round(primary_conf, 4), "qwen": payload,
            "secondary_executed": executed, "secondary_available": available,
            "secondary_assessment": assessment, "disagreement": disagreement,
            "warning": warning, "reason": reason, "reasons": [reason],
            "disclaimer": DISCLAIMER_TEXT,
        }


def make_decision(
    primary_result: dict[str, Any],
    qwen_review: Optional[dict[str, Any]] = None,
    confidence_threshold: float = DEFAULT_CONFIDENCE_THRESHOLD,
    high_confidence_threshold: float = DEFAULT_HIGH_CONFIDENCE_THRESHOLD,
) -> dict[str, Any]:
    """Authoritative convenience helper to execute the conservative DecisionEngine."""
    engine = DecisionEngine(
        confidence_threshold=confidence_threshold,
        high_confidence_threshold=high_confidence_threshold,
    )
    return engine.evaluate(primary_result, qwen_review)

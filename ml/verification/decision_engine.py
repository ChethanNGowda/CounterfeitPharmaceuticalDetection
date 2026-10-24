"""Conservative Deterministic Decision Engine for Pharmaceutical Screening.

Authoritative decision-synthesis path combining predictions from the primary
visual classifier (EfficientNet-B0) and secondary AI verification (Qwen Vision / Ollama).

Standardized Output Contract:
- final_result: Exactly one of:
    * 'LIKELY AUTHENTIC'
    * 'LIKELY COUNTERFEIT'
    * 'SUSPICIOUS / NEEDS VERIFICATION'
- needs_human_verification: bool

Decision policy uses authentic probability:
1. Invalid image quality always returns UNKNOWN and requires a retake/manual review.
2. Below 50% authentic probability indicates counterfeit; 50%-70% requires review;
   above the configured 70% cutoff indicates authentic.
3. In the below-50% band, secondary concerns remain warnings and the red counterfeit
   indication is retained; all counterfeit indications still require human verification.
   Above that band, direct class conflicts or explicit Qwen suspicious concerns require
   manual review.
"""

from __future__ import annotations

from typing import Any, Optional

from ml.config import (
    COUNTERFEIT_AUTHENTIC_PROBABILITY_CUTOFF,
    DEFAULT_CONFIDENCE_THRESHOLD,
    DEFAULT_HIGH_CONFIDENCE_THRESHOLD,
)

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
        if not COUNTERFEIT_AUTHENTIC_PROBABILITY_CUTOFF <= self.threshold <= 1.0:
            raise ValueError("Authentic probability threshold must be between 0.50 and 1.00.")
        # Kept for callers using the legacy constructor; final routing now uses
        # the authentic-probability bands, so this value no longer changes it.
        self.high_threshold = float(high_confidence_threshold)

    def evaluate(self, primary_result: dict[str, Any], qwen_review: Optional[dict[str, Any]] = None) -> dict[str, Any]:
        """Apply 50% / configured authentic-probability screening bands."""
        primary_model = primary_result.get("model_name", "efficientnet_b0")
        raw_pred = str(primary_result.get("predicted_class") or primary_result.get("prediction", "UNKNOWN")).upper()
        primary_pred = "COUNTERFEIT" if "COUNTERFEIT" in raw_pred else "AUTHENTIC" if "AUTHENTIC" in raw_pred else "UNKNOWN"
        try:
            primary_conf = float(primary_result.get("confidence", 0.0))
            if not 0.0 <= primary_conf <= 1.0:
                primary_conf = 0.0
        except (TypeError, ValueError):
            primary_conf = 0.0
        probabilities = primary_result.get("probabilities") or {}
        try:
            raw_auth_probability = primary_result.get(
                "authentic_probability", probabilities.get("authentic")
            )
            authentic_probability = (
                float(raw_auth_probability)
                if raw_auth_probability is not None
                else None
            )
            if authentic_probability is not None and not 0.0 <= authentic_probability <= 1.0:
                authentic_probability = None
        except (TypeError, ValueError):
            authentic_probability = None
        # Older callers may provide only class and confidence.
        if authentic_probability is None:
            if primary_pred == "AUTHENTIC":
                authentic_probability = primary_conf
            elif primary_pred == "COUNTERFEIT":
                authentic_probability = 1.0 - primary_conf
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
        elif primary_pred == "UNKNOWN" or authentic_probability is None:
            reason = "The primary model returned an invalid class or authentic probability. Manual review is required."
            prediction, final, needs = primary_pred, "SUSPICIOUS / NEEDS VERIFICATION", True
            warning = reason
        elif authentic_probability < COUNTERFEIT_AUTHENTIC_PROBABILITY_CUTOFF:
            reason = (
                f"Authentic probability is {authentic_probability * 100:.1f}% "
                "(below 50%); counterfeit is indicated."
            )
            prediction, final, needs = "COUNTERFEIT", "LIKELY COUNTERFEIT", True
            # A secondary disagreement can prompt a human check, but does not
            # change the requested <50% counterfeit headline or red UI state.
            if available and assessment == "AUTHENTIC":
                disagreement = True
                warning = "Secondary visual review disagreed; the red counterfeit indication follows the below-50% authentic probability, and a pharmacist should verify the medicine."
            elif available and assessment == "SUSPICIOUS":
                warning = "Secondary visual review raised a concern; have a pharmacist verify the medicine."
        elif available and assessment in ("AUTHENTIC", "COUNTERFEIT") and assessment != primary_pred:
            reason = f"Conflicting evidence: primary classifier predicts {primary_pred}, but secondary AI reviewer assessed {assessment}."
            prediction, final, needs, disagreement = primary_pred, "SUSPICIOUS / NEEDS VERIFICATION", True, True
            warning = reason
        elif available and assessment == "SUSPICIOUS":
            reason = "Secondary AI reviewer raised a suspicious visual concern; manual verification is required."
            prediction, final, needs, warning = primary_pred, "SUSPICIOUS / NEEDS VERIFICATION", True, reason
        elif COUNTERFEIT_AUTHENTIC_PROBABILITY_CUTOFF <= authentic_probability <= self.threshold:
            reason = (
                f"Authentic probability ({authentic_probability * 100:.1f}%) is in the "
                f"50.0%-{self.threshold * 100:.1f}% manual-review band."
            )
            prediction, final, needs = primary_pred, "SUSPICIOUS / NEEDS VERIFICATION", True
            if executed and not available:
                warning = "Secondary AI verification was attempted but unavailable; manual review is still required."
        else:
            accepted_class = (
                "COUNTERFEIT"
                if authentic_probability < COUNTERFEIT_AUTHENTIC_PROBABILITY_CUTOFF
                else "AUTHENTIC"
            )
            prediction = accepted_class
            final = "LIKELY AUTHENTIC" if accepted_class == "AUTHENTIC" else "LIKELY COUNTERFEIT"
            needs = accepted_class == "COUNTERFEIT"
            if available and assessment == accepted_class:
                reason = f"Primary visual classifier and secondary AI review corroborate {accepted_class.lower()} evidence."
            elif accepted_class == "COUNTERFEIT":
                reason = (
                    f"Authentic probability is {authentic_probability * 100:.1f}% "
                    "(below 50%); counterfeit is indicated."
                )
            else:
                reason = f"Authentic probability is {authentic_probability * 100:.1f}%."
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

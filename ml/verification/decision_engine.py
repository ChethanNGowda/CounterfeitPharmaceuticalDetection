"""Conservative Deterministic Decision Engine for Pharmaceutical Screening.

Synthesizes predictions from the primary deep visual classifier (EfficientNet-B0)
and the secondary AI reasoning review layer (qwen3:8b).

Decision Rules (Confidence Threshold = 0.70):
1. Quality Screening:
   - If image quality checks fail (severe blur, tiny resolution, extreme exposure),
     Final = 'SUSPICIOUS / NEEDS VERIFICATION'
     needs_human_verification = True.
2. Low Primary Confidence (< 0.70):
   - If primary classifier confidence < 0.70,
     Final = 'SUSPICIOUS / NEEDS VERIFICATION'
     needs_human_verification = True.
3. High Primary Confidence (>= 0.70) with Qwen Available:
   - If primary = AUTHENTIC and Qwen = AUTHENTIC:
     Final = 'LIKELY AUTHENTIC'
     needs_human_verification = False.
   - If primary = COUNTERFEIT and Qwen = COUNTERFEIT:
     Final = 'LIKELY COUNTERFEIT'
     needs_human_verification = True.
   - If primary and Qwen disagree (conflict):
     Final = 'SUSPICIOUS / NEEDS VERIFICATION'
     needs_human_verification = True.
   - If Qwen = SUSPICIOUS (uncertain):
     Final = 'SUSPICIOUS / NEEDS VERIFICATION'
     needs_human_verification = True.
4. High Primary Confidence (>= 0.70) with Qwen Unavailable:
   - Primary = AUTHENTIC -> Final = 'LIKELY AUTHENTIC'
     warning = 'Secondary AI verification unavailable — result based on primary classifier.'
   - Primary = COUNTERFEIT -> Final = 'LIKELY COUNTERFEIT'
     warning = 'Secondary AI verification unavailable — result based on primary classifier.'
"""

from __future__ import annotations

from typing import Any, Optional

DEFAULT_CONFIDENCE_THRESHOLD = 0.70

DISCLAIMER_TEXT = (
    "AI-assisted preliminary screening only. Visual and convolutional appearance "
    "analysis CANNOT certify chemical purity, active pharmaceutical ingredients (API), "
    "or bioequivalence. Laboratory chemical testing remains the sole definitive standard."
)


class DecisionEngine:
    """Combines primary classifier outputs with secondary Qwen reasoning review."""

    def __init__(self, confidence_threshold: float = DEFAULT_CONFIDENCE_THRESHOLD):
        self.threshold = float(confidence_threshold)

    def evaluate(
        self,
        primary_result: dict[str, Any],
        qwen_review: Optional[dict[str, Any]] = None,
    ) -> dict[str, Any]:
        """Synthesize primary classifier metrics and secondary AI review.

        Parameters
        ----------
        primary_result : dict
            Output from `predict()`.
        qwen_review : dict, optional
            Output from `QwenReviewer.review_evidence()`.

        Returns
        -------
        dict
            Synthesized verdict matching contract:
            primary_model, prediction, confidence, qwen, final_result,
            needs_human_verification, warning, disclaimer.
        """
        primary_model = primary_result.get("model_name", "efficientnet_b0")
        raw_pred = str(
            primary_result.get("predicted_class") or primary_result.get("prediction", "UNKNOWN")
        ).upper()

        if "COUNTERFEIT" in raw_pred:
            primary_pred = "COUNTERFEIT"
        elif "AUTHENTIC" in raw_pred:
            primary_pred = "AUTHENTIC"
        else:
            primary_pred = "UNKNOWN"

        primary_conf = float(primary_result.get("confidence", 0.0))
        quality = primary_result.get("quality") or {}
        quality_is_valid = quality.get("is_valid", True)

        # Default fallback for qwen_review if omitted
        if qwen_review is None:
            qwen_review = {
                "available": False,
                "assessment": "SUSPICIOUS",
                "confidence": 0.0,
                "reasoning": ["Secondary AI verification was not executed."],
                "needs_human_verification": True,
                "warning": "Secondary AI verification unavailable — result based on primary classifier.",
            }

        qwen_available = bool(qwen_review.get("available", False))
        qwen_assessment = str(qwen_review.get("assessment", "SUSPICIOUS")).upper()

        # Rule 1: Quality Check Failed
        if not quality_is_valid:
            reason = f"Image quality check failed: {quality.get('reason', 'Poor quality')}"
            return {
                "primary_model": primary_model,
                "prediction": primary_pred,
                "confidence": round(primary_conf, 4),
                "qwen": qwen_review,
                "final_result": "SUSPICIOUS / NEEDS VERIFICATION",
                "needs_human_verification": True,
                "warning": reason,
                "reason": reason,
                "disclaimer": DISCLAIMER_TEXT,
            }

        # Rule 2: Low Primary Confidence (< threshold)
        if primary_conf < self.threshold or primary_pred == "UNKNOWN":
            reason = (
                f"Primary model confidence ({primary_conf*100:.1f}%) is below screening "
                f"threshold ({self.threshold*100:.1f}%). Requires physical laboratory inspection."
            )
            return {
                "primary_model": primary_model,
                "prediction": primary_pred,
                "confidence": round(primary_conf, 4),
                "qwen": qwen_review,
                "final_result": "SUSPICIOUS / NEEDS VERIFICATION",
                "needs_human_verification": True,
                "warning": reason,
                "reason": reason,
                "disclaimer": DISCLAIMER_TEXT,
            }

        # Rule 3: High Primary Confidence (>= threshold) with Qwen Available
        if qwen_available:
            if primary_pred == "AUTHENTIC" and qwen_assessment == "AUTHENTIC":
                final_result = "LIKELY AUTHENTIC"
                needs_human = False
                warning = None
                reason = "Primary visual classifier and secondary AI review corroborate authentic evidence."

            elif primary_pred == "COUNTERFEIT" and qwen_assessment == "COUNTERFEIT":
                final_result = "LIKELY COUNTERFEIT"
                needs_human = True
                warning = "Evidence indicates counterfeit medicine. Quarantine sample."
                reason = "Both primary visual classifier and secondary AI review indicate counterfeit characteristics."

            elif qwen_assessment == "SUSPICIOUS":
                final_result = "SUSPICIOUS / NEEDS VERIFICATION"
                needs_human = True
                warning = "Secondary AI reviewer flagged evidence as suspicious or requiring additional verification."
                reason = "Secondary review requires manual verification."

            else:
                # Disagreement / Conflict: e.g. primary AUTHENTIC vs Qwen COUNTERFEIT or vice versa
                final_result = "SUSPICIOUS / NEEDS VERIFICATION"
                needs_human = True
                warning = f"Conflicting evidence: primary classifier predicts {primary_pred}, but secondary AI reviewer assessed {qwen_assessment}."
                reason = warning

        else:
            # Rule 4: Qwen Unavailable Fallback
            warning = "Secondary AI verification unavailable — result based on primary classifier."
            if primary_pred == "AUTHENTIC":
                final_result = "LIKELY AUTHENTIC"
                needs_human = False
                reason = f"Primary classifier indicates authentic ({primary_conf*100:.1f}% confidence); secondary review unavailable."
            else:
                final_result = "LIKELY COUNTERFEIT"
                needs_human = True
                reason = f"Primary classifier indicates counterfeit ({primary_conf*100:.1f}% confidence); secondary review unavailable."

        return {
            "primary_model": primary_model,
            "prediction": primary_pred,
            "confidence": round(primary_conf, 4),
            "qwen": qwen_review,
            "final_result": final_result,
            "needs_human_verification": needs_human,
            "warning": warning,
            "reason": reason,
            "disclaimer": DISCLAIMER_TEXT,
        }


def make_decision(
    primary_result: dict[str, Any],
    qwen_review: Optional[dict[str, Any]] = None,
    confidence_threshold: float = DEFAULT_CONFIDENCE_THRESHOLD,
) -> dict[str, Any]:
    """Helper function to execute the conservative DecisionEngine."""
    engine = DecisionEngine(confidence_threshold=confidence_threshold)
    return engine.evaluate(primary_result, qwen_review)

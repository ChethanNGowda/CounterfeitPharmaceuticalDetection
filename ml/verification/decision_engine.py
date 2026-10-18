"""Conservative Deterministic Decision Engine for Pharmaceutical Screening.

Authoritative decision-synthesis path combining predictions from the primary
visual classifier (EfficientNet-B0) and secondary AI verification (Qwen Vision / Ollama).

Standardized Output Contract:
- final_result: Exactly one of:
    * 'LIKELY AUTHENTIC'
    * 'LIKELY COUNTERFEIT'
    * 'SUSPICIOUS / NEEDS VERIFICATION'
- needs_human_verification: bool

Decision Rules:
1. Quality Screening Gate:
   - If image quality precheck fails (severe blur, low resolution, extreme exposure),
     final_result = 'SUSPICIOUS / NEEDS VERIFICATION', needs_human_verification = True.
2. Low Primary Confidence Gate (< screening threshold, default 0.70):
   - If primary confidence < 0.70 or prediction is UNKNOWN,
     final_result = 'SUSPICIOUS / NEEDS VERIFICATION', needs_human_verification = True.
3. Secondary AI Verification Available:
   - 3A. Corroborated Authentic (Primary AUTHENTIC + Secondary AUTHENTIC):
     final_result = 'LIKELY AUTHENTIC', needs_human_verification = False.
   - 3B. Corroborated Counterfeit (Primary COUNTERFEIT + Secondary COUNTERFEIT):
     final_result = 'LIKELY COUNTERFEIT', needs_human_verification = True (quarantine).
   - 3C. Explicit Conflict (AUTHENTIC vs COUNTERFEIT or vice versa):
     final_result = 'SUSPICIOUS / NEEDS VERIFICATION', needs_human_verification = True.
   - 3D. Secondary UNCERTAIN / INCONCLUSIVE:
     * If primary confidence >= high_confidence_threshold (default 0.90):
       Preserve primary classification label, but flag for manual review because secondary AI could not confirm:
       - Primary AUTHENTIC -> final_result = 'LIKELY AUTHENTIC', needs_human_verification = True.
       - Primary COUNTERFEIT -> final_result = 'LIKELY COUNTERFEIT', needs_human_verification = True.
     * If primary confidence < high_confidence_threshold (0.70 to 0.899):
       Uncorroborated moderate prediction -> final_result = 'SUSPICIOUS / NEEDS VERIFICATION',
       needs_human_verification = True.
   - 3E. Secondary SUSPICIOUS (explicit concern flagged by secondary reviewer):
     final_result = 'SUSPICIOUS / NEEDS VERIFICATION', needs_human_verification = True.
4. Secondary AI Unavailable / Fallback:
   4a. Secondary was invoked but failed (connection refused, timeout, error) — README §Qwen Vision graceful degradation:
       - Primary AUTHENTIC  (>= 0.70) -> final_result = 'LIKELY AUTHENTIC',   needs_human_verification = True.
       - Primary COUNTERFEIT(>= 0.70) -> final_result = 'LIKELY COUNTERFEIT', needs_human_verification = True.
   4b. Secondary was never invoked (vision_mode='never' or high-confidence auto skip):
       - Primary AUTHENTIC  (>= 0.70) -> final_result = 'LIKELY AUTHENTIC',   needs_human_verification = False.
       - Primary COUNTERFEIT(>= 0.70) -> final_result = 'LIKELY COUNTERFEIT', needs_human_verification = True.
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

    def evaluate(
        self,
        primary_result: dict[str, Any],
        qwen_review: Optional[dict[str, Any]] = None,
    ) -> dict[str, Any]:
        """Synthesize primary classifier metrics and secondary AI verification.

        Parameters
        ----------
        primary_result : dict
            Output from `predict()`.
        qwen_review : dict, optional
            Output from `QwenVisionVerifier.verify_image()` (production) or,
            for legacy use, `QwenReviewer.review_evidence()`.

        Returns
        -------
        dict
            Synthesized verdict matching the unified contract:
            final_result ('LIKELY AUTHENTIC' | 'LIKELY COUNTERFEIT' | 'SUSPICIOUS / NEEDS VERIFICATION'),
            needs_human_verification (bool), primary_model, prediction, confidence,
            qwen, reason, warning, disclaimer, disagreement (bool).
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

        # Normalize secondary AI review input
        secondary_executed = qwen_review is not None
        if qwen_review is None:
            qwen_payload = {
                "available": False,
                "assessment": "UNAVAILABLE",
                "confidence": 0.0,
                "reasoning": ["Secondary AI verification was not executed."],
                "needs_human_verification": True,
                "warning": "Secondary AI verification unavailable — result based on primary classifier.",
            }
            qwen_available = False
            qwen_assessment = "UNAVAILABLE"
        else:
            qwen_payload = dict(qwen_review)
            qwen_available = bool(
                qwen_review.get("available", False)
                and qwen_review.get("status") != "UNAVAILABLE"
            )
            qwen_assessment = str(qwen_review.get("assessment", "UNCERTAIN")).strip().upper()

        warning: Optional[str] = None
        disagreement = False

        # Rule 1: Quality Check Failed
        if not quality_is_valid:
            reason = f"Image quality check failed: {quality.get('reason', 'Poor quality')}"
            return {
                "final_result": "SUSPICIOUS / NEEDS VERIFICATION",
                "needs_human_verification": True,
                "primary_model": primary_model,
                "prediction": primary_pred,
                "primary_prediction": primary_pred,
                "confidence": round(primary_conf, 4),
                "primary_confidence": round(primary_conf, 4),
                "qwen": qwen_payload,
                "secondary_executed": secondary_executed,
                "secondary_available": qwen_available,
                "secondary_assessment": qwen_assessment,
                "disagreement": False,
                "warning": reason,
                "reason": reason,
                "reasons": [reason],
                "disclaimer": DISCLAIMER_TEXT,
                "final_status": "SUSPICIOUS / NEEDS VERIFICATION",
            }

        # Rule 2: Low Primary Confidence (< threshold) or UNKNOWN prediction
        if primary_conf < self.threshold or primary_pred == "UNKNOWN":
            reason = (
                f"Primary model confidence ({primary_conf*100:.1f}%) is below screening "
                f"threshold ({self.threshold*100:.1f}%). Requires physical laboratory inspection."
            )
            return {
                "final_result": "SUSPICIOUS / NEEDS VERIFICATION",
                "needs_human_verification": True,
                "primary_model": primary_model,
                "prediction": primary_pred,
                "primary_prediction": primary_pred,
                "confidence": round(primary_conf, 4),
                "primary_confidence": round(primary_conf, 4),
                "qwen": qwen_payload,
                "secondary_executed": secondary_executed,
                "secondary_available": qwen_available,
                "secondary_assessment": qwen_assessment,
                "disagreement": False,
                "warning": reason,
                "reason": reason,
                "reasons": [reason],
                "disclaimer": DISCLAIMER_TEXT,
                "final_status": "SUSPICIOUS / NEEDS VERIFICATION",
            }

        # Rule 3: High Primary Confidence (>= threshold) with Secondary AI Available
        if qwen_available:
            # 3A: Corroborated Authentic
            if primary_pred == "AUTHENTIC" and qwen_assessment == "AUTHENTIC":
                final_result = "LIKELY AUTHENTIC"
                needs_human = False
                reason = "Primary visual classifier and secondary AI review corroborate authentic evidence."

            # 3B: Corroborated Counterfeit
            elif primary_pred == "COUNTERFEIT" and qwen_assessment == "COUNTERFEIT":
                final_result = "LIKELY COUNTERFEIT"
                needs_human = True
                warning = "Evidence indicates counterfeit medicine. Quarantine sample."
                reason = "Both primary visual classifier and secondary AI review indicate counterfeit characteristics."

            # 3C: Explicit Conflict (Models disagree)
            elif (primary_pred == "AUTHENTIC" and qwen_assessment == "COUNTERFEIT") or (
                primary_pred == "COUNTERFEIT" and qwen_assessment == "AUTHENTIC"
            ):
                final_result = "SUSPICIOUS / NEEDS VERIFICATION"
                needs_human = True
                disagreement = True
                warning = (
                    f"Conflicting evidence: primary classifier predicts {primary_pred}, "
                    f"but secondary AI reviewer assessed {qwen_assessment}."
                )
                reason = warning

            # 3D: Secondary AI is UNCERTAIN (Non-contradictory visual uncertainty)
            elif qwen_assessment in ("UNCERTAIN", "INCONCLUSIVE"):
                if primary_conf >= self.high_threshold:
                    # High primary confidence (>= 90%) preserved as primary classification label,
                    # but requires manual verification because secondary AI could not confirm authenticity
                    if primary_pred == "AUTHENTIC":
                        final_result = "LIKELY AUTHENTIC"
                        needs_human = True
                        reason = (
                            f"Primary classifier has high confidence ({primary_conf*100:.1f}%) "
                            f"indicating authentic, but secondary AI visual assessment was uncertain "
                            f"and recommended manual review. Physical verification required."
                        )
                        warning = (
                            "Secondary AI visual assessment was uncertain; manual review required "
                            "to confirm authenticity despite high primary model confidence."
                        )
                    else:
                        final_result = "LIKELY COUNTERFEIT"
                        needs_human = True
                        reason = (
                            f"Primary classifier has high confidence ({primary_conf*100:.1f}%) "
                            f"indicating counterfeit; secondary AI visual assessment was uncertain "
                            f"(no contradictory evidence observed). Quarantine sample for verification."
                        )
                        warning = (
                            "Potential counterfeit identified with high primary confidence; "
                            "quarantine sample for laboratory inspection."
                        )
                else:
                    # Moderate primary confidence (70% - 89.9%) + uncertain secondary -> require verification
                    final_result = "SUSPICIOUS / NEEDS VERIFICATION"
                    needs_human = True
                    reason = (
                        f"Primary model confidence ({primary_conf*100:.1f}%) is moderate (below "
                        f"{self.high_threshold*100:.1f}% high-confidence threshold), and secondary "
                        f"AI was uncertain. Mandatory verification recommended."
                    )
                    warning = "Secondary AI assessment is uncertain; moderate primary confidence requires laboratory verification."

            # 3E: Secondary AI flagged SUSPICIOUS (explicit concern)
            elif qwen_assessment == "SUSPICIOUS":
                final_result = "SUSPICIOUS / NEEDS VERIFICATION"
                needs_human = True
                warning = "Secondary AI reviewer flagged evidence as suspicious or requiring additional verification."
                reason = warning

            # 3F: Any other unclassified state
            else:
                final_result = "SUSPICIOUS / NEEDS VERIFICATION"
                needs_human = True
                warning = f"Secondary AI returned unclassified assessment '{qwen_assessment}'."
                reason = warning

        else:
            # Rule 4: Secondary AI Unavailable / Fallback
            #
            # Two distinct sub-cases per README §Qwen Vision graceful degradation (line 298):
            #   4a. secondary_executed=True  (Qwen was invoked but failed — conn refused, timeout, error):
            #       needs_human_verification = True for ALL primary predictions, because secondary
            #       verification was expected and could not be completed.
            #   4b. secondary_executed=False (Qwen never invoked — vision_mode='never' or
            #       high-confidence auto skip by design):
            #       AUTHENTIC → needs_human = False  (README example JSON: secondary_executed=false,
            #       needs_human_verification=false)
            #       COUNTERFEIT → needs_human = True  (always conservative for counterfeit outcomes)
            if secondary_executed:
                # 4a: Attempted but failed
                warning = (
                    "Secondary AI verification was requested but failed (connection refused, "
                    "timeout, or error) — result based on primary classifier only. "
                    "Physical verification recommended."
                )
                if primary_pred == "AUTHENTIC":
                    final_result = "LIKELY AUTHENTIC"
                    needs_human = True
                    reason = (
                        f"Primary classifier indicates authentic ({primary_conf*100:.1f}% confidence); "
                        f"secondary verification was attempted but unavailable — manual review advised."
                    )
                else:
                    final_result = "LIKELY COUNTERFEIT"
                    needs_human = True
                    reason = (
                        f"Primary classifier indicates counterfeit ({primary_conf*100:.1f}% confidence); "
                        f"secondary verification unavailable. Quarantine sample for laboratory inspection."
                    )
            else:
                # 4b: Never invoked (by design — vision_mode='never' or high-confidence auto skip)
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
            "final_result": final_result,
            "needs_human_verification": needs_human,
            "primary_model": primary_model,
            "prediction": primary_pred,
            "primary_prediction": primary_pred,
            "confidence": round(primary_conf, 4),
            "primary_confidence": round(primary_conf, 4),
            "qwen": qwen_payload,
            "secondary_executed": secondary_executed,
            "secondary_available": qwen_available,
            "secondary_assessment": qwen_assessment,
            "disagreement": disagreement,
            "warning": warning,
            "reason": reason,
            "reasons": [reason] if reason else [],
            "disclaimer": DISCLAIMER_TEXT,
            # Backward-compatibility alias
            "final_status": final_result,
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

"""Unit tests for the conservative Decision Engine synthesis rules.

Tests the 4-rule deterministic system:
  Rule 1: Quality check failed → SUSPICIOUS / NEEDS VERIFICATION
  Rule 2: Low primary confidence (< 0.70) → SUSPICIOUS / NEEDS VERIFICATION
  Rule 3: High confidence + Qwen available → based on agreement / conflict
  Rule 4: High confidence + Qwen unavailable → primary classifier fallback
"""

import pytest
from ml.verification.decision_engine import DecisionEngine, make_decision


@pytest.fixture
def engine():
    return DecisionEngine(confidence_threshold=0.70)


# ---------------------------------------------------------------------------
# Helper factories for clean test inputs
# ---------------------------------------------------------------------------

def _primary(predicted_class="authentic", confidence=0.90, quality_valid=True, quality_reason=None):
    q = {"is_valid": quality_valid}
    if quality_reason:
        q["reason"] = quality_reason
    return {
        "model_name": "efficientnet_b0",
        "predicted_class": predicted_class,
        "confidence": confidence,
        "quality": q,
    }


def _qwen(available=True, assessment="AUTHENTIC", confidence=0.85, reasoning=None, needs_human=None):
    if reasoning is None:
        reasoning = ["Evidence reviewed by secondary AI."]
    if needs_human is None:
        needs_human = assessment != "AUTHENTIC"
    return {
        "available": available,
        "assessment": assessment,
        "confidence": confidence,
        "reasoning": reasoning,
        "needs_human_verification": needs_human,
        "warning": "Visual analysis cannot establish chemical authenticity.",
    }


def _unavailable_qwen(reason="Ollama timed out"):
    return {
        "available": False,
        "assessment": "SUSPICIOUS",
        "confidence": 0.0,
        "reasoning": [reason],
        "needs_human_verification": True,
        "warning": "Secondary AI verification unavailable — result based on primary classifier.",
    }


# ---------------------------------------------------------------------------
# Rule 1: Quality Check Failed
# ---------------------------------------------------------------------------

def test_rule1_quality_failed_returns_suspicious(engine):
    primary = _primary(predicted_class="counterfeit", confidence=0.99, quality_valid=False,
                       quality_reason="Image blur score 20 below minimum 50")
    result = engine.evaluate(primary, None)
    assert result["final_result"] == "SUSPICIOUS / NEEDS VERIFICATION"
    assert result["needs_human_verification"] is True
    assert "quality check failed" in result["reason"].lower()
    assert "disclaimer" in result
    assert "qwen" in result


def test_rule1_quality_failed_overrides_high_confidence(engine):
    """Even with 99% confidence and Qwen available, poor quality → SUSPICIOUS."""
    primary = _primary(predicted_class="authentic", confidence=0.99, quality_valid=False)
    qwen = _qwen(available=True, assessment="AUTHENTIC")
    result = engine.evaluate(primary, qwen)
    assert result["final_result"] == "SUSPICIOUS / NEEDS VERIFICATION"
    assert result["needs_human_verification"] is True


# ---------------------------------------------------------------------------
# Rule 2: Low Primary Confidence (< 0.70)
# ---------------------------------------------------------------------------

def test_rule2_low_confidence_returns_suspicious(engine):
    primary = _primary(predicted_class="authentic", confidence=0.58)
    qwen = _qwen(available=True, assessment="AUTHENTIC")
    result = engine.evaluate(primary, qwen)
    assert result["final_result"] == "SUSPICIOUS / NEEDS VERIFICATION"
    assert result["needs_human_verification"] is True
    assert "below" in result["reason"].lower()


def test_rule2_exactly_at_threshold_passes(engine):
    """confidence = 0.70 meets the threshold; should NOT trigger Rule 2."""
    primary = _primary(predicted_class="authentic", confidence=0.70)
    qwen = _qwen(available=True, assessment="AUTHENTIC")
    result = engine.evaluate(primary, qwen)
    assert result["final_result"] != "SUSPICIOUS / NEEDS VERIFICATION"


def test_rule2_just_below_threshold(engine):
    primary = _primary(predicted_class="counterfeit", confidence=0.6999)
    result = engine.evaluate(primary, None)
    assert result["final_result"] == "SUSPICIOUS / NEEDS VERIFICATION"


def test_rule2_unknown_pred_triggers_suspicious(engine):
    """An unknown/unparseable prediction class should escalate to SUSPICIOUS."""
    primary = {
        "model_name": "efficientnet_b0",
        "predicted_class": "garbage_label",
        "confidence": 0.95,
        "quality": {"is_valid": True},
    }
    result = engine.evaluate(primary, None)
    assert result["final_result"] == "SUSPICIOUS / NEEDS VERIFICATION"


# ---------------------------------------------------------------------------
# Rule 3: High Confidence + Qwen Available
# ---------------------------------------------------------------------------

def test_rule3_authentic_authentic_agreement(engine):
    """Both primary and Qwen say AUTHENTIC → LIKELY AUTHENTIC."""
    primary = _primary(predicted_class="authentic", confidence=0.88)
    qwen = _qwen(available=True, assessment="AUTHENTIC")
    result = engine.evaluate(primary, qwen)
    assert result["final_result"] == "LIKELY AUTHENTIC"
    assert result["needs_human_verification"] is False
    assert "corroborate" in result["reason"].lower()
    assert "disclaimer" in result


def test_rule3_counterfeit_counterfeit_agreement(engine):
    """Both primary and Qwen say COUNTERFEIT → LIKELY COUNTERFEIT."""
    primary = _primary(predicted_class="counterfeit", confidence=0.95)
    qwen = _qwen(available=True, assessment="COUNTERFEIT", confidence=0.90, needs_human=True)
    result = engine.evaluate(primary, qwen)
    assert result["final_result"] == "LIKELY COUNTERFEIT"
    assert result["needs_human_verification"] is True


def test_rule3_qwen_suspicious_escalates(engine):
    """Qwen returns SUSPICIOUS regardless of primary → SUSPICIOUS / NEEDS VERIFICATION."""
    primary = _primary(predicted_class="authentic", confidence=0.92)
    qwen = _qwen(available=True, assessment="SUSPICIOUS")
    result = engine.evaluate(primary, qwen)
    assert result["final_result"] == "SUSPICIOUS / NEEDS VERIFICATION"
    assert result["needs_human_verification"] is True


def test_rule3_conflict_authentic_vs_counterfeit_qwen(engine):
    """Primary says AUTHENTIC but Qwen says COUNTERFEIT → conflict → SUSPICIOUS."""
    primary = _primary(predicted_class="authentic", confidence=0.91)
    qwen = _qwen(available=True, assessment="COUNTERFEIT", confidence=0.80)
    result = engine.evaluate(primary, qwen)
    assert result["final_result"] == "SUSPICIOUS / NEEDS VERIFICATION"
    assert result["needs_human_verification"] is True
    assert "conflict" in result["reason"].lower() or "conflict" in result.get("warning", "").lower()


def test_rule3_conflict_counterfeit_vs_authentic_qwen(engine):
    """Primary says COUNTERFEIT but Qwen says AUTHENTIC → conflict → SUSPICIOUS."""
    primary = _primary(predicted_class="counterfeit", confidence=0.92)
    qwen = _qwen(available=True, assessment="AUTHENTIC", confidence=0.70)
    result = engine.evaluate(primary, qwen)
    assert result["final_result"] == "SUSPICIOUS / NEEDS VERIFICATION"
    assert result["needs_human_verification"] is True


# ---------------------------------------------------------------------------
# Rule 4: High Confidence + Qwen Unavailable
# ---------------------------------------------------------------------------

def test_rule4_unavailable_qwen_authentic_fallback(engine):
    """Qwen unavailable + primary AUTHENTIC → LIKELY AUTHENTIC with warning."""
    primary = _primary(predicted_class="authentic", confidence=0.91)
    qwen = _unavailable_qwen("Ollama service unreachable.")
    result = engine.evaluate(primary, qwen)
    assert result["final_result"] == "LIKELY AUTHENTIC"
    assert result["needs_human_verification"] is False
    assert "unavailable" in result["reason"].lower()
    assert result["warning"] is not None


def test_rule4_unavailable_qwen_counterfeit_fallback(engine):
    """Qwen unavailable + primary COUNTERFEIT → LIKELY COUNTERFEIT with warning."""
    primary = _primary(predicted_class="counterfeit", confidence=0.94)
    qwen = _unavailable_qwen("Ollama timed out after 20s.")
    result = engine.evaluate(primary, qwen)
    assert result["final_result"] == "LIKELY COUNTERFEIT"
    assert result["needs_human_verification"] is True
    assert "unavailable" in result["reason"].lower()


def test_rule4_none_qwen_review_is_treated_as_unavailable(engine):
    """Passing None as qwen_review should produce same fallback path as unavailable."""
    primary = _primary(predicted_class="authentic", confidence=0.85)
    result = engine.evaluate(primary, None)
    assert result["final_result"] == "LIKELY AUTHENTIC"
    assert result["qwen"]["available"] is False


# ---------------------------------------------------------------------------
# Output contract invariants (all paths)
# ---------------------------------------------------------------------------

REQUIRED_KEYS = {
    "primary_model", "prediction", "confidence",
    "qwen", "final_result", "needs_human_verification",
    "warning", "reason", "disclaimer",
}

VALID_FINAL_RESULTS = {
    "LIKELY AUTHENTIC",
    "LIKELY COUNTERFEIT",
    "SUSPICIOUS / NEEDS VERIFICATION",
}


@pytest.mark.parametrize("primary_class,qwen_assessment,conf", [
    ("authentic", "AUTHENTIC", 0.90),
    ("counterfeit", "COUNTERFEIT", 0.95),
    ("authentic", "SUSPICIOUS", 0.88),
    ("counterfeit", "AUTHENTIC", 0.87),
    ("authentic", "COUNTERFEIT", 0.91),
])
def test_output_contract_keys_always_present(engine, primary_class, qwen_assessment, conf):
    primary = _primary(predicted_class=primary_class, confidence=conf)
    qwen = _qwen(available=True, assessment=qwen_assessment)
    result = engine.evaluate(primary, qwen)
    assert REQUIRED_KEYS.issubset(result.keys()), f"Missing keys: {REQUIRED_KEYS - result.keys()}"
    assert result["final_result"] in VALID_FINAL_RESULTS
    assert 0.0 <= result["confidence"] <= 1.0
    assert result["primary_model"] == "efficientnet_b0"
    assert "disclaimer" in result


def test_make_decision_helper_function():
    """make_decision() convenience wrapper returns the same contract."""
    primary = _primary(predicted_class="authentic", confidence=0.88)
    qwen = _qwen(available=True, assessment="AUTHENTIC")
    result = make_decision(primary, qwen, confidence_threshold=0.70)
    assert REQUIRED_KEYS.issubset(result.keys())
    assert result["final_result"] == "LIKELY AUTHENTIC"
    assert result["primary_model"] == "efficientnet_b0"


def test_make_decision_no_qwen():
    """make_decision() with no qwen review triggers fallback."""
    primary = _primary(predicted_class="counterfeit", confidence=0.93)
    result = make_decision(primary)
    assert result["final_result"] == "LIKELY COUNTERFEIT"
    assert result["qwen"]["available"] is False


# ---------------------------------------------------------------------------
# Qwen UNCERTAIN Handling: Calibrated Rule 3D
# ---------------------------------------------------------------------------

def test_rule3d_qwen_uncertain_high_confidence_counterfeit_preserved(engine):
    """High-confidence primary counterfeit (>= 90%) preserved when Qwen is merely uncertain."""
    primary = _primary(predicted_class="counterfeit", confidence=0.96)
    qwen = _qwen(available=True, assessment="UNCERTAIN")
    result = engine.evaluate(primary, qwen)
    assert result["final_result"] == "LIKELY COUNTERFEIT"
    assert result["needs_human_verification"] is True
    assert "uncertain" in result["reason"].lower()


def test_rule3d_qwen_uncertain_high_confidence_authentic_preserved(engine):
    """High-confidence primary authentic (>= 90%) preserved when Qwen is merely uncertain."""
    primary = _primary(predicted_class="authentic", confidence=0.93)
    qwen = _qwen(available=True, assessment="UNCERTAIN")
    result = engine.evaluate(primary, qwen)
    assert result["final_result"] == "LIKELY AUTHENTIC"
    assert result["needs_human_verification"] is False
    assert "uncertain" in result["reason"].lower()


def test_rule3d_qwen_uncertain_moderate_confidence_escalates(engine):
    """Moderate primary confidence (< 90%) escalates to verification when Qwen is uncertain."""
    primary = _primary(predicted_class="counterfeit", confidence=0.78)
    qwen = _qwen(available=True, assessment="UNCERTAIN")
    result = engine.evaluate(primary, qwen)
    assert result["final_result"] == "SUSPICIOUS / NEEDS VERIFICATION"
    assert result["needs_human_verification"] is True
    assert "moderate" in result["reason"].lower()


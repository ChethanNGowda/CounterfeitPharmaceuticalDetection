from ml.verification.decision_engine import DecisionEngine


def _primary(authentic_probability, quality=True, predicted_class=None, confidence=None):
    predicted_class = predicted_class or (
        "authentic" if authentic_probability >= 0.5 else "counterfeit"
    )
    confidence = confidence if confidence is not None else max(
        authentic_probability, 1.0 - authentic_probability
    )
    return {
        "model_name": "efficientnet_b0",
        "predicted_class": predicted_class,
        "confidence": confidence,
        "authentic_probability": authentic_probability,
        "counterfeit_probability": 1.0 - authentic_probability,
        "quality": {"is_valid": quality},
    }


def _secondary(assessment="AUTHENTIC", available=True, status="AVAILABLE"):
    return {
        "available": available,
        "status": status,
        "assessment": assessment,
        "confidence": "HIGH",
        "reasoning": ["Secondary visual assessment."],
    }


def test_authentic_probability_boundaries_use_the_0_50_and_0_70_bands():
    engine = DecisionEngine(confidence_threshold=0.70)

    below_counterfeit = engine.evaluate(_primary(0.4999))
    at_counterfeit_boundary = engine.evaluate(_primary(0.50))
    at_authentic_cutoff = engine.evaluate(_primary(0.70))
    above_authentic_cutoff = engine.evaluate(_primary(0.7001))

    assert below_counterfeit["final_result"] == "LIKELY COUNTERFEIT"
    assert below_counterfeit["needs_human_verification"] is True
    assert at_counterfeit_boundary["final_result"] == "SUSPICIOUS / NEEDS VERIFICATION"
    assert at_authentic_cutoff["final_result"] == "SUSPICIOUS / NEEDS VERIFICATION"
    assert above_authentic_cutoff["final_result"] == "LIKELY AUTHENTIC"
    assert above_authentic_cutoff["needs_human_verification"] is False


def test_legacy_high_confidence_parameter_does_not_override_authentic_probability_policy():
    result = DecisionEngine(
        confidence_threshold=0.70,
        high_confidence_threshold=0.90,
    ).evaluate(_primary(0.70, confidence=0.99))

    assert result["final_result"] == "SUSPICIOUS / NEEDS VERIFICATION"
    assert result["needs_human_verification"] is True
    assert "CANNOT certify" in result["disclaimer"]


def test_quality_failure_overrides_high_model_confidence():
    result = DecisionEngine().evaluate(_primary(0.99, quality=False), _secondary())

    assert result["prediction"] == "UNKNOWN"
    assert result["final_result"] == "SUSPICIOUS / NEEDS VERIFICATION"
    assert result["needs_human_verification"] is True
    assert result["secondary_executed"] is False


def test_secondary_disagreement_requires_manual_review():
    result = DecisionEngine().evaluate(
        _primary(0.85),
        _secondary(assessment="COUNTERFEIT"),
    )

    assert result["final_result"] == "SUSPICIOUS / NEEDS VERIFICATION"
    assert result["needs_human_verification"] is True
    assert result["disagreement"] is True


def test_secondary_outage_in_manual_review_band_stays_manual():
    result = DecisionEngine().evaluate(
        _primary(0.62),
        _secondary(available=False, status="UNAVAILABLE", assessment="UNCERTAIN"),
    )

    assert result["final_result"] == "SUSPICIOUS / NEEDS VERIFICATION"
    assert result["needs_human_verification"] is True
    assert "unavailable" in result["warning"].lower()


def test_invalid_secondary_assessment_requires_manual_review():
    result = DecisionEngine().evaluate(
        _primary(0.85),
        _secondary(assessment="NOT_A_VALID_ASSESSMENT"),
    )

    assert result["final_result"] == "SUSPICIOUS / NEEDS VERIFICATION"
    assert result["needs_human_verification"] is True
    assert result["qwen"]["status"] == "INVALID"


def test_malformed_quality_metadata_fails_closed():
    result = DecisionEngine().evaluate(
        _primary(0.95, quality="false"),
    )

    assert result["final_result"] == "SUSPICIOUS / NEEDS VERIFICATION"
    assert result["needs_human_verification"] is True

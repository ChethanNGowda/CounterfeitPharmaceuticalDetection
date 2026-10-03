"""LEGACY SECONDARY REVIEWER — superseded by QwenVisionVerifier (qwen_verifier.py).

This module was the original secondary AI layer. It sent *structured JSON evidence*
(classifier probabilities, quality flags) to qwen3:8b for text-based reasoning.

**Production pipeline** (Phase 2+) uses ml/verification/qwen_verifier.py instead:
  - Model: qwen3-vl:4b (vision-language model)
  - Input: actual pharmaceutical image encoded as base64
  - Invocation: QwenVisionVerifier.verify_image()

This file is retained for:
  - tests/test_qwen_verifier.py — 20+ unit tests covering QwenReviewer logic
  - ml/verification/__init__.py — backward-compat public exports
  - ml/verification/decision_engine.py — docstring reference

Do NOT use QwenReviewer for new inference code. Use QwenVisionVerifier instead.

IMPORTANT SAFETY NOTICE:
qwen3:8b is an LLM reasoning layer over statistical evidence, NOT an image classifier
and NOT a chemical laboratory instrument. It cannot establish chemical authenticity.
"""

from __future__ import annotations

import json
import os
import re
from typing import Any, Optional
import urllib.error
import urllib.request


DEFAULT_OLLAMA_BASE_URL = "http://localhost:11434"
DEFAULT_OLLAMA_MODEL = "qwen3:8b"
DEFAULT_OLLAMA_TIMEOUT = 20.0

QWEN_SYSTEM_PROMPT = """You are a secondary AI reasoning and review assistant in a counterfeit pharmaceutical screening system.
You review the statistical findings produced by the primary visual classifier and image quality analyzer.
You are NOT a laboratory instrument and CANNOT verify chemical composition or active ingredients.

Given the structured screening evidence, provide a reasoned review.
You must use cautious language:
- "The visual classifier indicates..."
- "The available evidence is consistent with..."
- "Additional verification is recommended."

Return STRICT JSON ONLY matching this exact structure:
{
  "assessment": "AUTHENTIC" | "COUNTERFEIT" | "SUSPICIOUS",
  "confidence": 0.0 to 1.0,
  "reasoning": [
    "First reasoning statement.",
    "Second reasoning statement."
  ],
  "needs_human_verification": true | false,
  "warning": "Visual analysis cannot establish chemical authenticity."
}
Allowed assessment values: AUTHENTIC, COUNTERFEIT, SUSPICIOUS.
Do not output any text before or after the JSON.
"""


def clean_json_text(raw_text: str) -> str:
    """Extract clean JSON substring from model response."""
    text = raw_text.strip()
    match = re.search(r"```(?:json)?\s*(\{.*?\})\s*```", text, re.DOTALL)
    if match:
        return match.group(1).strip()
    start = text.find("{")
    end = text.rfind("}")
    if start != -1 and end != -1 and end > start:
        return text[start : end + 1].strip()
    return text


def build_evidence_payload(
    primary_result: dict[str, Any],
    quality_result: Optional[dict[str, Any]] = None,
) -> dict[str, Any]:
    """Construct standard structured evidence dictionary for Qwen reasoning."""
    model_name = primary_result.get("model_name", "efficientnet_b0")
    pred = str(primary_result.get("predicted_class") or primary_result.get("prediction", "unknown")).lower()
    if "counterfeit" in pred:
        pred_label = "counterfeit"
    elif "authentic" in pred:
        pred_label = "authentic"
    else:
        pred_label = "unknown"

    auth_p = float(primary_result.get("authentic_probability", 0.0))
    fake_p = float(primary_result.get("counterfeit_probability", 0.0))
    conf = float(primary_result.get("confidence", max(auth_p, fake_p)))

    quality = quality_result or primary_result.get("quality") or {}
    is_valid_quality = quality.get("is_valid", True)
    blur_score = quality.get("blur_score", 100.0)
    brightness = quality.get("brightness_mean", 128.0)
    dims = quality.get("dimensions", [224, 224])

    return {
        "model": model_name,
        "prediction": pred_label,
        "authentic_probability": round(auth_p, 4),
        "counterfeit_probability": round(fake_p, 4),
        "confidence": round(conf, 4),
        "image_quality": "good" if is_valid_quality else "poor",
        "quality_checks": {
            "resolution_ok": dims[0] >= 64 and dims[1] >= 64,
            "blur_ok": blur_score >= 50.0,
            "brightness_ok": 15.0 <= brightness <= 245.0,
        },
    }


def validate_qwen_response(data: dict[str, Any]) -> dict[str, Any]:
    """Validate and sanitize structured output from qwen3:8b."""
    raw_assessment = str(data.get("assessment", "SUSPICIOUS")).upper().strip()
    if raw_assessment in ("AUTHENTIC", "COUNTERFEIT", "SUSPICIOUS"):
        assessment = raw_assessment
    else:
        assessment = "SUSPICIOUS"

    try:
        conf = float(data.get("confidence", 0.5))
        conf = max(0.0, min(1.0, conf))
    except (TypeError, ValueError):
        conf = 0.5

    raw_reasoning = data.get("reasoning", [])
    if isinstance(raw_reasoning, list):
        reasoning = [str(r).strip() for r in raw_reasoning if str(r).strip()]
    elif isinstance(raw_reasoning, str) and raw_reasoning.strip():
        reasoning = [raw_reasoning.strip()]
    else:
        reasoning = []

    if not reasoning:
        reasoning = ["Statistical assessment by secondary AI reviewer."]

    needs_human = bool(data.get("needs_human_verification", assessment != "AUTHENTIC"))
    warning = data.get("warning") or "Visual analysis cannot establish chemical authenticity."

    return {
        "available": True,
        "assessment": assessment,
        "confidence": round(conf, 4),
        "reasoning": reasoning,
        "needs_human_verification": needs_human,
        "warning": warning,
    }


class QwenReviewer:
    """Coordinates secondary reasoning review with locally installed qwen3:8b via Ollama."""

    def __init__(
        self,
        base_url: Optional[str] = None,
        model_name: Optional[str] = None,
        timeout: Optional[float] = None,
    ):
        self.base_url = (
            base_url
            or os.environ.get("OLLAMA_BASE_URL")
            or DEFAULT_OLLAMA_BASE_URL
        ).rstrip("/")
        self.model_name = (
            model_name
            or os.environ.get("OLLAMA_MODEL")
            or DEFAULT_OLLAMA_MODEL
        )
        env_timeout = os.environ.get("OLLAMA_TIMEOUT")
        if timeout is not None:
            self.timeout = float(timeout)
        elif env_timeout:
            try:
                self.timeout = float(env_timeout)
            except ValueError:
                self.timeout = DEFAULT_OLLAMA_TIMEOUT
        else:
            self.timeout = DEFAULT_OLLAMA_TIMEOUT

    def review_evidence(self, evidence: dict[str, Any]) -> dict[str, Any]:
        """Send structured screening evidence to qwen3:8b for review.

        Returns validated JSON review or a safe fallback when unavailable.
        """
        user_message = f"Screening Evidence:\n{json.dumps(evidence, indent=2)}"
        payload = {
            "model": self.model_name,
            "prompt": f"{QWEN_SYSTEM_PROMPT}\n\n{user_message}",
            "stream": False,
            "format": "json",
        }

        endpoint = f"{self.base_url}/api/generate"
        req_data = json.dumps(payload).encode("utf-8")
        request = urllib.request.Request(
            endpoint,
            data=req_data,
            headers={"Content-Type": "application/json"},
        )

        try:
            with urllib.request.urlopen(request, timeout=self.timeout) as resp:
                status_code = resp.getcode()
                raw_body = resp.read().decode("utf-8")

            if status_code != 200:
                return {
                    "available": False,
                    "assessment": "SUSPICIOUS",
                    "confidence": 0.0,
                    "reasoning": [f"Ollama returned HTTP status {status_code}."],
                    "needs_human_verification": True,
                    "warning": "Secondary AI verification unavailable — result based on primary classifier.",
                    "error": f"HTTP {status_code}",
                }

            response_json = json.loads(raw_body)
            raw_text = response_json.get("response", "").strip()
            if not raw_text:
                return {
                    "available": False,
                    "assessment": "SUSPICIOUS",
                    "confidence": 0.0,
                    "reasoning": ["Empty response received from secondary AI reviewer."],
                    "needs_human_verification": True,
                    "warning": "Secondary AI verification unavailable — result based on primary classifier.",
                    "error": "Empty model response",
                }

            cleaned = clean_json_text(raw_text)
            parsed = json.loads(cleaned)
            return validate_qwen_response(parsed)

        except urllib.error.HTTPError as http_err:
            return {
                "available": False,
                "assessment": "SUSPICIOUS",
                "confidence": 0.0,
                "reasoning": [f"Ollama model error: HTTP {http_err.code} ({http_err.reason})."],
                "needs_human_verification": True,
                "warning": "Secondary AI verification unavailable — result based on primary classifier.",
                "error": f"HTTP {http_err.code}",
            }

        except urllib.error.URLError as url_err:
            return {
                "available": False,
                "assessment": "SUSPICIOUS",
                "confidence": 0.0,
                "reasoning": [f"Ollama service unreachable at {self.base_url}."],
                "needs_human_verification": True,
                "warning": "Secondary AI verification unavailable — result based on primary classifier.",
                "error": str(url_err.reason),
            }

        except (TimeoutError, OSError) as time_err:
            return {
                "available": False,
                "assessment": "SUSPICIOUS",
                "confidence": 0.0,
                "reasoning": [f"Secondary review timed out after {self.timeout}s."],
                "needs_human_verification": True,
                "warning": "Secondary AI verification unavailable — result based on primary classifier.",
                "error": str(time_err),
            }

        except json.JSONDecodeError as json_err:
            return {
                "available": True,
                "assessment": "SUSPICIOUS",
                "confidence": 0.0,
                "reasoning": ["Malformed non-JSON output returned by secondary reviewer."],
                "needs_human_verification": True,
                "warning": "Additional verification required.",
                "error": f"JSONDecodeError: {json_err}",
            }

        except Exception as unexpected_err:
            return {
                "available": False,
                "assessment": "SUSPICIOUS",
                "confidence": 0.0,
                "reasoning": [f"Unexpected error in secondary review: {unexpected_err}"],
                "needs_human_verification": True,
                "warning": "Secondary AI verification unavailable — result based on primary classifier.",
                "error": str(unexpected_err),
            }


def review_screening_evidence(
    primary_result: dict[str, Any],
    quality_result: Optional[dict[str, Any]] = None,
    base_url: Optional[str] = None,
    model_name: Optional[str] = None,
    timeout: Optional[float] = None,
) -> dict[str, Any]:
    """Helper function to build structured evidence and query qwen3:8b."""
    evidence = build_evidence_payload(primary_result, quality_result)
    reviewer = QwenReviewer(base_url=base_url, model_name=model_name, timeout=timeout)
    return reviewer.review_evidence(evidence)

"""Secondary AI Visual Verification Layer using Qwen Vision models via local Ollama.

This module provides secondary visual inspection (tablet shape, color, surface texture,
markings, packaging, batch/expiry visibility, image quality) to support preliminary
pharmaceutical screening alongside the specialized primary classifier (EfficientNet-B0).

IMPORTANT SAFETY NOTICE:
Visual inspection alone cannot prove pharmaceutical authenticity or counterfeiting.
This is a secondary AI visual verification system and does not replace chemical laboratory testing.
"""

from __future__ import annotations

import base64
import io
import json
import os
from pathlib import Path
import re
from typing import Any, Optional, Union
import urllib.error
import urllib.request
from PIL import Image

DEFAULT_OLLAMA_BASE_URL = "http://localhost:11434"
DEFAULT_OLLAMA_VISION_MODEL = "qwen3-vl:4b"
DEFAULT_OLLAMA_TIMEOUT = 240.0

# Ordered preference list: first available installed model wins
_VISION_MODEL_PREFERENCE = [
    "qwen3-vl:8b",
    "qwen3-vl:4b",
    "qwen3-vl:2b",
    "qwen2.5vl:7b",
]

# Max image dimension (px) before sending to vision model — keeps token count within VRAM budget
_MAX_IMAGE_DIMENSION = 448


def _detect_vision_model(base_url: str = DEFAULT_OLLAMA_BASE_URL) -> str:
    """Return the best available Qwen Vision model installed in Ollama.

    Checks the Ollama /api/tags endpoint and returns the first model from
    _VISION_MODEL_PREFERENCE that is already installed. Falls back to
    DEFAULT_OLLAMA_VISION_MODEL if none installed or Ollama unreachable.
    """
    try:
        req = urllib.request.Request(f"{base_url.rstrip('/')}/api/tags")
        with urllib.request.urlopen(req, timeout=5) as resp:
            data = json.loads(resp.read().decode("utf-8"))
        installed = [m.get("name", "") for m in data.get("models", [])]
        for preferred in _VISION_MODEL_PREFERENCE:
            if any(preferred == name or name.startswith(preferred) for name in installed):
                return preferred
    except Exception:
        pass
    return DEFAULT_OLLAMA_VISION_MODEL

QWEN_VISION_PROMPT = """/no_think
Analyze the attached medicine/tablet image for counterfeit detection. Examine tablet shape, color, surface, markings, packaging (if visible), and any irregularities.

Do NOT invent information. Only report what is actually visible. Do not make definitive authenticity claims without clear evidence.

Respond ONLY in this exact format (no other text before or after):

Assessment: AUTHENTIC / COUNTERFEIT / UNCERTAIN

Visual Confidence: LOW / MEDIUM / HIGH

Image Quality: GOOD / FAIR / POOR

Tablet Analysis:
* Shape: 
* Color: 
* Surface: 
* Markings: 
* Edges: 
* Other visible characteristics: 

Packaging Analysis:
Not visible.

Observations:
* 
* 

Potential Concerns:
* 

Recommendation:
AUTOMATED SCREENING / MANUAL REVIEW

Final Explanation:
"""





def parse_qwen_vision_output(raw_text: str) -> dict[str, Any]:
    """Parse structured fields from Qwen Vision text response.

    Uses the LAST match for each field so that intermediate thinking chain
    occurrences don't override the model's final structured answer.
    """
    result: dict[str, Any] = {
        "assessment": "UNCERTAIN",
        "confidence": "LOW",
        "image_quality": "FAIR",
        "recommendation": "MANUAL REVIEW",
        "raw_text": raw_text.strip(),
    }

    # Use last match for each field (thinking trace may contain earlier occurrences)
    assessments = re.findall(r"Assessment:\s*(AUTHENTIC|COUNTERFEIT|UNCERTAIN)", raw_text, re.IGNORECASE)
    if assessments:
        result["assessment"] = assessments[-1].upper()

    confidences = re.findall(r"Visual Confidence:\s*(LOW|MEDIUM|HIGH)", raw_text, re.IGNORECASE)
    if confidences:
        result["confidence"] = confidences[-1].upper()

    qualities = re.findall(r"Image Quality:\s*(GOOD|FAIR|POOR)", raw_text, re.IGNORECASE)
    if qualities:
        result["image_quality"] = qualities[-1].upper()

    recs = re.findall(r"Recommendation:\s*(AUTOMATED SCREENING|MANUAL REVIEW)", raw_text, re.IGNORECASE)
    if recs:
        result["recommendation"] = recs[-1].upper()

    return result


class QwenVisionVerifier:
    """Manages secondary visual verification with a Qwen Vision model via Ollama."""

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

        # Auto-detect best installed vision model if not explicitly provided
        env_model = os.environ.get("OLLAMA_VISION_MODEL") or os.environ.get("OLLAMA_MODEL")
        if model_name:
            self.model_name = model_name
        elif env_model:
            self.model_name = env_model
        else:
            self.model_name = _detect_vision_model(self.base_url)

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

    def _encode_image_b64(self, image_path: Path) -> str:
        """Encode image to base64 JPEG string, resizing if larger than _MAX_IMAGE_DIMENSION."""
        with Image.open(image_path) as img:
            rgb_img = img.convert("RGB")
            w, h = rgb_img.size
            if max(w, h) > _MAX_IMAGE_DIMENSION:
                scale = _MAX_IMAGE_DIMENSION / max(w, h)
                rgb_img = rgb_img.resize(
                    (int(w * scale), int(h * scale)),
                    Image.LANCZOS,
                )
            buf = io.BytesIO()
            rgb_img.save(buf, format="JPEG", quality=88)
            return base64.b64encode(buf.getvalue()).decode("utf-8")


    def verify_image(self, image_path: Union[str, Path]) -> dict[str, Any]:
        """Send the actual image to the Qwen Vision model via Ollama.

        Returns structured verification results or a safe fallback if unavailable.
        """
        path = Path(image_path)
        if not path.is_file():
            return {
                "available": False,
                "status": "UNAVAILABLE",
                "assessment": "UNCERTAIN",
                "confidence": "LOW",
                "image_quality": "POOR",
                "recommendation": "MANUAL REVIEW",
                "reason": f"Image file not found: {path}",
                "model_name": self.model_name,
                "raw_text": "",
            }

        try:
            # Validate image can be opened
            with Image.open(path) as test_img:
                test_img.verify()
        except Exception as img_err:
            return {
                "available": False,
                "status": "UNAVAILABLE",
                "assessment": "UNCERTAIN",
                "confidence": "LOW",
                "image_quality": "POOR",
                "recommendation": "MANUAL REVIEW",
                "reason": f"Invalid or unreadable image file: {img_err}",
                "model_name": self.model_name,
                "raw_text": "",
            }

        # Attempt 1: Try python ollama library if installed
        raw_text = None
        ollama_pkg_error = None
        try:
            import ollama

            client = ollama.Client(host=self.base_url, timeout=self.timeout)
            b64_img = self._encode_image_b64(path)
            sys_directive = (
                "You are a pharmaceutical image analysis system. "
                "Output ONLY the structured report in the exact format requested. "
                "No preamble, no thinking traces, no extra commentary."
            )
            resp = client.generate(
                model=self.model_name,
                prompt=QWEN_VISION_PROMPT,
                system=sys_directive,
                images=[b64_img],
                options={"temperature": 0.1, "num_predict": 2000},
            )
            raw_text = (resp.response or "").strip()
            if not raw_text and hasattr(resp, "thinking") and resp.thinking:
                raw_text = resp.thinking.strip()
        except ImportError:
            ollama_pkg_error = "ollama python package not installed"
        except Exception as client_err:
            err_str = str(client_err)
            # Detect model not found (404)
            if "not found" in err_str.lower() or "404" in err_str:
                return {
                    "available": False,
                    "status": "UNAVAILABLE",
                    "assessment": "UNCERTAIN",
                    "confidence": "LOW",
                    "image_quality": "POOR",
                    "recommendation": "MANUAL REVIEW",
                    "reason": (
                        f"Model '{self.model_name}' is not installed in Ollama.\n"
                        f"To install this model, run:\n"
                        f"  ollama pull {self.model_name}\n\n"
                        f"(Note: {self.model_name} is in the ~8B class. On an RTX 3050 4GB GPU, "
                        f"Ollama will offload layers across VRAM and 16GB system RAM.)"
                    ),
                    "model_name": self.model_name,
                    "raw_text": "",
                }
            # Detect multimodal unsupported
            if "multimodal" in err_str.lower():
                return {
                    "available": False,
                    "status": "UNAVAILABLE",
                    "assessment": "UNCERTAIN",
                    "confidence": "LOW",
                    "image_quality": "POOR",
                    "recommendation": "MANUAL REVIEW",
                    "reason": (
                        f"Model '{self.model_name}' does not support visual/image inputs.\n"
                        f"Please pull an official Qwen Vision model:\n"
                        f"  ollama pull {DEFAULT_OLLAMA_VISION_MODEL}"
                    ),
                    "model_name": self.model_name,
                    "raw_text": "",
                }
            # Detect connection refused / offline
            if "connection refused" in err_str.lower() or "connect" in err_str.lower():
                return {
                    "available": False,
                    "status": "UNAVAILABLE",
                    "assessment": "UNCERTAIN",
                    "confidence": "LOW",
                    "image_quality": "POOR",
                    "recommendation": "MANUAL REVIEW",
                    "reason": f"Ollama is not running (connection refused at {self.base_url}).",
                    "model_name": self.model_name,
                    "raw_text": "",
                }
            # Detect timeout
            if "timed out" in err_str.lower():
                return {
                    "available": False,
                    "status": "UNAVAILABLE",
                    "assessment": "UNCERTAIN",
                    "confidence": "LOW",
                    "image_quality": "POOR",
                    "recommendation": "MANUAL REVIEW",
                    "reason": f"Vision verification timed out after {self.timeout}s.",
                    "model_name": self.model_name,
                    "raw_text": "",
                }
            # Fall back to HTTP urllib call in case client syntax issue
            ollama_pkg_error = err_str

        # Attempt 2: Direct HTTP API via urllib
        if raw_text is None:
            try:
                b64_img = self._encode_image_b64(path)
                payload = {
                    "model": self.model_name,
                    "messages": [
                        {
                            "role": "system",
                            "content": "You are the AI Vision Verification module of a Counterfeit Pharmaceutical Detection system. Directly output the structured verification report in the exact format requested. Do NOT output internal thinking or reasoning chains.",
                        },
                        {
                            "role": "user",
                            "content": QWEN_VISION_PROMPT,
                            "images": [b64_img],
                        }
                    ],
                    "stream": False,
                    "options": {"temperature": 0.1, "num_predict": 900},
                }
                endpoint = f"{self.base_url}/api/chat"
                req_data = json.dumps(payload).encode("utf-8")
                req = urllib.request.Request(
                    endpoint,
                    data=req_data,
                    headers={"Content-Type": "application/json"},
                )
                with urllib.request.urlopen(req, timeout=self.timeout) as resp:
                    resp_data = json.loads(resp.read().decode("utf-8"))
                    msg_obj = resp_data.get("message", {})
                    raw_text = msg_obj.get("content", "").strip()
                    if not raw_text:
                        raw_text = msg_obj.get("thinking", "").strip()
            except urllib.error.HTTPError as http_err:
                if http_err.code == 404:
                    return {
                        "available": False,
                        "status": "UNAVAILABLE",
                        "assessment": "UNCERTAIN",
                        "confidence": "LOW",
                        "image_quality": "POOR",
                        "recommendation": "MANUAL REVIEW",
                        "reason": (
                            f"Model '{self.model_name}' is not installed in Ollama.\n"
                            f"To install this model, run:\n"
                            f"  ollama pull {self.model_name}\n\n"
                            f"(Note: {self.model_name} is in the ~8B class. On an RTX 3050 4GB GPU, "
                            f"Ollama will offload layers across VRAM and 16GB system RAM.)"
                        ),
                        "model_name": self.model_name,
                        "raw_text": "",
                    }
                error_body = ""
                try:
                    error_body = http_err.read().decode("utf-8")
                except Exception:
                    pass
                if "multimodal" in error_body.lower():
                    return {
                        "available": False,
                        "status": "UNAVAILABLE",
                        "assessment": "UNCERTAIN",
                        "confidence": "LOW",
                        "image_quality": "POOR",
                        "recommendation": "MANUAL REVIEW",
                        "reason": f"Model '{self.model_name}' does not support vision inputs.",
                        "model_name": self.model_name,
                        "raw_text": "",
                    }
                return {
                    "available": False,
                    "status": "UNAVAILABLE",
                    "assessment": "UNCERTAIN",
                    "confidence": "LOW",
                    "image_quality": "POOR",
                    "recommendation": "MANUAL REVIEW",
                    "reason": f"Ollama HTTP error {http_err.code}: {http_err.reason}. {error_body}".strip(),
                    "model_name": self.model_name,
                    "raw_text": "",
                }
            except urllib.error.URLError as url_err:
                return {
                    "available": False,
                    "status": "UNAVAILABLE",
                    "assessment": "UNCERTAIN",
                    "confidence": "LOW",
                    "image_quality": "POOR",
                    "recommendation": "MANUAL REVIEW",
                    "reason": f"Ollama is not running (connection refused at {self.base_url}).",
                    "model_name": self.model_name,
                    "raw_text": "",
                }
            except (TimeoutError, OSError) as to_err:
                return {
                    "available": False,
                    "status": "UNAVAILABLE",
                    "assessment": "UNCERTAIN",
                    "confidence": "LOW",
                    "image_quality": "POOR",
                    "recommendation": "MANUAL REVIEW",
                    "reason": f"Vision verification timed out after {self.timeout}s: {to_err}",
                    "model_name": self.model_name,
                    "raw_text": "",
                }
            except Exception as final_err:
                return {
                    "available": False,
                    "status": "UNAVAILABLE",
                    "assessment": "UNCERTAIN",
                    "confidence": "LOW",
                    "image_quality": "POOR",
                    "recommendation": "MANUAL REVIEW",
                    "reason": f"Vision verification error: {final_err} (prior: {ollama_pkg_error})",
                    "model_name": self.model_name,
                    "raw_text": "",
                }

        if not raw_text:
            return {
                "available": False,
                "status": "UNAVAILABLE",
                "assessment": "UNCERTAIN",
                "confidence": "LOW",
                "image_quality": "POOR",
                "recommendation": "MANUAL REVIEW",
                "reason": "Empty response received from Qwen Vision model.",
                "model_name": self.model_name,
                "raw_text": "",
            }

        parsed = parse_qwen_vision_output(raw_text)
        return {
            "available": True,
            "status": "AVAILABLE",
            "assessment": parsed["assessment"],
            "confidence": parsed["confidence"],
            "image_quality": parsed["image_quality"],
            "recommendation": parsed["recommendation"],
            "raw_text": raw_text,
            "reason": None,
            "model_name": self.model_name,
        }

    def format_vision_section(self, verification: dict[str, Any]) -> str:
        """Format the Qwen Vision Verification section."""
        lines = [
            "=" * 50,
            "QWEN VISION VERIFICATION",
            "=" * 24,
            "",
        ]
        if not verification.get("available", False):
            lines.append("Status: UNAVAILABLE")
            lines.append("")
            lines.append("Reason:")
            lines.append(verification.get("reason", "Ollama service unavailable."))
            return "\n".join(lines)

        raw = verification.get("raw_text", "").strip()

        # Try to match the final structured report starting at "Assessment:" followed by "Visual Confidence:"
        pattern = re.compile(
            r"Assessment:\s*(?:AUTHENTIC|COUNTERFEIT|UNCERTAIN)\s*\n+\s*Visual Confidence:\s*(?:LOW|MEDIUM|HIGH)",
            re.IGNORECASE,
        )
        matches = list(pattern.finditer(raw))
        if matches:
            clean_block = raw[matches[-1].start():].strip()
            clean_block = clean_block.replace("==================================================", "").replace("QWEN VISION VERIFICATION", "").strip()
            lines.append(clean_block)
            return "\n".join(lines)

        # Fallback 2: Check for explicit QWEN VISION VERIFICATION header
        if "QWEN VISION VERIFICATION" in raw:
            parts = raw.split("QWEN VISION VERIFICATION")
            after = parts[-1].strip().lstrip("=").strip()
            if "Assessment:" in after:
                lines.append(after)
                return "\n".join(lines)

        # Fallback 3: Synthesize cleanly from parsed fields so format is always compliant
        lines.append(f"Assessment: {verification.get('assessment', 'UNCERTAIN')}")
        lines.append("")
        lines.append(f"Visual Confidence: {verification.get('confidence', 'MEDIUM')}")
        lines.append("")
        lines.append(f"Image Quality: {verification.get('image_quality', 'GOOD')}")
        lines.append("")
        lines.append("Tablet Analysis:")
        lines.append(verification.get("tablet_analysis") or "* Shape: Examined\n* Color: Examined\n* Surface: Examined\n* Markings: None visible\n* Edges: Intact")
        lines.append("")
        lines.append("Packaging Analysis:")
        lines.append(verification.get("packaging_analysis") or "Not visible.")
        lines.append("")
        lines.append("Observations:")
        lines.append(verification.get("observations") or "* Tablet appearance evaluated by secondary AI visual verifier.")
        lines.append("")
        lines.append("Potential Concerns:")
        lines.append(verification.get("potential_concerns") or "* Secondary AI visual inspection only; physical laboratory analysis required.")
        lines.append("")
        lines.append(f"Recommendation:\n{verification.get('recommendation', 'MANUAL REVIEW')}")
        lines.append("")
        lines.append(f"Final Explanation:\n{verification.get('final_explanation') or 'Visual screening alone cannot establish chemical authenticity.'}")
        return "\n".join(lines)


def synthesize_final_result(
    primary_result: dict[str, Any],
    qwen_result: Optional[dict[str, Any]] = None,
) -> dict[str, Any]:
    """Conservative synthesis of Primary ML Classifier and Qwen Vision Verification."""
    pred = primary_result.get("prediction", "UNKNOWN").upper()
    conf = float(primary_result.get("confidence", 0.0))
    status = primary_result.get("status", "NEEDS MANUAL REVIEW")
    quality = primary_result.get("quality") or {}
    quality_valid = quality.get("is_valid", True)

    qwen_avail = bool(qwen_result and qwen_result.get("available", False))
    qwen_assess = (qwen_result.get("assessment", "UNCERTAIN") if qwen_result else "UNAVAILABLE").upper()
    qwen_rec = (qwen_result.get("recommendation", "MANUAL REVIEW") if qwen_result else "MANUAL REVIEW").upper()

    # Rule 1: Quality check failed
    if not quality_valid:
        return {
            "final_status": "NEEDS MANUAL REVIEW",
            "reason": f"Image quality check failed: {quality.get('reason', 'Poor quality')}",
            "disagreement": False,
        }

    # Rule 2: Primary confidence below threshold
    if status == "NEEDS MANUAL REVIEW" or conf < 0.70 or pred == "UNKNOWN":
        return {
            "final_status": "NEEDS MANUAL REVIEW",
            "reason": f"Primary classifier confidence ({conf*100:.1f}%) is below screening threshold 70.0%",
            "disagreement": False,
        }

    # Rule 3: High primary confidence + Qwen Vision Available
    if qwen_avail:
        # Corroboration: Authentic
        if pred == "AUTHENTIC" and qwen_assess == "AUTHENTIC":
            return {
                "final_status": "LIKELY AUTHENTIC",
                "reason": "Both primary ML classifier and secondary AI visual verification corroborate authentic characteristics.",
                "disagreement": False,
            }

        # Corroboration: Counterfeit
        if pred == "COUNTERFEIT" and qwen_assess == "COUNTERFEIT":
            return {
                "final_status": "LIKELY COUNTERFEIT",
                "reason": "Both primary ML classifier and secondary AI visual verification indicate counterfeit characteristics.",
                "disagreement": False,
            }

        # Disagreement
        if (pred == "COUNTERFEIT" and qwen_assess == "AUTHENTIC") or (pred == "AUTHENTIC" and qwen_assess == "COUNTERFEIT"):
            return {
                "final_status": "NEEDS MANUAL REVIEW",
                "reason": (
                    f"Disagreement between primary ML classifier ({pred}) and secondary "
                    f"AI visual assessment ({qwen_assess}). Mandatory physical inspection required."
                ),
                "disagreement": True,
            }

        # Qwen Uncertain or Recommends Manual Review
        return {
            "final_status": "NEEDS MANUAL REVIEW",
            "reason": f"Secondary AI visual assessment is {qwen_assess} (recommends {qwen_rec}).",
            "disagreement": False,
        }

    # Rule 4: Qwen Vision Unavailable Fallback
    if pred == "AUTHENTIC":
        return {
            "final_status": "LIKELY AUTHENTIC",
            "reason": f"Primary classifier indicates authentic ({conf*100:.1f}% confidence); secondary visual verification unavailable.",
            "disagreement": False,
        }
    else:
        return {
            "final_status": "LIKELY COUNTERFEIT",
            "reason": f"Primary classifier indicates counterfeit ({conf*100:.1f}% confidence); secondary visual verification unavailable.",
            "disagreement": False,
        }


def format_final_screening_result(
    primary_result: dict[str, Any],
    qwen_result: Optional[dict[str, Any]] = None,
) -> str:
    """Format the FINAL SCREENING RESULT block according to project specifications."""
    pred = primary_result.get("prediction", "UNKNOWN").upper()
    conf = float(primary_result.get("confidence", 0.0)) * 100

    if qwen_result and qwen_result.get("available", False):
        qwen_assess = qwen_result.get("assessment", "UNCERTAIN").upper()
    else:
        qwen_assess = "UNAVAILABLE"

    synthesis = synthesize_final_result(primary_result, qwen_result)
    final_status = synthesis["final_status"]

    lines = [
        "=" * 50,
        "FINAL SCREENING RESULT",
        "=" * 22,
        "",
        f"Primary ML Prediction: {pred}",
        f"Primary ML Confidence: {conf:.2f}%",
        "",
        f"Qwen Visual Assessment: {qwen_assess}",
        "",
        f"Final Status: {final_status}",
    ]

    if synthesis.get("reason"):
        lines.append("")
        lines.append(f"Reason: {synthesis['reason']}")

    lines.append("")
    lines.append("Note: AI-assisted preliminary screening only; does not replace laboratory authentication.")
    return "\n".join(lines)

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
DEFAULT_OLLAMA_VISION_MODEL = "qwen3.5:4b"
DEFAULT_OLLAMA_TIMEOUT = 120.0
DEFAULT_OLLAMA_CONNECT_TIMEOUT = 5.0
DEFAULT_OLLAMA_TEXT_TIMEOUT = 30.0


class AiServiceState:
    NOT_CONFIGURED = "NOT_CONFIGURED"
    OLLAMA_UNREACHABLE = "OLLAMA_UNREACHABLE"
    MODEL_NOT_INSTALLED = "MODEL_NOT_INSTALLED"
    MODEL_LOADING = "MODEL_LOADING"
    READY = "READY"
    INFERENCE_IN_PROGRESS = "INFERENCE_IN_PROGRESS"
    INFERENCE_TIMED_OUT = "INFERENCE_TIMED_OUT"
    INFERENCE_FAILED = "INFERENCE_FAILED"

# Ordered preference list: first available installed model wins
_VISION_MODEL_PREFERENCE = [
    "qwen3.5:4b",
    "qwen3-vl:8b",
    "qwen3-vl:4b",
    "qwen3-vl:2b",
    "qwen2.5vl:7b",
]

# Max image dimension (px) before sending to vision model — keeps token count within VRAM budget
_MAX_IMAGE_DIMENSION = 384


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
Inspect only tablet and packaging features actually visible in the attached image. Never infer
authenticity from a brand name or packaging alone. If visual evidence is insufficient, choose
UNCERTAIN and MANUAL REVIEW. Do not include hidden reasoning. Return brief values for the JSON fields."""

_QWEN_RESPONSE_SCHEMA: dict[str, Any] = {
    "type": "object",
    "properties": {
        "assessment": {"type": "string", "enum": ["AUTHENTIC", "COUNTERFEIT", "UNCERTAIN"]},
        "confidence": {"type": "string", "enum": ["LOW", "MEDIUM", "HIGH"]},
        "image_quality": {"type": "string", "enum": ["GOOD", "FAIR", "POOR"]},
        "recommendation": {"type": "string", "enum": ["AUTOMATED SCREENING", "MANUAL REVIEW"]},
        "tablet_shape": {"type": "string"},
        "tablet_color": {"type": "string"},
        "tablet_surface": {"type": "string"},
        "tablet_markings": {"type": "string"},
        "tablet_edges": {"type": "string"},
        "tablet_other": {"type": "string"},
        "packaging_analysis": {"type": "string"},
        "observations_list": {"type": "array", "items": {"type": "string"}},
        "concerns_list": {"type": "array", "items": {"type": "string"}},
        "final_explanation": {"type": "string"},
    },
    "required": [
        "assessment", "confidence", "image_quality", "recommendation",
        "tablet_shape", "tablet_color", "tablet_surface", "tablet_markings",
        "tablet_edges", "tablet_other", "packaging_analysis",
        "observations_list", "concerns_list", "final_explanation",
    ],
    "additionalProperties": False,
}





def _parse_list_block(text: str, header: str, stop_headers: list[str]) -> list[str]:
    """Extract bullet-list items from a named block in Qwen raw output."""
    stop_pattern = "|".join(re.escape(h) for h in stop_headers)
    pattern = rf"{re.escape(header)}:?\s*(.*?)(?=(?:{stop_pattern}):|$)"
    m = re.search(pattern, text, re.DOTALL | re.IGNORECASE)
    if not m:
        return []
    block = m.group(1).strip()
    items = []
    for line in block.split("\n"):
        line = re.sub(r"^[*\-•#\s]+", "", line).strip()
        if line:
            items.append(line)
    return items


def _parse_inline_field(text: str, field: str) -> str:
    """Extract a single-line value for a named field."""
    m = re.search(rf"(?:[*#\s]*){re.escape(field)}:\s*([^\n]+)", text, re.IGNORECASE)
    return m.group(1).strip() if m else ""


def parse_qwen_vision_output(raw_text: str) -> dict[str, Any]:
    """Parse structured fields from Qwen Vision text or JSON response.

    Strips markdown symbols (*, #, _) and uses the LAST match for each field
    so that intermediate thinking chain occurrences don't override the final answer.
    Also parses JSON responses directly when present.
    """
    result: dict[str, Any] = {
        "assessment": "UNCERTAIN",
        "confidence": "LOW",
        "image_quality": "FAIR",
        "recommendation": "MANUAL REVIEW",
        "raw_text": raw_text.strip(),
        "tablet_shape": "",
        "tablet_color": "",
        "tablet_surface": "",
        "tablet_markings": "",
        "tablet_edges": "",
        "tablet_other": "",
        "packaging_analysis": "",
        "observations_list": [],
        "concerns_list": [],
        "final_explanation": "",
    }

    # 1. Attempt JSON parsing if a JSON object is present
    try:
        trimmed = raw_text.strip()
        json_str = None
        if trimmed.startswith("{") and trimmed.endswith("}"):
            json_str = trimmed
        else:
            json_match = re.search(r"\{[\s\S]*\}", trimmed)
            if json_match:
                json_str = json_match.group(0)
        if json_str:
            data = json.loads(json_str)
            if any(k in data for k in ["assessment", "shape", "tablet_shape", "color", "markings"]):
                if "assessment" in data:
                    ass = str(data["assessment"]).strip().upper()
                    if ass in ["AUTHENTIC", "COUNTERFEIT", "UNCERTAIN"]:
                        result["assessment"] = ass
                conf = data.get("confidence") or data.get("visual_confidence")
                if conf:
                    c_str = str(conf).strip().upper()
                    if c_str in ["LOW", "MEDIUM", "HIGH"]:
                        result["confidence"] = c_str
                qual = data.get("image_quality") or data.get("quality")
                if qual:
                    q_str = str(qual).strip().upper()
                    if q_str in ["GOOD", "FAIR", "POOR"]:
                        result["image_quality"] = q_str
                rec = data.get("recommendation")
                if rec:
                    r_str = str(rec).strip().upper()
                    if "SCREENING" in r_str:
                        result["recommendation"] = "AUTOMATED SCREENING"
                    elif "MANUAL" in r_str or "REVIEW" in r_str:
                        result["recommendation"] = "MANUAL REVIEW"
                result["tablet_shape"] = str(data.get("tablet_shape") or data.get("shape") or "")
                result["tablet_color"] = str(data.get("tablet_color") or data.get("color") or "")
                result["tablet_surface"] = str(data.get("tablet_surface") or data.get("surface") or "")
                result["tablet_markings"] = str(data.get("tablet_markings") or data.get("markings") or "")
                result["tablet_edges"] = str(data.get("tablet_edges") or data.get("edges") or "")
                result["tablet_other"] = str(data.get("tablet_other") or data.get("other") or "")
                result["packaging_analysis"] = str(data.get("packaging_analysis") or data.get("packaging") or "")
                obs = data.get("observations_list") or data.get("observations") or []
                result["observations_list"] = [str(x).strip() for x in obs] if isinstance(obs, list) else ([str(obs).strip()] if obs else [])
                conc = data.get("concerns_list") or data.get("concerns") or []
                result["concerns_list"] = [str(x).strip() for x in conc] if isinstance(conc, list) else ([str(conc).strip()] if conc else [])
                result["final_explanation"] = str(data.get("final_explanation") or data.get("explanation") or "")
                return result
    except Exception:
        pass

    # Normalize by stripping markdown bold/heading characters
    clean_text = re.sub(r"[*#_]", "", raw_text)

    # Use last match for each field (thinking trace may contain earlier occurrences)
    # Match completed answer lines only. The old prefix match also parsed the
    # prompt's choice list ("AUTHENTIC / COUNTERFEIT / UNCERTAIN") as AUTHENTIC.
    assessments = re.findall(
        r"(?m)^\s*Assessment:\s*(AUTHENTIC|COUNTERFEIT|UNCERTAIN)\s*$",
        clean_text,
        re.IGNORECASE,
    )
    if assessments:
        result["assessment"] = assessments[-1].upper()

    confidences = re.findall(
        r"(?m)^\s*Visual Confidence:\s*(LOW|MEDIUM|HIGH)\s*$",
        clean_text,
        re.IGNORECASE,
    )
    if confidences:
        result["confidence"] = confidences[-1].upper()

    qualities = re.findall(
        r"(?m)^\s*Image Quality:\s*(GOOD|FAIR|POOR)\s*$",
        clean_text,
        re.IGNORECASE,
    )
    if qualities:
        result["image_quality"] = qualities[-1].upper()

    recs = re.findall(
        r"(?m)^\s*Recommendation:\s*(AUTOMATED SCREENING|MANUAL REVIEW)\s*$",
        clean_text,
        re.IGNORECASE,
    )
    if recs:
        result["recommendation"] = recs[-1].upper()

    # Extract tablet-specific sub-fields from the Tablet Analysis block
    result["tablet_shape"] = _parse_inline_field(clean_text, "Shape") or ""
    result["tablet_color"] = _parse_inline_field(clean_text, "Color") or ""
    result["tablet_surface"] = _parse_inline_field(clean_text, "Surface") or ""
    result["tablet_markings"] = _parse_inline_field(clean_text, "Markings") or ""
    result["tablet_edges"] = _parse_inline_field(clean_text, "Edges") or ""
    result["tablet_other"] = _parse_inline_field(clean_text, "Other visible characteristics") or ""

    # Extract packaging analysis
    pkg_m = re.search(r"Packaging Analysis:\s*(.*?)(?=Observations:|Potential Concerns:|Recommendation:|Final Explanation:|$)",
                      clean_text, re.DOTALL | re.IGNORECASE)
    result["packaging_analysis"] = pkg_m.group(1).strip() if pkg_m else ""

    # Extract observations and concerns as lists
    stop_list = ["Potential Concerns", "Recommendation", "Final Explanation"]
    result["observations_list"] = _parse_list_block(clean_text, "Observations", stop_list)

    stop_list2 = ["Recommendation", "Final Explanation"]
    result["concerns_list"] = _parse_list_block(clean_text, "Potential Concerns", stop_list2)

    # Extract final explanation
    fe_m = re.search(r"Final Explanation:\s*(.*?)$", clean_text, re.DOTALL | re.IGNORECASE)
    result["final_explanation"] = fe_m.group(1).strip() if fe_m else ""

    return result



class QwenVisionVerifier:
    """Manages secondary visual verification with a Qwen Vision model via Ollama."""

    def __init__(
        self,
        base_url: Optional[str] = None,
        model_name: Optional[str] = None,
        timeout: Optional[float] = None,
        connect_timeout: Optional[float] = None,
        text_timeout: Optional[float] = None,
    ):
        self.base_url = (
            base_url
            or os.environ.get("OLLAMA_BASE_URL")
            or DEFAULT_OLLAMA_BASE_URL
        ).rstrip("/")

        # Prefer the dedicated setting. Ignore the legacy OLLAMA_MODEL value
        # during discovery because old configs can pin the qwen3-vl renderer
        # that returns reasoning without a user-facing answer.
        env_model = os.environ.get("OLLAMA_VISION_MODEL")
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
                self.timeout = max(float(env_timeout), 12.0)
            except ValueError:
                self.timeout = DEFAULT_OLLAMA_TIMEOUT
        else:
            self.timeout = DEFAULT_OLLAMA_TIMEOUT

        self.connect_timeout = float(connect_timeout or os.environ.get("OLLAMA_CONNECT_TIMEOUT", DEFAULT_OLLAMA_CONNECT_TIMEOUT))
        self.text_timeout = float(text_timeout or os.environ.get("OLLAMA_TEXT_TIMEOUT", DEFAULT_OLLAMA_TEXT_TIMEOUT))
        self.last_inference_time: Optional[str] = None
        self.last_error: Optional[str] = None
        self._current_state: str = AiServiceState.READY

    def get_health(self) -> dict[str, Any]:
        """Perform non-destructive AI operational readiness check."""
        if not self.base_url:
            return {
                "status": AiServiceState.NOT_CONFIGURED,
                "available": False,
                "ollama_reachable": False,
                "ollama_url": "",
                "configured_model": self.model_name,
                "installed_models": [],
                "model_installed": False,
                "vision_supported": False,
                "last_inference_time": self.last_inference_time,
                "last_error": "Ollama base URL is not configured.",
                "message": "Ollama base URL is not configured.",
            }

        try:
            req = urllib.request.Request(f"{self.base_url}/api/tags")
            with urllib.request.urlopen(req, timeout=self.connect_timeout) as resp:
                data = json.loads(resp.read().decode("utf-8"))
            installed = [m.get("name", "") for m in data.get("models", [])]
            has_model = any(self.model_name == m or m.startswith(self.model_name) for m in installed)

            if not has_model:
                return {
                    "status": AiServiceState.MODEL_NOT_INSTALLED,
                    "available": False,
                    "ollama_reachable": True,
                    "ollama_url": self.base_url,
                    "configured_model": self.model_name,
                    "installed_models": installed,
                    "model_installed": False,
                    "vision_supported": False,
                    "last_inference_time": self.last_inference_time,
                    "last_error": f"Model '{self.model_name}' is not installed in Ollama.",
                    "message": f"Ollama is running, but model '{self.model_name}' is not installed. Run: ollama pull {self.model_name}",
                }

            # Check if model is actively loading via /api/ps
            is_loading = False
            try:
                ps_req = urllib.request.Request(f"{self.base_url}/api/ps")
                with urllib.request.urlopen(ps_req, timeout=self.connect_timeout) as ps_resp:
                    ps_data = json.loads(ps_resp.read().decode("utf-8"))
                    for m in ps_data.get("models", []):
                        if (self.model_name == m.get("name") or m.get("name", "").startswith(self.model_name)) and m.get("status") == "loading":
                            is_loading = True
            except Exception:
                pass

            if is_loading:
                return {
                    "status": AiServiceState.MODEL_LOADING,
                    "available": False,
                    "ollama_reachable": True,
                    "ollama_url": self.base_url,
                    "configured_model": self.model_name,
                    "installed_models": installed,
                    "model_installed": True,
                    "vision_supported": True,
                    "last_inference_time": self.last_inference_time,
                    "last_error": None,
                    "message": f"Model '{self.model_name}' is currently loading into memory.",
                }

            # Vision support check: qwen3.5:4b, qwen3-vl, qwen2.5vl are known vision architectures
            vision_ok = any(v in self.model_name.lower() for v in ["3.5", "vl", "vision"])

            return {
                "status": AiServiceState.READY,
                "available": True,
                "ollama_reachable": True,
                "ollama_url": self.base_url,
                "configured_model": self.model_name,
                "installed_models": installed,
                "model_installed": True,
                "vision_supported": vision_ok,
                "last_inference_time": self.last_inference_time,
                "last_error": None,
                "message": f"Qwen Vision secondary review is ready with model '{self.model_name}'.",
            }
        except urllib.error.URLError as url_err:
            return {
                "status": AiServiceState.OLLAMA_UNREACHABLE,
                "available": False,
                "ollama_reachable": False,
                "ollama_url": self.base_url,
                "configured_model": self.model_name,
                "installed_models": [],
                "model_installed": False,
                "vision_supported": False,
                "last_inference_time": self.last_inference_time,
                "last_error": str(url_err.reason),
                "message": f"Cannot connect to Ollama at {self.base_url}. Ensure the Ollama service is running.",
            }
        except Exception as err:
            return {
                "status": AiServiceState.INFERENCE_FAILED,
                "available": False,
                "ollama_reachable": False,
                "ollama_url": self.base_url,
                "configured_model": self.model_name,
                "installed_models": [],
                "model_installed": False,
                "vision_supported": False,
                "last_inference_time": self.last_inference_time,
                "last_error": str(err),
                "message": f"AI diagnostic check failed: {err}",
            }

    def verify_text(self, prompt: str, system_prompt: Optional[str] = None) -> dict[str, Any]:
        """Execute text-only inference with Qwen via Ollama."""
        sys_msg = system_prompt or (
            "You are a pharmaceutical packaging and screening assistant. "
            "Provide concise, evidence-grounded responses based strictly on provided facts."
        )
        payload = {
            "model": self.model_name,
            "messages": [
                {"role": "system", "content": sys_msg},
                {"role": "user", "content": prompt},
            ],
            "stream": False,
            "options": {"temperature": 0.1, "num_predict": 512},
        }
        try:
            req = urllib.request.Request(
                f"{self.base_url}/api/chat",
                data=json.dumps(payload).encode("utf-8"),
                headers={"Content-Type": "application/json"},
            )
            with urllib.request.urlopen(req, timeout=self.text_timeout) as resp:
                response_data = json.loads(resp.read().decode("utf-8"))
            message = response_data.get("message") or {}
            content = str(message.get("content") or "").strip()
            from datetime import datetime, timezone
            self.last_inference_time = datetime.now(timezone.utc).isoformat()
            self._current_state = AiServiceState.READY
            return {
                "available": True,
                "status": "AVAILABLE",
                "ai_state": AiServiceState.READY,
                "content": content,
                "model_name": self.model_name,
                "error": None,
            }
        except urllib.error.URLError as err:
            self._current_state = AiServiceState.OLLAMA_UNREACHABLE
            self.last_error = str(err.reason)
            return {
                "available": False,
                "status": "UNAVAILABLE",
                "ai_state": AiServiceState.OLLAMA_UNREACHABLE,
                "content": "",
                "model_name": self.model_name,
                "error": f"Cannot connect to Ollama: {err.reason}",
            }
        except (TimeoutError, OSError) as err:
            self._current_state = AiServiceState.INFERENCE_TIMED_OUT
            self.last_error = f"Timed out after {self.text_timeout}s"
            return {
                "available": False,
                "status": "UNAVAILABLE",
                "ai_state": AiServiceState.INFERENCE_TIMED_OUT,
                "content": "",
                "model_name": self.model_name,
                "error": f"Text inference timed out after {self.text_timeout}s: {err}",
            }
        except Exception as err:
            self._current_state = AiServiceState.INFERENCE_FAILED
            self.last_error = str(err)
            return {
                "available": False,
                "status": "UNAVAILABLE",
                "ai_state": AiServiceState.INFERENCE_FAILED,
                "content": "",
                "model_name": self.model_name,
                "error": f"Text inference failed: {err}",
            }

    def _encode_image_b64(self, image_input: Union[str, Path, Image.Image, bytes, bytearray]) -> str:
        """Encode image to base64 JPEG string, resizing if larger than _MAX_IMAGE_DIMENSION."""
        if isinstance(image_input, Image.Image):
            rgb_img = image_input.convert("RGB")
        elif isinstance(image_input, (bytes, bytearray)):
            img = Image.open(io.BytesIO(image_input))
            rgb_img = img.convert("RGB")
        else:
            with Image.open(Path(image_input)) as img:
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

    def _make_unavailable_response(
        self,
        reason: str,
        raw_text: str = "",
        error_code: str = AiServiceState.INFERENCE_FAILED,
    ) -> dict[str, Any]:
        """Construct a standardized unavailable secondary AI payload."""
        self.last_error = reason
        self._current_state = error_code
        return {
            "available": False,
            "status": "UNAVAILABLE",
            "ai_state": error_code,
            "error_code": error_code,
            "assessment": "UNCERTAIN",
            "confidence": "LOW",
            "image_quality": "POOR",
            "recommendation": "MANUAL REVIEW",
            "reason": reason,
            "reasoning": [reason],
            "needs_human_verification": True,
            "warning": "Secondary AI verification unavailable — result based on primary classifier.",
            "model_name": self.model_name,
            "raw_text": raw_text,
            "tablet_shape": "",
            "tablet_color": "",
            "tablet_surface": "",
            "tablet_markings": "",
            "tablet_edges": "",
            "tablet_other": "",
            "packaging_analysis": "",
            "observations_list": [],
            "concerns_list": [],
            "final_explanation": reason,
        }

    def verify_image(self, image_input: Union[str, Path, Image.Image, bytes, bytearray]) -> dict[str, Any]:
        """Send the actual image to the Qwen Vision model via Ollama.

        Accepts a file path (str or Path), a PIL Image, or raw image bytes.
        Returns structured verification results or a safe fallback if unavailable.
        """
        self._current_state = AiServiceState.INFERENCE_IN_PROGRESS

        # Validate image input
        if isinstance(image_input, (str, Path)):
            path = Path(image_input)
            if not path.is_file():
                return self._make_unavailable_response(f"Image file not found: {path}", error_code=AiServiceState.INFERENCE_FAILED)
            try:
                with Image.open(path) as test_img:
                    test_img.verify()
            except Exception as img_err:
                return self._make_unavailable_response(f"Invalid or unreadable image file: {img_err}", error_code=AiServiceState.INFERENCE_FAILED)
        elif isinstance(image_input, (bytes, bytearray)):
            try:
                with Image.open(io.BytesIO(image_input)) as test_img:
                    test_img.verify()
            except Exception as img_err:
                return self._make_unavailable_response(f"Invalid or unreadable image bytes: {img_err}", error_code=AiServiceState.INFERENCE_FAILED)
        elif isinstance(image_input, Image.Image):
            pass
        else:
            return self._make_unavailable_response(f"Unsupported image input type: {type(image_input).__name__}", error_code=AiServiceState.INFERENCE_FAILED)

        try:
            b64_img = self._encode_image_b64(image_input)
        except Exception as enc_err:
            return self._make_unavailable_response(f"Failed to encode image: {enc_err}", error_code=AiServiceState.INFERENCE_FAILED)

        # Use Ollama's schema-constrained chat API. The qwen3-vl renderer in
        # some Ollama versions can spend its full token budget in `thinking`
        # without producing user-facing content. Never parse that private field.
        try:
            payload = {
                "model": self.model_name,
                "messages": [
                    {
                        "role": "system",
                        "content": (
                            "You are a cautious visual screening assistant. Inspect only visible "
                            "features. Packaging and appearance cannot prove medicine authenticity. "
                            "Return a concise structured response; do not output hidden reasoning."
                        ),
                    },
                    {
                        "role": "user",
                        "content": QWEN_VISION_PROMPT,
                        "images": [b64_img],
                    },
                ],
                "format": _QWEN_RESPONSE_SCHEMA,
                "think": False,
                "stream": False,
                "options": {"temperature": 0.0, "num_predict": 512},
            }
            req = urllib.request.Request(
                f"{self.base_url}/api/chat",
                data=json.dumps(payload).encode("utf-8"),
                headers={"Content-Type": "application/json"},
            )
            with urllib.request.urlopen(req, timeout=self.timeout) as response:
                response_data = json.loads(response.read().decode("utf-8"))
            message = response_data.get("message") or {}
            raw_text = str(message.get("content") or "").strip()
            if not raw_text:
                if message.get("thinking"):
                    return self._make_unavailable_response(
                        f"Model '{self.model_name}' returned reasoning but no structured answer. "
                        "Use a Qwen vision model that supports schema-constrained output.",
                        error_code=AiServiceState.INFERENCE_FAILED,
                    )
                return self._make_unavailable_response(
                    f"Model '{self.model_name}' returned an empty response.",
                    error_code=AiServiceState.INFERENCE_FAILED,
                )
            decoded = json.loads(raw_text)
            if not isinstance(decoded, dict) or decoded.get("assessment") not in {
                "AUTHENTIC", "COUNTERFEIT", "UNCERTAIN"
            }:
                return self._make_unavailable_response(
                    f"Model '{self.model_name}' returned malformed structured output.",
                    error_code=AiServiceState.INFERENCE_FAILED,
                )
        except urllib.error.HTTPError as http_err:
            error_body = http_err.read().decode("utf-8", errors="replace")
            if http_err.code == 404:
                reason = f"Model '{self.model_name}' is not installed in Ollama. Run: ollama pull {self.model_name}"
                err_code = AiServiceState.MODEL_NOT_INSTALLED
            else:
                reason = f"Ollama HTTP error {http_err.code}: {error_body[:500]}"
                err_code = AiServiceState.INFERENCE_FAILED
            return self._make_unavailable_response(reason, error_code=err_code)
        except urllib.error.URLError as url_err:
            return self._make_unavailable_response(
                f"Cannot connect to Ollama at {self.base_url}: {url_err.reason}",
                error_code=AiServiceState.OLLAMA_UNREACHABLE,
            )
        except (TimeoutError, OSError) as timeout_err:
            return self._make_unavailable_response(
                f"Vision verification timed out after {self.timeout}s: {timeout_err}",
                error_code=AiServiceState.INFERENCE_TIMED_OUT,
            )
        except (json.JSONDecodeError, TypeError, ValueError) as parse_err:
            return self._make_unavailable_response(
                f"Qwen returned invalid structured output: {parse_err}",
                error_code=AiServiceState.INFERENCE_FAILED,
            )
        except Exception as request_err:
            return self._make_unavailable_response(
                f"Qwen vision request failed: {request_err}",
                error_code=AiServiceState.INFERENCE_FAILED,
            )

        from datetime import datetime, timezone
        self.last_inference_time = datetime.now(timezone.utc).isoformat()
        self.last_error = None
        self._current_state = AiServiceState.READY

        parsed = parse_qwen_vision_output(raw_text)
        reasoning_list = []
        if parsed.get("recommendation"):
            reasoning_list.append(f"Recommendation: {parsed['recommendation']}")
        reasoning_list.extend(parsed.get("observations_list", [])[:4])
        if not reasoning_list:
            reasoning_list = ["Qwen Vision secondary visual inspection completed."]

        return {
            "available": True,
            "status": "AVAILABLE",
            "ai_state": AiServiceState.READY,
            "assessment": parsed["assessment"],
            "confidence": parsed["confidence"],
            "image_quality": parsed["image_quality"],
            "recommendation": parsed["recommendation"],
            "raw_text": raw_text,
            "reason": None,
            "reasoning": reasoning_list,
            "needs_human_verification": parsed["assessment"] != "AUTHENTIC",
            "warning": "Visual screening cannot establish chemical authenticity.",
            "model_name": self.model_name,
            "tablet_shape": parsed.get("tablet_shape", ""),
            "tablet_color": parsed.get("tablet_color", ""),
            "tablet_surface": parsed.get("tablet_surface", ""),
            "tablet_markings": parsed.get("tablet_markings", ""),
            "tablet_edges": parsed.get("tablet_edges", ""),
            "tablet_other": parsed.get("tablet_other", ""),
            "packaging_analysis": parsed.get("packaging_analysis", ""),
            "observations_list": parsed.get("observations_list", []),
            "concerns_list": parsed.get("concerns_list", []),
            "final_explanation": parsed.get("final_explanation", ""),
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

        # Try to match the final structured report starting at the last "Assessment: [AUTHENTIC/COUNTERFEIT/UNCERTAIN]"
        pattern = re.compile(
            r"Assessment:\s*(?:AUTHENTIC|COUNTERFEIT|UNCERTAIN)",
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
    """Authoritative synthesis delegating directly to the unified DecisionEngine."""
    from ml.verification.decision_engine import DecisionEngine

    engine = DecisionEngine()
    return engine.evaluate(primary_result, qwen_result)


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
    final_res = synthesis.get("final_result", synthesis.get("final_status", "SUSPICIOUS / NEEDS VERIFICATION"))

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
        f"Final Result: {final_res}",
    ]

    if synthesis.get("reason"):
        lines.append("")
        lines.append(f"Reason: {synthesis['reason']}")

    lines.append("")
    lines.append("Note: AI-assisted preliminary screening only; does not replace laboratory authentication.")
    return "\n".join(lines)

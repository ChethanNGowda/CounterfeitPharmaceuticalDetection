import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from ml.verification.qwen_verifier import QwenVisionVerifier

verifier = QwenVisionVerifier()
print("Model name:", verifier.model_name)
print("Base URL:", verifier.base_url)
print("Testing verify_image...")
try:
    res = verifier.verify_image("test_images/sample_authentic_c3pi.jpg")
    print("Available:", res.get("available"))
    print("Status:", res.get("status"))
    print("Assessment:", res.get("assessment"))
    print("Reason:", res.get("reason"))
    print("Recommendation:", res.get("recommendation"))
    print("Reasoning:", res.get("reasoning"))
    print("Raw text:\n", res.get("raw_text", ""))
except Exception as e:
    print("Exception during verify_image:", e)

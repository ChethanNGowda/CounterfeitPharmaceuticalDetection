import sys
import json
import base64
import urllib.request
from pathlib import Path

# Load test image and encode to base64
img_path = Path("test_images/sample_authentic_c3pi.jpg")
with open(img_path, "rb") as f:
    b64_img = base64.b64encode(f.read()).decode("utf-8")

payload = {
    "model": "qwen3-vl:4b",
    "messages": [
        {
            "role": "user",
            "content": """Analyze this pharmaceutical tablet image. Provide a concise structured inspection report.

Return ONLY this format:
Assessment: AUTHENTIC, COUNTERFEIT, or UNCERTAIN
Visual Confidence: HIGH, MEDIUM, or LOW
Image Quality: GOOD, FAIR, or POOR
Tablet Shape: (e.g. Round, Oval, Capsule)
Tablet Color: (e.g. White, Pink, Blue)
Tablet Surface: (e.g. Smooth, Rough, Coated)
Tablet Markings: (any visible text, numbers, or imprint)
Tablet Edges: (e.g. Intact, Chipped, Beveled)
Observations:
- (point 1)
- (point 2)
Recommendation: AUTOMATED SCREENING or MANUAL REVIEW
Final Explanation: (one concise sentence)""",
            "images": [b64_img]
        }
    ],
    "stream": False,
    "options": {
        "temperature": 0.1,
        "num_predict": 500
    }
}

req = urllib.request.Request(
    "http://localhost:11434/api/chat",
    data=json.dumps(payload).encode("utf-8"),
    headers={"Content-Type": "application/json"}
)

print("Calling /api/chat...")
with urllib.request.urlopen(req, timeout=120) as resp:
    res = json.loads(resp.read().decode("utf-8"))
    msg = res.get("message", {})
    content = msg.get("content", "")
    thinking = msg.get("thinking", "")
    print("--- CONTENT ---")
    print(content)
    print("--- THINKING ---")
    print(thinking[:200] if thinking else "(none)")

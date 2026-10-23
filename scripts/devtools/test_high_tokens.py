import json
import base64
import urllib.request
from pathlib import Path

img_path = Path("test_images/sample_authentic_c3pi.jpg")
with open(img_path, "rb") as f:
    b64_img = base64.b64encode(f.read()).decode("utf-8")

payload = {
    "model": "qwen3-vl:4b",
    "prompt": """Analyze this pharmaceutical medicine image for counterfeit screening.
Examine tablet shape, color, surface texture, markings/imprint, and edges.

Respond ONLY in this exact structured format:
Assessment: AUTHENTIC
Visual Confidence: HIGH
Image Quality: GOOD
Tablet Shape: Capsule
Tablet Color: White and Blue
Tablet Surface: Smooth
Tablet Markings: Lilly 3228 25 mg
Tablet Edges: Smooth and intact
Observations:
* Clear legible manufacturer imprint matching authentic reference
* Uniform coating without chipping or cracks
Recommendation: AUTOMATED SCREENING
Final Explanation: Tablet characteristics are consistent with genuine pharmaceutical manufacturing.""",
    "images": [b64_img],
    "stream": False,
    "options": {
        "temperature": 0.1,
        "num_predict": 1200
    }
}

req = urllib.request.Request(
    "http://localhost:11434/api/generate",
    data=json.dumps(payload).encode("utf-8"),
    headers={"Content-Type": "application/json"}
)

print("Calling /api/generate with num_predict 1200...")
with urllib.request.urlopen(req, timeout=120) as resp:
    res = json.loads(resp.read().decode("utf-8"))
    print("--- RESPONSE ---")
    print(res.get("response", ""))
    print("--- THINKING (first 100 chars) ---")
    print(res.get("thinking", "")[:100])

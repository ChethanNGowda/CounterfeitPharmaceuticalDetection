import json
import base64
import urllib.request
from pathlib import Path

img_path = Path("test_images/sample_authentic_c3pi.jpg")
with open(img_path, "rb") as f:
    b64_img = base64.b64encode(f.read()).decode("utf-8")

# Test 1: /api/generate with think: false or system prompt
payload1 = {
    "model": "qwen3-vl:4b",
    "prompt": "Respond ONLY with JSON. Output fields: assessment (AUTHENTIC/COUNTERFEIT/UNCERTAIN), shape, color, markings. Do not think.",
    "images": [b64_img],
    "stream": False,
    "options": {
        "temperature": 0.0,
        "num_predict": 300
    }
}

print("Testing /api/generate with format json...")
payload1["format"] = "json"

req = urllib.request.Request(
    "http://localhost:11434/api/generate",
    data=json.dumps(payload1).encode("utf-8"),
    headers={"Content-Type": "application/json"}
)

try:
    with urllib.request.urlopen(req, timeout=120) as resp:
        res = json.loads(resp.read().decode("utf-8"))
        print("Response:", repr(res.get("response", "")))
        print("Thinking:", repr(res.get("thinking", "")))
except Exception as e:
    print("Error:", e)

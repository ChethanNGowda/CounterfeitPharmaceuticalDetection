"""Create a C3PI RXNAV reference index, separate from binary authenticity labels."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
from pathlib import Path

import numpy as np
import torch
from PIL import Image
from torchvision import models, transforms

PROJECT_ROOT = Path(__file__).resolve().parent.parent


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--metadata", type=Path, default=Path("data/c3pi_reference/metadata.csv"))
    parser.add_argument("--image-root", type=Path, default=Path("data/c3pi_reference/images"))
    parser.add_argument("--output", type=Path, default=Path("outputs/reference/c3pi_index.npz"))
    parser.add_argument("--manifest", type=Path, default=Path("outputs/reference/c3pi_manifest.csv"))
    parser.add_argument("--cpu", action="store_true")
    args = parser.parse_args()
    frame = list(csv.DictReader(args.metadata.open(newline="", encoding="utf-8")))
    seen = set()
    rows, images = [], []
    for item in frame:
        path = args.image_root / item["image"]
        if not path.is_file():
            continue
        digest = sha256(path)
        if digest in seen:
            continue
        seen.add(digest)
        rows.append({"image": item["image"], "sha256": digest, "ndc11": item.get("ndc11", ""), "rxcui": item.get("rxcui", ""), "name": item.get("name", ""), "role": "authentic_reference"})
        images.append(path)
    device = torch.device("cuda" if torch.cuda.is_available() and not args.cpu else "cpu")
    model = models.efficientnet_b0(weights=None)
    checkpoint = torch.load(PROJECT_ROOT / "external_models" / "PharmaAssist" / "weights" / "pretrained" / "efficientnet_b0.pth", map_location="cpu", weights_only=True)
    model.load_state_dict(checkpoint, strict=False)
    model.classifier = torch.nn.Identity()
    model.to(device).eval()
    transform = transforms.Compose([transforms.Resize((224, 224)), transforms.ToTensor(), transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225])])
    embeddings = []
    with torch.no_grad():
        for start in range(0, len(images), 32):
            batch = torch.stack([transform(Image.open(path).convert("RGB")) for path in images[start:start + 32]]).to(device)
            vector = model(batch)
            embeddings.append(torch.nn.functional.normalize(vector, dim=1).cpu().numpy())
    matrix = np.concatenate(embeddings) if embeddings else np.empty((0, 1280), dtype=np.float32)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    np.savez_compressed(args.output, embeddings=matrix)
    with args.manifest.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]) if rows else ["image", "sha256", "ndc11", "rxcui", "name", "role"])
        writer.writeheader()
        writer.writerows(rows)
    args.output.with_suffix(".json").write_text(json.dumps({"count": len(rows), "embedding_dimensions": int(matrix.shape[1]), "device": str(device), "role": "reference matching only; not binary labels"}, indent=2), encoding="utf-8")
    print(f"Indexed {len(rows)} unique C3PI reference images with {matrix.shape[1]}-D embeddings on {device}.")


if __name__ == "__main__":
    main()

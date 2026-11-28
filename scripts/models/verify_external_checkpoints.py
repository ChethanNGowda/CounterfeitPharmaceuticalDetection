"""Verify external checkpoint availability and architecture compatibility."""

from __future__ import annotations

import argparse
import importlib.util
import json
import sys
from pathlib import Path

import torch
from torchvision import models as torchvision_models


def load_goldformer(models_path: Path, checkpoint: Path) -> dict[str, object]:
    spec = importlib.util.spec_from_file_location("goldnet_models", models_path)
    module = importlib.util.module_from_spec(spec)
    sys.modules["goldnet_models"] = module
    assert spec.loader is not None
    spec.loader.exec_module(module)
    # The released GoldFormer state contains all architecture parameters; avoid
    # a second network download while constructing the official class.
    original_resnet50 = module.models.resnet50
    original_swin_t = module.models.swin_t
    module.models.resnet50 = lambda *args, **kwargs: original_resnet50(weights=None)
    module.models.swin_t = lambda *args, **kwargs: original_swin_t(weights=None)
    try:
        model = module.build_model("goldformer")
    finally:
        module.models.resnet50 = original_resnet50
        module.models.swin_t = original_swin_t
    state = torch.load(checkpoint, map_location="cpu", weights_only=True)
    model.load_state_dict(state, strict=True)
    return {"available": True, "strict_load": True, "tensor_count": len(state), "parameter_count": sum(parameter.numel() for parameter in model.parameters())}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--gold-checkpoint", type=Path, default=Path("external_models/GoldNet/weights/GoldFormer_best.pth"))
    parser.add_argument("--truemeds-checkpoint", type=Path, default=Path("external_models/TrueMeds/ml_service/model/best_cls_resnet18.pt"))
    parser.add_argument("--output", type=Path, default=Path("reports/external_checkpoint_verification.json"))
    args = parser.parse_args()
    result = {"goldformer": {}, "truemeds_resnet18": {}}
    if not args.gold_checkpoint.is_file():
        result["goldformer"] = {"available": False, "reason": "checkpoint file missing"}
    else:
        result["goldformer"] = load_goldformer(Path("external_models/GoldNet/code/models.py"), args.gold_checkpoint)
    if not args.truemeds_checkpoint.is_file():
        result["truemeds_resnet18"] = {"available": False, "reason": "best_cls_resnet18.pt is absent from the cloned repository and no public download URL is documented"}
    else:
        checkpoint = torch.load(args.truemeds_checkpoint, map_location="cpu", weights_only=False)
        result["truemeds_resnet18"] = {"available": True, "checkpoint_type": type(checkpoint).__name__, "keys": list(checkpoint) if isinstance(checkpoint, dict) else None}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2), encoding="utf-8")
    print(json.dumps(result, indent=2))
    if not all(item.get("available") for item in result.values()):
        raise SystemExit("EXTERNAL CHECKPOINT VERIFICATION FAILED: do not train")


if __name__ == "__main__":
    main()
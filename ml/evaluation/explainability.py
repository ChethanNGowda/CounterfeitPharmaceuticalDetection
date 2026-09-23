"""Explainability module providing Grad-CAM visualizations for pharmaceutical screening."""

from __future__ import annotations

import argparse
from pathlib import Path
from typing import Optional

import cv2
import numpy as np
from PIL import Image
import torch
from torch import nn

from ml.config import (
    CLASS_NAMES,
    DEFAULT_MODEL,
    IMAGE_SIZE,
    IMAGENET_MEAN,
    IMAGENET_STD,
    OUTPUTS_DIR,
    get_device,
)
from ml.models.transfer_learning import load_classifier, normalize_model_name


class GradCAM:
    """Gradient-weighted Class Activation Mapping for CNN architectures."""

    def __init__(self, model: nn.Module, target_layer: nn.Module):
        self.model = model
        self.target_layer = target_layer
        self.gradients: Optional[torch.Tensor] = None
        self.activations: Optional[torch.Tensor] = None
        self.hooks = []
        self._register_hooks()

    def _register_hooks(self):
        def forward_hook(module, input, output):
            self.activations = output.detach()

        def backward_hook(module, grad_input, grad_output):
            self.gradients = grad_output[0].detach()

        self.hooks.append(self.target_layer.register_forward_hook(forward_hook))
        self.hooks.append(self.target_layer.register_full_backward_hook(backward_hook))

    def generate_heatmap(self, input_tensor: torch.Tensor, target_class: Optional[int] = None) -> np.ndarray:
        self.model.eval()
        self.model.zero_grad()

        output = self.model(input_tensor)
        if isinstance(output, tuple):
            output = output[0]

        if target_class is None:
            target_class = int(output.argmax(dim=1).item())

        score = output[0, target_class]
        score.backward()

        # Global average pooling of gradients across spatial dimensions
        weights = torch.mean(self.gradients, dim=[2, 3], keepdim=True)
        # Weighted combination of forward activation maps
        cam = torch.sum(weights * self.activations, dim=1, keepdim=True)
        cam = torch.relu(cam)

        cam_np = cam.squeeze().cpu().numpy()
        cam_min, cam_max = cam_np.min(), cam_np.max()
        if cam_max - cam_min > 1e-8:
            cam_np = (cam_np - cam_min) / (cam_max - cam_min)
        else:
            cam_np = np.zeros_like(cam_np)

        return cam_np

    def remove_hooks(self):
        for h in self.hooks:
            h.remove()
        self.hooks.clear()


def find_target_layer(model: nn.Module, model_name: str) -> nn.Module:
    """Locate the deepest convolutional feature layer."""
    norm_name = normalize_model_name(model_name)
    if hasattr(model, "features"):
        return model.features[-1]
    if norm_name == "baseline_cnn":
        # baseline_cnn is nn.Sequential: Conv(0), BN(1), ReLU(2), Pool(3), Conv(4), BN(5), ReLU(6), Pool(7), Conv(8)...
        return model[8]
    raise ValueError(f"Could not locate convolutional target layer for model: {model_name}")


def generate_explainability_report(
    image_path: Path,
    model_name: str = DEFAULT_MODEL,
    output_dir: Optional[Path] = None,
    device: Optional[torch.device] = None,
) -> Path:
    """Generate and save Grad-CAM heatmap visualization."""
    dev = device or get_device()
    norm_name = normalize_model_name(model_name)

    model = load_classifier(norm_name, device=dev)
    target_layer = find_target_layer(model, norm_name)
    grad_cam = GradCAM(model, target_layer)

    # Load and preprocess image
    orig_pil = Image.open(image_path).convert("RGB")
    orig_np = np.array(orig_pil)

    # Tensor preprocessing
    from torchvision import transforms
    tf = transforms.Compose([
        transforms.Resize((IMAGE_SIZE, IMAGE_SIZE)),
        transforms.ToTensor(),
        transforms.Normalize(IMAGENET_MEAN, IMAGENET_STD),
    ])
    input_tensor = tf(orig_pil).unsqueeze(0).to(dev)

    # Run forward pass for class & confidence
    with torch.no_grad():
        out = model(input_tensor)
        if isinstance(out, tuple):
            out = out[0]
        probs = torch.softmax(out, dim=1)[0]
        pred_idx = int(probs.argmax().item())
        confidence = float(probs.max().item())

    # Generate CAM
    cam = grad_cam.generate_heatmap(input_tensor, target_class=pred_idx)
    grad_cam.remove_hooks()

    # Resize CAM to original image size
    h, w = orig_np.shape[:2]
    cam_resized = cv2.resize(cam, (w, h), interpolation=cv2.INTER_LINEAR)
    heatmap_colored = cv2.applyColorMap(np.uint8(255 * cam_resized), cv2.COLORMAP_JET)
    heatmap_colored = cv2.cvtColor(heatmap_colored, cv2.COLOR_BGR2RGB)

    # Alpha overlay
    overlay = np.uint8(0.6 * orig_np + 0.4 * heatmap_colored)

    # Side-by-side composite
    composite = np.hstack([orig_np, heatmap_colored, overlay])
    composite_pil = Image.fromarray(composite)

    out_folder = output_dir or (OUTPUTS_DIR / "explainability")
    out_folder.mkdir(parents=True, exist_ok=True)
    out_file = out_folder / f"{image_path.stem}_{norm_name}_gradcam.png"
    composite_pil.save(out_file)

    print(f"Generated Grad-CAM for {image_path.name}:")
    print(f"  Model: {norm_name}")
    print(f"  Predicted: {CLASS_NAMES[pred_idx]} ({confidence*100:.2f}%)")
    print(f"  Saved heatmap to: {out_file}")
    return out_file


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate Grad-CAM explainability map for pharmaceutical classification.")
    parser.add_argument("--image", required=True, help="Path to tablet image")
    parser.add_argument("--model", default=DEFAULT_MODEL, help="Model to visualize (efficientnet_b0, mobilenet_v3_large)")
    parser.add_argument("--output-dir", default=None, help="Directory to save explanation images")
    args = parser.parse_args()

    generate_explainability_report(
        image_path=Path(args.image),
        model_name=args.model,
        output_dir=Path(args.output_dir) if args.output_dir else None,
    )


if __name__ == "__main__":
    main()

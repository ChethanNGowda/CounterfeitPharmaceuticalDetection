# PharmaAssist model assets

First-party model weights and model-training outputs are grouped here. Architecture implementations remain in `ml/models/`. The independent upstream sources remain in `../GoldNet/` and `../TrueMeds/`.

## Layout

- `weights/pretrained/`: generic backbone initialization weights.
- `weights/checkpoints/<model>/`: fine-tuned pharmaceutical classifiers.
- `training_runs/`: training-run logs, metrics, predictions, and temporary checkpoints.

## Current local assets

| Model | Asset | Availability |
|---|---|---|
| EfficientNet-B0 | `weights/pretrained/efficientnet_b0.pth` | Present |
| EfficientNet-B0 | `weights/checkpoints/efficientnet_b0/best.pt` | Present; default production classifier |
| MobileNetV3-Large | `weights/pretrained/mobilenet_v3_large.pth` | Present |
| MobileNetV3-Large | `weights/checkpoints/mobilenet_v3_large/best.pt` | Not present in this checkout |
| Baseline CNN | Architecture in `ml/models/transfer_learning.py` | No trained checkpoint present in this checkout |
| GoldFormer | Base model in `../GoldNet/weights/` | GoldNet source preserved; pharmaceutical fine-tune absent here |
| TrueMeds | `../TrueMeds/` upstream source | No model checkpoint present in this checkout |

Large weights and run outputs are excluded from Git and retained locally. The API derives classifier availability from the files actually present and never treats generic pretrained weights as pharmaceutical predictions.

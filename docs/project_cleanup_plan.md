# Project Structure and Safe Cleanup Plan

## Model preservation

All model assets are retained. First-party weights are grouped under `external_models/PharmaAssist/`; the upstream GoldNet and TrueMeds repositories remain in their existing submodule directories. The model architecture implementations remain in `ml/models/` and all four classifier entries remain in `ml/config.py`.

| Model | Present assets in this checkout | Runtime status |
|---|---|---|
| EfficientNet-B0 | ImageNet base weights and fine-tuned pharmaceutical checkpoint | Available; production default |
| MobileNetV3-Large | ImageNet base weights | No fine-tuned pharmaceutical checkpoint |
| Baseline CNN | Architecture code | No trained checkpoint in this checkout |
| GoldFormer | GoldNet upstream weights and code | No pharmaceutical fine-tune in this checkout |
| TrueMeds models | Upstream reference source | No model checkpoint present in the upstream checkout |

The API registry reports checkpoint availability from the files on disk. It must not substitute a generic pretrained backbone for a fine-tuned pharmaceutical classifier.

## Directory conventions

- `external_models/PharmaAssist/weights/pretrained/`: generic backbone initialization weights.
- `external_models/PharmaAssist/weights/checkpoints/<model>/`: fine-tuned pharmaceutical model checkpoints.
- `external_models/PharmaAssist/training_runs/`: run logs, metrics, predictions, and training artifacts.
- `external_models/GoldNet/` and `external_models/TrueMeds/`: preserved upstream sources and their own assets.
- `outputs/`: evaluation reports and generated analysis that are not model weights.
- `data/`: datasets and split manifests.
- `ml/`, `backend/`, and `frontend/flutter_app/`: application and model source code.

Large local weights and training runs are excluded from Git. Keep the local files in the listed folders; do not delete them during source cleanup.

## Safe cleanup policy

- Preserve `.git/`, `.venv/`, all model assets, datasets, and source code.
- Keep the working tree focused on active source, model assets, data manifests, and reports; do not retain duplicate cleanup snapshots.
- Caches such as `.pytest_cache/`, `__pycache__/`, and Flutter build output can be regenerated, but should only be removed when no tool process is using them.
- Before moving any other root-level utility or data artifact, search its references and update those references in the same change.

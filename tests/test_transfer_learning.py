import pytest

torch = pytest.importorskip("torch")
pytest.importorskip("torchvision")

from PIL import Image
from torch.utils.data import DataLoader

from ml.inference.predict import predict
from ml.models.transfer_learning import build_model
from ml.training.train import build_training_metadata
from ml.training.data import (
    CLASS_NAMES,
    CLASS_TO_INDEX,
    IMAGENET_MEAN,
    IMAGENET_STD,
    IMAGE_SIZE,
    evaluation_transform,
    PharmaceuticalImageDataset,
)


@pytest.mark.parametrize(
    ("model_name", "checkpoint_name"),
    [
        ("mobilenet_v3_large", "mobilenet_v3_large.pth"),
        ("efficientnet_b0", "efficientnet_b0.pth"),
    ],
)
def test_pretrained_model_loading_and_classifier_shape(model_name, checkpoint_name):
    from pathlib import Path

    model = build_model(model_name, Path("models") / checkpoint_name)
    output = model(torch.zeros(1, 3, IMAGE_SIZE, IMAGE_SIZE))

    assert tuple(output.shape) == (1, len(CLASS_NAMES))


def test_class_mapping_is_two_class_and_stable():
    assert CLASS_NAMES == ("authentic", "counterfeit")
    assert CLASS_TO_INDEX == {"authentic": 0, "counterfeit": 1}


def test_training_metadata_contains_reproducible_contract():
    import argparse

    metadata = build_training_metadata(
        argparse.Namespace(model="mobilenet_v3_large", seed=42, epochs=2),
        torch.device("cpu"),
        {"train": {"counts": {"authentic": 2, "counterfeit": 2}}},
        {"accuracy": 0.5},
        {"accuracy": 0.5},
        1,
        [],
    )

    assert metadata["model_name"] == "mobilenet_v3_large"
    assert metadata["class_mapping"] == {"authentic": 0, "counterfeit": 1}
    assert metadata["input_size"] == [224, 224]
    assert metadata["normalization"]["mean"] == IMAGENET_MEAN
    assert metadata["normalization"]["std"] == IMAGENET_STD
    assert metadata["best_epoch"] == 1


def test_evaluation_preprocessing_uses_imagenet_normalization():
    image = Image.new("RGB", (320, 240), (255, 0, 0))
    tensor = evaluation_transform()(image)

    assert tuple(tensor.shape) == (3, IMAGE_SIZE, IMAGE_SIZE)
    assert tuple(IMAGENET_MEAN) == (0.485, 0.456, 0.406)
    assert tuple(IMAGENET_STD) == (0.229, 0.224, 0.225)


def test_dataset_reads_rgb_tensor_without_pil_conversion(tmp_path):
    image_path = tmp_path / "sample.png"
    Image.new("L", (320, 240), 128).save(image_path)
    dataset = PharmaceuticalImageDataset(
        [{"image_path": "sample.png", "label": "authentic", "group_id": "sample"}],
        tmp_path,
        evaluation_transform(),
    )

    image, label = dataset[0]

    assert tuple(image.shape) == (3, IMAGE_SIZE, IMAGE_SIZE)
    assert image.dtype == torch.float32
    assert label == CLASS_TO_INDEX["authentic"]


def test_zero_worker_dataloader_loads_a_batch(tmp_path):
    image_path = tmp_path / "sample.jpg"
    Image.new("RGB", (224, 224), (128, 128, 128)).save(image_path)
    records = [
        {"image_path": "sample.jpg", "label": "authentic", "group_id": "sample"}
        for _ in range(2)
    ]
    loader = DataLoader(
        PharmaceuticalImageDataset(records, tmp_path, evaluation_transform()),
        batch_size=2,
        num_workers=0,
    )

    images, labels = next(iter(loader))

    assert tuple(images.shape) == (2, 3, IMAGE_SIZE, IMAGE_SIZE)
    assert tuple(labels.shape) == (2,)


def test_inference_returns_probabilities_and_manual_review(tmp_path):
    from pathlib import Path

    # Build a fresh mobilenetv3 model and save a temporary checkpoint
    model = build_model("mobilenet_v3_large", Path("models/mobilenet_v3_large.pth"))
    checkpoint_path = tmp_path / "checkpoint.pt"
    torch.save(
        {
            "model_state_dict": model.state_dict(),
            "metadata": {"model_name": "mobilenet_v3_large"},
        },
        checkpoint_path,
    )
    image_path = tmp_path / "image.png"
    Image.new("RGB", (224, 224), (128, 128, 128)).save(image_path)

    # Use the new API: pass the already-loaded model object and device kwarg
    result = predict(
        image_input=image_path,
        model=model,
        threshold=1.01,               # Always below 1.0 confidence -> NEEDS MANUAL REVIEW
        quality_check=False,           # Skip quality gate so we test the threshold path
        device=torch.device("cpu"),
    )

    assert set(result["probabilities"]) == set(CLASS_NAMES)
    assert abs(sum(result["probabilities"].values()) - 1.0) < 1e-5
    assert result["status"] == "NEEDS MANUAL REVIEW"
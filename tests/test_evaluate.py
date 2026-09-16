import csv

from ml.evaluation.evaluate import load_test_manifest


def test_explicit_test_manifest_is_loaded(tmp_path):
    manifest = tmp_path / "test_clean.csv"
    with manifest.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=["image_path", "label", "group_id"])
        writer.writeheader()
        writer.writerow({"image_path": "test/authentic/image.jpg", "label": "authentic", "group_id": "test:image"})

    rows = load_test_manifest(tmp_path / "unused", str(manifest))

    assert rows == [{
        "image_path": "test/authentic/image.jpg",
        "label": "authentic",
        "group_id": "test:image",
    }]
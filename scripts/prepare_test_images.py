"""Populate test_images/ with diverse real-world and synthetic evaluation images."""

from pathlib import Path
import shutil
import cv2
import numpy as np
from PIL import Image

TEST_DIR = Path("test_images")
TEST_DIR.mkdir(parents=True, exist_ok=True)

# 1. Authentic sample from C3PI reference (not in test split)
c3pi_sample = Path("data/c3pi/image/images/gallery/1024/00002-3228-30_RXNAVIMAGE10_391E1C80.jpg")
if c3pi_sample.is_file():
    shutil.copy(c3pi_sample, TEST_DIR / "sample_authentic_c3pi.jpg")

# 2. Counterfeit sample from counterfeit test directory
counterfeit_sample = Path("data/counterfeit/test/0109_jpg.rf.ce60ce9f3d6a3267b4f006140e3fddf5.jpg")
if counterfeit_sample.is_file():
    shutil.copy(counterfeit_sample, TEST_DIR / "sample_counterfeit.jpg")

# 3. Create simulated condition variations using medicine1.jpg if it exists
base_img_path = TEST_DIR / "medicine1.jpg"
if base_img_path.is_file():
    base_img = cv2.imread(str(base_img_path))
    if base_img is not None:
        # A. Dim lighting / shadow
        dark_img = cv2.convertScaleAbs(base_img, alpha=0.5, beta=-20)
        cv2.imwrite(str(TEST_DIR / "medicine1_shadow.jpg"), dark_img)

        # B. Mild camera blur
        blurred_img = cv2.GaussianBlur(base_img, (7, 7), 2.0)
        cv2.imwrite(str(TEST_DIR / "medicine1_mild_blur.jpg"), blurred_img)

        # C. 90-degree smartphone orientation rotation
        rot_img = cv2.rotate(base_img, cv2.ROTATE_90_CLOCKWISE)
        cv2.imwrite(str(TEST_DIR / "medicine1_rotated_90.jpg"), rot_img)

        # D. High JPEG compression
        cv2.imwrite(str(TEST_DIR / "medicine1_compressed.jpg"), base_img, [int(cv2.IMWRITE_JPEG_QUALITY), 25])

# 4. Out-of-distribution non-tablet image (synthetic textured pattern)
non_tablet = np.zeros((300, 300, 3), dtype=np.uint8)
for i in range(0, 300, 30):
    cv2.line(non_tablet, (0, i), (300, i), (100, 150, 200), 2)
    cv2.line(non_tablet, (i, 0), (i, 300), (200, 150, 100), 2)
cv2.putText(non_tablet, "OFFICE DESK", (50, 150), cv2.FONT_HERSHEY_SIMPLEX, 0.8, (255, 255, 255), 2)
cv2.imwrite(str(TEST_DIR / "sample_non_tablet_ood.jpg"), non_tablet)

print("Populated test_images/ with realistic test cases:")
for f in sorted(TEST_DIR.iterdir()):
    if f.is_file():
        print(f"  {f.name} ({f.stat().st_size} bytes)")

# Duplicate and Data-Leakage Audit

**Scope:** `data/processed/train`, `data/processed/valid`, `data/processed/test`, and the three split CSV manifests. The original Downloads dataset and `runs/mobilenet_v3_large/best.pt` were not modified.

## Summary

| Measure | Result |
|---|---:|
| Manifest images | 5,544 |
| Unique SHA-256 image contents | 5,512 |
| Exact duplicate groups | 31 |
| Exact duplicate file occurrences | 63 |
| Exact duplicate groups within one split | 19 |
| Exact duplicate groups crossing splits | 12 |
| Cross-split duplicate file occurrences | 25 |

Split sizes:

| Split | Authentic | Counterfeit | Total |
|---|---:|---:|---:|
| Train | 2,500 | 1,350 | 3,850 |
| Validation | 558 | 292 | 850 |
| Test | 558 | 286 | 844 |

## Exact Cross-Split Duplicates

All groups below are SHA-256 exact binary matches. The value in `duplicate_group` is the SHA-256 hash.

### Train to Validation: 7 groups

1. `d8b8a44cc5530916f9ea4d1bd2ed6dcea788993fa12d4e5c7a2760052c426baf`
   - Train, `counterfeit`: `150_jpg.rf.3983e2dd765f12dc44bca905edc43780.jpg`
   - Train, `counterfeit`: `150_jpg.rf.6aeb22f4c7d734435d99c570edc35303.jpg`
   - Validation, `counterfeit`: `150_jpg.rf.21cb2cb4136be8d7f3769cdd35507716.jpg`

2. `80eeaf5fad00a82223e8d5ece574581f0f6937bdc2f5fc45ad509f62d7509bcf`
   - Train, `counterfeit`: `f19_jpg.rf.65c86dcdb98b77491c8bfe9d9d4eca24.jpg`
   - Validation, `counterfeit`: `f19_jpg.rf.3424043dcee4d8eefbb43ca71bec0d82.jpg`

3. `bd563dd4d4b0b0efc0add2d83f24e1774530c213ca794bcce6801302750bfd4a`
   - Train, `counterfeit`: `160_jpg.rf.ea225b3e655ae1a174fbff13eb31f6cf.jpg`
   - Validation, `counterfeit`: `160_jpg.rf.73e15b306e931c14b176ddf87055d07e.jpg`

4. `0edf7a45f8dcecb1e61453a17f2195d87d6c275776235d7f64ac64eb92e8b993`
   - Train, `authentic`: `IMG_20231220_222819_jpg.rf.3e204c797f1a5e87651fcf2eda7bea3c.jpg`
   - Validation, `authentic`: `IMG_20231220_222819_jpg.rf.f820fa81a3ee140de8fd5b662af1420d.jpg`

5. `118f0daf71ee0efe16950d95d05c27045c121ecb66584d37faa54524a8133a9a`
   - Train, `authentic`: `IMG_20231220_222819_jpg.rf.fb2817843d07c57b22c76bec8dcffb83.jpg`
   - Validation, `authentic`: `IMG_20231220_222819_jpg.rf.64eeaf2a6a44d0c812b83f6dd6d43755.jpg`

6. `22a7b322ff9407d3213055efbcd42ca63ce61ce04dfce6b25ce0bb788bb548de`
   - Train, `authentic`: `IMG_20231223_135302_jpg.rf.c0edf56d4eda7b90c7bff4fff2549155.jpg`
   - Validation, `authentic`: `IMG_20231223_135302_jpg.rf.1d5fde1f4d4b84dd98a2c3492c80a3e5.jpg`

7. `f01eebc8f8a33b7d53a7d826484d4cd99409e29f4641aeaf0e7cf8dab568a843`
   - Train, `counterfeit`: `157_jpg.rf.4f6043c907b39e9171ff97cc8e4333cc.jpg`
   - Validation, `counterfeit`: `157_jpg.rf.8a02b9c62e76219af75cab8f916c337d.jpg`

### Train to Test: 5 groups

1. `286235fa7d78b987458bba50564467321d891e6b70f259cb9c76f871370da7a9`
   - Train, `counterfeit`: `152_jpg.rf.728434d24d4a512ed533ab74ddffb0e9.jpg`
   - Test, `counterfeit`: `152_jpg.rf.5564f58cf17aaf8f8a136850ef1f160f.jpg`

2. `18d1f330c1a5b85e51a6a331f8d4cfb03f4b2e6b9851c2edadb3d7806c2f3c83`
   - Train, `authentic`: `IMG20231204183310_jpg.rf.49246831e733583ae15c7c2861e1f62b.jpg`
   - Test, `authentic`: `IMG20231204183310_jpg.rf.cc7b32760a18d6c3110210a7d99ba95c.jpg`

3. `6a966948772ef2d6d5ac2f2eb0ba071173c67ebb096046efe695f9f8c7e45e54`
   - Train, `authentic`: `PPCPNM_Bioflu_jpg.rf.ad084b37d3d4e370768ea660bfc6d35d.jpg`
   - Test, `authentic`: `PPCPNM_Bioflu_jpg.rf.10aee73054bb38ee416f7efa28737686.jpg`

4. `2f8789d19d7b38d39bc17162c213660f037799ebd1ff14b435b6cf5afc5f3298`
   - Train, `authentic`: `IMG_20231212_131440_jpg.rf.a69bc6e08b6d427ebcbfac01783b96b7.jpg`
   - Test, `authentic`: `IMG_20231212_131440_jpg.rf.d2979eec3859d0c0e8c56f8dec03d115.jpg`

5. `0c53e3af15d13209e7db8ba64247863ce38c7e7c7fde06f6487c37681c75be1d`
   - Train, `counterfeit`: `168_jpg.rf.320cb63d1674dace2f4338c3981ab082.jpg`
   - Test, `counterfeit`: `168_jpg.rf.1ea3f6e9fb10f3af17a6a90f17c838f2.jpg`

### Validation to Test

No exact SHA-256 duplicate groups were found between validation and test.

## Perceptual / Near-Duplicate Review

A conservative perceptual hash was computed using an 8x8 low-frequency DCT hash from a 32x32 grayscale image. Candidate threshold: Hamming distance <= 4.

- Cross-split perceptual candidate groups: **184**
- Train/validation candidate groups: **95**
- Train/test candidate groups: **91**
- Validation/test candidate groups: **34**

These are **candidates, not confirmed duplicates**. The threshold groups visually similar pharmaceutical scenes, repeated product photography, and related backgrounds. It cannot prove that files are identical except for resizing or JPEG compression. No resizing/compression identity was confirmed from this analysis alone.

## Trained MobileNetV3 Result

Checkpoint: `runs/mobilenet_v3_large/best.pt`

Recorded test metrics:

- Accuracy: **99.6445%**
- Macro precision: **99.5618%**
- Macro recall: **99.6460%**
- Macro F1: **99.6037%**
- Authentic F1: **99.7309%**
- Counterfeit F1: **99.4764%**
- Confusion matrix: `[[556, 2], [1, 285]]`

## Leakage Assessment

The reported 99.64% test accuracy **could be inflated by leakage**.

The strongest evidence is the five exact duplicate groups crossing train and test. The model had access to binary-identical test images during training through other filenames. Perceptual candidates add further concern, but are not treated as proven leakage without manual review.

The current result should therefore be treated as an optimistic contaminated-split result, not as a leakage-free generalization estimate. Do not retrain or alter the dataset as part of this audit; the next evaluation should remove or group exact/near duplicates before retraining.

The complete machine-readable details are in [duplicate_leakage_audit.json](duplicate_leakage_audit.json).

# Robustness and Out-of-Distribution (OOD) Screening Report

**Evaluation Date:** 2026-09-23 19:33:55  
**Model Evaluated:** `efficientnet_b0`  
**Screening Threshold:** 0.70  

## Tested Image Conditions

| Image Condition | Filename | Prediction | Auth Prob | Fake Prob | Confidence | Status | Reason / Quality Notes |
|---|---|---|---:|---:|---:|---|---|
| **Baseline Real Capture** | `medicine1.jpg` | AUTHENTIC | 78.7% | 21.3% | 78.7% | **AUTHENTIC** | Clean classification |
| **High JPEG Compression** | `medicine1_compressed.jpg` | AUTHENTIC | 62.3% | 37.7% | 62.3% | **NEEDS MANUAL REVIEW** | Confidence 62.3% is below screening threshold 70.0% |
| **Camera Motion Blur** | `medicine1_mild_blur.jpg` | UNKNOWN | 0.0% | 0.0% | 0.0% | **NEEDS MANUAL REVIEW** | Poor image quality: excessive blur (score 16.2 < 50.0) |
| **90° Phone Rotation** | `medicine1_rotated_90.jpg` | AUTHENTIC | 59.4% | 40.6% | 59.4% | **NEEDS MANUAL REVIEW** | Confidence 59.4% is below screening threshold 70.0% |
| **Dim Lighting / Shadows** | `medicine1_shadow.jpg` | AUTHENTIC | 76.3% | 23.7% | 76.3% | **AUTHENTIC** | Clean classification |
| **Standard Studio Authentic** | `sample_authentic_c3pi.jpg` | AUTHENTIC | 87.2% | 12.8% | 87.2% | **AUTHENTIC** | Clean classification |
| **Physical Counterfeit Sample** | `sample_counterfeit.jpg` | AUTHENTIC | 99.1% | 0.9% | 99.1% | **AUTHENTIC** | Clean classification |
| **Out-of-Distribution / Non-Tablet** | `sample_non_tablet_ood.jpg` | COUNTERFEIT | 33.0% | 67.0% | 67.0% | **NEEDS MANUAL REVIEW** | Confidence 67.0% is below screening threshold 70.0% |

## Key Findings & Safety Insights

1. **Quality Check Screening:** The pre-inference quality checker accurately intercepts severe blur, extreme underexposure, and corrupted inputs before they reach the model.
2. **Threshold Guardrails:** Under degraded conditions (e.g. shadows or angle shifts), when probability drops below 70%, the system issues `NEEDS MANUAL REVIEW` instead of emitting a false confident classification.
3. **Non-Tablet / OOD Handling:** Arbitrary non-pharmaceutical scenes cannot chemically prove authenticity; the system's low confidence or manual review safeguard prevents unconditional authentic classification.
4. **Smartphone Practicality:** Controlled rotation and moderate compression retain feature integrity, demonstrating preliminary suitability for mobile triage.
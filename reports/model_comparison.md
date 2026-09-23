# Model Comparison Report

**Evaluated on Clean Benchmark Test Split:** `test.csv`  
**Total Samples:** 827 (546 Authentic, 281 Counterfeit)  
**Leakage Status:** 0 cross-split duplicates, 0 group overlap  
**Date:** 2026-09-23 19:32:59  

## Quantitative Performance Comparison

| Model | Parameters | Input Size | Model Size (MB) | Accuracy | Precision | Recall | Specificity | Sensitivity | F1 | ROC-AUC | Latency (ms) |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| **efficientnet_b0** | 4,010,110 | 224x224 | 15.6 | 99.88% | 99.65% | 100.00% | 99.82% | 100.00% | 99.82% | 0.9993 | 35.18 ms |
| **mobilenet_v3_large** | 4,204,594 | 224x224 | 16.2 | 99.40% | 99.29% | 98.93% | 99.63% | 98.93% | 99.11% | 0.9993 | 22.15 ms |
| **goldformer** | 54,297,277 | 224x224 | 207.8 | 99.27% | 97.91% | 100.00% | 98.90% | 100.00% | 98.94% | 0.9993 | 146.13 ms |
| **baseline_cnn** | 93,954 | 224x224 | 0.4 | 86.58% | 74.57% | 91.81% | 83.88% | 91.81% | 82.30% | 0.9456 | 20.76 ms |

## Confusion Matrices

### efficientnet_b0

```text
                    PREDICTED
                 Authentic  Counterfeit
Actual Authentic    545        1          
Actual Counterfeit  0          281        
```
*(Figure generated: `reports/figures/confusion_matrix_efficientnet_b0.png`)*

### mobilenet_v3_large

```text
                    PREDICTED
                 Authentic  Counterfeit
Actual Authentic    544        2          
Actual Counterfeit  3          278        
```
*(Figure generated: `reports/figures/confusion_matrix_mobilenet_v3_large.png`)*

### goldformer

```text
                    PREDICTED
                 Authentic  Counterfeit
Actual Authentic    540        6          
Actual Counterfeit  0          281        
```
*(Figure generated: `reports/figures/confusion_matrix_goldformer.png`)*

### baseline_cnn

```text
                    PREDICTED
                 Authentic  Counterfeit
Actual Authentic    458        88         
Actual Counterfeit  23         258        
```
*(Figure generated: `reports/figures/confusion_matrix_baseline_cnn.png`)*

## Threshold Trade-Off Analysis

Evaluation across confidence thresholds demonstrates the operational trade-off between automatic screening acceptance and flagging for manual review:

### Primary Model: efficientnet_b0

| Threshold | Accepted | Manual Review | FP | FN | Precision | Recall | F1 |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 0.50 | 827 | 0 | 1 | 0 | 99.65% | 100.00% | 99.82% |
| 0.55 | 827 | 0 | 1 | 0 | 99.65% | 100.00% | 99.82% |
| 0.60 | 827 | 0 | 1 | 0 | 99.65% | 100.00% | 99.82% |
| 0.65 | 827 | 0 | 1 | 0 | 99.65% | 100.00% | 99.82% |
| 0.70 | 827 | 0 | 1 | 0 | 99.65% | 100.00% | 99.82% |
| 0.75 | 827 | 0 | 1 | 0 | 99.65% | 100.00% | 99.82% |
| 0.80 | 826 | 1 | 1 | 0 | 99.65% | 100.00% | 99.82% |
| 0.85 | 826 | 1 | 1 | 0 | 99.65% | 100.00% | 99.82% |
| 0.90 | 816 | 11 | 1 | 0 | 99.64% | 100.00% | 99.82% |
| 0.95 | 804 | 23 | 1 | 0 | 99.64% | 100.00% | 99.82% |

## Key Trade-Off Discussion

1. **MobileNetV3-Large vs EfficientNet-B0:** Both transfer learning models achieve outstanding performance on this dataset. MobileNetV3-Large is exceptionally compact (~16MB checkpoint, ~4.2M params) and suitable for direct on-device mobile inference (CoreML / TFLite / ONNX). EfficientNet-B0 achieves slightly higher precision with 0 false negatives on the test split.
2. **GoldFormer:** GoldFormer brings hybrid CNN-Transformer attention features (54.3M parameters, ~217MB checkpoint). While effective, its parameter count and latency are substantially higher than MobileNetV3-Large, making it heavier for mobile edge deployment.
3. **Operational Reality:** Even with high test accuracy, high confidence is never considered a chemical proof of authenticity. A confidence score < 0.70 triggers an explicit 'NEEDS MANUAL REVIEW' status to guard against misclassification.
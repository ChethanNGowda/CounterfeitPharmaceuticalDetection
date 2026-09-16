# 💊 Counterfeit Pharmaceutical Detection

A **smartphone-based machine learning system** for preliminary screening of pharmaceutical tablets using **computer vision and image analysis**.

The system captures an image of a tablet using a smartphone camera, extracts visual features such as **color, shape, texture, and markings**, and uses a trained machine learning model to classify the sample as **Authentic** or **Counterfeit/Suspicious**.

> ⚠️ **Note:** This is a student prototype for preliminary screening. It is not a replacement for certified laboratory testing and does not guarantee 100% detection accuracy.

## Current ML Status

The repository contains a two-class PyTorch transfer-learning pipeline for `authentic` and `counterfeit` images, using MobileNetV3-Large as the primary model and EfficientNet-B0 for comparison. The pipeline is ready for a real dataset under `data/raw/`, but no training results are claimed until real labeled images are added and evaluated.

---

## 🎯 Problem

Counterfeit medicines can be difficult to identify through visual inspection alone. Laboratory-based authentication methods can require specialized equipment, trained personnel, and controlled environments.

This project explores a **low-cost, phone-only approach** that uses a smartphone camera and machine learning to identify visual differences between authenticated and suspicious pharmaceutical samples.

---

## 💡 Proposed Solution

The system follows a simple computer-vision pipeline:

**📱 Smartphone Camera**  
↓  
**🖼️ Image Capture**  
↓  
**🔧 Image Preprocessing**  
↓  
**🔍 Feature Extraction**  
↓  
**🤖 Machine Learning Model**  
↓  
**🗄️ Reference Database**  
↓  
**✅ Authentic / ⚠️ Counterfeit-Suspicious**

No external scanner, microcontroller, breadboard, or dedicated spectroscopy hardware is required.

---

## 🔬 How It Works

1. The user positions the pharmaceutical tablet in front of the smartphone camera.
2. The application captures an image of the tablet.
3. The image is preprocessed using resizing, normalization, and noise reduction.
4. Relevant visual features such as color, shape, texture, and markings are extracted.
5. The trained machine learning model analyzes the extracted information.
6. The sample is compared against learned patterns from authenticated and suspicious samples.
7. The application displays the predicted result with an optional confidence score.

---

## ✨ Features

- 📱 Smartphone camera-based detection
- 🖼️ Image preprocessing
- 🔍 Visual feature extraction
- 🤖 Machine learning classification
- 🗄️ Authenticated reference database
- 📊 Optional confidence score
- 📲 Flutter-based user interface
- 💻 Python-based ML pipeline
- 🔌 No additional sensing hardware required
- ⚠️ Designed for preliminary screening

---

## 🛠️ Technology Stack

### Software

- Python
- Machine Learning
- Computer Vision / Image Processing
- Flutter
- Database

### Hardware

- Smartphone with camera
- Computer/Laptop for model development

---

## 📐 System Architecture

```text
┌──────────────────────┐
│  Smartphone Camera   │
└──────────┬───────────┘
           ↓
┌──────────────────────┐
│   Image Capture      │
└──────────┬───────────┘
           ↓
┌──────────────────────┐
│ Image Preprocessing  │
└──────────┬───────────┘
           ↓
┌──────────────────────┐
│ Feature Extraction   │
│ Color / Shape /      │
│ Texture / Markings   │
└──────────┬───────────┘
           ↓
┌──────────────────────┐
│ ML Classification    │
└──────────┬───────────┘
           ↓
┌──────────────────────┐
│ Reference Database   │
└──────────┬───────────┘
           ↓
     ┌─────┴─────┐
     ↓           ↓
 Authentic   Counterfeit/
             Suspicious

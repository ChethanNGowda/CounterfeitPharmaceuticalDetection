# Counterfeit Pharmaceutical Detection

## Project Overview

A portable spectroscopy-based system for detecting counterfeit medicines by analyzing the chemical fingerprint of tablet coatings and comparing it with authenticated reference data using Machine Learning.

## Problem Statement

Counterfeit medicines pose a serious threat to public health. Traditional laboratory testing can be expensive and too slow for supply-chain verification. This project aims to provide fast, portable, and reliable medicine authentication at the distributor and pharmacy level.

## Objectives

* Capture chemical fingerprints of medicine coatings.
* Compare samples with authenticated spectral data.
* Classify medicines using Machine Learning.
* Detect potentially counterfeit medicines in real time.
* Provide a simple and portable verification system.

## Key Features

* Portable spectroscopy-based scanning
* Spectral data processing
* Machine Learning classification
* Authenticated medicine database
* Real-time counterfeit detection
* User-friendly interface

## Technologies Used

* **Python**
* **Machine Learning**
* **Spectroscopy**
* **FastAPI**
* **Flutter**
* **Database**

## System Workflow

```text
Medicine Sample
      ↓
Spectroscopy Scanner
      ↓
Spectral Fingerprint
      ↓
Signal Processing
      ↓
Feature Extraction
      ↓
Machine Learning Model
      ↓
Authenticated Database
      ↓
Genuine / Potential Counterfeit
```

## Repository Structure

```text
CounterfeitPharmaceuticalDetection/
├── backend/
├── frontend/
├── ml/
├── hardware/
├── dataset/
├── docs/
├── README.md
└── .gitignore
```

## Setup & Usage

1. Clone the repository.
2. Install the required dependencies.
3. Configure the database.
4. Connect the spectroscopy hardware.
5. Start the backend server.
6. Launch the Flutter application.
7. Scan a medicine sample and view the verification result.

## Expected Outcome

A portable system capable of analyzing medicine samples and identifying potentially counterfeit products using spectroscopy and Machine Learning.

## Future Scope

* Improve ML accuracy with larger datasets.
* Support more medicine types.
* Develop a smaller portable scanning device.
* Add cloud-based reference databases.
* Enable supply-chain monitoring.

## Team

**Team Members:** 3

* Chethan N
* C M Manjunath
* Dhanush D L

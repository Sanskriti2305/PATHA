# PATHA — Smart Roads. Safer Cities.

> A citizen-centric road damage reporting and monitoring platform that transforms geo-tagged road reports into a structured, map-based view of road conditions.

[![Flutter](https://img.shields.io/badge/Flutter-02569B?logo=flutter\&logoColor=white)](https://flutter.dev/)
[![Firebase](https://img.shields.io/badge/Firebase-FFCA28?logo=firebase\&logoColor=black)](https://firebase.google.com/)
[![Cloudinary](https://img.shields.io/badge/Cloudinary-3448C5?logo=cloudinary\&logoColor=white)](https://cloudinary.com/)
[![OpenStreetMap](https://img.shields.io/badge/OpenStreetMap-7EBC6F?logo=openstreetmap\&logoColor=white)](https://www.openstreetmap.org/)

---

## Overview

Road damage such as potholes, cracks, and surface deterioration can create safety hazards, increase travel time, damage vehicles, and disrupt everyday mobility.

**PATHA** provides a simple digital workflow for citizens to report road damage with photographic evidence and automatically captured location data. Reports are stored centrally, tracked through their lifecycle, and visualized geographically so that road issues can be understood in their actual spatial context.

The platform brings together **citizen reporting, geo-tagging, image evidence, cloud storage, complaint tracking, and interactive map visualization** in a single system.

Project Timeline: Feb 2026 – March 2026
---

## The Problem

Traditional road complaint processes can make it difficult to:

* Report road damage with precise location and visual evidence
* Identify where reported issues are concentrated
* Track the status of submitted complaints
* Maintain structured and accessible road-condition data
* Provide citizens with a clear view of reported road issues

PATHA addresses these gaps by creating a **location-aware and evidence-based reporting layer for road infrastructure**.

---

## Key Features

### 📍 Geo-Tagged Road Reporting

Citizens can submit road damage reports with automatically captured geographic coordinates, issue details, and photographic evidence.

### 📸 Evidence-Based Reporting

Images provide visual evidence of the reported road condition and are securely stored through Cloudinary.

### 🗺️ Interactive Road Map

Reported issues are displayed geographically using OpenStreetMap-based map visualization, allowing users to understand the spatial distribution of road damage.

### 📋 Complaint Management

Users can view submitted complaints, inspect individual report details, and follow their current status.

### 🔄 Real-Time Data Synchronization

Firebase Realtime Database maintains structured report data and synchronizes updates across the application.

### 🕒 Location & Timestamp Capture

Each submission is associated with location and submission-time information, improving the reliability and context of the report.

### 🔎 Road Issue Visibility

Users can explore reported road problems through the complaints and map interfaces rather than relying on isolated complaint records.

---

## How PATHA Works

```text
┌──────────────────────┐
│       CITIZEN        │
│  Reports Road Issue  │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────────────┐
│       REPORT MODULE          │
│ Image + Details + GPS Data   │
└──────────┬───────────────────┘
           │
      ┌────┴─────┐
      ▼          ▼
┌───────────┐ ┌──────────────┐
│ Cloudinary│ │   Firebase   │
│   Images  │ │ Reports/Data │
└─────┬─────┘ └──────┬───────┘
      │              │
      └──────┬───────┘
             ▼
┌──────────────────────────────┐
│        PATHA PLATFORM        │
│ Complaints • Tracking • Map  │
└──────────────┬───────────────┘
               │
               ▼
┌──────────────────────────────┐
│      ROAD CONDITION VIEW     │
│ Location-based issue mapping │
└──────────────────────────────┘
```

---

## System Architecture

PATHA follows a lightweight cloud-based architecture designed around independent application, storage, geolocation, and visualization components.

```text
                    ┌─────────────────────┐
                    │   Flutter Web/App   │
                    │                     │
                    │ Report │ Track │ Map│
                    └──────────┬──────────┘
                               │
              ┌────────────────┼────────────────┐
              │                │                │
              ▼                ▼                ▼
       ┌────────────┐   ┌────────────┐   ┌──────────────┐
       │  Firebase  │   │ Cloudinary │   │  Nominatim   │
       │    RTDB    │   │   Images   │   │  Geocoding   │
       └────────────┘   └────────────┘   └──────────────┘
              │                │                │
              └────────────────┼────────────────┘
                               ▼
                     ┌─────────────────────┐
                     │ PATHA Data Layer    │
                     │ Reports + Location  │
                     │ Images + Status     │
                     └──────────┬──────────┘
                                │
                                ▼
                     ┌─────────────────────┐
                     │ Map & User Views    │
                     └─────────────────────┘
```

---

## Application Workflow

### 1. Report

The citizen opens PATHA and submits a road-damage report with an image, issue details, and automatically captured location.

### 2. Store

The image is uploaded to Cloudinary while structured report information is stored in Firebase Realtime Database.

### 3. Locate

The captured coordinates are used to identify and display the report at its geographic location.

### 4. Track

The citizen can access the submitted complaint and view its current status.

### 5. Visualize

Reported road issues are displayed on an interactive map, providing a city-level spatial view of reported problems.

---

## Technology Stack

| Category           | Technology                 |
| ------------------ | -------------------------- |
| Frontend           | Flutter                    |
| Web Application    | Flutter Web                |
| Mobile Application | Flutter / Android          |
| Database           | Firebase Realtime Database |
| Image Storage      | Cloudinary                 |
| Maps               | OpenStreetMap              |
| Geocoding          | Nominatim API              |
| Location           | Device Geolocation         |
| Language           | Dart                       |
| Version Control    | Git & GitHub               |

---

## Project Structure

```text
PATHA/
│
├── lib/
│   ├── screens/
│   │   ├── home/
│   │   ├── report/
│   │   ├── complaints/
│   │   ├── track/
│   │   └── map/
│   │
│   ├── services/
│   │   ├── firebase/
│   │   ├── cloudinary/
│   │   ├── geolocation/
│   │   └── geocoding/
│   │
│   ├── models/
│   ├── widgets/
│   └── main.dart
│
├── assets/
├── android/
├── web/
├── pubspec.yaml
└── README.md
```

> Adjust the folder names above to match the final repository structure if your implementation uses different names.

---
## Running Locally

### Prerequisites

* Flutter SDK
* Dart SDK
* Android Studio / VS Code
* Firebase project
* Cloudinary account
* Internet connection for map and geocoding services

### Installation

```bash
# Clone the repository
git clone https://github.com/YOUR_USERNAME/PATHA.git

# Navigate to the project
cd PATHA

# Install dependencies
flutter pub get

# Run the application
flutter run
```

For web:

```bash
flutter run -d chrome
```

---

## Configuration

Before running the application, configure the required Firebase and Cloudinary credentials.

Keep credentials outside the repository and **never commit private API keys, service-account files, or production secrets to GitHub**.

---

## Design Approach

PATHA is designed around five principles:

**Simple** — Reporting a road issue should require minimal effort.

**Evidence-based** — Reports are supported by images and location data.

**Location-aware** — Road issues are meaningful only when their geographic context is known.

**Transparent** — Citizens can access their reports and track their status.

**Scalable** — The application separates the user interface, data storage, image storage, and location services to support independent scaling.

---

## Impact

PATHA creates a structured digital channel between **citizens and road-condition data**.

Instead of isolated complaints, every report contributes:

**Evidence → Location → Structured Data → Map Visibility → Better Road Awareness**

This provides a stronger foundation for understanding road conditions and improving public mobility.

---

## Project Status

**Status:** Working Prototype

PATHA currently implements citizen road-damage reporting, geo-tagged data capture, image storage, complaint tracking, real-time data synchronization, and interactive map visualization.

---

## Built For

**Smart Road Damage Reporting & Rapid Response System for Solapur Municipal Corporation**

Developed as a smart-city mobility solution focused on improving citizen participation, road-condition visibility, and digital infrastructure monitoring.

---

## Author

**Sanskriti Shukla**

Computer Science & Engineering — Artificial Intelligence & Machine Learning

[GitHub](https://github.com/Sanskriti2305)

---

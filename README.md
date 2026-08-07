# 🌴 CocoConnect

> A digital ecosystem developed for the **Coconut Growers Association of Sri Lanka (CGASL)** to modernize coconut estate management, connect stakeholders, and enhance marketplace operations.

---

# Overview

CocoConnect is a digital platform designed to support the Sri Lankan coconut industry by providing an integrated ecosystem for estate owners, estate managers, buyers, service providers, and administrators.

The platform streamlines estate management, facilitates marketplace transactions, improves stakeholder communication, and enables data-driven decision-making through a centralized digital solution.

This project is developed as a **Third-Year Information Systems Group Project** at the **University of Colombo School of Computing (UCSC)** in collaboration with the **Coconut Growers Association of Sri Lanka (CGASL)**.

---

# Project Objectives

* Digitalize coconut estate management processes.
* Improve collaboration among industry stakeholders.
* Provide a centralized marketplace for coconut-related products and services.
* Simplify communication between buyers, estate owners, and service providers.
* Improve productivity through digital record management and reporting.

---

# Key Features

## Estate Owner

* Estate management
* Harvest management
* Marketplace management
* Buyer communication
* Service request management
* Dashboard and analytics

## Estate Manager

* Estate monitoring
* Harvest tracking
* Task management
* Workforce coordination
* Progress reporting

## Buyer

* Browse products
* Search and filter listings
* Purchase coconut products
* In-app negotiation and communication
* Order management

## Service Providers

* Offer machinery, fertilizer, labour, and other agricultural services
* Manage service requests
* Track ongoing services

## Administrator

* User management
* Marketplace moderation
* System monitoring
* Reports and analytics
* Platform administration

---

# Technology Stack

## Mobile Application

* Flutter
* Dart

## Backend

* Node.js
* Express.js

## Database

* PostgreSQL

## Development Tools

* Visual Studio Code
* Android Studio
* Git
* GitHub
* Postman
* Figma

## Future Integrations

* Firebase Cloud Messaging
* Google Maps API

---

# Repository Structure

```text
CocoConnect
│
├── backend/
│   ├── src/
│   ├── routes/
│   ├── controllers/
│   ├── middleware/
│   └── config/
│
├── mobile/
│
├── docs/
│
├── database/
│
├── README.md
│
└── .gitignore
```

---

# Git Branch Strategy

## Main Branches

* `main` — Production-ready code
* `develop` — Integration branch

## Feature Branches

* `estate-owner`
* `estate-manager`
* `buyer`
* `admin`

## Sub Feature Branches

### Estate Owner

* `estate-owner-dev1`
* `estate-owner-dev2`

### Buyer

* `buyer-dev1`
* `buyer-dev2`

---

# Development Workflow

1. Clone the repository.
2. Switch to your assigned branch.
3. Pull the latest changes before starting development.
4. Implement your assigned feature.
5. Commit changes using meaningful commit messages.
6. Push changes to your feature branch.
7. Create a Pull Request to merge into `develop`.
8. After testing and review, approved changes will be merged into `main`.

---

# Getting Started

## Clone the Repository

```bash
git clone https://github.com/<organization-or-username>/CocoConnect.git
```

## Navigate to the Project

```bash
cd CocoConnect
```

## Backend Setup

```bash
cd backend
npm install
npm run dev
```

## Mobile Application

```bash
cd mobile
flutter pub get
flutter run
```

---

# Team Modules

* Estate Owner
* Estate Manager
* Buyer
* Administrator

---

# Contributors

Developed by the Third-Year Information Systems undergraduate team of the **University of Colombo School of Computing (UCSC)** in collaboration with the **Coconut Growers Association of Sri Lanka (CGASL)**.

---

# License

This project is developed for academic purposes as part of the Bachelor of Science in Information Systems degree programme at the University of Colombo School of Computing (UCSC).

© 2026 CocoConnect Team. All rights reserved.

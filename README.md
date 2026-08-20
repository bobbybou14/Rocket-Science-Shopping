# 🇨🇦 Rocket Science Shopping

> **Helping Canadians save money on groceries through community-powered price intelligence.**

---

## Project Status

**Current Version:** v0.6.0

Rocket Science Shopping is an actively developed Flutter application designed to help Canadian shoppers compare grocery prices, track spending, and make smarter purchasing decisions.

The project is currently focused on building a robust cloud-based grocery price database and an intuitive shopping experience.

---

# Features

## Product Management

- Barcode scanning
- Manual barcode lookup
- Product lookup using Open Food Facts
- Product images
- Product catalog
- Product details

## Shopping

- Shopping cart
- Quantity controls
- Remove items
- Ontario HST calculation
- Running subtotal
- Shopping dashboard

## Price Intelligence

- Canadian grocery stores
- Product pricing
- Best price comparison
- Average price
- Potential savings
- Store comparison

## Administration

- Product management
- Store management
- Price management
- Supabase cloud synchronization

---

# Technology Stack

- Flutter
- Dart
- Material 3
- Supabase
- PostgreSQL
- Open Food Facts API
- Git
- GitHub

---

# Database

## Products

Stores:

- Barcode
- Name
- Brand
- Category
- Size
- Product Image
- Taxable Status

---

## Stores

Stores:

- Store Name
- Province
- City

---

## Prices

Stores:

- Product Barcode
- Store
- Province
- City
- Price
- Date Updated

---

# Current Architecture

```
Flutter
    │
    ├── Dashboard
    ├── Scanner
    ├── Shopping Cart
    ├── Product Catalog
    ├── Product Details
    ├── Admin
    │
    ├── Services
    ├── Models
    ├── Reusable Widgets
    │
    ▼
Supabase
```

---

# Roadmap

## ✅ Version 0.6 — Foundation

- Flutter application
- Supabase backend
- Product management
- Store management
- Price management
- Dashboard
- Product catalog
- Price intelligence
- Reusable widgets
- Centralized theme

---

## 🚀 Version 0.7 — Smart Shopping

- Global product search
- Favorites
- Recently scanned
- Categories
- Improved dashboard
- Better navigation

---

## 🚀 Version 0.8 — Price Intelligence

- Price history
- Price trend charts
- Biggest price drops
- Store rankings
- Weekly savings

---

## 🚀 Version 0.9 — Shopping Optimizer

- Shopping list optimization
- Cheapest store recommendations
- Multi-store comparisons
- Savings calculator

---

## 🚀 Version 1.0 — Public Beta

- Android release
- iPhone release
- User accounts
- Community pricing
- Receipt OCR
- AI shopping assistant

---

# Getting Started

Clone the repository

```bash
git clone https://github.com/bobbybou14/Rocket-Science-Shopping.git
```

Install dependencies

```bash
flutter pub get
```

Run the application

```bash
flutter run
```

---

# Vision

Rocket Science Shopping aims to become the most comprehensive grocery price comparison platform in Canada by combining community pricing, barcode scanning, receipt OCR, and intelligent shopping recommendations into one easy-to-use mobile application.

---

# License

This project is currently under active development.

License information will be added prior to the public release.
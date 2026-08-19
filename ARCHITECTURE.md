# Rocket Science Shopping Architecture

## Purpose

Rocket Science Shopping is a privacy-first, community-powered grocery price platform.

The mobile app helps shoppers scan products, build carts, compare prices, and eventually upload receipts so grocery prices can be updated automatically without requiring manual entry.

---

## Core Architecture

```text
Flutter Mobile App
        |
        v
Supabase Backend
        |
        +-- products
        +-- stores
        +-- prices
        +-- receipts
        +-- receipt_items
        |
        v
Shopping Optimizer
        |
        v
Recommendations
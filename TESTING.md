# Testing Strategy

## Overview
This document outlines the testing strategy for the General Store Inventory Management & POS System. The application is built using Flutter (Web-first) with Clean Architecture, Riverpod for state management, Isar for local offline-first storage, and Firebase for cloud syncing.

## 1. Unit Testing

### Domain & Data Layers
- **Repositories**: Test `LocalDbService` and individual repositories (e.g., `InventoryRepositoryImpl`, `SalesRepositoryImpl`) using mocked Isar instances to ensure correct CRUD operations.
- **Models & Serialization**: Ensure `fromJson` and `toJson` methods correctly serialize and deserialize complex fields (e.g., parsing JSON strings for items in `SaleModel`).
- **Extensions & Utils**: Test utilities like `dart_extensions.dart` (Currency formatters, String validation, DateTime helpers).

### State Management (Riverpod)
- Test `StateNotifierProvider` logic by verifying state changes.
- Ensure that actions like `addToCart`, `updateQuantity`, and `checkout` in `pos_controller.dart` properly mutate the `POSState` and update totals.

*Example Test Run command:*
```bash
flutter test
```

## 2. Widget Testing

- **Reusable Components**: Test base components such as `AppScaffold`, `ErrorWidget`, `EmptyState`, and Form fields to ensure they render properly under different states.
- **Dialogs & Overlays**: Test customer creation dialogs, payment modal, and barcode scanner inputs to verify user interactions trigger the expected Controller methods.
- **POS Screen Layouts**: Ensure the GridView catalog displays products properly and updates when items go out-of-stock.

## 3. Integration Testing

- Use `integration_test` package to simulate a complete Cashier flow:
  1. Login with a test Cashier account.
  2. Search for a product in the catalog.
  3. Scan a simulated barcode to add to cart.
  4. Change quantities.
  5. Select a Khata customer.
  6. Process the checkout.
  7. Verify the inventory stock decreased and the sale record exists.

## 4. Manual / QA Testing

- **Offline Sync**: Verify that the application continues to process sales while offline. Reconnect the device to the internet and ensure the background `SyncService` correctly pushes the local Isar records up to Firestore without data loss.
- **Print / PDF Layouts**: Test the PDF rendering of sales receipts and Barcode labels on thermal printers (80mm / 50x30mm) using desktop printer drivers.
- **Excel Export**: Ensure downloaded Excel spreadsheets map data to columns accurately.

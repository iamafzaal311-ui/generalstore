# Production Deployment Guide

## Overview
This guide covers the deployment of the General Store Inventory Management & POS System as a Flutter Web application hosted on Firebase Hosting.

## Prerequisites
1. Flutter SDK (`stable` channel, version >= 3.10.0)
2. Firebase CLI installed (`npm install -g firebase-tools`)
3. A Firebase project created in the Firebase Console.
4. Appropriate Firestore indices built for offline sync performance.

## 1. Firebase Preparation

1. **Login to Firebase CLI**:
   ```bash
   firebase login
   ```
2. **Initialize Firebase** in your project directory (if not already done):
   ```bash
   firebase init
   ```
   - Select `Firestore` and `Hosting`.
   - Select the correct Firebase project.
   - For Firestore rules, choose `firestore.rules`.
   - For public directory, type `build/web`.
   - Choose `Yes` to configure as a single-page app (rewrites all urls to `index.html`).

3. **Deploy Firestore Rules**:
   ```bash
   firebase deploy --only firestore:rules
   ```

## 2. Flutter Web Build

To build the application for web with optimal performance:

1. **Clean the project**:
   ```bash
   flutter clean
   flutter pub get
   ```

2. **Build the Web App**:
   For maximum performance, we use the CanvasKit renderer (default on desktop web):
   ```bash
   flutter build web --release --web-renderer canvaskit
   ```

3. **Cross-Origin Resource Sharing (CORS)** (Optional but Recommended):
   If you rely on specific external image assets or APIs, ensure CORS is correctly configured on your Firebase Storage buckets.
   Create a `cors.json`:
   ```json
   [
     {
       "origin": ["*"],
       "method": ["GET"],
       "maxAgeSeconds": 3600
     }
   ]
   ```
   Deploy it using `gsutil cors set cors.json gs://<your-project-id>.appspot.com`.

## 3. Deploy to Firebase Hosting

Run the following command to deploy the generated `build/web` folder to production:

```bash
firebase deploy --only hosting
```

## 4. Post-Deployment Checks
- Navigate to the provided Firebase Hosting URL.
- Verify that the service worker installs properly (allows for offline caching).
- Create a test sale and verify that the local Isar database saves the record immediately, and the `SyncService` synchronizes it to Cloud Firestore.

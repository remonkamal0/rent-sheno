# SMS SERVICES - Tenant & Property Management Mobile App

SMS SERVICES is a clean, premium, and professional Flutter mobile application built as a Property/Tenant Management System. It allows residents to manage their home information, submit maintenance requests, handle payments, upload insurance coverage information, and view notifications.

## Table of Contents

- [Features](#features)
- [Tech Stack](#tech-stack)
- [Installation & Local Setup](#installation--local-setup)
- [Supabase Configuration](#supabase-configuration)
  - [1. Database Schema Creation](#1-database-schema-creation)
  - [2. Row Level Security (RLS) Policies](#2-row-level-security-rls-policies)
  - [3. Storage Bucket Configuration](#3-storage-bucket-configuration)
- [Environment Variables](#environment-variables)
- [Building the Application](#building-the-application)
  - [Android Build](#android-build)
  - [iOS Build](#ios-build)

---

## Features

- **Multi-language Support:** Native toggle for English (LTR) and Arabic (RTL) locales.
- **Graceful Mock Fallback:** Seamlessly operates offline or in demo mode if Supabase credentials are not supplied.
- **Authentication:** Supabase Auth (Email + Password), persistent login ("Remember Me"), and forgot password recovery.
- **Home Dashboard:** Property summary banners, upcoming balances calculations, quick shortcuts, and latest alerts.
- **Maintenance Center:** Custom status badges, categorization grid, repair timeline updates, and media picking (supporting up to 3 image attachments).
- **Payment Portal:** Balances dashboard, detailed invoices breakdown, receipt logs, and card/ACH checkout simulations.
- **Renter's Insurance:** Active policy metric badges, expiration alert triggers, lease coverage checklists, and document picker.
- **Notification Center:** Custom vertical filter channels (`All`, `Unread`, `Maintenance`, `Payments`, `Insurance`, `General`).

---

## Tech Stack

- **Framework:** Flutter (Material 3)
- **Language:** Dart
- **Backend Architecture:** Supabase Client & PostgreSQL Database
- **State Management:** Flutter Riverpod (Notifier & FutureProvider bindings)
- **Routing Engine:** GoRouter (incorporating Auth Guard redirection and ShellRoute tab bars)
- **Security:** Secure Session Storage (`flutter_secure_storage`)
- **Notifications:** Local Notifications (`flutter_local_notifications`)
- **Asset pickers:** `image_picker` (Photos attachments) and `file_picker` (PDF/PNG insurance proofs)

---

## Installation & Local Setup

1. **Install Flutter SDK:**
   Verify Flutter is installed (v3.10.7 or later recommended):
   ```bash
   flutter --version
   ```

2. **Clone and Navigate into the Project:**
   ```bash
   cd sms_services
   ```

3. **Install Dependencies:**
   ```bash
   flutter pub get
   ```

4. **Run Codebase Unit Tests:**
   Ensure everything functions correctly:
   ```bash
   flutter test
   ```

5. **Start Development Environment:**
   ```bash
   flutter run
   ```

---

## Supabase Configuration

### 1. Database Schema Creation

Run the schema SQL query located in:
`supabase/migrations/20260817000000_sms_services_schema.sql`

This script configures the required database tables:
- `profiles` (User metadata linked to `auth.users.id`)
- `properties` (Addresses and image assets)
- `units` (Property unit entries)
- `leases` (Dates and payment terms)
- `maintenance_requests` (Title, categories, schedules, status)
- `maintenance_attachments` (Image references linked to requests)
- `charges` (Outstanding bills)
- `payments` (Payment transaction receipts)
- `insurance_policies` (Coverage summaries and verification files)
- `notifications` (System warnings)

### 2. Row Level Security (RLS) Policies

RLS is enabled on all tenant-specific tables to enforce strict data isolation. Profiles can only access records matching their personal `resident_id` profile session context:
- `profiles`: SELECT/UPDATE allowed only for `auth.uid() = auth_user_id`.
- `maintenance_requests`, `charges`, `payments`, `insurance_policies`, `notifications`: Restricted to records where the linking `resident_id` maps to the active authenticated account ID.

### 3. Storage Bucket Configuration

Initialize the following buckets within Supabase Storage console:
- `avatars` (Publicly readable, uploads restricted to authenticated owners)
- `property-images` (Publicly readable, uploads restricted to admins)
- `maintenance-attachments` (Private, restricted read/write to authenticated users)
- `insurance-documents` (Private, restricted read/write to authenticated users)

---

## Environment Variables

To bind the mobile app with a live Supabase project, launch or compile the app using `--dart-define` parameters:

```bash
flutter run \
  --dart-define=SUPABASE_URL="https://your-project.supabase.co" \
  --dart-define=SUPABASE_ANON_KEY="your-anon-key-here"
```

If these keys are left unset, the app **automatically detects the placeholders and starts in Mock Data mode**, allowing full, uninterrupted navigation using the predefined tenant demo credentials:
- **Email:** `john.doe@example.com`
- **Password:** `password123`

---

## Building the Application

### Android Build

1. **Build APK (Release):**
   ```bash
   flutter build apk --release
   ```
   *The generated package will be saved at `build/app/outputs/flutter-apk/app-release.apk`.*

2. **Build Android App Bundle (AAB - for Play Store upload):**
   ```bash
   flutter build appbundle --release
   ```
   *The bundle will be saved at `build/app/outputs/bundle/release/app-release.aab`.*

### iOS Build

1. **Pre-configuration:**
   Set up Cocoapods in the `ios` directory:
   ```bash
   cd ios && pod install && cd ..
   ```

2. **Build iOS Application Bundle:**
   ```bash
   flutter build ios --release --no-codesign
   ```
   *For publishing, open the `ios/Runner.xcworkspace` in Xcode to configure provisioning profiles and archive the build.*

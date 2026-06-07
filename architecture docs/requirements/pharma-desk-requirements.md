# PharmaDesk — High Level Requirements

## 1. User Management

- Roles: Patient, Pharmacist, Admin
- Registration, login, logout (JWT-based auth)
- Role-based access control across all modules
- Profile management per role

## 2. Patient Module

- Register and manage patient profiles
- View active and past prescriptions
- Request prescription refills
- Track medication pickup status
- Receive alerts for refill due dates and pickup ready notifications

## 3. Prescription Management

- Pharmacist creates and submits digital prescriptions for patients
- Pharmacist reviews and processes prescriptions through workflow: pending → verified → dispensed → rejected
- Flag duplicate or conflicting drug prescriptions
- Attach notes to prescriptions
- View full prescription history per patient
- Cancel or modify pending prescriptions
- Full prescription audit trail

## 4. Drug & Inventory Management

- Maintain drug catalog (name, category, dosage forms, price)
- Track stock levels per drug
- Expiry date tracking with alerts
- Low stock threshold alerts
- Manage suppliers and purchase orders

## 5. Billing & Payments

- Auto-generate invoice when prescription is dispensed
- Apply discounts where applicable
- Payment status tracking (paid, pending, partial)
- Billing history per patient

## 6. Notifications & Alerts

- Low stock alerts → pharmacist
- Prescription ready for pickup → patient
- Expiry warnings → pharmacist
- Refill reminders → patient

## 7. Analytics Dashboard (Admin/Pharmacist)

- Most dispensed drugs
- Monthly revenue summary
- Low stock overview
- Prescription volume trends

## 8. Mobile App (React Native — Patient)

- View prescriptions and pickup status
- Daily medication schedule with reminders
- Request refills
- Scan prescription barcode

## 9. Non-Functional Requirements

- Secure API (JWT + role guards)
- Input validation on all forms
- Paginated lists for drugs, patients, prescriptions
- Audit logging for prescription changes
- Responsive web UI

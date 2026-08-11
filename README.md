# Tailor Express Platform

This workspace contains a Flutter web app for Tailor Express booking plus a lightweight Python API for shared order storage.

## What is included

- Customer booking flow with policy-before-payment gate
- Private admin, employee, receptionist supervisor, driver supervisor, receptionist, tailor, and driver routes
- Shared booking API with JSON file storage
- Tracking page with driver-safe customer links
- Render-ready Docker deployment

## Local run

1. Start the API server:
   `python server.py`
2. Start Flutter web:
   `flutter run -d chrome`
3. In local development the Flutter app will call `http://127.0.0.1:8090/api/orders` automatically.

## Render deployment

- Render will build the Flutter web app.
- The runtime serves both the built web app and `/api/orders` from `server.py`.
- Shared orders are stored in `data/orders.json` inside the container. Add a Render Disk mounted at `/app/data` if you need orders to survive service rebuilds.

## Current credentials

Private dashboards use separate direct links and role credentials:

- Admin: `/login/admin` with `admin / Admin123!`
- Customer Service: `/login/employee` with `ops / Ops123!`
- Receptionist Supervisor: `/login/receptionistSupervisor` with `reception-lead / ReceptionLead123!`
- Driver Supervisor: `/login/driverSupervisor` with `driver-lead / DriverLead123!`
- Receptionist: `/login/receptionist` with `reception / Reception123!`
- Tailor: `/login/tailor` with `afroz / Tailor123!`
- Driver: `/login/driver` with `omar / Driver123!`

## Payment API

The app uses a backend UPay/UPayments hosted-checkout endpoint at `/api/payments/create`.
Set these environment variables on the server or Render:

- `UPAYMENTS_API_KEY`: server Bearer token from UPay/UPayments. Never expose this in Flutter/web code.
- `UPAYMENTS_BASE_URL`: UPayments API base URL. Use `https://sandboxapi.upayments.com` for sandbox unless UPay gives you a different live URL.
- `APP_BASE_URL`: public app URL used for return/cancel/webhook URLs, for example `https://tailor-express-booking.onrender.com`.
- `PAYMENT_AMOUNT_KWD`: default home-service amount, currently `3.500`.

Customers accept the policies first, then they are redirected to the hosted UPay checkout page.

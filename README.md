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

## Staff portal

All staff use one private login link: `/login/staff`. The signed-in user's role controls the dashboard tools.

Default credentials:

- Admin: `admin / Admin123!`
- Customer Service: `ops / Ops123!`
- Receptionist Supervisor: `reception-lead / ReceptionLead123!`
- Driver Supervisor: `driver-lead / DriverLead123!`
- Receptionist: `reception / Reception123!`
- Tailor: `afroz / Tailor123!`
- Driver: `omar / Driver123!`

Admin can create extra staff users from the Staff Users panel. Prototype staff users are stored in data/staff_users.json; production should move staff accounts to a real database with hashed passwords.

## Payment API

The app uses a backend UPay/UPayments hosted-checkout endpoint at `/api/payments/create`.
Set these environment variables on the server or Render:

- `UPAYMENTS_API_KEY`: server Bearer token from UPay/UPayments. Never expose this in Flutter/web code.
- `UPAYMENTS_BASE_URL`: UPayments API base URL. Use `https://sandboxapi.upayments.com` for sandbox unless UPay gives you a different live URL.
- `APP_BASE_URL`: public app URL used for return/cancel/webhook URLs, for example `https://tailor-express-booking.onrender.com`.
- `PAYMENT_AMOUNT_KWD`: default home-service amount, currently `3.500`.

Customers accept the policies first, then they are redirected to the hosted UPay checkout page.

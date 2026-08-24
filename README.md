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
- Shared orders, delivery area prices and runtime-created staff users are stored under `/app/data`.
- The Blueprint includes a 1 GB Render Disk mounted at `/app/data` so new bookings survive redeploys and restarts.
- Persistent disks require a paid Render instance type. The Blueprint uses `starter`.

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

- `UPAYMENTS_API_KEY`: plain live Bearer token from UPay/UPayments. Never expose this in Flutter/web code. Do not use the encrypted API key here.
- `UPAYMENTS_SANDBOX_API_KEY`: optional sandbox Bearer token. If omitted, the backend uses the UPayments whitelabel sandbox token for test checkout only.
- `UPAYMENTS_BASE_URL`: UPayments API base URL. Use `https://sandboxapi.upayments.com` for sandbox tests. Use `https://uapi.upayments.com` for live UInterfaceV2 payments. Do not use the old V1 host `https://api.upayments.com`.
- `APP_BASE_URL`: public app URL used for return/cancel/webhook URLs, for example `https://tailor-express-booking.onrender.com`.
- `PAYMENT_AMOUNT_KWD`: default home-service amount, currently `3.500`.

When `UPAYMENTS_BASE_URL` is `https://sandboxapi.upayments.com`, the checkout is sandbox-only and will not create a real debit/settlement. For real KNET/Apple Pay collection, set `UPAYMENTS_BASE_URL` to `https://uapi.upayments.com` and set `UPAYMENTS_API_KEY` to the live plain API token. The backend automatically maps the old V1 live URL `https://api.upayments.com` to the V2 live URL, but Render should still be configured with the correct V2 value.

Customers accept the policies first, then they are redirected to the hosted UPay checkout page.

## Delivery prices and bills

Admin users can edit delivery prices, activate/deactivate areas, and print customer bills from the dashboard. The selected active area price is shown to customers before payment and is used as the UPay checkout amount. When UPay redirects back with `payment=success`, the order is marked paid and the bill remains available in the dashboard. The price table is persisted in `/app/data/area_prices.json`, so keep the Render Disk mounted at `/app/data`.

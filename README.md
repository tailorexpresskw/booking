# Tailor Express Platform

This workspace contains a Flutter web app for Tailor Express booking plus a lightweight Python API for shared order storage.

## What is included

- Customer booking flow with policy-before-payment gate
- Private admin, employee, tailor, and driver routes
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
- Shared orders are stored in `data/orders.json` inside the container.

## Current credentials

- Admin: `admin / Admin123!`
- Employee: `ops / Ops123!`
- Tailor: `afroz / Tailor123!`
- Driver: `omar / Driver123!`


## Payment API

The app uses a backend MyFatoorah invoice-link endpoint at `/api/payments/create`.
Set these environment variables on the server or Render:

- `MYFATOORAH_API_KEY`: server token from MyFatoorah. Never expose this in Flutter/web code.
- `MYFATOORAH_BASE_URL`: `https://api.myfatoorah.com` for live Kuwait payments.
- `PAYMENT_AMOUNT_KWD`: default home-service amount, currently `3.500`.

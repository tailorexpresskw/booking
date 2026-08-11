import json
import os
import re
import urllib.error
import urllib.request
from datetime import datetime
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from threading import Lock
from urllib.parse import unquote, urlparse
import urllib.parse

ROOT = Path(__file__).resolve().parent
WEB_ROOT = ROOT / 'build' / 'web'
DATA_DIR = ROOT / 'data'
SEED_FILE = DATA_DIR / 'seed_orders.json'
ORDERS_FILE = DATA_DIR / 'orders.json'
STORE_LOCK = Lock()
DEFAULT_LAT = 29.3759
DEFAULT_LNG = 47.9774


def ensure_storage() -> None:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    if ORDERS_FILE.exists():
        return
    if SEED_FILE.exists():
        ORDERS_FILE.write_text(SEED_FILE.read_text(encoding='utf-8-sig'), encoding='utf-8')
    else:
        ORDERS_FILE.write_text('[]', encoding='utf-8')


def normalize_order(order: dict) -> dict:
    defaults = {
        'branch': 'Pending assignment',
        'receptionist': 'Pending assignment',
        'driver': 'Pending assignment',
        'tailor': 'Pending assignment',
        'stage': 'newBooking',
        'timeline': [],
    }
    for key, value in defaults.items():
        if key == 'timeline':
            if not isinstance(order.get(key), list):
                order[key] = []
        elif not str(order.get(key, '')).strip():
            order[key] = value
    return order


def load_orders() -> list[dict]:
    ensure_storage()
    with STORE_LOCK:
        payload = json.loads(ORDERS_FILE.read_text(encoding='utf-8-sig'))
    if not isinstance(payload, list):
        return []
    return [normalize_order(order) for order in payload if isinstance(order, dict)]


def save_orders(orders: list[dict]) -> None:
    ensure_storage()
    with STORE_LOCK:
        ORDERS_FILE.write_text(json.dumps(orders, ensure_ascii=False, indent=2), encoding='utf-8')


def next_order_id(orders: list[dict]) -> str:
    current = 2400
    for order in orders:
        match = re.match(r'TE-(\d+)$', str(order.get('id', '')))
        if match:
            current = max(current, int(match.group(1)))
    return f'TE-{current + 1}'


def timestamp() -> str:
    return datetime.now().strftime('%d-%m-%Y %I:%M %p')




def payment_amount() -> float:
    try:
        return float(os.environ.get('PAYMENT_AMOUNT_KWD', '3.500'))
    except ValueError:
        return 3.5


def normalize_mobile_for_upayments(mobile: str) -> str:
    digits = ''.join(ch for ch in mobile if ch.isdigit())
    if digits.startswith('965'):
        return f'+{digits}'
    if len(digits) == 8:
        return f'+965{digits}'
    return f'+{digits}' if digits else ''


def app_base_url(payload: dict) -> str:
    configured = os.environ.get('APP_BASE_URL', '').strip().rstrip('/')
    if configured:
        return configured
    origin = str(payload.get('origin', '')).strip().rstrip('/')
    return origin or 'http://127.0.0.1:8090'


def create_upayments_payment(payload: dict) -> dict:
    token = os.environ.get('UPAYMENTS_API_KEY', '').strip()
    if not token:
        raise RuntimeError('Payment API is not configured. Set UPAYMENTS_API_KEY on the server.')

    base_url = os.environ.get('UPAYMENTS_BASE_URL', 'https://sandboxapi.upayments.com').rstrip('/')
    amount = float(payload.get('amount') or payment_amount())
    order_id = str(payload.get('orderId', '')).strip() or next_order_id(load_orders())
    customer_name = str(payload.get('customer', 'Tailor Express Customer')).strip() or 'Tailor Express Customer'
    service = str(payload.get('service', 'Tailor Express home service')).strip() or 'Tailor Express home service'
    language = str(payload.get('language', 'en')).strip().lower()
    if language not in ('en', 'ar'):
        language = 'en'
    base = app_base_url(payload)
    encoded_order_id = urllib.parse.quote(order_id, safe='')
    mobile = normalize_mobile_for_upayments(str(payload.get('mobile', '')))

    body = {
        'products': [
            {
                'name': service,
                'description': 'Tailor Express home service booking',
                'price': amount,
                'quantity': 1,
            }
        ],
        'order': {
            'id': order_id,
            'reference': order_id,
            'description': f'Tailor Express booking {order_id}',
            'currency': 'KWD',
            'amount': amount,
        },
        'language': language,
        'reference': {'id': order_id},
        'customer': {
            'uniqueId': mobile.replace('+', '') or order_id,
            'name': customer_name,
            'mobile': mobile,
        },
        'returnUrl': f'{base}/track?order={encoded_order_id}&payment=success',
        'cancelUrl': f'{base}/track?order={encoded_order_id}&payment=failed',
        'notificationUrl': f'{base}/api/payments/webhook',
        'customerExtraData': order_id,
        'paymentLinkExpiryInMinutes': int(os.environ.get('UPAYMENTS_LINK_EXPIRY_MINUTES', '60')),
    }

    request = urllib.request.Request(
        f'{base_url}/api/v1/charge',
        data=json.dumps(body).encode('utf-8'),
        headers={
            'Accept': 'application/json',
            'Authorization': f'Bearer {token}',
            'Content-Type': 'application/json',
        },
        method='POST',
    )
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            result = json.loads(response.read().decode('utf-8'))
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode('utf-8', errors='replace')
        raise RuntimeError(f'UPayments error {exc.code}: {detail}') from exc

    data = result.get('data') if isinstance(result, dict) else None
    if not isinstance(data, dict):
        raise RuntimeError('Unexpected UPayments response.')
    payment_url = data.get('link')
    if not payment_url:
        raise RuntimeError('UPayments did not return a payment URL.')
    return {
        'provider': 'upayments',
        'paymentUrl': payment_url,
        'trackId': data.get('trackId'),
        'amount': amount,
    }

def build_order(payload: dict, orders: list[dict]) -> dict:
    area_en = str(payload.get('areaEn', '')).strip()
    area_ar = str(payload.get('areaAr', area_en)).strip() or area_en
    block = str(payload.get('block', '')).strip()
    street = str(payload.get('street', '')).strip()
    building = str(payload.get('building', '')).strip()
    customer = str(payload.get('customer', '')).strip()
    mobile = str(payload.get('mobile', '')).strip()
    service = str(payload.get('service', '')).strip()
    preference = str(payload.get('preference', '')).strip()
    window = str(payload.get('window', '')).strip()
    notes = str(payload.get('notes', '')).strip()
    language = str(payload.get('language', 'en')).strip().lower()

    if language == 'ar':
        address = f'{area_ar}، قطعة {block}، شارع {street}، مبنى {building}'
        timeline = [
            f'{timestamp()} - تم إرسال الحجز',
            f'{timestamp()} - بانتظار تعيين العمليات',
        ]
    else:
        address = f'{area_en}, Block {block}, Street {street}, Building {building}'
        timeline = [
            f'{timestamp()} - Booking submitted',
            f'{timestamp()} - Waiting for operations assignment',
        ]

    return {
        'id': next_order_id(orders),
        'customer': customer,
        'mobile': mobile,
        'areaEn': area_en,
        'areaAr': area_ar,
        'address': address,
        'service': service,
        'preference': preference,
        'window': window,
        'branch': 'Pending assignment',
        'receptionist': 'Pending assignment',
        'driver': 'Pending assignment',
        'tailor': 'Pending assignment',
        'stage': 'newBooking',
        'lat': DEFAULT_LAT,
        'lng': DEFAULT_LNG,
        'notes': notes,
        'timeline': timeline,
    }


class TailorHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        directory = str(WEB_ROOT if WEB_ROOT.exists() else ROOT)
        super().__init__(*args, directory=directory, **kwargs)

    def log_message(self, fmt: str, *args) -> None:
        print(f'[{self.log_date_time_string()}] {fmt % args}')

    def end_headers(self) -> None:
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.send_header('Access-Control-Allow-Methods', 'GET,POST,PATCH,OPTIONS')
        self.send_header('Cache-Control', 'no-store')
        super().end_headers()

    def do_OPTIONS(self) -> None:
        self.send_response(204)
        self.end_headers()

    def _send_json(self, payload: object, status: int = 200) -> None:
        body = json.dumps(payload, ensure_ascii=False).encode('utf-8')
        self.send_response(status)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _read_json_body(self) -> dict:
        length = int(self.headers.get('Content-Length', '0') or '0')
        raw = self.rfile.read(length) if length else b'{}'
        return json.loads(raw.decode('utf-8') or '{}')

    def do_GET(self) -> None:
        parsed = urlparse(self.path)
        if parsed.path == '/api/health':
            self._send_json({'ok': True, 'date': datetime.now().isoformat()})
            return
        if parsed.path == '/api/orders':
            self._send_json(load_orders())
            return

        if WEB_ROOT.exists():
            candidate = (WEB_ROOT / parsed.path.lstrip('/')).resolve()
            try:
                candidate.relative_to(WEB_ROOT.resolve())
            except ValueError:
                self.send_error(403)
                return
            if parsed.path in ('', '/'):
                self.path = '/index.html'
            elif not candidate.exists() or candidate.is_dir():
                self.path = '/index.html'
        super().do_GET()

    def do_POST(self) -> None:
        parsed = urlparse(self.path)
        if parsed.path == '/api/payments/create':
            try:
                payload = self._read_json_body()
                payment = create_upayments_payment(payload)
            except json.JSONDecodeError:
                self._send_json({'error': 'Invalid JSON body'}, status=400)
            except RuntimeError as exc:
                self._send_json({'error': str(exc)}, status=503)
            except Exception as exc:
                self._send_json({'error': f'Payment request failed: {exc}'}, status=502)
            else:
                self._send_json(payment, status=201)
            return

        if parsed.path == '/api/payments/webhook':
            # UPayments sends server-to-server payment updates here.
            self._send_json({'ok': True})
            return

        if parsed.path != '/api/orders':
            self.send_error(404)
            return

        try:
            payload = self._read_json_body()
        except json.JSONDecodeError:
            self._send_json({'error': 'Invalid JSON body'}, status=400)
            return

        required = ['customer', 'mobile', 'areaEn', 'block', 'street', 'building', 'service', 'preference', 'window']
        missing = [key for key in required if not str(payload.get(key, '')).strip()]
        if missing:
            self._send_json({'error': f'Missing fields: {", ".join(missing)}'}, status=400)
            return

        orders = load_orders()
        order = build_order(payload, orders)
        orders.insert(0, order)
        save_orders(orders)
        self._send_json(order, status=201)

    def do_PATCH(self) -> None:
        parsed = urlparse(self.path)
        match = re.fullmatch(r'/api/orders/([^/]+)', parsed.path)
        if not match:
            self.send_error(404)
            return

        try:
            payload = self._read_json_body()
        except json.JSONDecodeError:
            self._send_json({'error': 'Invalid JSON body'}, status=400)
            return

        order_id = unquote(match.group(1))
        orders = load_orders()
        order = next((item for item in orders if str(item.get('id')) == order_id), None)
        if order is None:
            self._send_json({'error': 'Order not found'}, status=404)
            return

        allowed = {'branch', 'receptionist', 'driver', 'tailor', 'stage'}
        for key in allowed:
            if key in payload:
                order[key] = str(payload.get(key, '')).strip() or 'Pending assignment'

        note = str(payload.get('timelineNote', '')).strip()
        if note:
            timeline = order.setdefault('timeline', [])
            if not isinstance(timeline, list):
                timeline = []
                order['timeline'] = timeline
            timeline.append(f'{timestamp()} - {note}')

        normalize_order(order)
        save_orders(orders)
        self._send_json(order)



def main() -> None:
    ensure_storage()
    port = int(os.environ.get('PORT', '8090'))
    server = ThreadingHTTPServer(('0.0.0.0', port), TailorHandler)
    print(f'Tailor Express server running on http://0.0.0.0:{port}')
    server.serve_forever()


if __name__ == '__main__':
    main()

import json
import html
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
DATA_DIR = Path(os.environ.get('DATA_DIR', ROOT / 'data'))
SEED_FILE = Path(os.environ.get('SEED_FILE', DATA_DIR / 'seed_orders.json'))
FALLBACK_SEED_FILE = ROOT / 'seed_orders.json'
REPO_SEED_FILE = ROOT / 'data' / 'seed_orders.json'
ORDERS_FILE = DATA_DIR / 'orders.json'
STAFF_USERS_FILE = DATA_DIR / 'staff_users.json'
AREA_PRICES_FILE = DATA_DIR / 'area_prices.json'
PAYMENT_DRAFTS_FILE = DATA_DIR / 'payment_drafts.json'
STORE_LOCK = Lock()
DEFAULT_LAT = 29.3759
DEFAULT_LNG = 47.9774

DEFAULT_AREA_NAMES = [
    'Abdali',
    'Abdullah Al-Mubarak',
    'Abdullah Al-Salem',
    'Abu Al Hasaniya',
    'Abu Futaira',
    'Abu Halifa',
    'Adailiya',
    'Adan',
    'Ahmadi',
    'Ali Sabah Al-Salem',
    'Amghara',
    'Andalus',
    'Ardiya',
    'Ardiya Industrial',
    'Ashbelia',
    'Bayan',
    'Bneid Al Gar',
    'Daiya',
    'Dasma',
    'Dhajeej',
    'Doha',
    'Egaila',
    'Fahaheel',
    'Faiha',
    'Farwaniya',
    'Fintas',
    'Firdous',
    'Fnaitees',
    'Granada',
    'Hadiya',
    'Hateen',
    'Hawally',
    'Jaber Al Ahmad',
    'Jaber Al Ali',
    'Jabriya',
    'Jahra',
    'Jleeb Al-Shuyoukh',
    'Qadsiya',
    'Qairawan',
    'Kaifan',
    'Kabd',
    'Khaitan',
    'Khaldiya',
    'Kuwait City',
    'Mahboula',
    'Mangaf',
    'Mansouriya',
    'Messila',
    'Mirqab',
    'Mishref',
    'Mubarak Al-Abdullah',
    'Mubarak Al-Kabeer',
    'Nassem',
    'North West Sulaibikhat',
    'Nuzha',
    'Omariya',
    'Oyoun',
    'Qibla',
    'Qortuba',
    'Rabia',
    'Rawda',
    'Rehab',
    'Riggae',
    'Riqqa',
    'Rumaithiya',
    'Saad Al-Abdullah',
    'Sabah Al-Ahmad',
    'Sabah Al-Nasser',
    'Sabah Al-Salem',
    'Sabahiya',
    'Sabhan',
    'Salam',
    'Salmiya',
    'Salwa',
    'Shaab',
    'Sharq',
    'Shamiya',
    'Shuhada',
    'Shuwaikh',
    'Shuwaikh Industrial',
    'Siddeeq',
    'South Abdullah Al-Mubarak',
    'Sulaibiya',
    'Sulaibiya Industrial',
    'Sulaibikhat',
    'Surra',
    'Taima',
    'Wafra',
    'Waha',
    'West Abu Fatira',
    'West Abdullah Mubarak',
    'Yarmouk',
    'Zahra',
]

HIGH_PRICE_AREAS = {
    'Abdali',
    'Abu Futaira',
    'Abu Halifa',
    'Ahmadi',
    'Ali Sabah Al-Salem',
    'Egaila',
    'Fahaheel',
    'Farwaniya',
    'Fintas',
    'Firdous',
    'Fnaitees',
    'Hadiya',
    'Jaber Al Ahmad',
    'Jaber Al Ali',
    'Jahra',
    'Kabd',
    'Mahboula',
    'Mangaf',
    'Sabah Al-Ahmad',
    'Wafra',
}


DEFAULT_STAFF_USERS = [
    {'username': 'admin', 'password': 'Admin123!', 'displayName': 'Admin', 'role': 'admin', 'branch': '', 'active': True, 'availableToday': True, 'homeServiceToday': True},
    {'username': 'ops', 'password': 'Ops123!', 'displayName': 'Customer Service', 'role': 'employee', 'branch': '', 'active': True, 'availableToday': True, 'homeServiceToday': True},
    {'username': 'reception-lead', 'password': 'ReceptionLead123!', 'displayName': 'Reception Lead', 'role': 'receptionistSupervisor', 'branch': '', 'active': True, 'availableToday': True, 'homeServiceToday': True},
    {'username': 'driver-lead', 'password': 'DriverLead123!', 'displayName': 'Driver Lead', 'role': 'driverSupervisor', 'branch': '', 'active': True, 'availableToday': True, 'homeServiceToday': True},
    {'username': 'reception', 'password': 'Reception123!', 'displayName': 'Aisha', 'role': 'receptionist', 'branch': 'Yarmouk', 'active': True, 'availableToday': True, 'homeServiceToday': True},
    {'username': 'fatima', 'password': 'Reception123!', 'displayName': 'Fatima', 'role': 'receptionist', 'branch': 'Hessa AlMubarak District', 'active': True, 'availableToday': True, 'homeServiceToday': True},
    {'username': 'afroz', 'password': 'Tailor123!', 'displayName': 'AFROZ', 'role': 'tailor', 'branch': '', 'active': True, 'availableToday': True, 'homeServiceToday': True},
    {'username': 'omar', 'password': 'Driver123!', 'displayName': 'Omar', 'role': 'driver', 'branch': '', 'active': True, 'availableToday': True, 'homeServiceToday': True},
    {'username': 'khaled', 'password': 'Driver123!', 'displayName': 'Khaled', 'role': 'driver', 'branch': '', 'active': True, 'availableToday': True, 'homeServiceToday': True},
]
VALID_ROLES = {
    'admin',
    'employee',
    'receptionistSupervisor',
    'driverSupervisor',
    'receptionist',
    'tailor',
    'driver',
}


def ensure_storage() -> None:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    if not ORDERS_FILE.exists():
        if SEED_FILE.exists():
            ORDERS_FILE.write_text(SEED_FILE.read_text(encoding='utf-8-sig'), encoding='utf-8')
        elif FALLBACK_SEED_FILE.exists():
            ORDERS_FILE.write_text(FALLBACK_SEED_FILE.read_text(encoding='utf-8-sig'), encoding='utf-8')
        elif REPO_SEED_FILE.exists():
            ORDERS_FILE.write_text(REPO_SEED_FILE.read_text(encoding='utf-8-sig'), encoding='utf-8')
        else:
            ORDERS_FILE.write_text('[]', encoding='utf-8')
    if not STAFF_USERS_FILE.exists():
        STAFF_USERS_FILE.write_text(json.dumps(DEFAULT_STAFF_USERS, ensure_ascii=False, indent=2), encoding='utf-8')
    if not AREA_PRICES_FILE.exists():
        AREA_PRICES_FILE.write_text(json.dumps(default_area_prices(), ensure_ascii=False, indent=2), encoding='utf-8')
    if not PAYMENT_DRAFTS_FILE.exists():
        PAYMENT_DRAFTS_FILE.write_text('{}', encoding='utf-8')


def default_area_prices() -> list[dict]:
    return [
        {
            'areaEn': name,
            'price': 7.0 if name in HIGH_PRICE_AREAS else 5.0,
            'active': True,
        }
        for name in DEFAULT_AREA_NAMES
    ]


def normalize_area_price(item: dict) -> dict:
    area = str(item.get('areaEn', item.get('name', ''))).strip()
    try:
        price = float(item.get('price', 5.0))
    except (TypeError, ValueError):
        price = 5.0
    return {
        'areaEn': area,
        'price': max(price, 0.0),
        'active': bool(item.get('active', True)),
    }


def load_area_prices() -> list[dict]:
    ensure_storage()
    with STORE_LOCK:
        payload = json.loads(AREA_PRICES_FILE.read_text(encoding='utf-8-sig'))
    if not isinstance(payload, list):
        return default_area_prices()
    stored = {
        normalize_area_price(item)['areaEn'].lower(): normalize_area_price(item)
        for item in payload
        if isinstance(item, dict) and str(item.get('areaEn', item.get('name', ''))).strip()
    }
    for item in default_area_prices():
        stored.setdefault(item['areaEn'].lower(), item)
    return sorted(stored.values(), key=lambda item: item['areaEn'].lower())


def save_area_prices(items: list[dict]) -> None:
    ensure_storage()
    normalized = [normalize_area_price(item) for item in items if normalize_area_price(item)['areaEn']]
    with STORE_LOCK:
        AREA_PRICES_FILE.write_text(json.dumps(normalized, ensure_ascii=False, indent=2), encoding='utf-8')


def area_price_for(area_en: str) -> dict | None:
    normalized = area_en.strip().lower()
    for item in load_area_prices():
        if item['areaEn'].lower() == normalized:
            return item
    return None


def update_area_price(area_en: str, payload: dict) -> dict:
    target = area_en.strip()
    if not target:
        raise ValueError('Area is required.')
    prices = load_area_prices()
    area = next((item for item in prices if item['areaEn'].lower() == target.lower()), None)
    if area is None:
        area = {'areaEn': target, 'price': 5.0, 'active': True}
        prices.append(area)
    if 'price' in payload:
        try:
            price = float(payload['price'])
        except (TypeError, ValueError) as exc:
            raise ValueError('Price must be a number.') from exc
        if price < 0:
            raise ValueError('Price cannot be negative.')
        area['price'] = price
    if 'active' in payload:
        area['active'] = bool(payload['active'])
    save_area_prices(prices)
    return normalize_area_price(area)


def normalize_order(order: dict) -> dict:
    defaults = {
        'branch': 'Pending assignment',
        'receptionist': 'Pending assignment',
        'driver': 'Pending assignment',
        'tailor': 'Pending assignment',
        'stage': 'newBooking',
        'timeline': [],
        'invoiceNo': '',
        'paymentMethod': 'UPay',
        'paymentStatus': 'pending',
    }
    for key, value in defaults.items():
        if key == 'timeline':
            if not isinstance(order.get(key), list):
                order[key] = []
        elif not str(order.get(key, '')).strip():
            order[key] = value
    if 'deliveryPrice' not in order:
        area_price = area_price_for(str(order.get('areaEn', '')))
        order['deliveryPrice'] = area_price['price'] if area_price else payment_amount()
    try:
        order['deliveryPrice'] = float(order.get('deliveryPrice') or 0)
    except (TypeError, ValueError):
        order['deliveryPrice'] = 0.0
    if 'totalAmount' not in order:
        order['totalAmount'] = order['deliveryPrice']
    try:
        order['totalAmount'] = float(order.get('totalAmount') or order['deliveryPrice'])
    except (TypeError, ValueError):
        order['totalAmount'] = order['deliveryPrice']
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


def load_payment_drafts() -> dict:
    ensure_storage()
    with STORE_LOCK:
        payload = json.loads(PAYMENT_DRAFTS_FILE.read_text(encoding='utf-8-sig'))
    return payload if isinstance(payload, dict) else {}


def save_payment_drafts(drafts: dict) -> None:
    ensure_storage()
    with STORE_LOCK:
        PAYMENT_DRAFTS_FILE.write_text(json.dumps(drafts, ensure_ascii=False, indent=2), encoding='utf-8')


def save_payment_draft(draft_id: str, draft: dict) -> None:
    if not draft_id or not isinstance(draft, dict):
        return
    drafts = load_payment_drafts()
    saved = dict(draft)
    saved['draftId'] = draft_id
    saved['savedAt'] = datetime.now().isoformat()
    drafts[draft_id] = saved
    save_payment_drafts(drafts)


def get_payment_draft(draft_id: str) -> dict | None:
    draft = load_payment_drafts().get(draft_id)
    return draft if isinstance(draft, dict) else None


def delete_payment_draft(draft_id: str) -> None:
    drafts = load_payment_drafts()
    if draft_id in drafts:
        del drafts[draft_id]
        save_payment_drafts(drafts)


def normalize_staff_user(user: dict, include_password: bool = True) -> dict:
    normalized = {
        'username': str(user.get('username', '')).strip(),
        'displayName': str(user.get('displayName', '')).strip(),
        'role': str(user.get('role', 'employee')).strip(),
        'branch': str(user.get('branch', '')).strip(),
        'active': bool(user.get('active', True)),
        'availableToday': bool(user.get('availableToday', True)),
        'homeServiceToday': bool(user.get('homeServiceToday', True)),
    }
    if normalized['role'] not in VALID_ROLES:
        normalized['role'] = 'employee'
    if include_password:
        normalized['password'] = str(user.get('password', ''))
    return normalized


def public_staff_user(user: dict) -> dict:
    return normalize_staff_user(user, include_password=False)


def load_staff_users() -> list[dict]:
    ensure_storage()
    with STORE_LOCK:
        payload = json.loads(STAFF_USERS_FILE.read_text(encoding='utf-8-sig'))
    if not isinstance(payload, list):
        return [normalize_staff_user(user) for user in DEFAULT_STAFF_USERS]
    users = [normalize_staff_user(user) for user in payload if isinstance(user, dict)]
    return users or [normalize_staff_user(user) for user in DEFAULT_STAFF_USERS]


def save_staff_users(users: list[dict]) -> None:
    ensure_storage()
    normalized = [normalize_staff_user(user) for user in users]
    with STORE_LOCK:
        STAFF_USERS_FILE.write_text(json.dumps(normalized, ensure_ascii=False, indent=2), encoding='utf-8')


def authenticate_staff(username: str, password: str) -> dict | None:
    normalized_username = username.strip().lower()
    for user in load_staff_users():
        if not user.get('active', True):
            continue
        if user.get('username', '').lower() == normalized_username and user.get('password') == password:
            return public_staff_user(user)
    return None


def create_staff_user(payload: dict) -> dict:
    username = str(payload.get('username', '')).strip()
    password = str(payload.get('password', ''))
    display_name = str(payload.get('displayName', '')).strip()
    role = str(payload.get('role', 'employee')).strip()
    if not username or not password or not display_name:
        raise ValueError('Username, password and staff name are required.')
    if role not in VALID_ROLES:
        raise ValueError('Invalid staff role.')

    users = load_staff_users()
    if any(user.get('username', '').lower() == username.lower() for user in users):
        raise ValueError('Username already exists.')
    user = normalize_staff_user({
        'username': username,
        'password': password,
        'displayName': display_name,
        'role': role,
        'branch': str(payload.get('branch', '')).strip(),
        'active': bool(payload.get('active', True)),
        'availableToday': bool(payload.get('availableToday', True)),
        'homeServiceToday': bool(payload.get('homeServiceToday', True)),
    })
    users.append(user)
    save_staff_users(users)
    return public_staff_user(user)


def update_staff_user(username: str, payload: dict) -> dict:
    target = username.strip().lower()
    users = load_staff_users()
    user = next((item for item in users if item.get('username', '').lower() == target), None)
    if user is None:
        raise ValueError('User not found.')
    if 'displayName' in payload and str(payload.get('displayName', '')).strip():
        user['displayName'] = str(payload.get('displayName', '')).strip()
    if 'password' in payload and str(payload.get('password', '')):
        user['password'] = str(payload.get('password', ''))
    if 'role' in payload:
        role = str(payload.get('role', '')).strip()
        if role not in VALID_ROLES:
            raise ValueError('Invalid staff role.')
        user['role'] = role
    if 'branch' in payload:
        user['branch'] = str(payload.get('branch', '')).strip()
    if 'active' in payload:
        user['active'] = bool(payload.get('active'))
    if 'availableToday' in payload:
        user['availableToday'] = bool(payload.get('availableToday'))
    if 'homeServiceToday' in payload:
        user['homeServiceToday'] = bool(payload.get('homeServiceToday'))
    normalized = normalize_staff_user(user)
    for index, item in enumerate(users):
        if item.get('username', '').lower() == target:
            users[index] = normalized
            break
    save_staff_users(users)
    return public_staff_user(normalized)


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


def clean_gateway_error(detail: str) -> str:
    if not detail:
        return ''
    title_match = re.search(r'<title[^>]*>(.*?)</title>', detail, re.IGNORECASE | re.DOTALL)
    if title_match:
        detail = title_match.group(1)
    detail = re.sub(r'<script\b[^<]*(?:(?!</script>)<[^<]*)*</script>', ' ', detail, flags=re.IGNORECASE)
    detail = re.sub(r'<style\b[^<]*(?:(?!</style>)<[^<]*)*</style>', ' ', detail, flags=re.IGNORECASE)
    detail = re.sub(r'<[^>]+>', ' ', detail)
    detail = html.unescape(detail)
    detail = re.sub(r'\s+', ' ', detail).strip()
    return detail[:300]


def is_valid_payment_url(value: str) -> bool:
    if not value or '<' in value or '>' in value:
        return False
    parsed = urllib.parse.urlparse(value)
    if parsed.scheme not in ('http', 'https') or not parsed.netloc:
        return False
    if '/assets/' in parsed.path:
        return False
    return True


def upayments_token(base_url: str) -> str:
    configured = os.environ.get('UPAYMENTS_API_KEY', '').strip()
    if configured:
        return configured
    if 'sandboxapi.upayments.com' in base_url.lower():
        return 'jtest123'
    return ''


def create_upayments_payment(payload: dict) -> dict:
    base_url = os.environ.get('UPAYMENTS_BASE_URL', 'https://sandboxapi.upayments.com').rstrip('/')
    token = upayments_token(base_url)
    if not token:
        raise RuntimeError('Payment API is not configured. Set UPAYMENTS_API_KEY on the server.')

    order_id = str(payload.get('orderId', '')).strip() or next_order_id(load_orders())
    draft = payload.get('draft')
    if order_id.upper().startswith('DRAFT-') and isinstance(draft, dict):
        save_payment_draft(order_id, draft)
    existing_order = next((item for item in load_orders() if str(item.get('id')) == order_id), None)
    if existing_order is not None:
        amount = float(existing_order.get('totalAmount') or existing_order.get('deliveryPrice') or payment_amount())
    else:
        amount = float(payload.get('amount') or payment_amount())
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
        'returnUrl': f'{base}/track?order={encoded_order_id}&payment=return',
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
            # UPayments/Cloudflare blocks Python's default urllib signature.
            'User-Agent': 'Mozilla/5.0 TailorExpressBooking/1.0',
        },
        method='POST',
    )
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            raw = response.read().decode('utf-8')
            result = json.loads(raw)
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode('utf-8', errors='replace')
        cleaned = clean_gateway_error(detail)
        if detail.lstrip().lower().startswith(('<!doctype', '<html')):
            cleaned = cleaned or 'HTML error page returned.'
            raise RuntimeError(
                f'UPayments error {exc.code}: {cleaned}. Check UPAYMENTS_BASE_URL and live API key.'
            ) from exc
        raise RuntimeError(f'UPayments error {exc.code}: {cleaned or detail[:300]}') from exc
    except json.JSONDecodeError as exc:
        cleaned = clean_gateway_error(raw)
        raise RuntimeError(f'UPayments returned a non-JSON response: {cleaned or raw[:300]}') from exc

    data = result.get('data') if isinstance(result, dict) else None
    if isinstance(result, dict) and result.get('status') is False:
        message = str(result.get('message', '')).strip() or 'Payment request was rejected.'
        raise RuntimeError(f'UPayments rejected the payment request: {message}')
    if not isinstance(data, dict):
        message = str(result.get('message', '')).strip() if isinstance(result, dict) else ''
        raise RuntimeError(message or 'Unexpected UPayments response.')
    payment_url = (
        data.get('link')
        or data.get('paymentUrl')
        or data.get('paymentURL')
        or data.get('url')
    )
    payment_url = str(payment_url or '').strip()
    if not is_valid_payment_url(payment_url):
        raise RuntimeError('UPayments did not return a valid payment URL.')
    return {
        'provider': 'upayments',
        'paymentUrl': payment_url,
        'trackId': data.get('trackId'),
        'amount': amount,
    }


def first_query_value(payload: dict, *keys: str) -> str:
    for key in keys:
        value = payload.get(key)
        if isinstance(value, list) and value:
            value = value[0]
        if value is not None and str(value).strip():
            return str(value).strip()
    return ''


def find_payment_status_value(payload: object) -> str:
    status_keys = {
        'status',
        'result',
        'payment_status',
        'paymentStatus',
        'transaction_status',
        'transactionStatus',
    }
    if isinstance(payload, dict):
        for key, value in payload.items():
            if key in status_keys and isinstance(value, str) and value.strip():
                return value.strip()
        for value in payload.values():
            nested = find_payment_status_value(value)
            if nested:
                return nested
    if isinstance(payload, list):
        for value in payload:
            nested = find_payment_status_value(value)
            if nested:
                return nested
    return ''


def normalize_payment_state(status: str) -> str:
    normalized = status.strip().lower()
    if normalized in {'captured', 'paid', 'success', 'succeeded', 'approved'}:
        return 'paid'
    if normalized in {
        'failed',
        'cancel',
        'cancelled',
        'canceled',
        'declined',
        'expired',
        'void',
        'error',
    }:
        return 'failed'
    return 'pending'


def check_upayments_payment_status(track_id: str) -> dict:
    base_url = os.environ.get('UPAYMENTS_BASE_URL', 'https://sandboxapi.upayments.com').rstrip('/')
    token = upayments_token(base_url)
    if not token:
        raise RuntimeError('Payment API is not configured. Set UPAYMENTS_API_KEY on the server.')
    if not track_id:
        return {'verified': False, 'status': 'pending', 'rawStatus': '', 'raw': {}}

    request = urllib.request.Request(
        f'{base_url}/api/v1/get-payment-status/{urllib.parse.quote(track_id, safe="")}',
        headers={
            'Accept': 'application/json',
            'Authorization': f'Bearer {token}',
            'User-Agent': 'Mozilla/5.0 TailorExpressBooking/1.0',
        },
        method='GET',
    )
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            result = json.loads(response.read().decode('utf-8'))
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode('utf-8', errors='replace')
        raise RuntimeError(f'UPayments status error {exc.code}: {detail}') from exc

    raw_status = find_payment_status_value(result)
    status = normalize_payment_state(raw_status)
    return {
        'verified': status == 'paid',
        'status': status,
        'rawStatus': raw_status,
        'raw': result,
    }


def confirm_upayments_payment(payload: dict) -> dict:
    params = payload.get('params')
    if not isinstance(params, dict):
        params = payload

    draft_id = first_query_value(params, 'order', 'orderId', 'reference', 'reference_id')
    track_id = first_query_value(
        params,
        'track_id',
        'trackId',
        'trackid',
        'payment_id',
        'paymentId',
        'paymentID',
    )

    status = check_upayments_payment_status(track_id)
    if status.get('status') != 'paid':
        return status

    orders = load_orders()
    existing = next(
        (
            item
            for item in orders
            if str(item.get('paymentDraftId', '')).strip() == draft_id
            or str(item.get('id', '')).strip() == draft_id
        ),
        None,
    )
    if existing is not None:
        existing['paymentStatus'] = 'paid'
        normalize_order(existing)
        save_orders(orders)
        return {**status, 'order': existing}

    if not draft_id.upper().startswith('DRAFT-'):
        return status

    draft = get_payment_draft(draft_id)
    if draft is None:
        raise RuntimeError('Booking draft was not found. No order was created.')

    try:
        order = build_order({**draft, 'paymentStatus': 'paid', 'paymentDraftId': draft_id}, orders)
    except ValueError as exc:
        raise RuntimeError(str(exc)) from exc
    orders.insert(0, order)
    save_orders(orders)
    delete_payment_draft(draft_id)
    return {**status, 'order': order}

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
    area_price = area_price_for(area_en)
    if area_price is None:
        raise ValueError('Selected area is not available.')
    if not area_price.get('active', True):
        raise ValueError('Selected area is currently not available.')
    delivery_price = float(area_price.get('price') or 0.0)
    order_id = next_order_id(orders)

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
        'id': order_id,
        'invoiceNo': f'INV-{order_id.replace("TE-", "")}',
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
        'deliveryPrice': delivery_price,
        'totalAmount': delivery_price,
        'paymentMethod': str(payload.get('paymentMethod', 'UPay')).strip() or 'UPay',
        'paymentStatus': str(payload.get('paymentStatus', 'pending')).strip() or 'pending',
        'paymentDraftId': str(payload.get('paymentDraftId', '')).strip(),
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
        if parsed.path == '/api/area-prices':
            self._send_json(load_area_prices())
            return
        if parsed.path == '/api/staff-users':
            self._send_json([public_staff_user(user) for user in load_staff_users()])
            return
        if parsed.path == '/api/payments/status':
            query = urllib.parse.parse_qs(parsed.query)
            track_id = (
                query.get('track_id', [''])[0]
                or query.get('trackId', [''])[0]
                or query.get('trackid', [''])[0]
                or query.get('payment_id', [''])[0]
                or query.get('paymentId', [''])[0]
                or query.get('paymentID', [''])[0]
            )
            try:
                status = check_upayments_payment_status(track_id)
            except RuntimeError as exc:
                self._send_json({'error': str(exc), 'verified': False, 'status': 'pending'}, status=502)
            else:
                self._send_json(status)
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

        if parsed.path == '/api/payments/confirm':
            try:
                payload = self._read_json_body()
                payment = confirm_upayments_payment(payload)
            except json.JSONDecodeError:
                self._send_json({'error': 'Invalid JSON body'}, status=400)
            except RuntimeError as exc:
                self._send_json({'error': str(exc), 'verified': False, 'status': 'pending'}, status=502)
            except Exception as exc:
                self._send_json({'error': f'Payment confirmation failed: {exc}', 'verified': False, 'status': 'pending'}, status=502)
            else:
                self._send_json(payment)
            return

        if parsed.path == '/api/payments/webhook':
            # UPayments sends server-to-server payment updates here.
            self._send_json({'ok': True})
            return

        if parsed.path == '/api/login':
            try:
                payload = self._read_json_body()
                user = authenticate_staff(str(payload.get('username', '')), str(payload.get('password', '')))
            except json.JSONDecodeError:
                self._send_json({'error': 'Invalid JSON body'}, status=400)
                return
            if user is None:
                self._send_json({'error': 'Incorrect username or password'}, status=401)
            else:
                self._send_json({'user': user})
            return

        if parsed.path == '/api/staff-users':
            try:
                payload = self._read_json_body()
                user = create_staff_user(payload)
            except json.JSONDecodeError:
                self._send_json({'error': 'Invalid JSON body'}, status=400)
            except ValueError as exc:
                self._send_json({'error': str(exc)}, status=400)
            else:
                self._send_json(user, status=201)
            return

        if parsed.path == '/api/area-prices':
            try:
                payload = self._read_json_body()
                area = update_area_price(str(payload.get('areaEn', '')), payload)
            except json.JSONDecodeError:
                self._send_json({'error': 'Invalid JSON body'}, status=400)
            except ValueError as exc:
                self._send_json({'error': str(exc)}, status=400)
            else:
                self._send_json(area, status=201)
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
        try:
            order = build_order(payload, orders)
        except ValueError as exc:
            self._send_json({'error': str(exc)}, status=400)
            return
        orders.insert(0, order)
        save_orders(orders)
        self._send_json(order, status=201)

    def do_PATCH(self) -> None:
        parsed = urlparse(self.path)
        match = re.fullmatch(r'/api/orders/([^/]+)', parsed.path)
        area_match = re.fullmatch(r'/api/area-prices/([^/]+)', parsed.path)
        staff_match = re.fullmatch(r'/api/staff-users/([^/]+)', parsed.path)
        if staff_match:
            try:
                payload = self._read_json_body()
                user = update_staff_user(unquote(staff_match.group(1)), payload)
            except json.JSONDecodeError:
                self._send_json({'error': 'Invalid JSON body'}, status=400)
            except ValueError as exc:
                status = 404 if str(exc) == 'User not found.' else 400
                self._send_json({'error': str(exc)}, status=status)
            else:
                self._send_json(user)
            return

        if area_match:
            try:
                payload = self._read_json_body()
                area = update_area_price(unquote(area_match.group(1)), payload)
            except json.JSONDecodeError:
                self._send_json({'error': 'Invalid JSON body'}, status=400)
            except ValueError as exc:
                self._send_json({'error': str(exc)}, status=400)
            else:
                self._send_json(area)
            return

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

        allowed = {'branch', 'receptionist', 'driver', 'tailor', 'stage', 'paymentStatus'}
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

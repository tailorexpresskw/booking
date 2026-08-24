import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

void main() => runApp(TailorWebApp(state: AppState()));

const maroon = Color(0xFF6E1D32);
const gold = Color(0xFFC7A04B);
const ink = Color(0xFF21171A);
const sand = Color(0xFFFAF5EA);
const blush = Color(0xFFFFEEF0);

enum Role {
  admin,
  employee,
  receptionistSupervisor,
  driverSupervisor,
  receptionist,
  tailor,
  driver
}

enum Stage {
  newBooking,
  completed,
  onShop,
  outForDelivery,
  branchAssigned,
  assigned,
  onWay,
  tailoring,
  ready,
  delivered,
  cancelled
}

const ordersStorageKey = 'tailor_express_orders_v1';
const staffUsersStorageKey = 'tailor_express_staff_users_v1';
const areaPricesStorageKey = 'tailor_express_area_prices_v1';
const bookingScheduleStorageKey = 'tailor_express_booking_schedule_v1';
const paymentDraftStoragePrefix = 'tailor_express_payment_draft_';
const paymentGatewayOptions = <Map<String, String>>[
  {
    'src': 'knet',
    'labelEn': 'KNET',
    'labelAr': '\u0643\u064a \u0646\u062a',
  },
  {
    'src': 'cc',
    'labelEn': 'Credit card',
    'labelAr':
        '\u0628\u0637\u0627\u0642\u0629 \u0627\u0626\u062a\u0645\u0627\u0646',
  },
];

Role? roleFromSlug(String slug) {
  for (final role in Role.values) {
    if (role.name == slug) return role;
  }
  return null;
}

String roleLabel(Role role, bool ar) => switch (role) {
      Role.admin => ar ? 'الإدارة' : 'Management',
      Role.employee => ar ? 'خدمة العملاء' : 'Customer Service',
      Role.receptionistSupervisor =>
        ar ? 'مشرف الاستقبال' : 'Receptionist Supervisor',
      Role.driverSupervisor => ar ? 'مشرف السائقين' : 'Driver Supervisor',
      Role.receptionist => ar ? 'الاستقبال' : 'Receptionist',
      Role.tailor => ar ? 'الخياط' : 'Tailor',
      Role.driver => ar ? 'السائق' : 'Driver',
    };

String stageLabel(Stage stage, bool ar) => switch (stage) {
      Stage.newBooking => ar
          ? '\u0642\u064a\u062f \u0627\u0644\u0627\u0646\u062a\u0638\u0627\u0631'
          : 'Pending',
      Stage.completed ||
      Stage.branchAssigned =>
        ar ? '\u0645\u0643\u062a\u0645\u0644' : 'Completed',
      Stage.onShop || Stage.tailoring => ar
          ? '\u0641\u064a \u0627\u0644\u0645\u062d\u0644 - \u0642\u064a\u062f \u0627\u0644\u0639\u0645\u0644'
          : 'In Shop - In progress',
      Stage.ready => ar ? '\u062c\u0627\u0647\u0632' : 'Ready',
      Stage.outForDelivery || Stage.assigned || Stage.onWay => ar
          ? '\u062e\u0627\u0631\u062c \u0644\u0644\u062a\u0648\u0635\u064a\u0644'
          : 'Out for delivery',
      Stage.delivered => ar
          ? '\u062a\u0645 \u0627\u0644\u062a\u0633\u0644\u064a\u0645'
          : 'Delivered',
      Stage.cancelled => ar ? '\u0645\u0644\u063a\u064a' : 'Cancelled',
    };

String legacyStageLabel(Stage stage, bool ar) => switch (stage) {
      Stage.cancelled => ar ? '\u0645\u0644\u063a\u064a' : 'Cancelled',
      Stage.newBooking => ar ? 'طلب جديد' : 'New Order',
      Stage.completed || Stage.branchAssigned => ar ? 'مكتمل' : 'Completed',
      Stage.onShop || Stage.tailoring => ar ? 'في المحل' : 'On Shop',
      Stage.ready => ar ? 'جاهز' : 'Ready',
      Stage.outForDelivery ||
      Stage.assigned ||
      Stage.onWay =>
        ar ? 'خارج للتوصيل' : 'Out for Delivery',
      Stage.delivered => ar ? 'تم التسليم' : 'Delivered',
    };

Stage stageFromKey(String value) {
  final normalized = value.trim();
  if (normalized == 'branchAssigned') return Stage.completed;
  if (normalized == 'tailoring') return Stage.onShop;
  if (normalized == 'assigned' || normalized == 'onWay') {
    return Stage.outForDelivery;
  }
  for (final stage in Stage.values) {
    if (stage.name == normalized) return stage;
  }
  return Stage.newBooking;
}

Color stageColor(Stage stage) => switch (stage) {
      Stage.newBooking => gold,
      Stage.completed || Stage.branchAssigned => const Color(0xFF7A5B2F),
      Stage.onShop || Stage.tailoring => maroon,
      Stage.ready => const Color(0xFF3A9962),
      Stage.outForDelivery ||
      Stage.assigned ||
      Stage.onWay =>
        const Color(0xFF2A63B5),
      Stage.delivered => const Color(0xFF2D8A57),
      Stage.cancelled => const Color(0xFF9A3A2F),
    };

int stageRank(Stage stage) => switch (stage) {
      Stage.newBooking => 0,
      Stage.completed || Stage.branchAssigned => 1,
      Stage.onShop || Stage.tailoring => 2,
      Stage.ready => 3,
      Stage.outForDelivery || Stage.assigned || Stage.onWay => 4,
      Stage.delivered => 5,
      Stage.cancelled => 6,
    };

String customerStageLabel(Stage stage, bool ar) => switch (stage) {
      Stage.newBooking => ar
          ? '\u0642\u064a\u062f \u0627\u0644\u0627\u0646\u062a\u0638\u0627\u0631'
          : 'Pending',
      Stage.completed ||
      Stage.branchAssigned ||
      Stage.onShop ||
      Stage.tailoring =>
        ar
            ? '\u062c\u0627\u0631\u064a \u0627\u0644\u0639\u0645\u0644 \u0639\u0644\u064a\u0647'
            : 'Working on it',
      Stage.ready => ar ? '\u062c\u0627\u0647\u0632' : 'Ready',
      Stage.outForDelivery || Stage.assigned || Stage.onWay => ar
          ? '\u062e\u0627\u0631\u062c \u0644\u0644\u062a\u0648\u0635\u064a\u0644'
          : 'Out for delivery',
      Stage.delivered => ar
          ? '\u062a\u0645 \u0627\u0644\u062a\u0633\u0644\u064a\u0645'
          : 'Delivered',
      Stage.cancelled => ar ? '\u0645\u0644\u063a\u064a' : 'Cancelled',
    };

String legacyCustomerStageLabel(Stage stage, bool ar) => switch (stage) {
      Stage.cancelled => ar ? '\u0645\u0644\u063a\u064a' : 'Cancelled',
      Stage.newBooking => ar ? 'تم استلام الطلب' : 'Order received',
      Stage.completed ||
      Stage.branchAssigned ||
      Stage.onShop ||
      Stage.tailoring =>
        ar ? 'جاري العمل عليه' : 'Working on it',
      Stage.ready => ar ? 'جاهز' : 'Ready',
      Stage.outForDelivery ||
      Stage.assigned ||
      Stage.onWay =>
        ar ? 'خارج للتوصيل' : 'Out for Delivery',
      Stage.delivered => ar ? 'تم التسليم' : 'Delivered',
    };

bool isReadyForDriverAssignment(Order order) =>
    order.stage == Stage.ready && order.hasBranch && !order.hasDriver;

bool isDelivered(Order order) => order.stage == Stage.delivered;
bool isClosedOrder(Order order) =>
    order.stage == Stage.delivered || order.stage == Stage.cancelled;

bool isDraftOrderId(String value) =>
    value.trim().toUpperCase().startsWith('DRAFT-');

bool hasConfirmedPayment(Order order) {
  final status = order.paymentStatus.trim().toLowerCase();
  return !{'failed', 'cancelled', 'canceled', 'void'}.contains(status);
}

class Area {
  const Area(this.en, this.ar);
  final String en;
  final String ar;
  String name(bool isArabic) => isArabic ? ar : en;
}

class Order {
  const Order({
    required this.id,
    required this.customer,
    required this.mobile,
    required this.areaEn,
    required this.areaAr,
    required this.address,
    required this.service,
    required this.preference,
    required this.window,
    this.invoiceNo = '',
    this.deliveryPrice = 3.5,
    this.totalAmount = 3.5,
    this.paymentMethod = 'UPay',
    this.paymentStatus = 'pending',
    this.branch = 'Pending assignment',
    this.receptionist = 'Pending assignment',
    required this.driver,
    required this.tailor,
    required this.stage,
    required this.lat,
    required this.lng,
    required this.notes,
    required this.timeline,
  });

  final String id;
  final String customer;
  final String mobile;
  final String areaEn;
  final String areaAr;
  final String address;
  final String service;
  final String preference;
  final String window;
  final String invoiceNo;
  final double deliveryPrice;
  final double totalAmount;
  final String paymentMethod;
  final String paymentStatus;
  final String branch;
  final String receptionist;
  final String driver;
  final String tailor;
  final Stage stage;
  final double lat;
  final double lng;
  final String notes;
  final List<String> timeline;

  String area(bool isArabic) => isArabic ? areaAr : areaEn;

  bool get hasBranch => !isPendingAssignment(branch);
  bool get hasReceptionist => !isPendingAssignment(receptionist);
  bool get hasDriver => !isPendingAssignment(driver);

  Order copyWith({
    String? branch,
    String? receptionist,
    String? driver,
    String? tailor,
    String? window,
    Stage? stage,
    List<String>? timeline,
    String? notes,
    String? paymentStatus,
  }) =>
      Order(
        id: id,
        customer: customer,
        mobile: mobile,
        areaEn: areaEn,
        areaAr: areaAr,
        address: address,
        service: service,
        preference: preference,
        window: window ?? this.window,
        invoiceNo: invoiceNo,
        deliveryPrice: deliveryPrice,
        totalAmount: totalAmount,
        paymentMethod: paymentMethod,
        paymentStatus: paymentStatus ?? this.paymentStatus,
        branch: branch ?? this.branch,
        receptionist: receptionist ?? this.receptionist,
        driver: driver ?? this.driver,
        tailor: tailor ?? this.tailor,
        stage: stage ?? this.stage,
        lat: lat,
        lng: lng,
        notes: notes ?? this.notes,
        timeline: timeline ?? this.timeline,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'customer': customer,
        'mobile': mobile,
        'areaEn': areaEn,
        'areaAr': areaAr,
        'address': address,
        'service': service,
        'preference': preference,
        'window': window,
        'invoiceNo': invoiceNo,
        'deliveryPrice': deliveryPrice,
        'totalAmount': totalAmount,
        'paymentMethod': paymentMethod,
        'paymentStatus': paymentStatus,
        'branch': branch,
        'receptionist': receptionist,
        'driver': driver,
        'tailor': tailor,
        'stage': stage.name,
        'lat': lat,
        'lng': lng,
        'notes': notes,
        'timeline': timeline,
      };

  factory Order.fromJson(Map<String, dynamic> json) => Order(
        id: json['id'] as String? ?? '',
        customer: json['customer'] as String? ?? '',
        mobile: json['mobile'] as String? ?? '',
        areaEn: json['areaEn'] as String? ?? '',
        areaAr: json['areaAr'] as String? ?? '',
        address: json['address'] as String? ?? '',
        service: json['service'] as String? ?? '',
        preference: json['preference'] as String? ?? '',
        window: json['window'] as String? ?? '',
        invoiceNo: json['invoiceNo'] as String? ?? '',
        deliveryPrice: (json['deliveryPrice'] as num?)?.toDouble() ??
            (json['totalAmount'] as num?)?.toDouble() ??
            3.5,
        totalAmount: (json['totalAmount'] as num?)?.toDouble() ??
            (json['deliveryPrice'] as num?)?.toDouble() ??
            3.5,
        paymentMethod: json['paymentMethod'] as String? ?? 'UPay',
        paymentStatus: json['paymentStatus'] as String? ?? 'pending',
        branch: json['branch'] as String? ?? 'Pending assignment',
        receptionist: json['receptionist'] as String? ?? 'Pending assignment',
        driver: json['driver'] as String? ?? '',
        tailor: json['tailor'] as String? ?? '',
        stage: stageFromKey(json['stage'] as String? ?? ''),
        lat: (json['lat'] as num?)?.toDouble() ?? 0,
        lng: (json['lng'] as num?)?.toDouble() ?? 0,
        notes: json['notes'] as String? ?? '',
        timeline: [
          for (final item in (json['timeline'] as List? ?? const <dynamic>[]))
            item.toString(),
        ],
      );
}

class Complaint {
  const Complaint(this.orderId, this.customer, this.typeEn, this.typeAr,
      this.message, this.date);
  final String orderId;
  final String customer;
  final String typeEn;
  final String typeAr;
  final String message;
  final String date;
  String type(bool isArabic) => isArabic ? typeAr : typeEn;
}

class StaffUser {
  const StaffUser({
    required this.username,
    required this.password,
    required this.displayName,
    required this.role,
    this.branch = '',
    this.active = true,
    this.availableToday = true,
    this.homeServiceToday = true,
  });

  final String username;
  final String password;
  final String displayName;
  final Role role;
  final String branch;
  final bool active;
  final bool availableToday;
  final bool homeServiceToday;

  Map<String, dynamic> toJson() => {
        'username': username,
        'password': password,
        'displayName': displayName,
        'role': role.name,
        'branch': branch,
        'active': active,
        'availableToday': availableToday,
        'homeServiceToday': homeServiceToday,
      };

  factory StaffUser.fromJson(Map<String, dynamic> json) => StaffUser(
        username: json['username'] as String? ?? '',
        password: json['password'] as String? ?? '',
        displayName: json['displayName'] as String? ?? '',
        role: roleFromSlug(json['role'] as String? ?? '') ?? Role.employee,
        branch: json['branch'] as String? ?? '',
        active: json['active'] as bool? ?? true,
        availableToday: json['availableToday'] as bool? ?? true,
        homeServiceToday: json['homeServiceToday'] as bool? ?? true,
      );

  StaffUser copyWith({
    String? password,
    String? displayName,
    Role? role,
    String? branch,
    bool? active,
    bool? availableToday,
    bool? homeServiceToday,
  }) =>
      StaffUser(
        username: username,
        password: password ?? this.password,
        displayName: displayName ?? this.displayName,
        role: role ?? this.role,
        branch: branch ?? this.branch,
        active: active ?? this.active,
        availableToday: availableToday ?? this.availableToday,
        homeServiceToday: homeServiceToday ?? this.homeServiceToday,
      );
}

class DeliveryAreaPrice {
  const DeliveryAreaPrice({
    required this.areaEn,
    required this.price,
    this.active = true,
  });

  final String areaEn;
  final double price;
  final bool active;

  Map<String, dynamic> toJson() => {
        'areaEn': areaEn,
        'price': price,
        'active': active,
      };

  factory DeliveryAreaPrice.fromJson(Map<String, dynamic> json) =>
      DeliveryAreaPrice(
        areaEn: json['areaEn'] as String? ?? json['name'] as String? ?? '',
        price: (json['price'] as num?)?.toDouble() ?? 5.0,
        active: json['active'] as bool? ?? true,
      );
}

class BookingScheduleSettings {
  const BookingScheduleSettings({
    required this.enabled,
    required this.slots,
    required this.workingDays,
    required this.rows,
  });

  final bool enabled;
  final List<String> slots;
  final Set<String> workingDays;
  final Map<String, Map<String, int>> rows;

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'slots': slots,
        'workingDays': workingDays.toList(),
        'rows': [
          for (final entry in rows.entries)
            {
              'date': entry.key,
              'day': weekdayName(parseDateKey(entry.key) ?? DateTime.now()),
              'capacities': entry.value,
            }
        ],
      };

  factory BookingScheduleSettings.fromJson(Map<String, dynamic> json) {
    final slots = [
      for (final item in (json['slots'] as List? ?? defaultBookingSlots))
        if (item.toString().trim().isNotEmpty) item.toString().trim()
    ];
    final rows = <String, Map<String, int>>{};
    for (final item in (json['rows'] as List? ?? const [])) {
      if (item is! Map) continue;
      final date = item['date']?.toString().trim() ?? '';
      if (date.isEmpty) continue;
      final rawCapacities = item['capacities'];
      final capacities = <String, int>{};
      if (rawCapacities is Map) {
        for (final slot in slots) {
          final value = rawCapacities[slot];
          capacities[slot] =
              value is num ? value.toInt().clamp(0, 999).toInt() : 0;
        }
      } else if (rawCapacities is List) {
        for (var i = 0; i < slots.length; i++) {
          final value = i < rawCapacities.length ? rawCapacities[i] : 0;
          capacities[slots[i]] =
              value is num ? value.toInt().clamp(0, 999).toInt() : 0;
        }
      }
      rows[date] = capacities;
    }
    return BookingScheduleSettings(
      enabled: json['enabled'] as bool? ?? true,
      slots: slots.isEmpty ? defaultBookingSlots : slots,
      workingDays: {
        for (final item in (json['workingDays'] as List? ?? defaultWorkingDays))
          if (item.toString().trim().isNotEmpty) item.toString().trim()
      },
      rows: rows.isEmpty ? defaultBookingScheduleRows() : rows,
    );
  }
}

const defaultStaffUsers = <StaffUser>[
  StaffUser(
      username: 'admin',
      password: 'Admin123!',
      displayName: 'Admin',
      role: Role.admin),
  StaffUser(
      username: 'ops',
      password: 'Ops123!',
      displayName: 'Customer Service',
      role: Role.employee),
  StaffUser(
      username: 'reception-lead',
      password: 'ReceptionLead123!',
      displayName: 'Reception Lead',
      role: Role.receptionistSupervisor),
  StaffUser(
      username: 'driver-lead',
      password: 'DriverLead123!',
      displayName: 'Driver Lead',
      role: Role.driverSupervisor),
  StaffUser(
      username: 'reception',
      password: 'Reception123!',
      displayName: 'Aisha',
      role: Role.receptionist,
      branch: 'Yarmouk'),
  StaffUser(
      username: 'afroz',
      password: 'Tailor123!',
      displayName: 'AFROZ',
      role: Role.tailor),
  StaffUser(
      username: 'omar',
      password: 'Driver123!',
      displayName: 'Omar',
      role: Role.driver),
  StaffUser(
      username: 'khaled',
      password: 'Driver123!',
      displayName: 'Khaled',
      role: Role.driver),
  StaffUser(
      username: 'fatima',
      password: 'Reception123!',
      displayName: 'Fatima',
      role: Role.receptionist,
      branch: 'Hessa AlMubarak District'),
];

bool isPendingAssignment(String value) {
  final normalized = value.trim().toLowerCase();
  return normalized.isEmpty ||
      normalized.contains('pending') ||
      normalized.contains('\u0628\u0627\u0646\u062a\u0638\u0627\u0631');
}

String timelineNow(String note) {
  final now = DateTime.now();
  final stamp =
      '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  return '$stamp - $note';
}

String formatKwd(double value) => 'KD ${value.toStringAsFixed(3)}';

String formatVisitDate(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  return '$day-$month-${value.year}';
}

DateTime? parseDateKey(String value) {
  final match = RegExp(r'^(\d{1,2})-(\d{1,2})-(\d{4})$').firstMatch(value);
  if (match == null) return null;
  return DateTime(
    int.parse(match.group(3)!),
    int.parse(match.group(2)!),
    int.parse(match.group(1)!),
  );
}

String weekdayName(DateTime value) => switch (value.weekday) {
      DateTime.monday => 'Monday',
      DateTime.tuesday => 'Tuesday',
      DateTime.wednesday => 'Wednesday',
      DateTime.thursday => 'Thursday',
      DateTime.friday => 'Friday',
      DateTime.saturday => 'Saturday',
      _ => 'Sunday',
    };

const defaultBookingSlots = <String>[
  '12:00 PM - 1:00 PM',
  '1:00 PM - 2:00 PM',
  '2:00 PM - 3:00 PM',
  '3:00 PM - 4:00 PM',
  '4:00 PM - 5:00 PM',
  '5:00 PM - 6:00 PM',
  '6:00 PM - 7:00 PM',
  '7:00 PM - 8:00 PM',
  '8:00 PM - 9:00 PM',
];

const defaultWorkingDays = <String>[
  'Sunday',
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
];

Map<String, Map<String, int>> defaultBookingScheduleRows() {
  final today = DateTime.now();
  return {
    for (var i = 1; i <= 14; i++)
      formatVisitDate(today.add(Duration(days: i))): {
        for (final slot in defaultBookingSlots) slot: 2,
      }
  };
}

final kuwaitAreas = <Area>[
  const Area('Abdali', 'العبدلي'),
  const Area('Abdullah Al-Mubarak', 'عبدالله المبارك'),
  const Area('Abdullah Al-Salem', 'عبدالله السالم'),
  const Area('Abu Al Hasaniya', 'أبو الحصانية'),
  const Area('Abu Futaira', 'أبو فطيرة'),
  const Area('Abu Halifa', 'أبو حليفة'),
  const Area('Adailiya', 'العديلية'),
  const Area('Adan', 'العدان'),
  const Area('Ahmadi', 'الأحمدي'),
  const Area('Ali Sabah Al-Salem', 'علي صباح السالم'),
  const Area('Amghara', 'أمغرة'),
  const Area('Andalus', 'الأندلس'),
  const Area('Ardiya', 'العارضية'),
  const Area('Ardiya Industrial', 'العارضية الصناعية'),
  const Area('Ashbelia', 'أشبيلية'),
  const Area('Bayan', 'بيان'),
  const Area('Bneid Al Gar', 'بنيد القار'),
  const Area('Daiya', 'الدعية'),
  const Area('Dasma', 'الدسمة'),
  const Area('Dhajeej', 'ضجيج'),
  const Area('Doha', 'الدوحة'),
  const Area('Egaila', 'العقيلة'),
  const Area('Fahaheel', 'الفحيحيل'),
  const Area('Faiha', 'الفيحاء'),
  const Area('Farwaniya', 'الفروانية'),
  const Area('Fintas', 'الفنطاس'),
  const Area('Firdous', 'الفردوس'),
  const Area('Fnaitees', 'الفنيطيس'),
  const Area('Granada', 'غرناطة'),
  const Area('Hadiya', 'هدية'),
  const Area('Hateen', 'حطين'),
  const Area('Hawally', 'حولي'),
  const Area('Jaber Al Ahmad', 'جابر الأحمد'),
  const Area('Jaber Al Ali', 'جابر العلي'),
  const Area('Jabriya', 'الجابرية'),
  const Area('Jahra', 'الجهراء'),
  const Area('Jleeb Al-Shuyoukh', 'جليب الشيوخ'),
  const Area('Qadsiya', 'القادسية'),
  const Area('Qairawan', 'القيروان'),
  const Area('Kaifan', 'كيفان'),
  const Area('Kabd', 'كبد'),
  const Area('Khaitan', 'خيطان'),
  const Area('Khaldiya', 'الخالدية'),
  const Area('Kuwait City', 'مدينة الكويت'),
  const Area('Mahboula', 'المهبولة'),
  const Area('Mangaf', 'المنقف'),
  const Area('Mansouriya', 'المنصورية'),
  const Area('Messila', 'المسيلة'),
  const Area('Mirqab', 'المرقاب'),
  const Area('Mishref', 'مشرف'),
  const Area('Mubarak Al-Abdullah', 'مبارك العبدالله'),
  const Area('Mubarak Al-Kabeer', 'مبارك الكبير'),
  const Area('Nassem', 'النسيم'),
  const Area('North West Sulaibikhat', 'شمال غرب الصليبيخات'),
  const Area('Nuzha', 'النزهة'),
  const Area('Omariya', 'العمرية'),
  const Area('Oyoun', 'العيون'),
  const Area('Qibla', 'القبلة'),
  const Area('Qortuba', 'قرطبة'),
  const Area('Rabia', 'الرابية'),
  const Area('Rawda', 'الروضة'),
  const Area('Rehab', 'الرحاب'),
  const Area('Riggae', 'الرقعي'),
  const Area('Riqqa', 'الرقة'),
  const Area('Rumaithiya', 'الرميثية'),
  const Area('Saad Al-Abdullah', 'سعد العبدالله'),
  const Area('Sabah Al-Ahmad', 'صباح الأحمد'),
  const Area('Sabah Al-Nasser', 'صباح الناصر'),
  const Area('Sabah Al-Salem', 'صباح السالم'),
  const Area('Sabahiya', 'الصباحية'),
  const Area('Sabhan', 'صبحان'),
  const Area('Salam', 'السلام'),
  const Area('Salmiya', 'السالمية'),
  const Area('Salwa', 'سلوى'),
  const Area('Shaab', 'الشعب'),
  const Area('Sharq', 'شرق'),
  const Area('Shamiya', 'الشامية'),
  const Area('Shuhada', 'الشهداء'),
  const Area('Shuwaikh', 'الشويخ'),
  const Area('Shuwaikh Industrial', 'الشويخ الصناعية'),
  const Area('Siddeeq', 'الصديق'),
  const Area('South Abdullah Al-Mubarak', 'جنوب عبدالله المبارك'),
  const Area('Sulaibiya', 'الصليبية'),
  const Area('Sulaibiya Industrial', 'الصليبية الصناعية'),
  const Area('Sulaibikhat', 'الصليبيخات'),
  const Area('Surra', 'السرة'),
  const Area('Taima', 'تيماء'),
  const Area('Wafra', 'الوفرة'),
  const Area('Waha', 'الواحة'),
  const Area('West Abu Fatira', 'غرب أبو فطيرة'),
  const Area('West Abdullah Mubarak', 'غرب عبدالله المبارك'),
  const Area('Yarmouk', 'اليرموك'),
  const Area('Zahra', 'الزهراء'),
];

const highDeliveryPriceAreas = <String>{
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
};

List<DeliveryAreaPrice> defaultAreaPrices() => [
      for (final area in kuwaitAreas)
        DeliveryAreaPrice(
          areaEn: area.en,
          price: highDeliveryPriceAreas.contains(area.en) ? 7.0 : 5.0,
        ),
    ];

const complaints = <Complaint>[
  Complaint(
      'TE-2401',
      'Sara Alhamad',
      'Appointment delay',
      'تأخير موعد',
      'Customer asked for a tighter visit window before evening pickup.',
      '29-07-2026, 02:18 PM'),
  Complaint(
      'TE-2402',
      'Rana',
      'Quality follow-up',
      'متابعة الجودة',
      'Customer wants confirmation before final delivery dispatch.',
      '28-07-2026, 09:54 PM'),
  Complaint(
      'TE-2404',
      'Abeer Alajmi',
      'Order issue',
      'مشكلة في الطلب',
      'Requested an employee callback regarding fitting notes.',
      '27-07-2026, 03:31 PM'),
];

const seedOrders = <Order>[
  Order(
    id: 'TE-2401',
    customer: 'Sara Alhamad',
    mobile: '55868777',
    areaEn: 'North West Sulaibikhat',
    areaAr: 'شمال غرب الصليبيخات',
    address: 'North West Sulaibikhat, Block 4, Street 18, House 12',
    service: 'Repair',
    preference: 'Women tailor',
    window: '29-07-2026, 7:30 PM - 8:00 PM',
    driver: 'Omar',
    tailor: 'AFROZ',
    stage: Stage.outForDelivery,
    lat: 29.3606,
    lng: 47.9275,
    notes: 'Evening pickup and quick size check.',
    timeline: [
      '28-07-2026 08:12 PM • Booking approved',
      '29-07-2026 10:10 AM • Tailor assigned',
      '29-07-2026 06:58 PM • Out for delivery'
    ],
  ),
  Order(
    id: 'TE-2402',
    customer: 'Rana',
    mobile: '50904449',
    areaEn: 'Shaab',
    areaAr: 'الشعب',
    address: 'Shaab, Block 1, Street 10, Villa 6',
    service: 'Tailoring',
    preference: 'Women tailor',
    window: '29-07-2026, 5:00 PM - 5:30 PM',
    driver: 'Omar',
    tailor: 'AFROZ',
    stage: Stage.ready,
    lat: 29.3442,
    lng: 48.0045,
    notes: 'Evening dress fitting before travel.',
    timeline: [
      '27-07-2026 07:20 PM • Booking approved',
      '28-07-2026 01:15 PM • Tailoring in progress',
      '29-07-2026 03:40 PM • Ready for delivery'
    ],
  ),
  Order(
    id: 'TE-2403',
    customer: 'Athba Almajed',
    mobile: '90003313',
    areaEn: 'Abdullah Al-Salem',
    areaAr: 'عبدالله السالم',
    address: 'Abdullah Al-Salem, Block 3, Street 38, House 2',
    service: 'Tailoring',
    preference: 'Women tailor',
    window: '29-07-2026, 2:30 PM - 3:00 PM',
    driver: 'Omar',
    tailor: 'AFROZ',
    stage: Stage.delivered,
    lat: 29.3664,
    lng: 47.9798,
    notes: 'Delivery completed and received by customer.',
    timeline: [
      '26-07-2026 10:40 AM • Booking approved',
      '27-07-2026 04:15 PM • Tailoring in progress',
      '29-07-2026 03:02 PM • Delivered to customer'
    ],
  ),
  Order(
    id: 'TE-2404',
    customer: 'Abeer Alajmi',
    mobile: '55881373',
    areaEn: 'West Abdullah Mubarak',
    areaAr: 'غرب عبدالله المبارك',
    address: 'West Abdullah Mubarak, Block 5, Street 512, House 230',
    service: 'Repair',
    preference: 'No preference',
    window: '30-07-2026, 6:00 PM - 7:00 PM',
    driver: 'Pending assignment',
    tailor: 'AFROZ',
    stage: Stage.outForDelivery,
    lat: 29.2857,
    lng: 47.8890,
    notes: 'Customer prefers a call before arrival.',
    timeline: [
      '29-07-2026 09:30 AM • Booking approved',
      '29-07-2026 11:00 AM • Tailor reserved'
    ],
  ),
];

class AppState extends ChangeNotifier {
  AppState() {
    _loadStaffUsers();
    _loadAreaPrices();
    _loadBookingSchedule();
    _loadOrders();
    unawaited(refreshStaffUsers());
    unawaited(refreshAreaPrices());
    unawaited(refreshBookingSchedule(quiet: true));
    unawaited(refreshOrders());
    _poller = Timer.periodic(const Duration(seconds: 8), (_) {
      unawaited(refreshOrders(quiet: true));
    });
  }

  bool isArabic = false;
  bool _publicLanguageInitialized = false;
  Role? role;
  String user = '';
  StaffUser? currentStaff;
  final List<Order> orders = [];
  final List<StaffUser> staffUsers = [];
  final List<DeliveryAreaPrice> areaPrices = [];
  BookingScheduleSettings bookingSchedule = BookingScheduleSettings(
    enabled: true,
    slots: defaultBookingSlots,
    workingDays: defaultWorkingDays.toSet(),
    rows: defaultBookingScheduleRows(),
  );
  Timer? _poller;
  String notificationPermission = html.Notification.permission ?? 'default';
  int staffNotificationCount = 0;
  String staffNotificationText = '';

  String t(String en, String ar) => isArabic ? ar : en;
  TextDirection get dir => isArabic ? TextDirection.rtl : TextDirection.ltr;
  bool get signedIn => role != null;
  bool get browserNotificationsEnabled => notificationPermission == 'granted';

  Future<void> enableBrowserNotifications() async {
    try {
      notificationPermission = await html.Notification.requestPermission();
      if (browserNotificationsEnabled) {
        html.Notification('Tailor Express',
            body: t('Notifications are enabled.', 'تم تفعيل التنبيهات.'));
      }
    } catch (_) {
      notificationPermission = 'unsupported';
    }
    notifyListeners();
  }

  void toggleLang() {
    _publicLanguageInitialized = true;
    isArabic = !isArabic;
    notifyListeners();
  }

  void setArabic(bool value, {bool notify = true}) {
    if (isArabic == value) return;
    isArabic = value;
    if (notify) notifyListeners();
  }

  void ensurePublicDefaultArabic() {
    if (_publicLanguageInitialized) return;
    _publicLanguageInitialized = true;
    setArabic(true, notify: false);
  }

  void enterStaffArea() {
    _publicLanguageInitialized = false;
    setArabic(false, notify: false);
  }

  void _loadStaffUsers() {
    staffUsers.clear();
    final raw = html.window.localStorage[staffUsersStorageKey];
    if (raw == null || raw.isEmpty) {
      staffUsers.addAll(defaultStaffUsers);
      _saveStaffUsers();
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        staffUsers.addAll(decoded
            .whereType<Object?>()
            .map((item) => item is Map
                ? StaffUser.fromJson(Map<String, dynamic>.from(item))
                : null)
            .whereType<StaffUser>());
      }
    } catch (_) {
      staffUsers
        ..clear()
        ..addAll(defaultStaffUsers);
    }
    if (staffUsers.isEmpty) staffUsers.addAll(defaultStaffUsers);
  }

  void _saveStaffUsers() {
    html.window.localStorage[staffUsersStorageKey] =
        jsonEncode(staffUsers.map((item) => item.toJson()).toList());
  }

  Future<void> refreshStaffUsers() async {
    try {
      final response = await html.HttpRequest.request(
        apiUrl('/api/staff-users'),
        method: 'GET',
        requestHeaders: {'Accept': 'application/json'},
      );
      final decoded = jsonDecode(response.responseText ?? '[]');
      if (decoded is! List) return;
      staffUsers
        ..clear()
        ..addAll(decoded
            .whereType<Object?>()
            .map((item) => item is Map
                ? StaffUser.fromJson(Map<String, dynamic>.from(item))
                : null)
            .whereType<StaffUser>());
      if (staffUsers.isEmpty) staffUsers.addAll(defaultStaffUsers);
      _saveStaffUsers();
      notifyListeners();
    } catch (_) {}
  }

  Future<bool> login(String name, String pass) async {
    try {
      final response = await html.HttpRequest.request(
        apiUrl('/api/login'),
        method: 'POST',
        sendData: jsonEncode({'username': name.trim(), 'password': pass}),
        requestHeaders: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      );
      final status = response.status ?? 0;
      if (status >= 200 && status < 300 && response.responseText != null) {
        final decoded = Map<String, dynamic>.from(
            jsonDecode(response.responseText!) as Map);
        final remoteUser = decoded['user'];
        if (remoteUser is Map) {
          final matched =
              StaffUser.fromJson(Map<String, dynamic>.from(remoteUser));
          currentStaff = matched;
          role = matched.role;
          user = matched.displayName;
          notifyListeners();
          unawaited(refreshStaffUsers());
          return true;
        }
      }
      return false;
    } catch (_) {
      final normalized = name.trim().toLowerCase();
      StaffUser? matched;
      for (final item in staffUsers) {
        if (item.active &&
            item.username.toLowerCase() == normalized &&
            item.password == pass) {
          matched = item;
          break;
        }
      }
      if (matched == null) return false;
      currentStaff = matched;
      role = matched.role;
      user = matched.displayName;
      notifyListeners();
      return true;
    }
  }

  void logout() {
    role = null;
    user = '';
    currentStaff = null;
    notifyListeners();
  }

  bool canOpen(Role target) => role == target;

  Future<bool> addStaffUser(StaffUser next) async {
    final normalized = next.username.trim().toLowerCase();
    if (normalized.isEmpty ||
        next.password.isEmpty ||
        next.displayName.isEmpty) {
      return false;
    }
    if (staffUsers.any((user) => user.username.toLowerCase() == normalized)) {
      return false;
    }
    try {
      final response = await html.HttpRequest.request(
        apiUrl('/api/staff-users'),
        method: 'POST',
        sendData: jsonEncode(next.toJson()),
        requestHeaders: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      );
      final status = response.status ?? 0;
      if (status < 200 || status >= 300) return false;
      if (response.responseText != null && response.responseText!.isNotEmpty) {
        final created = StaffUser.fromJson(Map<String, dynamic>.from(
            jsonDecode(response.responseText!) as Map));
        staffUsers.removeWhere((user) =>
            user.username.toLowerCase() == created.username.toLowerCase());
        staffUsers.add(created);
      } else {
        staffUsers.add(next);
      }
      _saveStaffUsers();
      notifyListeners();
      return true;
    } catch (_) {
      staffUsers.add(next);
      _saveStaffUsers();
      notifyListeners();
      return true;
    }
  }

  Future<bool> updateStaffUser(StaffUser next) async {
    final normalized = next.username.trim().toLowerCase();
    final index = staffUsers
        .indexWhere((user) => user.username.toLowerCase() == normalized);
    if (index == -1 || next.displayName.trim().isEmpty) return false;
    try {
      final response = await html.HttpRequest.request(
        apiUrl('/api/staff-users/${Uri.encodeComponent(next.username)}'),
        method: 'PATCH',
        sendData: jsonEncode(next.toJson()),
        requestHeaders: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      );
      final status = response.status ?? 0;
      if (status < 200 || status >= 300) return false;
      if (response.responseText != null && response.responseText!.isNotEmpty) {
        staffUsers[index] = StaffUser.fromJson(Map<String, dynamic>.from(
            jsonDecode(response.responseText!) as Map));
      } else {
        staffUsers[index] = next;
      }
    } catch (_) {
      staffUsers[index] = next;
    }
    if (currentStaff?.username.toLowerCase() == normalized) {
      currentStaff = staffUsers[index];
      role = currentStaff!.role;
      user = currentStaff!.displayName;
    }
    _saveStaffUsers();
    notifyListeners();
    return true;
  }

  List<StaffUser> staffForRole(Role target,
      {String? branch, bool availableOnly = false}) {
    final branchFilter = branch?.trim().toLowerCase() ?? '';
    final people = staffUsers.where((item) {
      if (!item.active || item.role != target) return false;
      if (availableOnly && (!item.availableToday || !item.homeServiceToday)) {
        return false;
      }
      if (branchFilter.isNotEmpty &&
          item.branch.trim().toLowerCase() != branchFilter) {
        return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => a.displayName.compareTo(b.displayName));
    return people;
  }

  List<String> staffNamesForRole(Role target,
      {String? branch, bool availableOnly = false}) {
    final names = staffUsers
        .where((item) =>
            staffForRole(target, branch: branch, availableOnly: availableOnly)
                .contains(item))
        .map((item) => item.displayName)
        .where((name) => name.trim().isNotEmpty)
        .toSet()
        .toList();
    names.sort();
    return names;
  }

  String get currentStaffName => currentStaff?.displayName ?? user;

  Area areaFromName(String areaEn) {
    return kuwaitAreas.firstWhere(
      (area) => area.en.toLowerCase() == areaEn.trim().toLowerCase(),
      orElse: () => Area(areaEn.trim(), areaEn.trim()),
    );
  }

  List<Area> get activeAreas {
    final seen = <String>{};
    final areas = <Area>[];
    for (final price in areaPrices) {
      if (!price.active || !seen.add(price.areaEn.toLowerCase())) continue;
      areas.add(areaFromName(price.areaEn));
    }
    if (areas.isEmpty) {
      for (final area in kuwaitAreas) {
        if (seen.add(area.en.toLowerCase())) areas.add(area);
      }
    }
    areas.sort((a, b) => a.en.compareTo(b.en));
    return areas;
  }

  DeliveryAreaPrice? areaPrice(String areaEn) {
    for (final item in areaPrices) {
      if (item.areaEn.toLowerCase() == areaEn.trim().toLowerCase()) {
        return item;
      }
    }
    return null;
  }

  double deliveryPriceFor(String areaEn) =>
      areaPrice(areaEn)?.price ??
      (highDeliveryPriceAreas.contains(areaEn) ? 7.0 : 5.0);

  bool areaIsActive(String areaEn) => areaPrice(areaEn)?.active ?? true;

  void _loadAreaPrices() {
    areaPrices.clear();
    final raw = html.window.localStorage[areaPricesStorageKey];
    if (raw == null || raw.isEmpty) {
      areaPrices.addAll(defaultAreaPrices());
      _saveAreaPrices();
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        areaPrices.addAll(decoded
            .whereType<Object?>()
            .map((item) => item is Map
                ? DeliveryAreaPrice.fromJson(Map<String, dynamic>.from(item))
                : null)
            .whereType<DeliveryAreaPrice>());
      }
    } catch (_) {
      areaPrices
        ..clear()
        ..addAll(defaultAreaPrices());
    }
    if (areaPrices.isEmpty) areaPrices.addAll(defaultAreaPrices());
  }

  void _saveAreaPrices() {
    html.window.localStorage[areaPricesStorageKey] =
        jsonEncode(areaPrices.map((item) => item.toJson()).toList());
  }

  Future<void> refreshAreaPrices({bool quiet = false}) async {
    try {
      final response = await html.HttpRequest.request(
        apiUrl('/api/area-prices'),
        method: 'GET',
        requestHeaders: {'Accept': 'application/json'},
      );
      final decoded = jsonDecode(response.responseText ?? '[]');
      if (decoded is! List) return;
      areaPrices
        ..clear()
        ..addAll(decoded
            .whereType<Object?>()
            .map((item) => item is Map
                ? DeliveryAreaPrice.fromJson(Map<String, dynamic>.from(item))
                : null)
            .whereType<DeliveryAreaPrice>());
      if (areaPrices.isEmpty) areaPrices.addAll(defaultAreaPrices());
      _saveAreaPrices();
      notifyListeners();
    } catch (_) {
      if (!quiet) notifyListeners();
    }
  }

  Future<void> updateAreaPrice(String areaEn, double price, bool active,
      {String? newAreaEn}) async {
    final next = DeliveryAreaPrice(
        areaEn: (newAreaEn?.trim().isNotEmpty ?? false)
            ? newAreaEn!.trim()
            : areaEn,
        price: price,
        active: active);
    try {
      final response = await html.HttpRequest.request(
        apiUrl('/api/area-prices/${Uri.encodeComponent(areaEn)}'),
        method: 'PATCH',
        sendData: jsonEncode({
          ...next.toJson(),
          if (newAreaEn != null) 'newAreaEn': newAreaEn.trim(),
        }),
        requestHeaders: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      );
      final status = response.status ?? 0;
      if (status >= 200 && status < 300 && response.responseText != null) {
        _upsertAreaPrice(DeliveryAreaPrice.fromJson(Map<String, dynamic>.from(
            jsonDecode(response.responseText!) as Map)));
        notifyListeners();
        return;
      }
    } catch (_) {}
    _upsertAreaPrice(next);
    notifyListeners();
  }

  void _upsertAreaPrice(DeliveryAreaPrice next) {
    areaPrices.removeWhere(
        (item) => item.areaEn.toLowerCase() == next.areaEn.toLowerCase());
    areaPrices.add(next);
    areaPrices.sort((a, b) => a.areaEn.compareTo(b.areaEn));
    _saveAreaPrices();
  }

  void _loadBookingSchedule() {
    final raw = html.window.localStorage[bookingScheduleStorageKey];
    if (raw == null || raw.isEmpty) {
      _saveBookingSchedule();
      return;
    }
    try {
      bookingSchedule = BookingScheduleSettings.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw) as Map));
    } catch (_) {
      bookingSchedule = BookingScheduleSettings(
        enabled: true,
        slots: defaultBookingSlots,
        workingDays: defaultWorkingDays.toSet(),
        rows: defaultBookingScheduleRows(),
      );
    }
  }

  void _saveBookingSchedule() {
    html.window.localStorage[bookingScheduleStorageKey] =
        jsonEncode(bookingSchedule.toJson());
  }

  Future<void> refreshBookingSchedule({bool quiet = false}) async {
    try {
      final response = await html.HttpRequest.request(
        apiUrl('/api/booking-schedule'),
        method: 'GET',
        requestHeaders: {'Accept': 'application/json'},
      );
      if ((response.status ?? 0) < 200 || (response.status ?? 0) >= 300) {
        return;
      }
      bookingSchedule = BookingScheduleSettings.fromJson(
          Map<String, dynamic>.from(
              jsonDecode(response.responseText ?? '{}') as Map));
      _saveBookingSchedule();
      notifyListeners();
    } catch (_) {
      if (!quiet) notifyListeners();
    }
  }

  Future<void> updateBookingSchedule(BookingScheduleSettings next) async {
    bookingSchedule = next;
    _saveBookingSchedule();
    notifyListeners();
    try {
      final response = await html.HttpRequest.request(
        apiUrl('/api/booking-schedule'),
        method: 'PATCH',
        sendData: jsonEncode(next.toJson()),
        requestHeaders: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      );
      if ((response.status ?? 0) >= 200 &&
          (response.status ?? 0) < 300 &&
          response.responseText != null) {
        bookingSchedule = BookingScheduleSettings.fromJson(
            Map<String, dynamic>.from(
                jsonDecode(response.responseText!) as Map));
        _saveBookingSchedule();
        notifyListeners();
      }
    } catch (_) {}
  }

  List<String> availableSlotsForDate(DateTime date) {
    if (!bookingSchedule.enabled) return const [];
    final key = formatVisitDate(date);
    final capacities = bookingSchedule.rows[key];
    if (capacities == null) return const [];
    return [
      for (final slot in bookingSchedule.slots)
        if ((capacities[slot] ?? 0) > 0) slot,
    ];
  }

  bool isVisitDateAvailable(DateTime date) {
    if (!bookingSchedule.enabled) return false;
    if (!bookingSchedule.workingDays.contains(weekdayName(date))) return false;
    return availableSlotsForDate(date).isNotEmpty;
  }

  DateTime nextAvailableVisitDate(DateTime fallback) {
    final today = DateTime.now();
    for (var offset = 0; offset <= 45; offset++) {
      final day = DateTime(today.year, today.month, today.day)
          .add(Duration(days: offset));
      if (isVisitDateAvailable(day)) return day;
    }
    return fallback;
  }

  String apiUrl(String path) {
    const configured = String.fromEnvironment('API_BASE', defaultValue: '');
    if (configured.isNotEmpty) {
      return Uri.parse(configured).resolve(path).toString();
    }
    final host = html.window.location.hostname;
    if (host == '127.0.0.1' || host == 'localhost') {
      return 'http://127.0.0.1:8090$path';
    }
    return path;
  }

  void _loadOrders() {
    orders.clear();
    final raw = html.window.localStorage[ordersStorageKey];
    if (raw == null || raw.isEmpty) {
      orders.addAll(seedOrders);
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        orders.addAll(
          decoded
              .whereType<Object?>()
              .map((item) => item is Map
                  ? Order.fromJson(Map<String, dynamic>.from(item))
                  : null)
              .whereType<Order>(),
        );
      }
    } catch (_) {
      orders
        ..clear()
        ..addAll(seedOrders);
      return;
    }
    if (orders.isEmpty) {
      orders.addAll(seedOrders);
    }
  }

  void _saveOrders() {
    html.window.localStorage[ordersStorageKey] = jsonEncode(
      orders.map((order) => order.toJson()).toList(),
    );
  }

  List<Order>? _decodeOrders(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! List) return null;
    return decoded
        .whereType<Object?>()
        .map((item) => item is Map
            ? Order.fromJson(Map<String, dynamic>.from(item))
            : null)
        .whereType<Order>()
        .toList();
  }

  bool _sameOrders(List<Order> next) {
    if (orders.length != next.length) return false;
    for (var i = 0; i < orders.length; i++) {
      final a = orders[i];
      final b = next[i];
      if (a.id != b.id ||
          a.stage != b.stage ||
          a.branch != b.branch ||
          a.receptionist != b.receptionist ||
          a.driver != b.driver ||
          a.tailor != b.tailor ||
          a.window != b.window ||
          a.notes != b.notes ||
          a.deliveryPrice != b.deliveryPrice ||
          a.totalAmount != b.totalAmount ||
          a.paymentStatus != b.paymentStatus) {
        return false;
      }
    }
    return true;
  }

  Future<void> refreshOrders({bool quiet = false}) async {
    try {
      final response = await html.HttpRequest.request(
        apiUrl('/api/orders'),
        method: 'GET',
        requestHeaders: {'Accept': 'application/json'},
      );
      final remote = _decodeOrders(response.responseText);
      if (remote == null || _sameOrders(remote)) return;
      final previous = List<Order>.from(orders);
      orders
        ..clear()
        ..addAll(remote);
      _saveOrders();
      _notifyStaffChanges(previous, remote, quiet: quiet);
      notifyListeners();
    } catch (_) {
      if (!quiet) notifyListeners();
    }
  }

  void _notifyStaffChanges(
    List<Order> previous,
    List<Order> next, {
    required bool quiet,
  }) {
    if (!quiet || !signedIn) return;
    final previousById = {for (final order in previous) order.id: order};
    final messages = <String>[];
    final staffName = currentStaffName.toLowerCase();
    final isAdminOrSupervisor = role == Role.admin ||
        role == Role.receptionistSupervisor ||
        role == Role.driverSupervisor;

    for (final order in next) {
      final old = previousById[order.id];
      if (old == null) {
        if (role == Role.admin || role == Role.receptionistSupervisor) {
          messages.add(t('New booking ${order.id} needs branch assignment.',
              'حجز جديد ${order.id} يحتاج تعيين الفرع.'));
        }
        continue;
      }

      if (!old.hasBranch &&
          order.hasBranch &&
          !order.hasDriver &&
          (role == Role.admin || role == Role.driverSupervisor)) {
        messages.add(t('${order.id} is ready for driver assignment.',
            '${order.id} جاهز لتعيين السائق.'));
      }
      if (old.branch.toLowerCase() != order.branch.toLowerCase() &&
          order.hasBranch &&
          isAdminOrSupervisor) {
        messages.add(t('${order.id} was assigned to ${order.branch}.',
            '${order.id} assigned to ${order.branch}.'));
      }
      if (old.receptionist.toLowerCase() != order.receptionist.toLowerCase() &&
          order.hasReceptionist &&
          isAdminOrSupervisor) {
        messages.add(t(
            '${order.id} was assigned to receptionist ${order.receptionist}.',
            '${order.id} assigned to receptionist ${order.receptionist}.'));
      }
      if (old.receptionist.toLowerCase() != order.receptionist.toLowerCase() &&
          order.receptionist.toLowerCase() == staffName &&
          role == Role.receptionist) {
        messages.add(
            t('${order.id} was assigned to you.', 'تم تعيين ${order.id} لك.'));
      }
      if (old.driver.toLowerCase() != order.driver.toLowerCase() &&
          order.hasDriver &&
          isAdminOrSupervisor) {
        messages.add(t('${order.id} was assigned to driver ${order.driver}.',
            '${order.id} assigned to driver ${order.driver}.'));
      }
      if (old.driver.toLowerCase() != order.driver.toLowerCase() &&
          order.driver.toLowerCase() == staffName &&
          role == Role.driver) {
        messages.add(t('${order.id} was assigned for delivery.',
            'تم تعيين ${order.id} للتوصيل.'));
      }
      if (old.tailor.toLowerCase() != order.tailor.toLowerCase() &&
          !isPendingAssignment(order.tailor) &&
          isAdminOrSupervisor) {
        messages.add(t('${order.id} was assigned to tailor ${order.tailor}.',
            '${order.id} assigned to tailor ${order.tailor}.'));
      }
      if (old.tailor.toLowerCase() != order.tailor.toLowerCase() &&
          order.tailor.toLowerCase() == staffName &&
          role == Role.tailor) {
        messages.add(t('${order.id} was assigned for tailoring.',
            'تم تعيين ${order.id} للخياطة.'));
      }
      if (old.stage != order.stage && isAdminOrSupervisor) {
        messages.add(t(
            '${order.id} status changed to ${stageLabel(order.stage, false)}.',
            '${order.id} status changed to ${stageLabel(order.stage, false)}.'));
      }
    }

    if (messages.isEmpty) return;
    staffNotificationCount += messages.length;
    staffNotificationText = messages.first;
    if (browserNotificationsEnabled) {
      html.Notification('Tailor Express', body: staffNotificationText);
    }
  }

  Order? byId(String id) {
    for (final order in orders) {
      if (order.id.toLowerCase() == id.trim().toLowerCase()) return order;
    }
    return null;
  }

  void savePaymentDraft(String draftId, Map<String, dynamic> draft) {
    html.window.localStorage['$paymentDraftStoragePrefix$draftId'] =
        jsonEncode(draft);
  }

  Map<String, dynamic>? paymentDraft(String draftId) {
    final raw = html.window.localStorage['$paymentDraftStoragePrefix$draftId'];
    if (raw == null || raw.isEmpty) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return null;
    }
  }

  void removePaymentDraft(String draftId) {
    html.window.localStorage.remove('$paymentDraftStoragePrefix$draftId');
  }

  Map<String, dynamic> decodeJsonObjectOrThrow(String text, int status) {
    if (text.trim().isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      throw const FormatException('JSON response was not an object.');
    } on FormatException {
      final preview = text
          .replaceAll(
              RegExp(r'<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>',
                  caseSensitive: false),
              ' ')
          .replaceAll(
              RegExp(r'<style\b[^<]*(?:(?!<\/style>)<[^<]*)*<\/style>',
                  caseSensitive: false),
              ' ')
          .replaceAll(RegExp(r'<[^>]+>'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      throw Exception(preview.isEmpty
          ? 'Payment server returned HTTP $status with a non-JSON response.'
          : 'Payment server returned HTTP $status with a non-JSON response: ${preview.substring(0, preview.length > 220 ? 220 : preview.length)}');
    }
  }

  Future<Map<String, dynamic>> postPaymentJson(
      String path, Map<String, dynamic> payload) async {
    final request = html.HttpRequest();
    final completer = Completer<html.HttpRequest>();
    request
      ..open('POST', apiUrl(path))
      ..setRequestHeader('Accept', 'application/json')
      ..setRequestHeader('Content-Type', 'application/json')
      ..timeout = 45000;

    request.onLoadEnd.first.then((_) {
      if (!completer.isCompleted) completer.complete(request);
    });
    request.onError.first.then((_) {
      if (!completer.isCompleted) completer.complete(request);
    });
    request.onTimeout.first.then((_) {
      if (!completer.isCompleted) {
        completer.completeError(Exception(
            'Payment server timed out before returning a checkout link.'));
      }
    });
    request.send(jsonEncode(payload));

    final response = await completer.future;
    final status = response.status ?? 0;
    final text = response.responseText ?? '';
    final body = decodeJsonObjectOrThrow(text, status);
    if (status == 0) {
      throw Exception(
          'Cannot reach the booking server. Refresh the page, wait for Render to wake up, then try payment again.');
    }
    if (status < 200 || status >= 300) {
      final message = body['error']?.toString();
      throw Exception(message == null || message.isEmpty
          ? 'Payment server returned HTTP $status.'
          : message);
    }
    return body;
  }

  Future<String> createPaymentLinkForDraft({
    required String draftId,
    required Map<String, dynamic> draft,
    required double amount,
    required String method,
    String paymentGatewaySrc = '',
  }) async {
    final body = await postPaymentJson('/api/payments/create', {
      'orderId': draftId,
      'customer': draft['customer']?.toString() ?? '',
      'mobile': draft['mobile']?.toString() ?? '',
      'service': draft['service']?.toString() ?? '',
      'amount': amount,
      'method': method,
      if (paymentGatewaySrc.trim().isNotEmpty)
        'paymentGatewaySrc': paymentGatewaySrc.trim(),
      'language': draft['language']?.toString() ?? (isArabic ? 'ar' : 'en'),
      'origin': html.window.location.origin,
      'draft': draft,
    });
    final url = body['paymentUrl']?.toString() ?? '';
    if (url.isEmpty) throw Exception('Payment URL was not returned.');
    return url;
  }

  Future<String> createPaymentLink({
    required Order order,
    required double amount,
    required String method,
  }) {
    return createPaymentLinkForDraft(
      draftId: order.id,
      draft: {
        'customer': order.customer,
        'mobile': order.mobile,
        'service': order.service,
        'language': isArabic ? 'ar' : 'en',
      },
      amount: amount,
      method: method,
    );
  }

  Future<Map<String, dynamic>> verifyPaymentReturn(
      Map<String, String> params) async {
    final query = Uri(queryParameters: params).query;
    final response = await html.HttpRequest.request(
      apiUrl('/api/payments/status?$query'),
      method: 'GET',
      requestHeaders: {'Accept': 'application/json'},
    );
    final status = response.status ?? 0;
    final body = response.responseText == null || response.responseText!.isEmpty
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(jsonDecode(response.responseText!) as Map);
    if (status < 200 || status >= 300) {
      throw Exception(
          body['error']?.toString() ?? 'Payment status could not be verified.');
    }
    return body;
  }

  Future<Map<String, dynamic>> confirmPaymentReturn(
      Map<String, String> params) async {
    final response = await html.HttpRequest.request(
      apiUrl('/api/payments/confirm'),
      method: 'POST',
      sendData: jsonEncode({
        'params': params,
        'orderId': params['order'] ?? '',
      }),
      requestHeaders: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    );
    final status = response.status ?? 0;
    final body = response.responseText == null || response.responseText!.isEmpty
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(jsonDecode(response.responseText!) as Map);
    if (status < 200 || status >= 300) {
      throw Exception(body['error']?.toString() ??
          'Payment confirmation could not be verified.');
    }
    final created = body['order'];
    if (created is Map) {
      final order = Order.fromJson(Map<String, dynamic>.from(created));
      orders.removeWhere((item) => item.id == order.id);
      orders.insert(0, order);
      _saveOrders();
      notifyListeners();
      body['orderObject'] = order;
    }
    return body;
  }

  Future<Order> createBooking({
    required String customer,
    required String mobile,
    required Area area,
    required String block,
    required String street,
    required String building,
    required String service,
    required String preference,
    required String window,
    required String notes,
    required String paymentMethod,
    String paymentStatus = 'pending',
    String? language,
    bool allowLocalFallback = true,
  }) async {
    final payload = {
      'customer': customer,
      'mobile': mobile,
      'areaEn': area.en,
      'areaAr': area.ar,
      'block': block,
      'street': street,
      'building': building,
      'service': service,
      'preference': preference,
      'window': window,
      'notes': notes,
      'paymentMethod': paymentMethod,
      'paymentStatus': paymentStatus,
      'language': language ?? (isArabic ? 'ar' : 'en'),
    };

    String? remoteError;
    try {
      final response = await html.HttpRequest.request(
        apiUrl('/api/orders'),
        method: 'POST',
        sendData: jsonEncode(payload),
        requestHeaders: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      );
      final status = response.status ?? 0;
      if (status >= 200 && status < 300 && response.responseText != null) {
        final created = Order.fromJson(Map<String, dynamic>.from(
            jsonDecode(response.responseText!) as Map));
        orders.removeWhere((order) => order.id == created.id);
        orders.insert(0, created);
        _saveOrders();
        notifyListeners();
        return created;
      }
      if (response.responseText != null && response.responseText!.isNotEmpty) {
        final decoded = jsonDecode(response.responseText!);
        if (decoded is Map && decoded['error'] != null) {
          remoteError = decoded['error'].toString();
        }
      }
    } catch (_) {}
    if (remoteError != null) {
      throw Exception(remoteError);
    }
    if (!allowLocalFallback) {
      throw Exception('Order could not be saved after payment confirmation.');
    }

    final deliveryPrice = deliveryPriceFor(area.en);
    final localOrderNumber = DateTime.now().millisecondsSinceEpoch;
    final local = Order(
      id: 'LOCAL-$localOrderNumber',
      invoiceNo: 'INV-LOCAL-$localOrderNumber',
      customer: customer,
      mobile: mobile,
      areaEn: area.en,
      areaAr: area.ar,
      address: isArabic
          ? '${area.ar}\u060c \u0642\u0637\u0639\u0629 $block\u060c \u0634\u0627\u0631\u0639 $street\u060c \u0645\u0628\u0646\u0649 $building'
          : '${area.en}, Block $block, Street $street, Building $building',
      service: service,
      preference: preference,
      window: window,
      deliveryPrice: deliveryPrice,
      totalAmount: deliveryPrice,
      paymentMethod: paymentMethod,
      paymentStatus: paymentStatus,
      branch: t('Pending assignment',
          '\u0628\u0627\u0646\u062a\u0638\u0627\u0631 \u0627\u0644\u062a\u0639\u064a\u064a\u0646'),
      receptionist: t('Pending assignment',
          '\u0628\u0627\u0646\u062a\u0638\u0627\u0631 \u0627\u0644\u062a\u0639\u064a\u064a\u0646'),
      driver: t('Pending assignment',
          '\u0628\u0627\u0646\u062a\u0638\u0627\u0631 \u0627\u0644\u062a\u0639\u064a\u064a\u0646'),
      tailor: t('Pending assignment',
          '\u0628\u0627\u0646\u062a\u0638\u0627\u0631 \u0627\u0644\u062a\u0639\u064a\u064a\u0646'),
      stage: Stage.newBooking,
      lat: 29.3759,
      lng: 47.9774,
      notes: notes,
      timeline: [
        t('Now - Booking submitted',
            '\u0627\u0644\u0622\u0646 - \u062a\u0645 \u0625\u0631\u0633\u0627\u0644 \u0627\u0644\u062d\u062c\u0632'),
        t('Next - Operations will assign tailor and driver',
            '\u0644\u0627\u062d\u0642\u0627\u064b - \u0633\u064a\u062a\u0645 \u062a\u0639\u064a\u064a\u0646 \u0627\u0644\u062e\u064a\u0627\u0637 \u0648\u0627\u0644\u0633\u0627\u0626\u0642'),
      ],
    );
    orders.insert(0, local);
    _saveOrders();
    notifyListeners();
    return local;
  }

  Future<Order> createBookingFromDraft(
    Map<String, dynamic> draft, {
    String paymentStatus = 'paid',
  }) {
    final areaEn = draft['areaEn']?.toString() ?? '';
    final areaAr = draft['areaAr']?.toString() ?? areaEn;
    final draftArea = kuwaitAreas.firstWhere(
      (item) => item.en.toLowerCase() == areaEn.toLowerCase(),
      orElse: () => Area(areaEn, areaAr),
    );
    return createBooking(
      customer: draft['customer']?.toString() ?? '',
      mobile: draft['mobile']?.toString() ?? '',
      area: draftArea,
      block: draft['block']?.toString() ?? '',
      street: draft['street']?.toString() ?? '',
      building: draft['building']?.toString() ?? '',
      service: draft['service']?.toString() ?? '',
      preference: draft['preference']?.toString() ?? '-',
      window: draft['window']?.toString() ?? '',
      notes: draft['notes']?.toString() ?? '',
      paymentMethod: draft['paymentMethod']?.toString() ?? 'UPay',
      paymentStatus: paymentStatus,
      language: draft['language']?.toString(),
      allowLocalFallback: false,
    );
  }

  Future<void> updateOrder(
    String id, {
    String? branch,
    String? receptionist,
    String? driver,
    String? tailor,
    String? window,
    String? notes,
    Stage? stage,
    String? paymentStatus,
    String? timelineNote,
  }) async {
    final index = orders.indexWhere((order) => order.id == id);
    if (index == -1) return;
    final original = orders[index];
    final nextTimeline = timelineNote == null
        ? original.timeline
        : [...original.timeline, timelineNow(timelineNote)];
    final local = original.copyWith(
      branch: branch,
      receptionist: receptionist,
      driver: driver,
      tailor: tailor,
      window: window,
      stage: stage,
      notes: notes,
      paymentStatus: paymentStatus,
      timeline: nextTimeline,
    );

    try {
      final response = await html.HttpRequest.request(
        apiUrl('/api/orders/$id'),
        method: 'PATCH',
        sendData: jsonEncode({
          if (branch != null) 'branch': branch,
          if (receptionist != null) 'receptionist': receptionist,
          if (driver != null) 'driver': driver,
          if (tailor != null) 'tailor': tailor,
          if (window != null) 'window': window,
          if (notes != null) 'notes': notes,
          if (stage != null) 'stage': stage.name,
          if (paymentStatus != null) 'paymentStatus': paymentStatus,
          if (timelineNote != null) 'timelineNote': timelineNote,
        }),
        requestHeaders: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      );
      final status = response.status ?? 0;
      if (status >= 200 && status < 300 && response.responseText != null) {
        orders[index] = Order.fromJson(Map<String, dynamic>.from(
            jsonDecode(response.responseText!) as Map));
        _saveOrders();
        notifyListeners();
        return;
      }
    } catch (_) {}

    orders[index] = local;
    _saveOrders();
    notifyListeners();
  }

  @override
  void dispose() {
    _poller?.cancel();
    super.dispose();
  }
}

class TailorWebApp extends StatelessWidget {
  const TailorWebApp({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Tailor Express Home Service',
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: maroon,
              primary: maroon,
              secondary: gold,
              surface: const Color(0xFFFFFBF6),
            ),
            scaffoldBackgroundColor: sand,
            fontFamily: 'Arial',
            cardTheme: CardThemeData(
              color: const Color(0xFFFFFBF6),
              elevation: 0,
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: const BorderSide(color: Color(0xFFE9D9BF)),
              ),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: maroon,
                foregroundColor: Colors.white,
                minimumSize: const Size(48, 48),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999)),
                textStyle: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                foregroundColor: maroon,
                minimumSize: const Size(48, 48),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                side: BorderSide(color: maroon.withOpacity(.65), width: 1.4),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999)),
                textStyle: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            filledButtonTheme: FilledButtonThemeData(
              style: FilledButton.styleFrom(
                minimumSize: const Size(48, 48),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999)),
                textStyle: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            snackBarTheme: const SnackBarThemeData(
              backgroundColor: maroon,
              contentTextStyle:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              behavior: SnackBarBehavior.floating,
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(color: Color(0xFFE2D6BC))),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(color: maroon, width: 1.8)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            ),
          ),
          builder: (context, child) => Directionality(
              textDirection: state.dir,
              child: child ?? const SizedBox.shrink()),
          initialRoute: browserInitialRoute(),
          onGenerateRoute: (settings) {
            final uri = Uri.parse(settings.name ?? '/');
            return MaterialPageRoute(builder: (_) => routeFor(uri));
          },
        );
      },
    );
  }

  String browserInitialRoute() {
    final path = html.window.location.pathname ?? '/';
    final query = html.window.location.search ?? '';
    final route = path.isEmpty || path == '/' ? '/booking' : path;
    return '$route$query';
  }

  Widget routeFor(Uri uri) {
    final path = uri.path.isEmpty ? '/' : uri.path;
    if (path == '/' || path == '/booking') {
      state.ensurePublicDefaultArabic();
      return BookingPage(
        state: state,
        paymentDraftId: uri.queryParameters['draft'],
        paymentFailed: uri.queryParameters['payment'] == 'failed',
      );
    }
    if (path == '/track') {
      state.ensurePublicDefaultArabic();
      return TrackPage(
          state: state,
          initialId: uri.queryParameters['order'],
          paymentResult: uri.queryParameters['payment'],
          paymentParams: uri.queryParameters);
    }
    if (path == '/staff') {
      state.enterStaffArea();
      return StaffHubPage(state: state);
    }
    if (path == '/login' ||
        path == '/login/staff' ||
        path.startsWith('/login/')) {
      state.enterStaffArea();
      return LoginPage(state: state);
    }
    if (path == '/dashboard' ||
        path == '/dashboard/staff' ||
        path.startsWith('/dashboard/')) {
      state.enterStaffArea();
      if (!state.signedIn || state.role == null) {
        return LockedPage(state: state, role: null);
      }
      return DashboardPage(state: state, role: state.role!);
    }
    state.ensurePublicDefaultArabic();
    return BookingPage(state: state);
  }
}

class Shell extends StatelessWidget {
  const Shell(
      {super.key,
      required this.state,
      required this.title,
      required this.subtitle,
      required this.body,
      this.public = false,
      this.role});
  final AppState state;
  final String title;
  final String subtitle;
  final Widget body;
  final bool public;
  final Role? role;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final compact = width < 640;
    final shellDirection = public ? state.dir : TextDirection.ltr;
    return Scaffold(
      body: SafeArea(
        child: Directionality(
          textDirection: shellDirection,
          child: SingleChildScrollView(
            padding: EdgeInsets.all(compact ? 14 : 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1240),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            brand(compact: compact),
                            Wrap(spacing: 10, runSpacing: 10, children: [
                              if (public)
                                nav(
                                    context,
                                    state.t('Book Service', 'احجز الخدمة'),
                                    '/booking'),
                              if (public)
                                nav(
                                    context,
                                    state.t('Track Order', 'تتبع الطلب'),
                                    '/track'),
                              if (role != null && state.signedIn)
                                Chip(
                                    label: Text(
                                        '${roleLabel(role!, state.isArabic)} • ${state.user}')),
                              if (role != null && state.signedIn)
                                notificationButton(context, state),
                              OutlinedButton(
                                  onPressed: state.toggleLang,
                                  child: Text(
                                      state.isArabic ? 'EN / AR' : 'AR / EN')),
                              if (role != null && state.signedIn)
                                ElevatedButton(
                                    onPressed: () {
                                      state.logout();
                                      Navigator.of(context)
                                          .pushNamedAndRemoveUntil(
                                              '/login/staff', (r) => false);
                                    },
                                    child: Text(
                                        state.t('Sign out', 'تسجيل الخروج'))),
                            ]),
                          ]),
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(compact ? 22 : 28),
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28),
                            gradient: const LinearGradient(
                                colors: [maroon, Color(0xFF2B0D16)])),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              brand(light: true, large: true),
                              if (title.trim().isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Text(title,
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: compact ? 28 : 34,
                                        fontWeight: FontWeight.w700,
                                        height: 1.05)),
                              ],
                              if (subtitle.trim().isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Text(subtitle,
                                    style: const TextStyle(
                                        color: Color(0xFFE6D8BD), height: 1.5)),
                              ],
                            ]),
                      ),
                      const SizedBox(height: 20),
                      body,
                    ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Widget brand({
  bool light = false,
  bool large = false,
  bool compact = false,
}) {
  final logoHeight = large ? 58.0 : (compact ? 34.0 : 40.0);
  final logoWidth = large ? 340.0 : (compact ? 190.0 : 250.0);
  final logo = Directionality(
    textDirection: TextDirection.ltr,
    child: Image.network(
      '/icons/tailor-logo-full.png',
      height: logoHeight,
      width: logoWidth,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (context, error, stackTrace) =>
          fallbackBrand(large: large, compact: compact),
    ),
  );
  if (!light) return logo;
  return Container(
    padding: EdgeInsets.symmetric(
      horizontal: large ? 18 : 12,
      vertical: large ? 12 : 8,
    ),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(999),
    ),
    child: logo,
  );
}

Widget fallbackBrand({
  bool large = false,
  bool compact = false,
}) {
  final markSize = large ? 46.0 : 34.0;
  final textStyle = TextStyle(
    color: maroon,
    fontWeight: FontWeight.w400,
    fontSize: large ? 26 : (compact ? 17 : 19),
    letterSpacing: large ? .4 : .1,
  );
  final logo = Directionality(
    textDirection: TextDirection.ltr,
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      TailorMark(size: markSize),
      SizedBox(width: large ? 14 : 12),
      Text('Tailor Express', style: textStyle),
    ]),
  );
  return logo;
}

class TailorMark extends StatelessWidget {
  const TailorMark({super.key, required this.size, this.light = false});
  final double size;
  final bool light;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: maroon,
        shape: BoxShape.circle,
      ),
      child: CustomPaint(
        painter: const TailorMarkPainter(color: Colors.white),
      ),
    );
  }
}

class TailorMarkPainter extends CustomPainter {
  const TailorMarkPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.width * .085
      ..strokeCap = StrokeCap.round;
    final inset = size.width * .30;
    canvas.drawLine(Offset(inset, inset),
        Offset(size.width - inset, size.height - inset), paint);
    canvas.drawLine(Offset(size.width - inset, inset),
        Offset(inset, size.height - inset), paint);
  }

  @override
  bool shouldRepaint(covariant TailorMarkPainter oldDelegate) =>
      oldDelegate.color != color;
}

Widget notificationButton(BuildContext context, AppState state) {
  final enabled = state.browserNotificationsEnabled;
  final count = state.staffNotificationCount;
  final label = enabled
      ? (count > 0
          ? state.t('Notifications $count', 'تنبيهات $count')
          : state.t('Notifications on', 'التنبيهات مفعلة'))
      : state.t('Enable notifications', 'تفعيل التنبيهات');
  return OutlinedButton.icon(
    onPressed: () async {
      if (!enabled) {
        await state.enableBrowserNotifications();
      }
      if (state.staffNotificationText.isNotEmpty && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(state.staffNotificationText)),
        );
      }
    },
    icon: Icon(enabled ? Icons.notifications_active : Icons.notifications_none),
    label: Text(label),
  );
}

Widget nav(BuildContext context, String label, String path) {
  final current =
      (ModalRoute.of(context)?.settings.name ?? '').startsWith(path) ||
          (path == '/booking' &&
              (ModalRoute.of(context)?.settings.name == '/' ||
                  ModalRoute.of(context)?.settings.name == '/booking'));
  return OutlinedButton(
    style: OutlinedButton.styleFrom(
        backgroundColor: current ? const Color(0xFFFFF4DD) : Colors.white),
    onPressed: () => Navigator.of(context).pushReplacementNamed(path),
    child: Text(label),
  );
}

class BookingPage extends StatefulWidget {
  const BookingPage({
    super.key,
    required this.state,
    this.paymentDraftId,
    this.paymentFailed = false,
  });
  final AppState state;
  final String? paymentDraftId;
  final bool paymentFailed;

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController();
  final mobile = TextEditingController();
  final block = TextEditingController();
  final street = TextEditingController();
  final building = TextEditingController();
  final notes = TextEditingController();
  Area area = kuwaitAreas.first;
  String service = 'Tailoring';
  String preference = '-';

  List<String> get serviceOptions => widget.state.isArabic
      ? const ['تصليح', 'تفصال']
      : const ['Repair', 'Tailoring'];

  List<String> get preferenceOptions => widget.state.isArabic
      ? const ['-', 'خياط', 'خياطه']
      : const ['-', 'Men tailor', 'Women tailor'];
  String window = '5:00 PM - 6:00 PM';
  DateTime visitDate = DateTime.now().add(const Duration(days: 1));
  double get selectedDeliveryPrice => widget.state.deliveryPriceFor(area.en);
  String money(double value) => formatKwd(value);
  String get visitDateText => formatVisitDate(visitDate);
  String get selectedVisitWindow => '$visitDateText, $window';
  List<String> get availableVisitSlots =>
      widget.state.availableSlotsForDate(visitDate);

  void ensureAvailableVisitSelection() {
    visitDate = widget.state.nextAvailableVisitDate(visitDate);
    final slots = availableVisitSlots;
    if (slots.isNotEmpty && !slots.contains(window)) {
      window = slots.first;
    }
  }

  @override
  void initState() {
    super.initState();
    widget.state.ensurePublicDefaultArabic();
    final draftId = widget.paymentDraftId;
    if (draftId != null) {
      final draft = widget.state.paymentDraft(draftId);
      if (draft != null) {
        applyPaymentDraft(draft);
        if (widget.paymentFailed) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(widget.state.t(
                    'Payment was not completed. Please try UPay again.',
                    '\u0644\u0645 \u064a\u0643\u062a\u0645\u0644 \u0627\u0644\u062f\u0641\u0639. \u064a\u0631\u062c\u0649 \u0627\u0644\u0645\u062d\u0627\u0648\u0644\u0629 \u0645\u0631\u0629 \u0623\u062e\u0631\u0649.'))));
            showPaymentGate();
          });
        }
      }
    }
  }

  void applyPaymentDraft(Map<String, dynamic> draft) {
    name.text = draft['customer']?.toString() ?? '';
    mobile.text = draft['mobile']?.toString() ?? '';
    block.text = draft['block']?.toString() ?? '';
    street.text = draft['street']?.toString() ?? '';
    building.text = draft['building']?.toString() ?? '';
    final areaEn = draft['areaEn']?.toString() ?? area.en;
    area = kuwaitAreas.firstWhere(
      (item) => item.en.toLowerCase() == areaEn.toLowerCase(),
      orElse: () => area,
    );
    final draftService = draft['service']?.toString();
    if (draftService != null && serviceOptions.contains(draftService)) {
      service = draftService;
    }
    final draftPreference = draft['preference']?.toString();
    if (draftPreference != null &&
        preferenceOptions.contains(draftPreference)) {
      preference = draftPreference;
    }
    final storedWindow = draft['window']?.toString() ?? '';
    final comma = storedWindow.indexOf(',');
    window =
        comma >= 0 ? storedWindow.substring(comma + 1).trim() : storedWindow;
    if (window.isEmpty) window = '5:00 PM - 6:00 PM';
    final isoDate = draft['visitDateIso']?.toString();
    if (isoDate != null && isoDate.isNotEmpty) {
      visitDate = DateTime.tryParse(isoDate) ?? visitDate;
    }
    final draftNotes = draft['customerNotes']?.toString();
    if (draftNotes != null) notes.text = draftNotes;
  }

  Map<String, dynamic> buildPaymentDraft(String paymentMethod) {
    final paymentNote = widget.state.isArabic
        ? 'الدفع: $paymentMethod'
        : 'Payment: $paymentMethod';
    final customerNotes = notes.text.trim();
    final mergedNotes =
        customerNotes.isEmpty ? paymentNote : '$customerNotes | $paymentNote';
    return {
      'customer': name.text.trim(),
      'mobile': mobile.text.trim(),
      'areaEn': area.en,
      'areaAr': area.ar,
      'block': block.text.trim(),
      'street': street.text.trim(),
      'building': building.text.trim(),
      'service': service,
      'preference': preference,
      'window': selectedVisitWindow,
      'visitDateIso': visitDate.toIso8601String(),
      'customerNotes': customerNotes,
      'notes': mergedNotes,
      'paymentMethod': paymentMethod,
      'amount': selectedDeliveryPrice,
      'language': widget.state.isArabic ? 'ar' : 'en',
    };
  }

  void ensureActiveSelectedArea() {
    final active = widget.state.activeAreas;
    if (active.isNotEmpty &&
        !active.any((item) => item.en.toLowerCase() == area.en.toLowerCase())) {
      area = active.first;
    }
  }

  @override
  void dispose() {
    name.dispose();
    mobile.dispose();
    block.dispose();
    street.dispose();
    building.dispose();
    notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    if (!serviceOptions.contains(service)) service = serviceOptions.first;
    if (!preferenceOptions.contains(preference)) preference = '-';
    return Shell(
      state: s,
      public: true,
      title: '',
      subtitle: '',
      body: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 980;
          final formCardWidth = narrow ? constraints.maxWidth : 760.0;
          final infoCardWidth = narrow ? constraints.maxWidth : 430.0;
          return Wrap(
            spacing: 18,
            runSpacing: 18,
            children: [
              SizedBox(
                width: formCardWidth,
                child: bookingFormCard(formCardWidth),
              ),
              SizedBox(
                width: infoCardWidth,
                child: bookingInfoCard(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget bookingFormCard(double cardWidth) {
    final s = widget.state;
    ensureActiveSelectedArea();
    ensureAvailableVisitSelection();
    final contentWidth = cardWidth - 44;
    final phone = cardWidth < 520;
    final wideField = phone ? contentWidth : 230.0;
    final halfField = phone ? (contentWidth - 12) / 2 : 150.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.t('Book a home visit', 'احجز زيارة منزلية'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  field(name, s.t('Customer name', 'اسم العميل'),
                      width: wideField),
                  field(mobile, s.t('Mobile number', 'رقم الهاتف'),
                      width: wideField, phone: true),
                  areaField(s, width: wideField),
                  SizedBox(
                    width: wideField,
                    child: InputDecorator(
                      decoration: InputDecoration(
                          labelText: s.t('Delivery price',
                              '\u0633\u0639\u0631 \u0627\u0644\u062a\u0648\u0635\u064a\u0644')),
                      child: Text(money(selectedDeliveryPrice),
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                  field(block, s.t('Block', 'قطعة'), width: halfField),
                  field(street, s.t('Street', 'شارع'), width: halfField),
                  field(building, s.t('Building / House', 'مبنى / منزل'),
                      width: wideField),
                  drop(
                      s,
                      s.t('Service', 'الخدمة'),
                      serviceOptions.contains(service)
                          ? service
                          : serviceOptions.first,
                      serviceOptions,
                      (v) => setState(() => service = v!),
                      width: wideField),
                  drop(
                      s,
                      s.t('Tailor preference', 'تفضيل الخياط'),
                      preferenceOptions.contains(preference)
                          ? preference
                          : preferenceOptions.first,
                      preferenceOptions,
                      (v) => setState(() => preference = v!),
                      width: wideField,
                      validator: (value) => value == null || value == '-'
                          ? s.t('Choose tailor preference', 'اختر تفضيل الخياط')
                          : null),
                  drop(
                      s,
                      s.t('Visit window', 'موعد الزيارة'),
                      window,
                      availableVisitSlots.isEmpty
                          ? [window]
                          : availableVisitSlots,
                      (v) => setState(() => window = v!),
                      width: wideField),
                  visitDateField(s, width: wideField),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                  controller: notes,
                  maxLines: 4,
                  decoration:
                      InputDecoration(labelText: s.t('Notes', 'ملاحظات'))),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  ElevatedButton(
                      onPressed: submit,
                      child: Text(s.t(
                          'Review policy & pay', 'راجع السياسة وانتقل للدفع'))),
                  OutlinedButton(
                      onPressed: () => showPolicyPreview(),
                      child: Text(s.t('Preview policies', 'عرض السياسات'))),
                  OutlinedButton(
                      onPressed: () =>
                          Navigator.of(context).pushReplacementNamed('/track'),
                      child: Text(s.t('Open tracking', 'افتح التتبع'))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget bookingInfoCard() {
    final s = widget.state;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.t('What happens before payment', 'ما الذي يحدث قبل الدفع'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            bullet(s.t(
                'Policies are shown before payment and must be accepted.',
                'يتم عرض السياسات قبل الدفع ويجب الموافقة عليها.')),
            bullet(s.t('The customer moves to payment only after agreeing.',
                'ينتقل العميل إلى الدفع فقط بعد الموافقة.')),
            bullet(s.t('Admin policy text is reused here automatically.',
                'يتم استخدام نص سياسات الإدارة هنا تلقائياً.')),
            const SizedBox(height: 10),
            for (final policy in adminPolicies)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFCF7),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE6D9BE)),
                ),
                child: Text(
                  s.isArabic ? policy.nameAr : policy.nameEn,
                  style:
                      const TextStyle(fontWeight: FontWeight.w700, color: ink),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget field(TextEditingController c, String label,
          {required double width, bool phone = false}) =>
      SizedBox(
        width: width,
        child: TextFormField(
          controller: c,
          keyboardType: phone ? TextInputType.phone : TextInputType.text,
          validator: (v) => v == null || v.trim().isEmpty
              ? widget.state.t('Required', 'مطلوب')
              : null,
          decoration: InputDecoration(labelText: label),
        ),
      );

  Widget areaField(AppState s, {required double width}) => SizedBox(
        width: width,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: openAreaPicker,
          child: InputDecorator(
            decoration: InputDecoration(
                labelText:
                    s.t('Area', '\u0627\u0644\u0645\u0646\u0637\u0642\u0629')),
            child: Row(
              children: [
                Expanded(
                    child: Text(
                        '${area.name(s.isArabic)} - ${money(selectedDeliveryPrice)}',
                        overflow: TextOverflow.ellipsis)),
                const Icon(Icons.arrow_drop_down),
              ],
            ),
          ),
        ),
      );

  Future<void> openAreaPicker() async {
    final s = widget.state;
    final areas = s.activeAreas;
    final areaSearch = TextEditingController();
    final selected = await showModalBottomSheet<Area>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final query = areaSearch.text.trim().toLowerCase();
          final shown = areas.where((item) {
            return query.isEmpty ||
                item.en.toLowerCase().contains(query) ||
                item.ar.toLowerCase().contains(query);
          }).toList();
          return SafeArea(
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.72,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            s.t('Choose area',
                                '\u0627\u062e\u062a\u0631 \u0627\u0644\u0645\u0646\u0637\u0642\u0629'),
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 10),
                        TextField(
                          controller: areaSearch,
                          onChanged: (_) => setSheetState(() {}),
                          decoration: InputDecoration(
                            labelText: s.t('Search area', 'ابحث عن المنطقة'),
                            suffixIcon: const Icon(Icons.search),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                      itemCount: shown.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final item = shown[index];
                        final chosen = item.en == area.en;
                        return ListTile(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          tileColor: chosen
                              ? const Color(0xFFFFF1CF)
                              : const Color(0xFFFFFCF7),
                          title: Text(item.name(s.isArabic)),
                          subtitle: Text(
                              '${s.t('Delivery', '\u0627\u0644\u062a\u0648\u0635\u064a\u0644')}: ${money(s.deliveryPriceFor(item.en))}'),
                          trailing: chosen
                              ? const Icon(Icons.check, color: gold)
                              : null,
                          onTap: () => Navigator.of(context).pop(item),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    areaSearch.dispose();
    if (selected != null) setState(() => area = selected);
  }

  Widget drop(AppState s, String label, String value, List<String> items,
          ValueChanged<String?> onChanged,
          {required double width, String? Function(String?)? validator}) =>
      SizedBox(
        width: width,
        child: DropdownButtonFormField<String>(
          value: value,
          isExpanded: true,
          decoration: InputDecoration(labelText: label),
          items: [
            for (final item in items)
              DropdownMenuItem(
                  value: item,
                  child: Text(item, overflow: TextOverflow.ellipsis))
          ],
          onChanged: onChanged,
          validator: validator,
        ),
      );

  Widget visitDateField(AppState s, {required double width}) => SizedBox(
        width: width,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: pickVisitDate,
          child: InputDecorator(
            decoration:
                InputDecoration(labelText: s.t('Visit day', 'يوم الزيارة')),
            child: Row(
              children: [
                Expanded(child: Text(visitDateText)),
                const Icon(Icons.calendar_month),
              ],
            ),
          ),
        ),
      );

  Future<void> pickVisitDate() async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: visitDate.isBefore(firstDate) ? firstDate : visitDate,
      firstDate: firstDate,
      lastDate: firstDate.add(const Duration(days: 30)),
      selectableDayPredicate: widget.state.isVisitDateAvailable,
    );
    if (picked != null) {
      setState(() {
        visitDate = picked;
        final slots = availableVisitSlots;
        if (slots.isNotEmpty) window = slots.first;
      });
    }
  }

  void submit() {
    if (!form.currentState!.validate()) return;
    if (!widget.state.areaIsActive(area.en)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(widget.state.t('This area is currently unavailable.',
              '\u0647\u0630\u0647 \u0627\u0644\u0645\u0646\u0637\u0642\u0629 \u063a\u064a\u0631 \u0645\u062a\u0627\u062d\u0629 \u062d\u0627\u0644\u064a\u0627.'))));
      return;
    }
    if (!widget.state.isVisitDateAvailable(visitDate) ||
        !availableVisitSlots.contains(window)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(widget.state.t(
              'Choose an available visit day and time.',
              'اختر يوم ووقت زيارة متاحين.'))));
      return;
    }
    showPolicyGate();
  }

  Future<void> showPolicyPreview() async {
    final s = widget.state;
    final dialogWidth = dialogContentWidth(context, 860);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.t('Policies before payment', 'السياسات قبل الدفع')),
        content: SizedBox(
          width: dialogWidth,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.t(
                    'The customer must review these policy items before moving to payment.',
                    'يجب على العميل مراجعة هذه السياسات قبل الانتقال إلى الدفع.')),
                const SizedBox(height: 14),
                for (final policy in adminPolicies) policyCard(policy),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(s.t('Close', 'إغلاق'))),
        ],
      ),
    );
  }

  Future<void> showPolicyGate() async {
    final s = widget.state;
    var agreed = false;
    final dialogWidth = dialogContentWidth(context, 860);
    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
              s.t('Review policy before payment', 'راجع السياسة قبل الدفع')),
          content: SizedBox(
            width: dialogWidth,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.t(
                      'Payment is locked until the customer agrees to the booking policies below.',
                      'يتم قفل الدفع حتى يوافق العميل على سياسات الحجز التالية.')),
                  const SizedBox(height: 14),
                  for (final policy in adminPolicies) policyCard(policy),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    value: agreed,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (value) =>
                        setDialogState(() => agreed = value ?? false),
                    title: Text(s.t(
                        'I have read and agree to these policies before payment.',
                        'لقد قرأت هذه السياسات وأوافق عليها قبل الدفع.')),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(s.t('Back', 'رجوع'))),
            ElevatedButton(
                onPressed:
                    agreed ? () => Navigator.of(context).pop(true) : null,
                child: Text(s.t('Proceed to payment', 'الانتقال إلى الدفع'))),
          ],
        ),
      ),
    );

    if (proceed == true && mounted) {
      await showPaymentGate();
    }
  }

  Future<void> showPaymentGate() async {
    final s = widget.state;
    final amount = selectedDeliveryPrice;
    final dialogWidth = dialogContentWidth(context, 540);
    var selectedGatewaySrc = 'knet';
    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(s.t('UPay checkout',
              '\u0627\u0644\u062f\u0641\u0639 \u0639\u0628\u0631 UPay')),
          content: SizedBox(
            width: dialogWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.t(
                    'Choose a payment method, then complete payment on UPay. The booking is saved only after payment succeeds.',
                    '\u0627\u062e\u062a\u0631 \u0637\u0631\u064a\u0642\u0629 \u0627\u0644\u062f\u0641\u0639 \u062b\u0645 \u0623\u0643\u0645\u0644 \u0627\u0644\u062f\u0641\u0639 \u0639\u0628\u0631 UPay. \u064a\u062a\u0645 \u062d\u0641\u0638 \u0627\u0644\u062d\u062c\u0632 \u0641\u0642\u0637 \u0628\u0639\u062f \u0646\u062c\u0627\u062d \u0627\u0644\u062f\u0641\u0639.')),
                const SizedBox(height: 14),
                Text(
                  s.t('Payment method',
                      '\u0637\u0631\u064a\u0642\u0629 \u0627\u0644\u062f\u0641\u0639'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final option in paymentGatewayOptions)
                      ChoiceChip(
                        label: Text(s.isArabic
                            ? option['labelAr']!
                            : option['labelEn']!),
                        selected: selectedGatewaySrc == option['src'],
                        onSelected: (_) => setDialogState(
                            () => selectedGatewaySrc = option['src']!),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: const Color(0xFFFFF7E7),
                      borderRadius: BorderRadius.circular(14)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          s.t('Home service visit',
                              '\u0632\u064a\u0627\u0631\u0629 \u062e\u062f\u0645\u0629 \u0645\u0646\u0632\u0644\u064a\u0629'),
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text(
                          '${s.t('Area', '\u0627\u0644\u0645\u0646\u0637\u0642\u0629')}: ${area.name(s.isArabic)}'),
                      const SizedBox(height: 6),
                      Text(
                          '${s.t('Visit', '\u0627\u0644\u0632\u064a\u0627\u0631\u0629')}: $selectedVisitWindow'),
                      const SizedBox(height: 6),
                      Text(
                          '${s.t('Amount', '\u0627\u0644\u0645\u0628\u0644\u063a')}: ${money(amount)}'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(s.t('Back', '\u0631\u062c\u0648\u0639'))),
            ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(s.t('Continue to UPay',
                    '\u0627\u0644\u0645\u062a\u0627\u0628\u0639\u0629 \u0625\u0644\u0649 UPay'))),
          ],
        ),
      ),
    );

    if (proceed != true || !mounted) return;

    final selectedGateway = paymentGatewayOptions.firstWhere(
      (option) => option['src'] == selectedGatewaySrc,
      orElse: () => paymentGatewayOptions.first,
    );
    final paid =
        'UPay - ${s.isArabic ? selectedGateway['labelAr'] : selectedGateway['labelEn']}';
    final draftId = 'DRAFT-${DateTime.now().millisecondsSinceEpoch}';
    final draft = buildPaymentDraft(paid);
    widget.state.savePaymentDraft(draftId, draft);
    try {
      final paymentUrl = await widget.state.createPaymentLinkForDraft(
        draftId: draftId,
        draft: draft,
        amount: amount,
        method: paid,
        paymentGatewaySrc: selectedGatewaySrc,
      );
      html.window.location.assign(paymentUrl);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(s.t(
              'UPay checkout opened. Complete payment to confirm the booking.',
              '\u062a\u0645 \u0641\u062a\u062d UPay. \u0623\u0643\u0645\u0644 \u0627\u0644\u062f\u0641\u0639 \u0644\u062a\u0623\u0643\u064a\u062f \u0627\u0644\u062d\u062c\u0632.'))));
    } catch (error) {
      widget.state.removePaymentDraft(draftId);
      if (!mounted) return;
      final detail = error.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(s.t(
              'Payment did not open. No booking was saved. Try again. $detail',
              '\u0644\u0645 \u062a\u0641\u062a\u062d \u0635\u0641\u062d\u0629 \u0627\u0644\u062f\u0641\u0639. \u0644\u0645 \u064a\u062a\u0645 \u062d\u0641\u0638 \u0627\u0644\u062d\u062c\u0632. \u062d\u0627\u0648\u0644 \u0645\u0631\u0629 \u0623\u062e\u0631\u0649. $detail'))));
    }
  }

  Future<void> legacyShowPaymentGate() async {
    final s = widget.state;
    final amount = selectedDeliveryPrice;
    final dialogWidth = dialogContentWidth(context, 540);
    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.t('UPay checkout', 'الدفع عبر UPay')),
        content: SizedBox(
          width: dialogWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.t(
                  'You will be redirected to UPay to complete payment securely.',
                  'سيتم تحويلك إلى UPay لإكمال الدفع بأمان.')),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: const Color(0xFFFFF7E7),
                    borderRadius: BorderRadius.circular(14)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.t('Home service visit', 'زيارة الخدمة المنزلية'),
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text('${s.t('Area', 'المنطقة')}: ${area.name(s.isArabic)}'),
                    const SizedBox(height: 6),
                    Text('${s.t('Visit', 'الزيارة')}: $selectedVisitWindow'),
                    const SizedBox(height: 6),
                    Text('${s.t('Amount', 'المبلغ')}: ${money(amount)}'),
                    if (amount < 0)
                      Text(s.t('Amount: KD 3.500', 'المبلغ: 3.500 د.ك')),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(s.t('Back', 'رجوع'))),
          ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(s.t('Continue to UPay', 'المتابعة إلى UPay'))),
        ],
      ),
    );

    if (proceed != true || !mounted) return;

    const paid = 'UPay';
    final paymentNote = s.isArabic ? 'الدفع: $paid' : 'Payment: $paid';
    final mergedNotes = notes.text.trim().isEmpty
        ? paymentNote
        : '${notes.text.trim()} | $paymentNote';
    Order? order;
    try {
      order = await widget.state.createBooking(
        customer: name.text.trim(),
        mobile: mobile.text.trim(),
        area: area,
        block: block.text.trim(),
        street: street.text.trim(),
        building: building.text.trim(),
        service: service,
        preference: preference,
        window: selectedVisitWindow,
        notes: mergedNotes,
        paymentMethod: paid,
      );
      final paymentUrl = await widget.state.createPaymentLink(
        order: order,
        amount: amount,
        method: paid,
      );
      html.window.location.assign(paymentUrl);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(s.t('UPay checkout opened. Booking created.',
              'تم فتح صفحة UPay وإنشاء الحجز.'))));
    } catch (error) {
      if (!mounted) return;
      final detail = error.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(s.t(
              'Booking created, but UPay did not return a checkout link: $detail',
              'تم إنشاء الحجز، لكن UPay لم يرجع رابط الدفع: $detail'))));
      if (order != null) {
        Navigator.of(context).pushReplacementNamed('/track?order=${order.id}');
      }
    }
  }

  Widget policyCard(PolicyRecord policy) {
    final s = widget.state;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: const Color(0xFFFFFCF7),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE6D9BE))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.isArabic ? policy.nameAr : policy.nameEn,
              style: const TextStyle(color: ink, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(s.isArabic ? policy.detailAr : policy.detailEn),
        ],
      ),
    );
  }

  double dialogContentWidth(BuildContext context, double desktopWidth) {
    final width = MediaQuery.of(context).size.width;
    if (width < 520) {
      return width * 0.82;
    }
    if (width < desktopWidth + 120) {
      return width * 0.78;
    }
    return desktopWidth;
  }
}

class TrackPage extends StatefulWidget {
  const TrackPage(
      {super.key,
      required this.state,
      this.initialId,
      this.paymentResult,
      this.paymentParams = const {}});
  final AppState state;
  final String? initialId;
  final String? paymentResult;
  final Map<String, String> paymentParams;

  @override
  State<TrackPage> createState() => _TrackPageState();
}

class _TrackPageState extends State<TrackPage> {
  late final TextEditingController id = TextEditingController(
      text:
          isDraftOrderId(widget.initialId ?? '') ? '' : widget.initialId ?? '');
  Order? order;
  bool checkingPayment = false;
  bool? paymentSucceeded;
  String paymentTitle = '';
  String paymentDetail = '';
  String retryDraftId = '';

  @override
  void initState() {
    super.initState();
    _loadInitialOrder();
  }

  Future<void> _loadInitialOrder() async {
    final initial = widget.initialId ?? '';
    if (initial.isEmpty) return;
    final result = (widget.paymentResult ?? '').toLowerCase();

    if (isDraftOrderId(initial)) {
      id.clear();
      await handlePaymentReturn(initial, result);
      return;
    }

    await widget.state.refreshOrders(quiet: true);
    if (!mounted) return;
    setState(() {
      final found = widget.state.byId(initial);
      order = found != null && hasConfirmedPayment(found) ? found : null;
    });
  }

  Future<void> handlePaymentReturn(String draftId, String result) async {
    final s = widget.state;
    if (result == 'failed' || result == 'cancel' || result == 'cancelled') {
      if (!mounted) return;
      setState(() {
        paymentSucceeded = false;
        retryDraftId = draftId;
        paymentTitle = s.t('Payment was not completed.',
            '\u0644\u0645 \u064a\u0643\u062a\u0645\u0644 \u0627\u0644\u062f\u0641\u0639.');
        paymentDetail = s.t(
            'No booking was saved. You can return to the payment step and try again.',
            '\u0644\u0645 \u064a\u062a\u0645 \u062d\u0641\u0638 \u0627\u0644\u062d\u062c\u0632. \u064a\u0645\u0643\u0646\u0643 \u0627\u0644\u0631\u062c\u0648\u0639 \u0644\u062e\u0637\u0648\u0629 \u0627\u0644\u062f\u0641\u0639 \u0648\u0627\u0644\u0645\u062d\u0627\u0648\u0644\u0629 \u0645\u0631\u0629 \u0623\u062e\u0631\u0649.');
      });
      return;
    }

    setState(() => checkingPayment = true);
    try {
      final status = await s.confirmPaymentReturn(widget.paymentParams);
      final verified = status['verified'] == true;
      final paymentState = status['status']?.toString().toLowerCase() ?? '';
      final verificationError = status['error']?.toString() ?? '';
      final rawStatus = status['rawStatus']?.toString() ?? '';
      final confirmedOrder = status['orderObject'];
      if (!verified || paymentState != 'paid' || confirmedOrder is! Order) {
        if (!mounted) return;
        final extraDetail = verificationError.isNotEmpty
            ? ' $verificationError'
            : rawStatus.isNotEmpty
                ? ' UPay status: $rawStatus.'
                : '';
        setState(() {
          paymentSucceeded = false;
          retryDraftId = draftId;
          paymentTitle = s.t('Payment is not confirmed yet.',
              '\u0627\u0644\u062f\u0641\u0639 \u063a\u064a\u0631 \u0645\u0624\u0643\u062f \u062d\u062a\u0649 \u0627\u0644\u0622\u0646.');
          paymentDetail = s.t(
              'No booking was saved because UPay did not confirm a captured payment.$extraDetail',
              '\u0644\u0645 \u064a\u062a\u0645 \u062d\u0641\u0638 \u0627\u0644\u062d\u062c\u0632 \u0644\u0623\u0646 UPay \u0644\u0645 \u064a\u0624\u0643\u062f \u0639\u0645\u0644\u064a\u0629 \u062f\u0641\u0639 \u0645\u0643\u062a\u0645\u0644\u0629.$extraDetail');
        });
        return;
      }

      s.removePaymentDraft(draftId);
      if (!mounted) return;
      id.text = confirmedOrder.id;
      setState(() {
        order = confirmedOrder;
        paymentSucceeded = true;
        paymentTitle = s.t('Payment confirmed. Booking created.',
            '\u062a\u0645 \u062a\u0623\u0643\u064a\u062f \u0627\u0644\u062f\u0641\u0639 \u0648\u0625\u0646\u0634\u0627\u0621 \u0627\u0644\u062d\u062c\u0632.');
        paymentDetail = s.t('Use this order number for tracking.',
            '\u0627\u0633\u062a\u062e\u062f\u0645 \u0631\u0642\u0645 \u0627\u0644\u0637\u0644\u0628 \u0647\u0630\u0627 \u0644\u0644\u062a\u062a\u0628\u0639.');
      });
    } catch (error) {
      if (!mounted) return;
      final detail = error.toString().replaceFirst('Exception: ', '');
      setState(() {
        paymentSucceeded = false;
        retryDraftId = draftId;
        paymentTitle = s.t('Payment could not be verified.',
            '\u062a\u0639\u0630\u0631 \u0627\u0644\u062a\u062d\u0642\u0642 \u0645\u0646 \u0627\u0644\u062f\u0641\u0639.');
        paymentDetail = s.t(
            'No booking was saved. If money was deducted, contact support before paying again. $detail',
            '\u0644\u0645 \u064a\u062a\u0645 \u062d\u0641\u0638 \u0627\u0644\u062d\u062c\u0632. \u0625\u0630\u0627 \u062a\u0645 \u062e\u0635\u0645 \u0627\u0644\u0645\u0628\u0644\u063a\u060c \u062a\u0648\u0627\u0635\u0644 \u0645\u0639 \u0627\u0644\u062f\u0639\u0645 \u0642\u0628\u0644 \u0625\u0639\u0627\u062f\u0629 \u0627\u0644\u062f\u0641\u0639. $detail');
      });
    } finally {
      if (mounted) setState(() => checkingPayment = false);
    }
  }

  @override
  void dispose() {
    id.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    return Shell(
      state: s,
      public: true,
      title: '',
      subtitle: '',
      body: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 980;
          final leftWidth = narrow ? constraints.maxWidth : 360.0;
          final rightWidth = narrow ? constraints.maxWidth : 820.0;
          return Wrap(
            spacing: 18,
            runSpacing: 18,
            children: [
              SizedBox(width: leftWidth, child: trackSearchCard()),
              SizedBox(width: rightWidth, child: trackingResultCard()),
            ],
          );
        },
      ),
    );
  }

  Widget trackSearchCard() {
    final s = widget.state;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.t('Track order', 'تتبع الطلب'),
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
                controller: id,
                decoration:
                    InputDecoration(labelText: s.t('Order ID', 'رقم الطلب'))),
            const SizedBox(height: 12),
            SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                    onPressed: search, child: Text(s.t('Search', 'بحث')))),
          ],
        ),
      ),
    );
  }

  Widget trackingResultCard() {
    final s = widget.state;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: checkingPayment
            ? Row(
                children: [
                  const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Text(s.t('Checking payment status...',
                          'جاري التحقق من حالة الدفع...'))),
                ],
              )
            : paymentTitle.isNotEmpty
                ? paymentNoticeCard()
                : order == null
                    ? Text(s.t('Search an order to show its status.',
                        'ابحث عن طلب لإظهار حالته.'))
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text('${s.t('Order', 'الطلب')} ${order!.id}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall),
                              badge(
                                  customerStageLabel(order!.stage, s.isArabic),
                                  stageColor(order!.stage)),
                              badge(
                                order!.paymentStatus.toLowerCase() == 'paid'
                                    ? s.t('Paid', 'مدفوع')
                                    : s.t('Payment pending', 'الدفع معلق'),
                                order!.paymentStatus.toLowerCase() == 'paid'
                                    ? const Color(0xFF2D8A57)
                                    : gold,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          bullet(
                              '${s.t('Current status', 'الحالة الحالية')}: ${customerStageLabel(order!.stage, s.isArabic)}'),
                          bullet(
                              '${s.t('Payment', 'الدفع')}: ${order!.paymentStatus.toLowerCase() == 'paid' ? s.t('Paid', 'مدفوع') : s.t('Pending', 'معلق')}'),
                        ],
                      ),
      ),
    );
  }

  Widget paymentNoticeCard() {
    final s = widget.state;
    final success = paymentSucceeded == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        badge(paymentTitle, success ? const Color(0xFF2D8A57) : maroon),
        const SizedBox(height: 12),
        Text(paymentDetail),
        if (order != null) ...[
          const SizedBox(height: 16),
          Text('${s.t('Order', 'الطلب')}: ${order!.id}',
              style:
                  const TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
          const SizedBox(height: 8),
          bullet('${s.t('Visit', 'الزيارة')}: ${order!.window}'),
          bullet('${s.t('Area', 'المنطقة')}: ${order!.area(s.isArabic)}'),
          bullet('${s.t('Payment', 'الدفع')}: ${s.t('Paid', 'مدفوع')}'),
        ],
        if (!success && retryDraftId.isNotEmpty) ...[
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pushReplacementNamed(
                '/booking?payment=failed&draft=${Uri.encodeComponent(retryDraftId)}'),
            child: Text(s.t('Try payment again', 'حاول الدفع مرة أخرى')),
          ),
        ],
      ],
    );
  }

  void search() => setState(() {
        if (isDraftOrderId(id.text)) {
          order = null;
          paymentSucceeded = false;
          paymentTitle = widget.state.t('Payment was not completed.',
              '\u0644\u0645 \u064a\u0643\u062a\u0645\u0644 \u0627\u0644\u062f\u0641\u0639.');
          paymentDetail = widget.state.t(
              'This is a temporary payment number, not a tracking number. Please finish payment to receive a real order number.',
              '\u0647\u0630\u0627 \u0631\u0642\u0645 \u062f\u0641\u0639 \u0645\u0624\u0642\u062a \u0648\u0644\u064a\u0633 \u0631\u0642\u0645 \u062a\u062a\u0628\u0639. \u064a\u0631\u062c\u0649 \u0625\u0643\u0645\u0627\u0644 \u0627\u0644\u062f\u0641\u0639 \u0644\u0644\u062d\u0635\u0648\u0644 \u0639\u0644\u0649 \u0631\u0642\u0645 \u0637\u0644\u0628 \u062d\u0642\u064a\u0642\u064a.');
          retryDraftId = id.text.trim();
          return;
        }
        paymentTitle = '';
        paymentDetail = '';
        retryDraftId = '';
        final found = widget.state.byId(id.text);
        order = found != null && hasConfirmedPayment(found) ? found : null;
      });

  Future<void> copy(String text, String message) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> openMap(Order order, bool google) async {
    final url = google
        ? 'https://www.google.com/maps/search/?api=1&query=${order.lat},${order.lng}'
        : 'https://www.openstreetmap.org/?mlat=${order.lat}&mlon=${order.lng}#map=16/${order.lat}/${order.lng}';
    await launchUrl(Uri.parse(url), webOnlyWindowName: '_blank');
  }
}

class StaffHubPage extends StatelessWidget {
  const StaffHubPage({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Shell(
      state: state,
      title: state.t('One private staff login.',
          '\u062a\u0633\u062c\u064a\u0644 \u062f\u062e\u0648\u0644 \u0645\u0648\u062d\u062f \u0644\u0644\u0645\u0648\u0638\u0641\u064a\u0646.'),
      subtitle: state.t(
          'Use /login/staff. The account role decides which dashboard features are available.',
          '\u0627\u0633\u062a\u062e\u062f\u0645 /login/staff. \u0646\u0648\u0639 \u0627\u0644\u062d\u0633\u0627\u0628 \u064a\u062d\u062f\u062f \u0627\u0644\u0623\u062f\u0648\u0627\u062a \u0627\u0644\u0645\u062a\u0627\u062d\u0629 \u0628\u0639\u062f \u0627\u0644\u062f\u062e\u0648\u0644.'),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        state.t('Staff portal',
                            '\u0628\u0648\u0627\u0628\u0629 \u0627\u0644\u0645\u0648\u0638\u0641\u064a\u0646'),
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 10),
                    Text('/login/staff'),
                    const SizedBox(height: 14),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final role in Role.values)
                        sectionChip(roleLabel(role, state.isArabic)),
                    ]),
                    const SizedBox(height: 18),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.of(context)
                          .pushReplacementNamed('/login/staff'),
                      icon: const Icon(Icons.lock_open),
                      label: Text(state.t('Open staff login',
                          '\u0641\u062a\u062d \u062a\u0633\u062c\u064a\u0644 \u0627\u0644\u0645\u0648\u0638\u0641\u064a\u0646')),
                    ),
                  ]),
            ),
          ),
        ),
      ),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.state});
  final AppState state;
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final form = GlobalKey<FormState>();
  final user = TextEditingController();
  final pass = TextEditingController();

  @override
  void dispose() {
    user.dispose();
    pass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    return Shell(
      state: s,
      title: s.t('Staff login.',
          '\u062a\u0633\u062c\u064a\u0644 \u062f\u062e\u0648\u0644 \u0627\u0644\u0645\u0648\u0638\u0641\u064a\u0646.'),
      subtitle: s.t(
          'One private link for admin, supervisors, receptionists, tailors and drivers. Permissions come from the user role.',
          '\u0631\u0627\u0628\u0637 \u062e\u0627\u0635 \u0648\u0627\u062d\u062f \u0644\u0644\u0625\u062f\u0627\u0631\u0629 \u0648\u0627\u0644\u0645\u0634\u0631\u0641\u064a\u0646 \u0648\u0627\u0644\u0627\u0633\u062a\u0642\u0628\u0627\u0644 \u0648\u0627\u0644\u062e\u064a\u0627\u0637\u064a\u0646 \u0648\u0627\u0644\u0633\u0627\u0626\u0642\u064a\u0646. \u0627\u0644\u0635\u0644\u0627\u062d\u064a\u0627\u062a \u062d\u0633\u0628 \u0646\u0648\u0639 \u0627\u0644\u0645\u0633\u062a\u062e\u062f\u0645.'),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Form(
                key: form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        s.t('Enter staff portal',
                            '\u0627\u0644\u062f\u062e\u0648\u0644 \u0625\u0644\u0649 \u0628\u0648\u0627\u0628\u0629 \u0627\u0644\u0645\u0648\u0638\u0641\u064a\u0646'),
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 14),
                    TextFormField(
                        controller: user,
                        validator: req,
                        decoration: InputDecoration(
                            labelText: s.t('Username',
                                '\u0627\u0633\u0645 \u0627\u0644\u0645\u0633\u062a\u062e\u062f\u0645'))),
                    const SizedBox(height: 12),
                    TextFormField(
                        controller: pass,
                        validator: req,
                        obscureText: true,
                        decoration: InputDecoration(
                            labelText: s.t('Password',
                                '\u0643\u0644\u0645\u0629 \u0627\u0644\u0645\u0631\u0648\u0631'))),
                    const SizedBox(height: 16),
                    ElevatedButton(
                        onPressed: submit,
                        child: Text(s.t('Enter dashboard',
                            '\u0627\u062f\u062e\u0644 \u0625\u0644\u0649 \u0627\u0644\u0644\u0648\u062d\u0629'))),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? req(String? v) => v == null || v.trim().isEmpty
      ? widget.state.t('Required', '\u0645\u0637\u0644\u0648\u0628')
      : null;

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    if (!await widget.state.login(user.text.trim(), pass.text)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(widget.state.t('Incorrect username or password.',
              '\u0627\u0633\u0645 \u0627\u0644\u0645\u0633\u062a\u062e\u062f\u0645 \u0623\u0648 \u0643\u0644\u0645\u0629 \u0627\u0644\u0645\u0631\u0648\u0631 \u063a\u064a\u0631 \u0635\u062d\u064a\u062d\u0629.'))));
      return;
    }
    Navigator.of(context)
        .pushNamedAndRemoveUntil('/dashboard/staff', (r) => false);
  }
}

class LockedPage extends StatelessWidget {
  const LockedPage({super.key, required this.state, required this.role});
  final AppState state;
  final Role? role;
  @override
  Widget build(BuildContext context) {
    return Shell(
      state: state,
      title: state.t('Access denied.', 'تم رفض الوصول.'),
      subtitle: state.t(
          'This dashboard needs the correct role login and stays hidden from customer pages.',
          'هذه اللوحة تحتاج إلى تسجيل دخول الدور الصحيح وتبقى مخفية عن صفحات العميل.'),
      body: ElevatedButton(
          onPressed: () =>
              Navigator.of(context).pushReplacementNamed('/login/staff'),
          child: Text(state.t('Go to login', 'اذهب إلى الدخول'))),
    );
  }
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key, required this.state, required this.role});
  final AppState state;
  final Role role;

  @override
  Widget build(BuildContext context) {
    if (role == Role.admin) {
      return AdminDashboard(state: state);
    }
    if (role == Role.receptionistSupervisor) {
      return ReceptionistSupervisorDashboard(state: state, role: role);
    }
    if (role == Role.driverSupervisor) {
      return DriverSupervisorDashboard(state: state, role: role);
    }
    if (role == Role.receptionist) {
      return ReceptionistDashboard(state: state, role: role);
    }

    final visibleOrders = state.orders.where(hasConfirmedPayment).toList();
    final active = visibleOrders
        .where((o) => hasConfirmedPayment(o) && !isClosedOrder(o))
        .toList();
    final staffName = state.currentStaffName.toLowerCase();
    final mine = switch (role) {
      Role.driver =>
        active.where((o) => o.driver.toLowerCase() == staffName).toList(),
      Role.tailor =>
        active.where((o) => o.tailor.toLowerCase() == staffName).toList(),
      _ => state.orders,
    };
    return Shell(
      state: state,
      role: role,
      title: state.t(
          '${roleLabel(role, false)} dashboard on its own protected route.',
          'لوحة ${roleLabel(role, true)} على رابطها المحمي الخاص.'),
      subtitle: state.t(
          'This route is separated from the public customer pages and locked by role.',
          'هذا الرابط منفصل عن صفحات العميل العامة ومقفل حسب الدور.'),
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 16, runSpacing: 16, children: [
          metric(
              state.t('All orders', 'كل الطلبات'), '${visibleOrders.length}'),
          metric(
              state.t('Active orders', 'الطلبات النشطة'), '${active.length}'),
          metric(state.t('Open complaints', 'الشكاوى المفتوحة'),
              '${complaints.length}'),
        ]),
        const SizedBox(height: 18),
        if (role == Role.employee)
          OrdersDashboardTable(
            state: state,
            orders: state.orders,
            title: state.t('Customer service orders', 'طلبات خدمة العملاء'),
          ),
        if (role == Role.employee) const SizedBox(height: 18),
        if (role == Role.employee)
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(state.t('Bookings overview', 'نظرة على الحجوزات'),
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 12),
                        for (final o in state.orders.take(6))
                          ListTile(
                              title: Text('${o.id} • ${o.customer}'),
                              subtitle: Text(
                                  '${o.area(state.isArabic)} • ${o.service}'),
                              trailing: badge(
                                  stageLabel(o.stage, state.isArabic),
                                  stageColor(o.stage))),
                      ]))),
        if (role == Role.tailor)
          OrdersDashboardTable(
            state: state,
            orders: mine,
            title: state.t('Assigned tailoring work', 'أعمال الخياطة المسندة'),
          ),
        if (role == Role.tailor) const SizedBox(height: 18),
        if (role == Role.tailor)
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            state.t('Assigned tailoring work',
                                'أعمال الخياطة المسندة'),
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 12),
                        for (final o in mine.take(6))
                          ListTile(
                              title: Text('${o.customer} • ${o.id}'),
                              subtitle: Text(
                                  '${o.service} • ${o.window}\n${o.notes}'),
                              trailing: badge(
                                  stageLabel(o.stage, state.isArabic),
                                  stageColor(o.stage))),
                      ]))),
        if (role == Role.driver)
          OrdersDashboardTable(
            state: state,
            orders: mine,
            title: state.t('My delivery orders', 'طلبات التوصيل الخاصة بي'),
          ),
        if (role == Role.driver) const SizedBox(height: 18),
        if (role == Role.driver)
          DriverOperationsPanel(state: state, orders: mine),
      ]),
    );
  }
}

List<String> customerProgressSteps(Order order, bool ar) {
  final rank = stageRank(order.stage);
  final steps = <String>[
    ar ? 'تم استلام الطلب' : 'Order received',
    ar ? 'جاري العمل عليه' : 'Working on it',
    ar ? 'جاهز' : 'Ready',
    ar ? 'خارج للتوصيل' : 'Out for Delivery',
    ar ? 'تم التسليم' : 'Delivered',
  ];
  final visible = rank <= 0 ? 1 : rank + 1;
  return steps.take(visible.clamp(1, steps.length).toInt()).toList();
}

class OrdersDashboardTable extends StatefulWidget {
  const OrdersDashboardTable({
    super.key,
    required this.state,
    required this.orders,
    this.title,
  });

  final AppState state;
  final List<Order> orders;
  final String? title;

  @override
  State<OrdersDashboardTable> createState() => _OrdersDashboardTableState();
}

class _OrdersDashboardTableState extends State<OrdersDashboardTable> {
  final search = TextEditingController();
  final idFilter = TextEditingController();
  final customerFilter = TextEditingController();
  final mobileFilter = TextEditingController();
  final areaFilter = TextEditingController();
  final serviceFilter = TextEditingController();
  final receptionistFilter = TextEditingController();
  final driverFilter = TextEditingController();
  Stage? selectedStage;
  String selectedBranch = 'All';

  AppState get state => widget.state;

  @override
  void initState() {
    super.initState();
    search.addListener(() => setState(() {}));
    for (final controller in columnFilters) {
      controller.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    search.dispose();
    for (final controller in columnFilters) {
      controller.dispose();
    }
    super.dispose();
  }

  List<TextEditingController> get columnFilters => [
        idFilter,
        customerFilter,
        mobileFilter,
        areaFilter,
        serviceFilter,
        receptionistFilter,
        driverFilter,
      ];

  bool matchesColumn(String value, TextEditingController controller) {
    final query = controller.text.trim().toLowerCase();
    return query.isEmpty || value.toLowerCase().contains(query);
  }

  List<Order> get filteredOrders {
    final query = search.text.trim().toLowerCase();
    final branch = selectedBranch.toLowerCase();
    final orders = widget.orders.where((order) {
      if (!hasConfirmedPayment(order)) return false;
      if (selectedStage != null &&
          stageRank(order.stage) != stageRank(selectedStage!)) {
        return false;
      }
      if (selectedBranch != 'All' && order.branch.toLowerCase() != branch) {
        return false;
      }
      if (!matchesColumn(order.id, idFilter) ||
          !matchesColumn(order.customer, customerFilter) ||
          !matchesColumn(order.mobile, mobileFilter) ||
          !matchesColumn('${order.areaEn} ${order.areaAr}', areaFilter) ||
          !matchesColumn(order.service, serviceFilter) ||
          !matchesColumn(order.receptionist, receptionistFilter) ||
          !matchesColumn(order.driver, driverFilter)) {
        return false;
      }
      if (query.isEmpty) return true;
      return [
        order.id,
        order.customer,
        order.mobile,
        order.areaEn,
        order.areaAr,
        order.service,
        order.branch,
        order.receptionist,
        order.driver,
      ].any((value) => value.toLowerCase().contains(query));
    }).toList();
    orders.sort((a, b) {
      final dateCompare = visitSortDate(a).compareTo(visitSortDate(b));
      if (dateCompare != 0) return dateCompare;
      return stageRank(a.stage).compareTo(stageRank(b.stage));
    });
    return orders;
  }

  Widget columnFilterField(TextEditingController controller, String label,
      {double width = 150}) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          suffixIcon: controller.text.trim().isEmpty
              ? null
              : IconButton(
                  tooltip: state.t('Clear', 'Clear'),
                  icon: const Icon(Icons.close),
                  onPressed: controller.clear,
                ),
        ),
      ),
    );
  }

  List<String> get branchOptions {
    final branches = widget.orders
        .where(hasConfirmedPayment)
        .map((order) => order.branch.trim())
        .where((branch) => branch.isNotEmpty && !isPendingAssignment(branch))
        .toSet()
        .toList()
      ..sort();
    return ['All', ...branches];
  }

  DataCell textCell(
    String value, {
    double width = 150,
    int maxLines = 2,
    Color? color,
    FontWeight? weight,
  }) =>
      DataCell(SizedBox(
        width: width,
        child: Text(
          value,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          softWrap: true,
          style: TextStyle(color: color, fontWeight: weight),
        ),
      ));

  bool get canAssignBranch {
    final role = state.role;
    return role == Role.admin ||
        role == Role.employee ||
        role == Role.receptionistSupervisor;
  }

  bool get canAssignDriver {
    final role = state.role;
    return role == Role.admin || role == Role.driverSupervisor;
  }

  bool get canChangeStatus {
    final role = state.role;
    return role == Role.admin ||
        role == Role.employee ||
        role == Role.receptionistSupervisor ||
        role == Role.driverSupervisor ||
        role == Role.receptionist ||
        role == Role.driver ||
        role == Role.tailor;
  }

  bool get canCancelOrReschedule {
    final role = state.role;
    return role == Role.admin || role == Role.employee;
  }

  List<Stage> get allowedStatusStages {
    final role = state.role;
    if (role == Role.driver || role == Role.driverSupervisor) {
      return [Stage.outForDelivery, Stage.delivered];
    }
    if (role == Role.receptionist || role == Role.receptionistSupervisor) {
      return [Stage.completed, Stage.onShop, Stage.ready];
    }
    if (role == Role.tailor) {
      return [Stage.onShop, Stage.ready];
    }
    return [
      Stage.completed,
      Stage.onShop,
      Stage.ready,
      Stage.outForDelivery,
      Stage.delivered,
      Stage.cancelled,
    ];
  }

  Future<void> assignBranchFromTable(BuildContext context, Order order) async {
    final assignment =
        await showReceptionAssignmentDialog(context, state, order);
    if (assignment == null) return;
    await state.updateOrder(
      order.id,
      branch: assignment.branch,
      receptionist: assignment.receptionist,
      timelineNote:
          'Branch assigned to ${assignment.branch} from orders dashboard',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(state.t('Branch assignment saved.', 'تم حفظ تعيين الفرع.')),
    ));
  }

  Future<void> assignDriverFromTable(BuildContext context, Order order) async {
    final driver = await showStaffSelectionDialog(
      context,
      state,
      title: state.t('Assign driver', 'تعيين السائق'),
      label: state.t('Driver', 'السائق'),
      items: state.staffNamesForRole(Role.driver, availableOnly: true),
      initialValue: order.hasDriver ? order.driver : null,
    );
    if (driver == null) return;
    await state.updateOrder(
      order.id,
      driver: driver,
      timelineNote: 'Driver assigned to $driver from orders dashboard',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:
          Text(state.t('Driver assignment saved.', 'تم حفظ تعيين السائق.')),
    ));
  }

  Future<void> setStatusFromTable(
      BuildContext context, Order order, Stage stage) async {
    final readyBy =
        stage == Stage.ready ? await showReadyByDialog(context, state) : null;
    if (stage == Stage.ready && readyBy == null) return;
    await state.updateOrder(
      order.id,
      stage: stage,
      timelineNote: stage == Stage.ready
          ? 'Order marked ready by $readyBy'
          : 'Status updated to ${stageLabel(stage, false)} from orders dashboard',
    );
  }

  Future<void> cancelOrderFromTable(BuildContext context, Order order) async {
    final reason = await showTextEntryDialog(
      context,
      title: state.t('Cancel order', 'إلغاء الطلب'),
      label: state.t('Reason', 'السبب'),
    );
    if (reason == null) return;
    await state.updateOrder(
      order.id,
      stage: Stage.cancelled,
      timelineNote: reason.trim().isEmpty
          ? 'Order cancelled from dashboard'
          : 'Order cancelled: ${reason.trim()}',
    );
  }

  Future<void> rescheduleOrderFromTable(
      BuildContext context, Order order) async {
    final nextWindow = await showRescheduleDialog(context, state, order);
    if (nextWindow == null) return;
    await state.updateOrder(
      order.id,
      window: nextWindow,
      timelineNote: 'Visit rescheduled to $nextWindow',
    );
  }

  Widget statusMenu(Order order) {
    final statusStages = allowedStatusStages;
    return PopupMenuButton<Stage>(
      tooltip: state.t('Change status', 'تغيير الحالة'),
      onSelected: (stage) => setStatusFromTable(context, order, stage),
      itemBuilder: (context) => [
        for (final stage in statusStages)
          PopupMenuItem(
            value: stage,
            child: Text(stageLabel(stage, state.isArabic)),
          ),
      ],
      child: Container(
        width: 112,
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          border: Border.all(color: maroon.withOpacity(.7)),
          borderRadius: BorderRadius.circular(999),
        ),
        alignment: Alignment.center,
        child: Text(
          state.t('Status', 'الحالة'),
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: maroon,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget rowActions(BuildContext context, Order order, {double width = 430}) {
    return SizedBox(
      width: width,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          compactTableButton(
            label: state.t('Branch', 'الفرع'),
            onPressed: isClosedOrder(order) || !canAssignBranch
                ? null
                : () => assignBranchFromTable(context, order),
          ),
          compactTableButton(
            label: state.t('Driver', 'السائق'),
            onPressed: isClosedOrder(order) || !canAssignDriver
                ? null
                : () => assignDriverFromTable(context, order),
          ),
          if (canChangeStatus && !isClosedOrder(order)) statusMenu(order),
          if (canCancelOrReschedule && !isClosedOrder(order))
            compactTableButton(
              label: state.t('Reschedule', 'إعادة الموعد'),
              onPressed: () => rescheduleOrderFromTable(context, order),
            ),
          if (canCancelOrReschedule && !isClosedOrder(order))
            compactTableButton(
              label: state.t('Cancel', 'إلغاء'),
              onPressed: () => cancelOrderFromTable(context, order),
            ),
          if (allowedStatusStages.contains(Stage.delivered))
            compactTableButton(
              label: state.t('Delivered', 'تم التسليم'),
              onPressed: isClosedOrder(order) || !canChangeStatus
                  ? null
                  : () => setStatusFromTable(context, order, Stage.delivered),
            ),
          compactTableButton(
            label: state.t('Bill', 'فاتورة'),
            onPressed: () => openInvoicePrint(order, state),
          ),
        ],
      ),
    );
  }

  Widget desktopActionMenu(BuildContext context, Order order) {
    return PopupMenuButton<String>(
      tooltip: state.t('Actions', 'الإجراءات'),
      onSelected: (value) {
        if (value == 'branch') assignBranchFromTable(context, order);
        if (value == 'driver') assignDriverFromTable(context, order);
        if (value == 'reschedule') rescheduleOrderFromTable(context, order);
        if (value == 'cancel') cancelOrderFromTable(context, order);
        if (value == 'bill') openInvoicePrint(order, state);
        if (value.startsWith('stage:')) {
          final stage = stageFromKey(value.substring('stage:'.length));
          setStatusFromTable(context, order, stage);
        }
      },
      itemBuilder: (context) => [
        if (canAssignBranch && !isClosedOrder(order))
          PopupMenuItem(
            value: 'branch',
            child: Text(state.t('Assign branch', 'تعيين الفرع')),
          ),
        if (canAssignDriver && !isClosedOrder(order))
          PopupMenuItem(
            value: 'driver',
            child: Text(state.t('Assign driver', 'تعيين السائق')),
          ),
        if (canChangeStatus && !isClosedOrder(order))
          for (final stage in allowedStatusStages)
            PopupMenuItem(
              value: 'stage:${stage.name}',
              child: Text(stageLabel(stage, state.isArabic)),
            ),
        if (canCancelOrReschedule && !isClosedOrder(order))
          PopupMenuItem(
            value: 'reschedule',
            child: Text(state.t('Reschedule order', 'إعادة جدولة الطلب')),
          ),
        if (canCancelOrReschedule && !isClosedOrder(order))
          PopupMenuItem(
            value: 'cancel',
            child: Text(state.t('Cancel order', 'إلغاء الطلب')),
          ),
        PopupMenuItem(
          value: 'bill',
          child: Text(state.t('Print bill', 'طباعة الفاتورة')),
        ),
      ],
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          border: Border.all(color: maroon.withOpacity(.75), width: 1.4),
          borderRadius: BorderRadius.circular(999),
        ),
        alignment: Alignment.center,
        child: Text(
          state.t('Actions', 'الإجراءات'),
          style: const TextStyle(color: maroon, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  Widget detailLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: ink, fontSize: 15, height: 1.35),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  Widget mobileOrderCard(BuildContext context, Order order,
      {bool highlighted = false}) {
    return Card(
      color: highlighted ? blush : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(order.id,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: highlighted ? maroon : ink)),
              badge(stageLabel(order.stage, state.isArabic),
                  stageColor(order.stage)),
              badge(
                  order.paymentStatus.toLowerCase() == 'paid'
                      ? state.t('Paid', 'مدفوع')
                      : state.t('Pending', 'معلق'),
                  order.paymentStatus.toLowerCase() == 'paid'
                      ? const Color(0xFF2D8A57)
                      : gold),
            ],
          ),
          const SizedBox(height: 12),
          detailLine(state.t('Visit', 'الزيارة'), order.window),
          detailLine(state.t('Customer', 'العميل'), order.customer),
          detailLine(state.t('Mobile', 'الهاتف'), order.mobile),
          detailLine(state.t('Area', 'المنطقة'), order.area(state.isArabic)),
          detailLine(state.t('Branch', 'الفرع'), order.branch),
          detailLine(state.t('Receptionist', 'الاستقبال'), order.receptionist),
          detailLine(state.t('Driver', 'السائق'), order.driver),
          detailLine(state.t('Service', 'الخدمة'), order.service),
          const SizedBox(height: 10),
          rowActions(context, order, width: double.infinity),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shown = filteredOrders;
    final compact = MediaQuery.of(context).size.width < 760;
    final visibleOrders = widget.orders.where(hasConfirmedPayment).toList();
    final activeShown = shown.where((order) => !isClosedOrder(order)).toList();
    final nearestActiveId = activeShown.isEmpty ? null : activeShown.first.id;
    final stageFilters = [
      null,
      Stage.newBooking,
      Stage.completed,
      Stage.onShop,
      Stage.ready,
      Stage.outForDelivery,
      Stage.delivered,
      Stage.cancelled,
    ];
    return adminCard(
      context,
      title: widget.title ?? state.t('Orders', 'الطلبات'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final stage in stageFilters)
              ChoiceChip(
                label: Text(stage == null
                    ? '${state.t('All', 'الكل')} ${visibleOrders.length}'
                    : '${stageLabel(stage, state.isArabic)} ${visibleOrders.where((o) => stageRank(o.stage) == stageRank(stage)).length}'),
                selected: selectedStage == stage,
                onSelected: (_) => setState(() => selectedStage = stage),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 12, runSpacing: 12, children: [
          SizedBox(
            width: 220,
            child: DropdownButtonFormField<String>(
              value: branchOptions.contains(selectedBranch)
                  ? selectedBranch
                  : 'All',
              decoration:
                  InputDecoration(labelText: state.t('Branch', 'الفرع')),
              items: [
                for (final branch in branchOptions)
                  DropdownMenuItem(value: branch, child: Text(branch)),
              ],
              onChanged: (value) =>
                  setState(() => selectedBranch = value ?? 'All'),
            ),
          ),
          SizedBox(
            width: 260,
            child: TextField(
              controller: search,
              decoration: InputDecoration(
                  labelText: state.t('Search', 'بحث'),
                  suffixIcon: const Icon(Icons.search)),
            ),
          ),
          OutlinedButton.icon(
            onPressed: () {
              setState(() {
                selectedStage = null;
                selectedBranch = 'All';
                search.clear();
                for (final controller in columnFilters) {
                  controller.clear();
                }
              });
            },
            icon: const Icon(Icons.refresh),
            label: Text(state.t('Reset', 'إعادة ضبط')),
          ),
        ]),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            columnFilterField(idFilter, 'ID', width: 110),
            const SizedBox(width: 10),
            columnFilterField(customerFilter, state.t('Customer', 'العميل'),
                width: 170),
            const SizedBox(width: 10),
            columnFilterField(mobileFilter, state.t('Mobile', 'الهاتف'),
                width: 140),
            const SizedBox(width: 10),
            columnFilterField(areaFilter, state.t('Area', 'المنطقة'),
                width: 170),
            const SizedBox(width: 10),
            columnFilterField(serviceFilter, state.t('Service', 'الخدمة'),
                width: 150),
            const SizedBox(width: 10),
            columnFilterField(
                receptionistFilter, state.t('Receptionist', 'الاستقبال'),
                width: 170),
            const SizedBox(width: 10),
            columnFilterField(driverFilter, state.t('Driver', 'السائق'),
                width: 150),
          ]),
        ),
        const SizedBox(height: 14),
        Text(
          state.t('Sorted by nearest home-service visit date first.',
              'مرتبة حسب أقرب موعد زيارة منزلية أولاً.'),
          style: const TextStyle(color: Color(0xFF756A5C)),
        ),
        const SizedBox(height: 14),
        if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: Text(
              visibleOrders.isEmpty
                  ? state.t(
                      'No confirmed orders yet. Failed or cancelled payment attempts are hidden.',
                      'لا توجد طلبات مؤكدة حتى الآن. يتم إخفاء محاولات الدفع الفاشلة أو الملغاة.')
                  : state.t('No orders match the selected filters.',
                      'لا توجد طلبات تطابق الفلاتر المحددة.'),
              style: const TextStyle(color: Color(0xFF756A5C)),
            ),
          )
        else if (compact)
          Column(
            children: [
              for (final order in shown.take(80)) ...[
                mobileOrderCard(context, order,
                    highlighted: order.id == nearestActiveId),
                const SizedBox(height: 12),
              ],
            ],
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              dataRowMinHeight: 92,
              dataRowMaxHeight: 118,
              headingRowHeight: 58,
              columnSpacing: 28,
              columns: [
                dataLabel('ID'),
                dataLabel(state.t('Actions', 'الإجراءات')),
                dataLabel(state.t('Visit Date & Time', 'موعد الزيارة')),
                dataLabel(state.t('Customer', 'العميل')),
                dataLabel(state.t('Mobile', 'الهاتف')),
                dataLabel(state.t('Area', 'المنطقة')),
                dataLabel(state.t('Branch', 'الفرع')),
                dataLabel(state.t('Services', 'الخدمات')),
                dataLabel(state.t('Receptionist', 'الاستقبال')),
                dataLabel(state.t('Driver', 'السائق')),
                dataLabel(state.t('Status', 'الحالة')),
                dataLabel(state.t('Payment', 'الدفع')),
              ],
              rows: [
                for (final order in shown.take(120))
                  DataRow(
                      color: WidgetStateProperty.resolveWith((states) =>
                          order.id == nearestActiveId ? blush : null),
                      cells: [
                        textCell(order.id,
                            width: 96,
                            maxLines: 1,
                            color: order.id == nearestActiveId ? maroon : null,
                            weight: order.id == nearestActiveId
                                ? FontWeight.w800
                                : null),
                        DataCell(desktopActionMenu(context, order)),
                        textCell(order.window,
                            width: 220,
                            color: order.id == nearestActiveId ? maroon : null,
                            weight: order.id == nearestActiveId
                                ? FontWeight.w800
                                : null),
                        textCell(order.customer, width: 170),
                        textCell(order.mobile, width: 120, maxLines: 1),
                        textCell(order.area(state.isArabic), width: 190),
                        textCell(order.branch, width: 210),
                        textCell(order.service, width: 160),
                        textCell(order.receptionist, width: 190),
                        textCell(order.driver, width: 150),
                        DataCell(badge(stageLabel(order.stage, state.isArabic),
                            stageColor(order.stage))),
                        DataCell(badge(
                            order.paymentStatus.toLowerCase() == 'paid'
                                ? state.t('Paid', 'مدفوع')
                                : state.t('Pending', 'معلق'),
                            order.paymentStatus.toLowerCase() == 'paid'
                                ? const Color(0xFF2D8A57)
                                : gold)),
                      ]),
              ],
            ),
          ),
        if (shown.length > 120) ...[
          const SizedBox(height: 10),
          Text(state.t('Showing first 120 matching orders.',
              'يتم عرض أول 120 طلب مطابق.')),
        ],
      ]),
    );
  }
}

DateTime visitSortDate(Order order) {
  final text = order.window;
  final dateMatch = RegExp(r'(\d{1,2})-(\d{1,2})-(\d{4})').firstMatch(text);
  final timeMatch =
      RegExp(r'(\d{1,2})(?::(\d{2}))?\s*(AM|PM)', caseSensitive: false)
          .firstMatch(text);
  final now = DateTime.now();
  var day = now.day;
  var month = now.month;
  var year = now.year;
  if (dateMatch != null) {
    day = int.tryParse(dateMatch.group(1)!) ?? day;
    month = int.tryParse(dateMatch.group(2)!) ?? month;
    year = int.tryParse(dateMatch.group(3)!) ?? year;
  }
  var hour = 23;
  var minute = 59;
  if (timeMatch != null) {
    hour = int.tryParse(timeMatch.group(1)!) ?? hour;
    minute = int.tryParse(timeMatch.group(2) ?? '0') ?? 0;
    final marker = timeMatch.group(3)!.toUpperCase();
    if (marker == 'PM' && hour < 12) hour += 12;
    if (marker == 'AM' && hour == 12) hour = 0;
  }
  return DateTime(year, month, day, hour, minute);
}

class BranchAssignmentCard extends StatelessWidget {
  const BranchAssignmentCard({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final pendingBranch = state.orders
        .where(
            (o) => hasConfirmedPayment(o) && !isClosedOrder(o) && !o.hasBranch)
        .toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
              state.t(
                  'Pending home-service orders', 'Pending home-service orders'),
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          if (pendingBranch.isEmpty)
            Text(state.t('No orders waiting for branch assignment.',
                'No orders waiting for branch assignment.')),
          for (final order in pendingBranch)
            workflowOrderCard(context, state, order, actions: [
              ElevatedButton.icon(
                onPressed: () => _assignBranch(context, order),
                icon: const Icon(Icons.storefront),
                label: Text(state.t('Assign branch', 'Assign branch')),
              ),
            ]),
        ]),
      ),
    );
  }

  Future<void> _assignBranch(BuildContext context, Order order) async {
    final assignment =
        await showReceptionAssignmentDialog(context, state, order);
    if (assignment == null) return;
    await state.updateOrder(
      order.id,
      branch: assignment.branch,
      receptionist: assignment.receptionist,
      timelineNote: 'Branch assigned to ${assignment.branch}',
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(state.t(
              'Branch assignment saved.', 'Branch assignment saved.'))));
    }
  }
}

class DriverAssignmentCard extends StatelessWidget {
  const DriverAssignmentCard({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final driverQueue = state.orders
        .where((o) => hasConfirmedPayment(o) && isReadyForDriverAssignment(o))
        .toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(state.t('Driver assignment queue', 'Driver assignment queue'),
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          if (driverQueue.isEmpty)
            Text(state.t('No ready orders waiting for a driver.',
                'No ready orders waiting for a driver.')),
          for (final order in driverQueue)
            workflowOrderCard(context, state, order, actions: [
              ElevatedButton.icon(
                onPressed: () => _assignDriver(context, order),
                icon: const Icon(Icons.local_shipping),
                label: Text(state.t('Assign driver', 'Assign driver')),
              ),
            ]),
        ]),
      ),
    );
  }

  Future<void> _assignDriver(BuildContext context, Order order) async {
    final driver = await showStaffSelectionDialog(
      context,
      state,
      title: state.t('Assign driver', 'Assign driver'),
      label: state.t('Driver', 'Driver'),
      items: state.staffNamesForRole(Role.driver, availableOnly: true),
      initialValue: order.hasDriver ? order.driver : null,
    );
    if (driver == null) return;
    await state.updateOrder(
      order.id,
      driver: driver,
      timelineNote: 'Driver assigned to $driver',
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(state.t(
              'Driver assignment saved.', 'Driver assignment saved.'))));
    }
  }
}

class OperationsTrackingPanel extends StatelessWidget {
  const OperationsTrackingPanel({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final active = state.orders
        .where((o) => hasConfirmedPayment(o) && !isClosedOrder(o))
        .toList();
    final history = state.orders
        .where((o) => hasConfirmedPayment(o) && isClosedOrder(o))
        .toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(state.t('Active order tracking', 'Active order tracking'),
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            if (active.isEmpty)
              Text(state.t('No active orders.', 'No active orders.')),
            for (final order in active.take(10))
              workflowOrderCard(context, state, order),
          ]),
        ),
      ),
      const SizedBox(height: 18),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(state.t('History', 'History'),
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            if (history.isEmpty)
              Text(state.t('No closed orders yet.', 'No closed orders yet.')),
            for (final order in history.take(10))
              workflowOrderCard(context, state, order),
          ]),
        ),
      ),
    ]);
  }
}

class DriverOperationsPanel extends StatelessWidget {
  const DriverOperationsPanel(
      {super.key, required this.state, required this.orders});
  final AppState state;
  final List<Order> orders;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(state.t('Driver route', 'مسار السائق'),
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          if (orders.isEmpty)
            Text(state.t(
                'No active driver orders.', 'لا توجد طلبات نشطة للسائق.')),
          for (final order in orders.take(8))
            workflowOrderCard(context, state, order, actions: [
              OutlinedButton.icon(
                onPressed: () => _copyTracking(context, order),
                icon: const Icon(Icons.copy),
                label: Text(state.t('Copy tracking', 'نسخ التتبع')),
              ),
              OutlinedButton.icon(
                onPressed: () => launchUrl(
                  Uri.parse(
                      'https://www.google.com/maps/search/?api=1&query=${order.lat},${order.lng}'),
                  webOnlyWindowName: '_blank',
                ),
                icon: const Icon(Icons.map_outlined),
                label: const Text('Google Maps'),
              ),
              if (order.stage != Stage.outForDelivery && !isClosedOrder(order))
                ElevatedButton.icon(
                  onPressed: () => _setStage(
                      context,
                      order,
                      Stage.outForDelivery,
                      'Driver marked order out for delivery'),
                  icon: const Icon(Icons.route),
                  label: Text(state.t('Out for Delivery', 'خارج للتوصيل')),
                ),
              if (!isClosedOrder(order))
                ElevatedButton.icon(
                  onPressed: () => _setStage(context, order, Stage.delivered,
                      'Driver marked order delivered'),
                  icon: const Icon(Icons.done_all),
                  label: Text(state.t('Delivered', 'تم التسليم')),
                ),
            ]),
        ]),
      ),
    );
  }

  Future<void> _copyTracking(BuildContext context, Order order) async {
    await Clipboard.setData(ClipboardData(text: buildTrackingLink(order.id)));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text(state.t('Tracking link copied.', 'تم نسخ رابط التتبع.'))));
    }
  }

  Future<void> _setStage(BuildContext context, Order order, Stage stage,
      String timelineNote) async {
    await state.updateOrder(order.id, stage: stage, timelineNote: timelineNote);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text(state.t('Order status updated.', 'تم تحديث حالة الطلب.'))));
    }
  }
}

class ReceptionAssignment {
  const ReceptionAssignment(this.branch, this.receptionist);
  final String branch;
  final String receptionist;
}

class ReceptionistSupervisorDashboard extends StatelessWidget {
  const ReceptionistSupervisorDashboard(
      {super.key, required this.state, required this.role});
  final AppState state;
  final Role role;

  @override
  Widget build(BuildContext context) {
    final pendingBranch = state.orders
        .where(
            (o) => hasConfirmedPayment(o) && !isClosedOrder(o) && !o.hasBranch)
        .toList();
    final active = state.orders
        .where((o) => hasConfirmedPayment(o) && !isClosedOrder(o))
        .toList();
    return Shell(
      state: state,
      role: role,
      title: state.t('Reception supervisor receives new booking notifications.',
          'مشرف الاستقبال يستقبل تنبيهات الحجوزات الجديدة.'),
      subtitle: state.t(
          'Assign the branch first, then optionally select the receptionist for the order.',
          'عيّن الفرع أولاً، ثم اختر موظف الاستقبال للطلب إذا كان معروفاً.'),
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 16, runSpacing: 16, children: [
          metric(state.t('New notifications', 'تنبيهات جديدة'),
              '${pendingBranch.length}'),
          metric(
              state.t('Active orders', 'الطلبات النشطة'), '${active.length}'),
          metric(state.t('Branches', 'الفروع'), '${adminBranches.length}'),
        ]),
        const SizedBox(height: 18),
        OrdersDashboardTable(
          state: state,
          orders: state.orders,
          title: state.t('Supervisor order list', 'قائمة طلبات المشرف'),
        ),
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(state.t('Branch assignment queue', 'قائمة تعيين الفروع'),
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              if (pendingBranch.isEmpty)
                Text(state.t('No new bookings waiting for branch assignment.',
                    'لا توجد حجوزات جديدة بانتظار تعيين الفرع.')),
              for (final order in pendingBranch)
                workflowOrderCard(context, state, order, actions: [
                  ElevatedButton.icon(
                    onPressed: () => _assignBranch(context, order),
                    icon: const Icon(Icons.storefront),
                    label: Text(state.t('Assign branch', 'تعيين الفرع')),
                  ),
                ]),
            ]),
          ),
        ),
        const SizedBox(height: 18),
        OperationsTrackingPanel(state: state),
        const SizedBox(height: 18),
        StaffUsersPanel(state: state),
        const SizedBox(height: 18),
        BranchReceptionistsPanel(state: state),
      ]),
    );
  }

  Future<void> _assignBranch(BuildContext context, Order order) async {
    final assignment =
        await showReceptionAssignmentDialog(context, state, order);
    if (assignment == null) return;
    await state.updateOrder(
      order.id,
      branch: assignment.branch,
      receptionist: assignment.receptionist,
      timelineNote: 'Branch assigned to ${assignment.branch}',
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              state.t('Branch assignment saved.', 'تم حفظ تعيين الفرع.'))));
    }
  }
}

class DriverSupervisorDashboard extends StatelessWidget {
  const DriverSupervisorDashboard(
      {super.key, required this.state, required this.role});
  final AppState state;
  final Role role;

  @override
  Widget build(BuildContext context) {
    final driverQueue = state.orders
        .where((o) => hasConfirmedPayment(o) && isReadyForDriverAssignment(o))
        .toList();
    final assigned = state.orders
        .where(
            (o) => hasConfirmedPayment(o) && !isClosedOrder(o) && o.hasDriver)
        .toList();
    return Shell(
      state: state,
      role: role,
      title: state.t('Driver supervisor is notified after branch assignment.',
          'مشرف السائقين يستقبل التنبيه بعد تعيين الفرع.'),
      subtitle: state.t(
          'Assign drivers only after an order is Ready, then it moves to Out for Delivery.',
          'عيّن السائق بعد أن يصبح الطلب جاهزاً، ثم ينتقل إلى خارج للتوصيل.'),
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 16, runSpacing: 16, children: [
          metric(state.t('Ready for driver', 'جاهز لتعيين السائق'),
              '${driverQueue.length}'),
          metric(state.t('Assigned drivers', 'السائقون المعينون'),
              '${assigned.length}'),
          metric(state.t('Active orders', 'الطلبات النشطة'),
              '${state.orders.where((o) => hasConfirmedPayment(o) && !isClosedOrder(o)).length}'),
        ]),
        const SizedBox(height: 18),
        OrdersDashboardTable(
          state: state,
          orders: state.orders,
          title: state.t('Supervisor order list', 'قائمة طلبات المشرف'),
        ),
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(state.t('Driver assignment queue', 'قائمة تعيين السائقين'),
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              if (driverQueue.isEmpty)
                Text(state.t('No ready orders waiting for a driver.',
                    'لا توجد طلبات جاهزة بانتظار السائق.')),
              for (final order in driverQueue)
                workflowOrderCard(context, state, order, actions: [
                  ElevatedButton.icon(
                    onPressed: () => _assignDriver(context, order),
                    icon: const Icon(Icons.local_shipping),
                    label: Text(state.t('Assign driver', 'تعيين السائق')),
                  ),
                ]),
            ]),
          ),
        ),
        const SizedBox(height: 18),
        OperationsTrackingPanel(state: state),
        const SizedBox(height: 18),
        StaffUsersPanel(state: state),
      ]),
    );
  }

  Future<void> _assignDriver(BuildContext context, Order order) async {
    final driver = await showStaffSelectionDialog(
      context,
      state,
      title: state.t('Assign driver', 'تعيين السائق'),
      label: state.t('Driver', 'السائق'),
      items: state.staffNamesForRole(Role.driver, availableOnly: true),
      initialValue: order.hasDriver ? order.driver : null,
    );
    if (driver == null) return;
    await state.updateOrder(
      order.id,
      driver: driver,
      timelineNote: 'Driver assigned to $driver',
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              state.t('Driver assignment saved.', 'تم حفظ تعيين السائق.'))));
    }
  }
}

class ReceptionistDashboard extends StatelessWidget {
  const ReceptionistDashboard(
      {super.key, required this.state, required this.role});
  final AppState state;
  final Role role;

  @override
  Widget build(BuildContext context) {
    final staffName = state.currentStaffName.toLowerCase();
    final staffBranch = state.currentStaff?.branch.trim().toLowerCase() ?? '';
    final branchOrders = state.orders.where((o) {
      if (isClosedOrder(o) || !o.hasBranch) return false;
      if (staffBranch.isNotEmpty &&
          o.branch.trim().toLowerCase() == staffBranch) {
        return true;
      }
      return o.receptionist.toLowerCase() == staffName;
    }).toList();
    final ready = branchOrders.where((o) => o.stage == Stage.ready).length;
    return Shell(
      state: state,
      role: role,
      title: state.t('Receptionist can prepare assigned branch orders.',
          'موظف الاستقبال يجهز الطلبات المعينة للفرع.'),
      subtitle: state.t(
          'Mark orders as Ready when the branch work is complete.',
          'حوّل الطلب إلى جاهز عند اكتمال العمل في الفرع.'),
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 16, runSpacing: 16, children: [
          metric(state.t('Branch orders', 'طلبات الفرع'),
              '${branchOrders.length}'),
          metric(state.t('Ready', 'جاهز'), '$ready'),
          metric(state.t('Need action', 'تحتاج إجراء'),
              '${branchOrders.length - ready}'),
        ]),
        const SizedBox(height: 18),
        OrdersDashboardTable(
          state: state,
          orders: branchOrders,
          title: state.t('My branch orders', 'طلبات الفرع الخاصة بي'),
        ),
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(state.t('Reception work queue', 'قائمة عمل الاستقبال'),
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              if (branchOrders.isEmpty)
                Text(state.t('No assigned branch orders yet.',
                    'لا توجد طلبات معينة لفرع حتى الآن.')),
              for (final order in branchOrders)
                workflowOrderCard(context, state, order, actions: [
                  if (stageRank(order.stage) < stageRank(Stage.completed))
                    OutlinedButton.icon(
                      onPressed: () => _setStage(context, order,
                          Stage.completed, 'Reception marked order completed'),
                      icon: const Icon(Icons.check),
                      label: Text(state.t('Completed', 'مكتمل')),
                    ),
                  if (stageRank(order.stage) < stageRank(Stage.onShop))
                    OutlinedButton.icon(
                      onPressed: () => _setStage(context, order, Stage.onShop,
                          'Reception moved order on shop'),
                      icon: const Icon(Icons.store),
                      label: Text(state.t('On Shop', 'في المحل')),
                    ),
                  if (order.stage != Stage.ready &&
                      order.stage != Stage.outForDelivery)
                    ElevatedButton.icon(
                      onPressed: () => _setStage(context, order, Stage.ready,
                          'Reception marked order ready'),
                      icon: const Icon(Icons.check_circle_outline),
                      label: Text(state.t('Mark ready', 'تحديد جاهز')),
                    ),
                ]),
            ]),
          ),
        ),
      ]),
    );
  }

  Future<void> _setStage(BuildContext context, Order order, Stage stage,
      String timelineNote) async {
    final readyBy =
        stage == Stage.ready ? await showReadyByDialog(context, state) : null;
    if (stage == Stage.ready && readyBy == null) return;
    await state.updateOrder(
      order.id,
      stage: stage,
      timelineNote: stage == Stage.ready
          ? 'Order marked ready by $readyBy'
          : timelineNote,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text(state.t('Order status updated.', 'تم تحديث حالة الطلب.'))));
    }
  }
}

Widget workflowOrderCard(BuildContext context, AppState state, Order order,
    {List<Widget> actions = const []}) {
  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE4D7BC)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(
        spacing: 10,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('${order.customer} • ${order.id}',
              style:
                  const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          badge(
              stageLabel(order.stage, state.isArabic), stageColor(order.stage)),
        ],
      ),
      const SizedBox(height: 8),
      Text('${order.area(state.isArabic)} • ${order.window}'),
      const SizedBox(height: 6),
      Text(order.address),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: [
        Chip(
            label: Text(
                '${state.t('Invoice', 'الفاتورة')}: ${order.invoiceNo.isEmpty ? order.id : order.invoiceNo}')),
        Chip(
            label: Text(
                '${state.t('Delivery price', 'سعر التوصيل')}: ${formatKwd(order.totalAmount)}')),
        Chip(
            label:
                Text('${state.t('Payment', 'الدفع')}: ${order.paymentStatus}')),
        Chip(label: Text('${state.t('Branch', 'الفرع')}: ${order.branch}')),
        Chip(
            label: Text(
                '${state.t('Receptionist', 'الاستقبال')}: ${order.receptionist}')),
        Chip(label: Text('${state.t('Driver', 'السائق')}: ${order.driver}')),
      ]),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        onPressed: () => openInvoicePrint(order, state),
        icon: const Icon(Icons.picture_as_pdf),
        label: Text(state.t('Print customer bill', 'طباعة فاتورة العميل')),
      ),
      if (actions.isNotEmpty) ...[
        const SizedBox(height: 10),
        Wrap(spacing: 10, runSpacing: 10, children: actions),
      ],
    ]),
  );
}

Future<ReceptionAssignment?> showReceptionAssignmentDialog(
    BuildContext context, AppState state, Order order) {
  var branch = order.hasBranch ? order.branch : adminBranches.first.name;
  const pending = 'Pending assignment';
  var receptionist = order.hasReceptionist ? order.receptionist : pending;
  return showDialog<ReceptionAssignment>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) {
        final receptionistItems = [
          pending,
          ...state.staffNamesForRole(Role.receptionist,
              branch: branch, availableOnly: true)
        ];
        if (!receptionistItems.contains(receptionist)) {
          receptionist = pending;
        }
        return AlertDialog(
          title: Text(state.t(
              'Assign branch and receptionist', 'تعيين الفرع وموظف الاستقبال')),
          content: SizedBox(
            width: 420,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(
                value: branch,
                decoration:
                    InputDecoration(labelText: state.t('Branch', 'الفرع')),
                items: [
                  for (final item in adminBranches)
                    DropdownMenuItem(value: item.name, child: Text(item.name)),
                ],
                onChanged: (value) => setDialogState(() {
                  branch = value ?? branch;
                  receptionist = pending;
                }),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: receptionist,
                decoration: InputDecoration(
                    labelText: state.t(
                        'Receptionist optional', 'موظف الاستقبال اختياري')),
                items: [
                  for (final item in receptionistItems)
                    DropdownMenuItem(value: item, child: Text(item)),
                ],
                onChanged: (value) =>
                    setDialogState(() => receptionist = value ?? receptionist),
              ),
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(state.t('Cancel', 'إلغاء')),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext)
                  .pop(ReceptionAssignment(branch, receptionist)),
              child: Text(state.t('Save', 'حفظ')),
            ),
          ],
        );
      },
    ),
  );
}

Future<String?> showStaffSelectionDialog(
  BuildContext context,
  AppState state, {
  required String title,
  required String label,
  required List<String> items,
  String? initialValue,
}) {
  final available = items.isEmpty ? <String>['Pending assignment'] : items;
  var selected =
      available.contains(initialValue) ? initialValue! : available.first;
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(title),
        content: DropdownButtonFormField<String>(
          value: selected,
          decoration: InputDecoration(labelText: label),
          items: [
            for (final item in available)
              DropdownMenuItem(value: item, child: Text(item)),
          ],
          onChanged: (value) =>
              setDialogState(() => selected = value ?? selected),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(state.t('Cancel', 'إلغاء')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(selected),
            child: Text(state.t('Save', 'حفظ')),
          ),
        ],
      ),
    ),
  );
}

Future<String?> showReadyByDialog(BuildContext context, AppState state) async {
  final controller = TextEditingController(text: state.currentStaffName);
  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(state.t('Who marked it ready?', 'من جهز الطلب؟')),
      content: SizedBox(
        width: 380,
        child: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: state.t('Receptionist / branch staff name',
                'اسم موظفة الاستقبال / موظف الفرع'),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(state.t('Cancel', 'إلغاء')),
        ),
        ElevatedButton(
          onPressed: () {
            final name = controller.text.trim();
            if (name.isEmpty) return;
            Navigator.of(dialogContext).pop(name);
          },
          child: Text(state.t('Save ready', 'حفظ جاهز')),
        ),
      ],
    ),
  );
  controller.dispose();
  return result;
}

Future<String?> showTextEntryDialog(
  BuildContext context, {
  required String title,
  required String label,
}) async {
  final controller = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 420,
        child: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(labelText: label),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Back'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(dialogContext).pop(controller.text),
          child: const Text('Save'),
        ),
      ],
    ),
  );
  controller.dispose();
  return result;
}

Future<String?> showRescheduleDialog(
  BuildContext context,
  AppState state,
  Order order,
) async {
  var selectedDate = state.nextAvailableVisitDate(
    parseDateKey(order.window) ?? DateTime.now(),
  );
  var slots = state.availableSlotsForDate(selectedDate);
  var selectedSlot = slots.contains(order.window)
      ? order.window
      : (slots.isEmpty ? '' : slots.first);

  return showDialog<String>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(state.t('Reschedule order', 'إعادة جدولة الطلب')),
        content: SizedBox(
          width: 420,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(state.t('Visit day', 'يوم الزيارة')),
              subtitle: Text(formatVisitDate(selectedDate)),
              trailing: const Icon(Icons.calendar_month),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: selectedDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 45)),
                  selectableDayPredicate: state.isVisitDateAvailable,
                );
                if (picked == null) return;
                setDialogState(() {
                  selectedDate = picked;
                  slots = state.availableSlotsForDate(selectedDate);
                  selectedSlot = slots.isEmpty ? '' : slots.first;
                });
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: slots.contains(selectedSlot) ? selectedSlot : null,
              decoration: InputDecoration(
                  labelText: state.t('Visit time', 'وقت الزيارة')),
              items: [
                for (final slot in slots)
                  DropdownMenuItem(value: slot, child: Text(slot)),
              ],
              onChanged: (value) =>
                  setDialogState(() => selectedSlot = value ?? selectedSlot),
            ),
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(state.t('Cancel', 'إلغاء')),
          ),
          ElevatedButton(
            onPressed: selectedSlot.isEmpty
                ? null
                : () => Navigator.of(dialogContext)
                    .pop('${formatVisitDate(selectedDate)}, $selectedSlot'),
            child: Text(state.t('Save', 'حفظ')),
          ),
        ],
      ),
    ),
  );
}

Future<void> showBranchReceptionistsDialog(
  BuildContext context,
  AppState state,
  BranchRecord branch,
) async {
  final selected = state
      .staffForRole(Role.receptionist)
      .where((user) =>
          user.branch.trim().toLowerCase() == branch.name.toLowerCase())
      .map((user) => user.username)
      .toSet();
  final saved = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(
            '${state.t('Branch receptionists', 'موظفو استقبال الفرع')} - ${branch.name}'),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              for (final user in state.staffForRole(Role.receptionist))
                CheckboxListTile(
                  value: selected.contains(user.username),
                  onChanged: (value) {
                    setDialogState(() {
                      if (value ?? false) {
                        selected.add(user.username);
                      } else {
                        selected.remove(user.username);
                      }
                    });
                  },
                  title: Text(user.displayName),
                  subtitle: Text(user.branch.trim().isEmpty
                      ? state.t('No branch', 'بدون فرع')
                      : user.branch),
                ),
              if (state.staffForRole(Role.receptionist).isEmpty)
                Text(state.t('Create receptionist users first.',
                    'أنشئ مستخدمي الاستقبال أولاً.')),
            ]),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(state.t('Cancel', 'إلغاء')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(state.t('Save', 'حفظ')),
          ),
        ],
      ),
    ),
  );
  if (saved != true) return;
  for (final user in state.staffForRole(Role.receptionist)) {
    final shouldBeInBranch = selected.contains(user.username);
    final isInBranch =
        user.branch.trim().toLowerCase() == branch.name.toLowerCase();
    if (shouldBeInBranch == isInBranch) continue;
    await state.updateStaffUser(
      user.copyWith(branch: shouldBeInBranch ? branch.name : ''),
    );
  }
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(state.t(
          'Branch receptionists saved.', 'تم حفظ موظفي استقبال الفرع.')),
    ));
  }
}

void openInvoicePrint(Order order, AppState state) {
  const escape = HtmlEscape();
  final invoiceNo = order.invoiceNo.isEmpty ? order.id : order.invoiceNo;
  final paymentLabel =
      order.paymentStatus.toLowerCase() == 'paid' ? 'Paid' : 'Pending';
  final rows = <String, String>{
    'Invoice': invoiceNo,
    'Order ID': order.id,
    'Customer': order.customer,
    'Mobile': order.mobile,
    'Area': order.area(state.isArabic),
    'Address': order.address,
    'Service': order.service,
    'Tailor preference': order.preference,
    'Visit window': order.window,
    'Delivery price': formatKwd(order.deliveryPrice),
    'Total': formatKwd(order.totalAmount),
    'Payment method': order.paymentMethod,
    'Payment status': paymentLabel,
  };
  final rowsHtml = rows.entries
      .map((entry) =>
          '<tr><th>${escape.convert(entry.key)}</th><td>${escape.convert(entry.value)}</td></tr>')
      .join();
  final notes = order.notes.trim().isEmpty ? '-' : order.notes.trim();
  final invoiceHtml = '''
<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <title>${escape.convert(invoiceNo)}</title>
  <style>
    body { font-family: Arial, sans-serif; color: #17130e; margin: 32px; }
    .brand { color: #c7a04b; font-size: 12px; letter-spacing: 3px; text-transform: uppercase; }
    h1 { margin: 8px 0 4px; font-size: 28px; }
    .meta { color: #6c6254; margin-bottom: 22px; }
    table { width: 100%; border-collapse: collapse; margin-top: 18px; }
    th, td { text-align: left; border-bottom: 1px solid #e8ddc8; padding: 10px 8px; }
    th { width: 34%; background: #fff8eb; }
    .total { margin-top: 22px; padding: 16px; background: #17130e; color: white; border-radius: 12px; font-size: 20px; }
    .notes { margin-top: 22px; padding: 14px; border: 1px solid #e8ddc8; border-radius: 12px; }
    @media print { button { display: none; } body { margin: 18mm; } }
  </style>
</head>
<body>
  <button onclick="window.print()">Print / Save PDF</button>
  <div class="brand">Tailor Express</div>
  <h1>Customer Bill</h1>
  <div class="meta">Generated ${DateTime.now().toLocal()}</div>
  <table>$rowsHtml</table>
  <div class="total">Total: ${escape.convert(formatKwd(order.totalAmount))}</div>
  <div class="notes"><strong>Notes</strong><br>${escape.convert(notes)}</div>
  <script>setTimeout(() => window.print(), 300);</script>
</body>
</html>
''';
  final blob = html.Blob([invoiceHtml], 'text/html');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.window.open(url, '_blank');
}

class AreaPricesPanel extends StatefulWidget {
  const AreaPricesPanel({super.key, required this.state});
  final AppState state;

  @override
  State<AreaPricesPanel> createState() => _AreaPricesPanelState();
}

class _AreaPricesPanelState extends State<AreaPricesPanel> {
  final search = TextEditingController();

  AppState get state => widget.state;

  @override
  void initState() {
    super.initState();
    search.addListener(() => setState(() {}));
    unawaited(state.refreshAreaPrices(quiet: true));
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = search.text.trim().toLowerCase();
    final areas = state.areaPrices.where((area) {
      final localized = state.areaFromName(area.areaEn).name(state.isArabic);
      return query.isEmpty ||
          area.areaEn.toLowerCase().contains(query) ||
          localized.toLowerCase().contains(query);
    }).toList()
      ..sort((a, b) => a.areaEn.compareTo(b.areaEn));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(state.t('Delivery Prices', 'أسعار التوصيل'),
                  style: Theme.of(context).textTheme.titleLarge),
              SizedBox(
                width: 260,
                child: TextField(
                  controller: search,
                  decoration: InputDecoration(
                      labelText: state.t('Search area', 'بحث عن منطقة')),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => unawaited(state.refreshAreaPrices()),
                icon: const Icon(Icons.refresh),
                label: Text(state.t('Refresh', 'تحديث')),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(state.t(
              'The selected active area price is shown to customers before payment and is used as the UPay amount.',
              'سعر المنطقة المفعلة يظهر للعميل قبل الدفع ويستخدم كمبلغ UPay.')),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              dataRowMinHeight: 64,
              dataRowMaxHeight: 78,
              columnSpacing: 38,
              columns: [
                dataLabel(state.t('Area', 'المنطقة')),
                dataLabel(state.t('Price', 'السعر')),
                dataLabel(state.t('Status', 'الحالة')),
                dataLabel(state.t('Action', 'الإجراء')),
              ],
              rows: [
                for (final area in areas) _areaRow(context, area),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  DataRow _areaRow(BuildContext context, DeliveryAreaPrice price) {
    final area = state.areaFromName(price.areaEn);
    return DataRow(cells: [
      DataCell(Text(area.name(state.isArabic))),
      DataCell(Text(formatKwd(price.price))),
      DataCell(badge(
          price.active
              ? state.t('Active', 'مفعلة')
              : state.t('Inactive', 'متوقفة'),
          price.active ? const Color(0xFF2D8A57) : const Color(0xFF9A3A2F))),
      DataCell(SizedBox(
        width: 250,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          compactTableButton(
            label: state.t('Edit', 'تعديل'),
            onPressed: () => editArea(context, price),
          ),
          const SizedBox(width: 8),
          compactTableButton(
            label: price.active
                ? state.t('Deactivate', 'إيقاف')
                : state.t('Activate', 'تفعيل'),
            onPressed: () => unawaited(state.updateAreaPrice(
                price.areaEn, price.price, !price.active)),
          ),
        ]),
      )),
    ]);
  }

  Future<void> editArea(BuildContext context, DeliveryAreaPrice area) async {
    final nameController = TextEditingController(text: area.areaEn);
    final controller =
        TextEditingController(text: area.price.toStringAsFixed(3));
    var active = area.active;
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
              '${state.t('Edit delivery price', 'تعديل سعر التوصيل')} - ${area.areaEn}'),
          content: SizedBox(
            width: 420,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                    labelText: state.t('Area name', 'اسم المنطقة')),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: controller,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                    labelText: state.t('Price KWD', 'السعر بالدينار')),
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                value: active,
                onChanged: (value) => setDialogState(() => active = value),
                title: Text(state.t('Area active', 'المنطقة مفعلة')),
              ),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(state.t('Cancel', 'إلغاء'))),
            ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(state.t('Save', 'حفظ'))),
          ],
        ),
      ),
    );
    if (saved != true) {
      nameController.dispose();
      controller.dispose();
      return;
    }
    final nextName = nameController.text.trim();
    final value = double.tryParse(controller.text.trim());
    nameController.dispose();
    controller.dispose();
    if (nextName.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(state.t('Enter an area name.', 'أدخل اسم المنطقة.'))));
      return;
    }
    if (value == null || value < 0) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(state.t('Enter a valid price.', 'أدخل سعرا صحيحا.'))));
      return;
    }
    await state.updateAreaPrice(area.areaEn, value, active,
        newAreaEn: nextName);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text(state.t('Delivery price saved.', 'تم حفظ سعر التوصيل.'))));
  }
}

class StaffUsersPanel extends StatefulWidget {
  const StaffUsersPanel({super.key, required this.state});
  final AppState state;

  @override
  State<StaffUsersPanel> createState() => _StaffUsersPanelState();
}

class _StaffUsersPanelState extends State<StaffUsersPanel> {
  final username = TextEditingController();
  final displayName = TextEditingController();
  final password = TextEditingController();
  final branch = TextEditingController();
  Role selectedRole = Role.driver;
  bool active = true;
  bool availableToday = true;
  bool homeServiceToday = true;

  AppState get state => widget.state;

  List<String> get branchChoices => [
        '-',
        for (final branch in adminBranches) branch.name,
      ];

  String normalizedBranchValue(String value) =>
      branchChoices.contains(value.trim()) ? value.trim() : '-';

  @override
  void dispose() {
    username.dispose();
    displayName.dispose();
    password.dispose();
    branch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return adminCard(
      context,
      title: state.t('Staff users and roles', 'Staff users and roles'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 12, runSpacing: 12, children: [
          SizedBox(
            width: 180,
            child: TextField(
              controller: username,
              decoration:
                  InputDecoration(labelText: state.t('Username', 'Username')),
            ),
          ),
          SizedBox(
            width: 180,
            child: TextField(
              controller: displayName,
              decoration: InputDecoration(
                  labelText: state.t('Staff name', 'Staff name')),
            ),
          ),
          SizedBox(
            width: 180,
            child: TextField(
              controller: password,
              obscureText: true,
              decoration:
                  InputDecoration(labelText: state.t('Password', 'Password')),
            ),
          ),
          SizedBox(
            width: 230,
            child: DropdownButtonFormField<Role>(
              value: selectedRole,
              decoration:
                  InputDecoration(labelText: state.t('User type', 'User type')),
              items: [
                for (final role in Role.values)
                  DropdownMenuItem(
                    value: role,
                    child: Text(roleLabel(role, state.isArabic)),
                  ),
              ],
              onChanged: (value) =>
                  setState(() => selectedRole = value ?? selectedRole),
            ),
          ),
          SizedBox(
            width: 220,
            child: DropdownButtonFormField<String>(
              value: normalizedBranchValue(branch.text),
              isExpanded: true,
              decoration:
                  InputDecoration(labelText: state.t('Branch', 'Branch')),
              items: [
                for (final item in branchChoices)
                  DropdownMenuItem(
                    value: item,
                    child: Text(item, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (value) =>
                  setState(() => branch.text = value == '-' ? '' : value ?? ''),
            ),
          ),
          SizedBox(
            width: 220,
            child: SwitchListTile(
              value: availableToday,
              contentPadding: EdgeInsets.zero,
              onChanged: (value) => setState(() => availableToday = value),
              title: Text(state.t('Available today', 'Available today')),
            ),
          ),
          ElevatedButton.icon(
            onPressed: addUser,
            icon: const Icon(Icons.person_add_alt),
            label: Text(state.t('Create user', 'Create user')),
          ),
        ]),
        const SizedBox(height: 18),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: [
              dataLabel(state.t('Username', 'Username')),
              dataLabel(state.t('Name', 'Name')),
              dataLabel(state.t('Type', 'Type')),
              dataLabel(state.t('Branch', 'Branch')),
              dataLabel(state.t('Available', 'Available')),
              dataLabel(state.t('Home service', 'Home service')),
              dataLabel(state.t('Status', 'Status')),
              dataLabel(state.t('Action', 'Action')),
            ],
            rows: [
              for (final item in state.staffUsers)
                DataRow(cells: [
                  DataCell(Text(item.username)),
                  DataCell(Text(item.displayName)),
                  DataCell(Text(roleLabel(item.role, state.isArabic))),
                  DataCell(
                      Text(item.branch.trim().isEmpty ? '-' : item.branch)),
                  DataCell(Text(item.availableToday
                      ? state.t('Yes', 'Yes')
                      : state.t('No', 'No'))),
                  DataCell(Text(item.homeServiceToday
                      ? state.t('Yes', 'Yes')
                      : state.t('No', 'No'))),
                  DataCell(Text(item.active
                      ? state.t('Active', 'Active')
                      : state.t('Off', 'Off'))),
                  DataCell(SizedBox(
                    width: 330,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      compactTableButton(
                        label: state.t('Edit', 'Edit'),
                        onPressed: () => editUser(item),
                      ),
                      const SizedBox(width: 8),
                      compactTableButton(
                        label: item.availableToday
                            ? state.t('Set unavailable', 'Set unavailable')
                            : state.t('Set available', 'Set available'),
                        onPressed: () => unawaited(state.updateStaffUser(item
                            .copyWith(availableToday: !item.availableToday))),
                      ),
                    ]),
                  )),
                ]),
            ],
          ),
        ),
      ]),
    );
  }

  Future<void> addUser() async {
    final ok = await state.addStaffUser(StaffUser(
      username: username.text.trim(),
      password: password.text,
      displayName: displayName.text.trim(),
      role: selectedRole,
      branch: branch.text.trim(),
      active: active,
      availableToday: availableToday,
      homeServiceToday: homeServiceToday,
    ));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? state.t('User created.', 'User created.')
          : state.t('Username already exists or fields are missing.',
              'Username already exists or fields are missing.')),
    ));
    if (!ok) return;
    username.clear();
    displayName.clear();
    password.clear();
    branch.clear();
    setState(() {});
  }

  Future<void> editUser(StaffUser user) async {
    final nameController = TextEditingController(text: user.displayName);
    final passwordController = TextEditingController();
    var editedBranch = normalizedBranchValue(user.branch);
    var role = user.role;
    var isActive = user.active;
    var isAvailable = user.availableToday;
    var isHomeService = user.homeServiceToday;
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title:
              Text('${state.t('Edit user', 'Edit user')} - ${user.username}'),
          content: SizedBox(
            width: 480,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                    labelText: state.t('Staff name', 'Staff name')),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: InputDecoration(
                    labelText: state.t(
                        'New password optional', 'New password optional')),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<Role>(
                value: role,
                decoration: InputDecoration(
                    labelText: state.t('User type', 'User type')),
                items: [
                  for (final item in Role.values)
                    DropdownMenuItem(
                      value: item,
                      child: Text(roleLabel(item, state.isArabic)),
                    ),
                ],
                onChanged: (value) =>
                    setDialogState(() => role = value ?? role),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: normalizedBranchValue(editedBranch),
                isExpanded: true,
                decoration:
                    InputDecoration(labelText: state.t('Branch', 'Branch')),
                items: [
                  for (final item in branchChoices)
                    DropdownMenuItem(
                      value: item,
                      child: Text(item, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (value) => setDialogState(
                    () => editedBranch = value == '-' ? '' : value ?? ''),
              ),
              SwitchListTile(
                value: isAvailable,
                onChanged: (value) => setDialogState(() => isAvailable = value),
                title: Text(state.t('Available today', 'Available today')),
              ),
              SwitchListTile(
                value: isHomeService,
                onChanged: (value) =>
                    setDialogState(() => isHomeService = value),
                title:
                    Text(state.t('Home service today', 'Home service today')),
              ),
              SwitchListTile(
                value: isActive,
                onChanged: (value) => setDialogState(() => isActive = value),
                title: Text(state.t('Active login', 'Active login')),
              ),
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(state.t('Cancel', 'Cancel')),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(state.t('Save', 'Save')),
            ),
          ],
        ),
      ),
    );
    if (saved == true) {
      final next = user.copyWith(
        displayName: nameController.text.trim(),
        password: passwordController.text.isEmpty
            ? user.password
            : passwordController.text,
        role: role,
        branch: editedBranch.trim() == '-' ? '' : editedBranch.trim(),
        active: isActive,
        availableToday: isAvailable,
        homeServiceToday: isHomeService,
      );
      await state.updateStaffUser(next);
    }
    nameController.dispose();
    passwordController.dispose();
    if (mounted) setState(() {});
  }
}

class BranchReceptionistsPanel extends StatelessWidget {
  const BranchReceptionistsPanel({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return adminCard(
      context,
      title: state.t('Receptionists by branch', 'موظفو الاستقبال حسب الفرع'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(state.t(
          'Assign receptionist users to branches so branch orders and Ready actions stay linked to the correct branch.',
          'عيّن مستخدمي الاستقبال للفروع حتى تبقى طلبات الفرع وإجراءات الجاهزية مرتبطة بالفرع الصحيح.',
        )),
        const SizedBox(height: 14),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final branch in adminBranches)
              SizedBox(
                width: 360,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(branch.name,
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 8),
                          Text(
                            state
                                    .staffNamesForRole(Role.receptionist,
                                        branch: branch.name)
                                    .isEmpty
                                ? state.t('No receptionists assigned.',
                                    'لا يوجد موظفو استقبال معينون.')
                                : state
                                    .staffNamesForRole(Role.receptionist,
                                        branch: branch.name)
                                    .join(', '),
                          ),
                          const SizedBox(height: 12),
                          compactTableButton(
                            label:
                                state.t('Set receptionists', 'تعيين الاستقبال'),
                            onPressed: () => showBranchReceptionistsDialog(
                                context, state, branch),
                          ),
                        ]),
                  ),
                ),
              ),
          ],
        ),
      ]),
    );
  }
}

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key, required this.state});
  final AppState state;

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

enum AdminSection {
  orders,
  assignments,
  history,
  users,
  prices,
  schedule,
  branches,
  policies
}

class _AdminDashboardState extends State<AdminDashboard> {
  late bool appointmentEnabled;
  late final TextEditingController slotListController;
  late final TextEditingController dateRangeController;
  late final TextEditingController branchSearchController;
  late final TextEditingController policyEnNameController;
  late final TextEditingController policyArNameController;
  late final TextEditingController policyEnDetailController;
  late final TextEditingController policyArDetailController;
  late final List<PolicyRecord> policies;
  late final List<TextEditingController> capacityControllers;
  final List<String> dayKeys = [
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday'
  ];
  final List<String> slotKeys = [
    '12pm',
    '1pm',
    '2pm',
    '3pm',
    '4pm',
    '5pm',
    '6pm',
    '7pm',
    '8pm'
  ];
  Set<String> workingDays = {
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday'
  };
  int selectedPolicyIndex = 0;
  AdminSection selectedSection = AdminSection.orders;

  AppState get s => widget.state;

  @override
  void initState() {
    super.initState();
    appointmentEnabled = s.bookingSchedule.enabled;
    slotListController =
        TextEditingController(text: s.bookingSchedule.slots.join(','));
    dateRangeController =
        TextEditingController(text: '29-07-2026 to 31-07-2026');
    branchSearchController = TextEditingController();
    policies = List<PolicyRecord>.from(adminPolicies);
    policyEnNameController = TextEditingController();
    policyArNameController = TextEditingController();
    policyEnDetailController = TextEditingController();
    policyArDetailController = TextEditingController();
    capacityControllers = [
      for (final _ in slotKeys) TextEditingController(text: '2')
    ];
    workingDays = s.bookingSchedule.workingDays.toSet();
    _loadPolicy(0);
    branchSearchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    slotListController.dispose();
    dateRangeController.dispose();
    branchSearchController.dispose();
    policyEnNameController.dispose();
    policyArNameController.dispose();
    policyEnDetailController.dispose();
    policyArDetailController.dispose();
    for (final controller in capacityControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visibleOrders = s.orders.where(hasConfirmedPayment).toList();
    final active = visibleOrders.where((o) => !isClosedOrder(o)).length;
    return Shell(
      state: s,
      role: Role.admin,
      title: s.t(
          'Admin dashboard with booking schedule, branches and policy settings.',
          'لوحة الإدارة مع إعدادات جدول الحجوزات والفروع والسياسات.'),
      subtitle: s.t(
          'This admin route now includes the same settings structure you showed: scheduling, branch management and bilingual policy editing.',
          'هذا الرابط الإداري يتضمن الآن نفس هيكل الإعدادات الذي عرضته: الجدولة وإدارة الفروع وتحرير السياسات باللغتين.'),
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 16, runSpacing: 16, children: [
          metric(s.t('All orders', 'كل الطلبات'), '${visibleOrders.length}'),
          metric(s.t('Active orders', 'الطلبات النشطة'), '$active'),
          metric(s.t('Open complaints', 'الشكاوى المفتوحة'),
              '${complaints.length}'),
          metric(s.t('Branches', 'الفروع'), '${adminBranches.length}'),
        ]),
        const SizedBox(height: 18),
        adminSectionNav(),
        const SizedBox(height: 18),
        if (selectedSection == AdminSection.orders)
          OrdersDashboardTable(
            state: s,
            orders: s.orders,
            title: s.t('Orders dashboard', 'لوحة الطلبات'),
          ),
        if (selectedSection == AdminSection.assignments) ...[
          BranchAssignmentCard(state: s),
          const SizedBox(height: 18),
          DriverAssignmentCard(state: s),
        ],
        if (selectedSection == AdminSection.history)
          OperationsTrackingPanel(state: s),
        if (selectedSection == AdminSection.prices) AreaPricesPanel(state: s),
        if (selectedSection == AdminSection.users) StaffUsersPanel(state: s),
        if (selectedSection == AdminSection.schedule)
          adminCard(
            context,
            title: s.t('Booking Schedule', 'جدول الحجوزات'),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              settingsBlock(
                context,
                title: s.t('Appointment Module', 'وحدة المواعيد'),
                action: smallSaveButton(() => unawaited(saveBookingSchedule())),
                child: SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<bool>(
                    value: appointmentEnabled,
                    decoration: InputDecoration(
                        labelText: s.t('Module status', 'حالة الوحدة')),
                    items: [
                      DropdownMenuItem(
                          value: true, child: Text(s.t('ON', 'تشغيل'))),
                      DropdownMenuItem(
                          value: false, child: Text(s.t('OFF', 'إيقاف'))),
                    ],
                    onChanged: (value) =>
                        setState(() => appointmentEnabled = value ?? true),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              settingsBlock(
                context,
                title: s.t('Time Slots', 'الفترات الزمنية'),
                action: smallSaveButton(
                    () => unawaited(saveBookingSchedule(regenerate: true))),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 420,
                        child: TextField(
                          controller: slotListController,
                          decoration: InputDecoration(
                              labelText: s.t('Time slots', 'الفترات الزمنية'),
                              hintText: '12pm,1pm,2pm,3pm'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                          s.t('Note: once you save new time slots, the previous setup will be removed.',
                              'ملاحظة: عند حفظ الفترات الجديدة سيتم استبدال الإعداد السابق.'),
                          style: const TextStyle(color: Colors.black54)),
                    ]),
              ),
              const SizedBox(height: 16),
              settingsBlock(
                context,
                title: s.t('Working Days', 'أيام العمل'),
                action: smallSaveButton(
                    () => unawaited(saveBookingSchedule(regenerate: true))),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final day in dayKeys)
                      SizedBox(
                        width: 130,
                        child: CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          value: workingDays.contains(day),
                          title: Text(dayLabel(day),
                              style: const TextStyle(fontSize: 13)),
                          onChanged: (value) {
                            setState(() {
                              if (value ?? false) {
                                workingDays.add(day);
                              } else {
                                workingDays.remove(day);
                              }
                            });
                          },
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              settingsBlock(
                context,
                title: s.t('Capacity Generator', 'توليد السعة'),
                action: OutlinedButton(
                    onPressed: () =>
                        unawaited(saveBookingSchedule(regenerate: true)),
                    child: Text(s.t('Continue', 'متابعة'))),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          s.t('Select a date range and click Continue to generate rows.',
                              'اختر نطاق التاريخ ثم اضغط متابعة لإنشاء الصفوف.'),
                          style: const TextStyle(color: Colors.black54)),
                      const SizedBox(height: 12),
                      Wrap(spacing: 12, runSpacing: 12, children: [
                        SizedBox(
                            width: 240,
                            child: TextField(
                                controller: dateRangeController,
                                decoration: InputDecoration(
                                    labelText:
                                        s.t('Date range', 'نطاق التاريخ')))),
                        for (var i = 0; i < slotKeys.length; i++)
                          SizedBox(
                              width: 105,
                              child: TextField(
                                  controller: capacityControllers[i],
                                  decoration:
                                      InputDecoration(labelText: slotKeys[i]))),
                      ]),
                      const SizedBox(height: 10),
                      Text(
                          s.t('Note: only working days will be generated.',
                              'ملاحظة: سيتم إنشاء أيام العمل فقط.'),
                          style: const TextStyle(color: Colors.black54)),
                    ]),
              ),
              const SizedBox(height: 16),
              settingsBlock(
                context,
                title: s.t('Existing Schedule Records', 'سجلات الجدول الحالية'),
                action: smallSaveButton(() => unawaited(saveBookingSchedule())),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: [
                      dataLabel(s.t('Date', 'التاريخ')),
                      dataLabel(s.t('Day', 'اليوم')),
                      for (final slot in s.bookingSchedule.slots)
                        dataLabel(slot),
                      dataLabel(s.t('Action', 'الإجراء')),
                    ],
                    rows: [
                      for (final row in s.bookingSchedule.rows.entries)
                        DataRow(cells: [
                          DataCell(Text(row.key)),
                          DataCell(Text(dayLabel(weekdayName(
                              parseDateKey(row.key) ?? DateTime.now())))),
                          for (final slot in s.bookingSchedule.slots)
                            DataCell(SizedBox(
                                width: 44,
                                child: Text('${row.value[slot] ?? 0}'))),
                          DataCell(compactTableButton(
                            label: s.t('Deactivate', 'إيقاف'),
                            onPressed: () =>
                                unawaited(deactivateScheduleDate(row.key)),
                          )),
                        ]),
                    ],
                  ),
                ),
              ),
            ]),
          ),
        if (selectedSection == AdminSection.branches)
          adminCard(
            context,
            title: s.t('Branches', 'الفروع'),
            action: Wrap(spacing: 10, runSpacing: 10, children: [
              SizedBox(
                  width: 220,
                  child: TextField(
                      controller: branchSearchController,
                      decoration:
                          InputDecoration(labelText: s.t('Search', 'بحث')))),
              ElevatedButton(
                  onPressed: () => notifySaved(s.t(
                      'Add branch flow is ready.', 'نموذج إضافة الفرع جاهز.')),
                  child: Text(s.t('Add Branch', 'إضافة فرع'))),
            ]),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                dataRowMinHeight: 64,
                dataRowMaxHeight: 92,
                columns: [
                  dataLabel(s.t('Branch Name', 'اسم الفرع')),
                  dataLabel(s.t('Address / Location', 'العنوان / الموقع')),
                  dataLabel(s.t('Working Hours', 'ساعات العمل')),
                  dataLabel(s.t('Contact No.', 'رقم التواصل')),
                  dataLabel(s.t('Receptionists', 'موظفو الاستقبال')),
                  dataLabel(s.t('Status', 'الحالة')),
                  dataLabel(s.t('Action', 'الإجراء')),
                ],
                rows: [
                  for (final branch in filteredBranches)
                    DataRow(cells: [
                      DataCell(Text(branch.name)),
                      DataCell(SizedBox(
                          width: 210,
                          child: Text(branch.locationLink,
                              overflow: TextOverflow.ellipsis))),
                      DataCell(SizedBox(width: 220, child: Text(branch.hours))),
                      DataCell(Text(branch.contact)),
                      DataCell(SizedBox(
                          width: 220,
                          child: Builder(builder: (context) {
                            final names = s.staffNamesForRole(Role.receptionist,
                                branch: branch.name);
                            return Text(
                              names.isEmpty ? '-' : names.join(', '),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            );
                          }))),
                      DataCell(
                          Text(s.isArabic ? branch.statusAr : branch.statusEn)),
                      DataCell(SizedBox(
                        width: 280,
                        child: Wrap(spacing: 8, runSpacing: 8, children: [
                          compactTableButton(
                            label: s.t('Set receptionists', 'تعيين الاستقبال'),
                            onPressed: () => showBranchReceptionistsDialog(
                                context, s, branch),
                          ),
                          compactTableButton(
                            label: s.t('Edit', 'تعديل'),
                            onPressed: () => notifySaved(s.t(
                                'Branch edit is ready.', 'تعديل الفرع جاهز.')),
                          ),
                        ]),
                      )),
                    ]),
                ],
              ),
            ),
          ),
        if (selectedSection == AdminSection.policies)
          adminCard(
            context,
            title: s.t('Edit Policy', 'تعديل السياسة'),
            action: OutlinedButton(
                onPressed: () => notifySaved(
                    s.t('Back to policy list.', 'العودة إلى قائمة السياسات.')),
                child: Text(s.t('Back to list', 'العودة للقائمة'))),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 10, runSpacing: 10, children: [
                for (var i = 0; i < policies.length; i++)
                  ChoiceChip(
                    label: Text(
                        s.isArabic ? policies[i].nameAr : policies[i].nameEn),
                    selected: selectedPolicyIndex == i,
                    selectedColor: const Color(0xFFFFF1CF),
                    onSelected: (_) => setState(() => _loadPolicy(i)),
                  ),
              ]),
              const SizedBox(height: 18),
              Wrap(spacing: 16, runSpacing: 16, children: [
                SizedBox(
                  width: 480,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                            controller: policyEnNameController,
                            decoration: InputDecoration(
                                labelText: s.t('Policy Name (English)',
                                    'اسم السياسة بالإنجليزية'))),
                        const SizedBox(height: 12),
                        TextField(
                            controller: policyEnDetailController,
                            maxLines: 16,
                            decoration: InputDecoration(
                                labelText: s.t('Detail (English)',
                                    'التفاصيل بالإنجليزية'))),
                      ]),
                ),
                SizedBox(
                  width: 480,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                            controller: policyArNameController,
                            textAlign: TextAlign.right,
                            decoration: InputDecoration(
                                labelText: s.t('Policy Name (Arabic)',
                                    'اسم السياسة بالعربية'))),
                        const SizedBox(height: 12),
                        TextField(
                            controller: policyArDetailController,
                            textAlign: TextAlign.right,
                            maxLines: 16,
                            decoration: InputDecoration(
                                labelText: s.t(
                                    'Detail (Arabic)', 'التفاصيل بالعربية'))),
                      ]),
                ),
              ]),
              const SizedBox(height: 16),
              smallSaveButton(savePolicy),
            ]),
          ),
        if (showLegacyAdminBlocks) ...[
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(spacing: 10, runSpacing: 10, children: [
                          sectionChip(s.t('Dashboard', 'لوحة التحكم')),
                          sectionChip(s.t('Booking Schedule', 'جدول الحجوزات')),
                          sectionChip(s.t('Branches', 'الفروع')),
                          sectionChip(s.t('Policies', 'السياسات')),
                        ]),
                        const SizedBox(height: 14),
                        Text(s.t('Bookings overview', 'نظرة على الحجوزات'),
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 12),
                        for (final o in s.orders.take(6))
                          ListTile(
                              title: Text('${o.id} • ${o.customer}'),
                              subtitle:
                                  Text('${o.area(s.isArabic)} • ${o.service}'),
                              trailing: badge(stageLabel(o.stage, s.isArabic),
                                  stageColor(o.stage))),
                      ]))),
          const SizedBox(height: 18),
          adminCard(
            context,
            title: s.t('Booking Schedule', 'جدول الحجوزات'),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              settingsBlock(
                context,
                title: s.t('Appointment Module', 'وحدة المواعيد'),
                action: smallSaveButton(() => notifySaved(s.t(
                    'Appointment module saved.',
                    'تم حفظ إعداد وحدة المواعيد.'))),
                child: SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<bool>(
                    value: appointmentEnabled,
                    decoration: InputDecoration(
                        labelText: s.t('Module status', 'حالة الوحدة')),
                    items: [
                      DropdownMenuItem(
                          value: true, child: Text(s.t('ON', 'تشغيل'))),
                      DropdownMenuItem(
                          value: false, child: Text(s.t('OFF', 'إيقاف'))),
                    ],
                    onChanged: (value) =>
                        setState(() => appointmentEnabled = value ?? true),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              settingsBlock(
                context,
                title: s.t('Time Slots', 'الفترات الزمنية'),
                action: smallSaveButton(() => notifySaved(
                    s.t('Time slots saved.', 'تم حفظ الفترات الزمنية.'))),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 420,
                        child: TextField(
                          controller: slotListController,
                          decoration: InputDecoration(
                              labelText: s.t('Time slots', 'الفترات الزمنية'),
                              hintText: '12pm,1pm,2pm,3pm'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                          s.t('Note: once you save new time slots, the previous setup will be removed.',
                              'ملاحظة: عند حفظ الفترات الجديدة سيتم استبدال الإعداد السابق.'),
                          style: const TextStyle(color: Colors.black54)),
                    ]),
              ),
              const SizedBox(height: 16),
              settingsBlock(
                context,
                title: s.t('Working Days', 'أيام العمل'),
                action: smallSaveButton(() => notifySaved(
                    s.t('Working days saved.', 'تم حفظ أيام العمل.'))),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final day in dayKeys)
                      SizedBox(
                        width: 130,
                        child: CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          value: workingDays.contains(day),
                          title: Text(dayLabel(day),
                              style: const TextStyle(fontSize: 13)),
                          onChanged: (value) {
                            setState(() {
                              if (value ?? false) {
                                workingDays.add(day);
                              } else {
                                workingDays.remove(day);
                              }
                            });
                          },
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              settingsBlock(
                context,
                title: s.t('Capacity Generator', 'توليد السعة'),
                action: OutlinedButton(
                    onPressed: () => notifySaved(s.t(
                        'Rows generated for working days.',
                        'تم إنشاء الصفوف لأيام العمل.')),
                    child: Text(s.t('Continue', 'متابعة'))),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          s.t('Select a date range and click Continue to generate rows.',
                              'اختر نطاق التاريخ ثم اضغط متابعة لإنشاء الصفوف.'),
                          style: const TextStyle(color: Colors.black54)),
                      const SizedBox(height: 12),
                      Wrap(spacing: 12, runSpacing: 12, children: [
                        SizedBox(
                            width: 240,
                            child: TextField(
                                controller: dateRangeController,
                                decoration: InputDecoration(
                                    labelText:
                                        s.t('Date range', 'نطاق التاريخ')))),
                        for (var i = 0; i < slotKeys.length; i++)
                          SizedBox(
                              width: 105,
                              child: TextField(
                                  controller: capacityControllers[i],
                                  decoration:
                                      InputDecoration(labelText: slotKeys[i]))),
                      ]),
                      const SizedBox(height: 10),
                      Text(
                          s.t('Note: only working days will be generated.',
                              'ملاحظة: سيتم إنشاء أيام العمل فقط.'),
                          style: const TextStyle(color: Colors.black54)),
                    ]),
              ),
              const SizedBox(height: 16),
              settingsBlock(
                context,
                title: s.t('Existing Schedule Records', 'سجلات الجدول الحالية'),
                action: smallSaveButton(() => notifySaved(
                    s.t('Schedule records saved.', 'تم حفظ سجلات الجدول.'))),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: [
                      dataLabel(s.t('Date', 'التاريخ')),
                      dataLabel(s.t('Day', 'اليوم')),
                      for (final slot in slotKeys) dataLabel(slot),
                    ],
                    rows: [
                      for (final row in scheduleRows)
                        DataRow(cells: [
                          DataCell(Text(row.date)),
                          DataCell(Text(s.isArabic ? row.dayAr : row.dayEn)),
                          for (final count in row.capacities)
                            DataCell(SizedBox(
                                width: 44,
                                child: TextField(
                                    controller:
                                        TextEditingController(text: '$count'),
                                    decoration: const InputDecoration(
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 8))))),
                        ]),
                    ],
                  ),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 18),
          adminCard(
            context,
            title: s.t('Branches', 'الفروع'),
            action: Wrap(spacing: 10, runSpacing: 10, children: [
              SizedBox(
                  width: 220,
                  child: TextField(
                      controller: branchSearchController,
                      decoration:
                          InputDecoration(labelText: s.t('Search', 'بحث')))),
              ElevatedButton(
                  onPressed: () => notifySaved(s.t(
                      'Add branch flow is ready.', 'نموذج إضافة الفرع جاهز.')),
                  child: Text(s.t('Add Branch', 'إضافة فرع'))),
            ]),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: [
                  dataLabel(s.t('Branch Name', 'اسم الفرع')),
                  dataLabel(s.t('Address / Location', 'العنوان / الموقع')),
                  dataLabel(s.t('Working Hours', 'ساعات العمل')),
                  dataLabel(s.t('Contact No.', 'رقم التواصل')),
                  dataLabel(s.t('Status', 'الحالة')),
                  dataLabel(s.t('Action', 'الإجراء')),
                ],
                rows: [
                  for (final branch in filteredBranches)
                    DataRow(cells: [
                      DataCell(Text(branch.name)),
                      DataCell(SizedBox(
                          width: 210,
                          child: Text(branch.locationLink,
                              overflow: TextOverflow.ellipsis))),
                      DataCell(SizedBox(width: 220, child: Text(branch.hours))),
                      DataCell(Text(branch.contact)),
                      DataCell(
                          Text(s.isArabic ? branch.statusAr : branch.statusEn)),
                      DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                        tinyActionButton(s.t('Edit', 'تعديل')),
                        const SizedBox(width: 6),
                        tinyActionButton(s.t('Delete', 'حذف')),
                      ])),
                    ]),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          adminCard(
            context,
            title: s.t('Edit Policy', 'تعديل السياسة'),
            action: OutlinedButton(
                onPressed: () => notifySaved(
                    s.t('Back to policy list.', 'العودة إلى قائمة السياسات.')),
                child: Text(s.t('Back to list', 'العودة للقائمة'))),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 10, runSpacing: 10, children: [
                for (var i = 0; i < policies.length; i++)
                  ChoiceChip(
                    label: Text(
                        s.isArabic ? policies[i].nameAr : policies[i].nameEn),
                    selected: selectedPolicyIndex == i,
                    selectedColor: const Color(0xFFFFF1CF),
                    onSelected: (_) => setState(() => _loadPolicy(i)),
                  ),
              ]),
              const SizedBox(height: 18),
              Wrap(spacing: 16, runSpacing: 16, children: [
                SizedBox(
                  width: 480,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                            controller: policyEnNameController,
                            decoration: InputDecoration(
                                labelText: s.t('Policy Name (English)',
                                    'اسم السياسة بالإنجليزية'))),
                        const SizedBox(height: 12),
                        TextField(
                            controller: policyEnDetailController,
                            maxLines: 16,
                            decoration: InputDecoration(
                                labelText: s.t('Detail (English)',
                                    'التفاصيل بالإنجليزية'))),
                      ]),
                ),
                SizedBox(
                  width: 480,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                            controller: policyArNameController,
                            textAlign: TextAlign.right,
                            decoration: InputDecoration(
                                labelText: s.t('Policy Name (Arabic)',
                                    'اسم السياسة بالعربية'))),
                        const SizedBox(height: 12),
                        TextField(
                            controller: policyArDetailController,
                            textAlign: TextAlign.right,
                            maxLines: 16,
                            decoration: InputDecoration(
                                labelText: s.t(
                                    'Detail (Arabic)', 'التفاصيل بالعربية'))),
                      ]),
                ),
              ]),
              const SizedBox(height: 16),
              smallSaveButton(savePolicy),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget adminSectionNav() {
    return Wrap(spacing: 10, runSpacing: 10, children: [
      adminSectionButton(AdminSection.orders, s.t('Orders', 'الطلبات')),
      adminSectionButton(
          AdminSection.assignments, s.t('Driver assignment', 'تعيين السائق')),
      adminSectionButton(AdminSection.history, s.t('History', 'السجل')),
      adminSectionButton(AdminSection.users, s.t('Users', 'المستخدمون')),
      adminSectionButton(
          AdminSection.prices, s.t('Delivery prices', 'أسعار التوصيل')),
      adminSectionButton(
          AdminSection.schedule, s.t('Booking Schedule', 'جدول الحجوزات')),
      adminSectionButton(AdminSection.branches, s.t('Branches', 'الفروع')),
      adminSectionButton(AdminSection.policies, s.t('Policies', 'السياسات')),
    ]);
  }

  Widget adminSectionButton(AdminSection section, String label) {
    final selected = selectedSection == section;
    return FilledButton.tonal(
      style: FilledButton.styleFrom(
        backgroundColor: selected ? maroon : const Color(0xFFFFF1CF),
        foregroundColor: selected ? Colors.white : const Color(0xFF8A6726),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
      onPressed: () => setState(() => selectedSection = section),
      child: Text(label),
    );
  }

  bool get showLegacyAdminBlocks => false;

  List<BranchRecord> get filteredBranches {
    final query = branchSearchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return adminBranches;
    }
    return adminBranches.where((branch) {
      return branch.name.toLowerCase().contains(query) ||
          branch.contact.toLowerCase().contains(query) ||
          branch.hours.toLowerCase().contains(query);
    }).toList();
  }

  void _loadPolicy(int index) {
    selectedPolicyIndex = index;
    final policy = policies[index];
    policyEnNameController.text = policy.nameEn;
    policyArNameController.text = policy.nameAr;
    policyEnDetailController.text = policy.detailEn;
    policyArDetailController.text = policy.detailAr;
  }

  void savePolicy() {
    policies[selectedPolicyIndex] = PolicyRecord(
      nameEn: policyEnNameController.text.trim(),
      nameAr: policyArNameController.text.trim(),
      detailEn: policyEnDetailController.text.trim(),
      detailAr: policyArDetailController.text.trim(),
    );
    notifySaved(s.t('Policy saved.', 'تم حفظ السياسة.'));
    setState(() {});
  }

  void notifySaved(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  List<String> get configuredSlots {
    final slots = slotListController.text
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    return slots.isEmpty ? defaultBookingSlots : slots;
  }

  Map<String, Map<String, int>> generatedScheduleRows() {
    final slots = configuredSlots;
    final today = DateTime.now();
    final rows = <String, Map<String, int>>{};
    for (var i = 1; i <= 30; i++) {
      final day =
          DateTime(today.year, today.month, today.day).add(Duration(days: i));
      if (!workingDays.contains(weekdayName(day))) continue;
      rows[formatVisitDate(day)] = {
        for (var index = 0; index < slots.length; index++)
          slots[index]: int.tryParse(
                  capacityControllers[index % capacityControllers.length]
                      .text
                      .trim()) ??
              2,
      };
    }
    return rows;
  }

  Future<void> saveBookingSchedule({bool regenerate = false}) async {
    final next = BookingScheduleSettings(
      enabled: appointmentEnabled,
      slots: configuredSlots,
      workingDays: workingDays.toSet(),
      rows: regenerate ? generatedScheduleRows() : s.bookingSchedule.rows,
    );
    await s.updateBookingSchedule(next);
    notifySaved(s.t('Booking schedule saved.', 'تم حفظ جدول الحجوزات.'));
    setState(() {});
  }

  Future<void> deactivateScheduleDate(String date) async {
    final rows = {
      for (final entry in s.bookingSchedule.rows.entries)
        entry.key: Map<String, int>.from(entry.value)
    };
    rows[date] = {
      for (final slot in s.bookingSchedule.slots) slot: 0,
    };
    await s.updateBookingSchedule(BookingScheduleSettings(
      enabled: s.bookingSchedule.enabled,
      slots: s.bookingSchedule.slots,
      workingDays: s.bookingSchedule.workingDays,
      rows: rows,
    ));
    notifySaved(s.t('Date deactivated.', 'تم إيقاف التاريخ.'));
    setState(() {});
  }

  String dayLabel(String day) => switch (day) {
        'Sunday' => s.t('Sunday', 'الأحد'),
        'Monday' => s.t('Monday', 'الاثنين'),
        'Tuesday' => s.t('Tuesday', 'الثلاثاء'),
        'Wednesday' => s.t('Wednesday', 'الأربعاء'),
        'Thursday' => s.t('Thursday', 'الخميس'),
        'Friday' => s.t('Friday', 'الجمعة'),
        'Saturday' => s.t('Saturday', 'السبت'),
        _ => day,
      };
}

class BranchRecord {
  const BranchRecord(
      {required this.name,
      required this.locationLink,
      required this.hours,
      required this.contact,
      required this.statusEn,
      required this.statusAr});
  final String name;
  final String locationLink;
  final String hours;
  final String contact;
  final String statusEn;
  final String statusAr;
}

class PolicyRecord {
  const PolicyRecord(
      {required this.nameEn,
      required this.nameAr,
      required this.detailEn,
      required this.detailAr});
  final String nameEn;
  final String nameAr;
  final String detailEn;
  final String detailAr;
}

class ScheduleRow {
  const ScheduleRow(
      {required this.date,
      required this.dayEn,
      required this.dayAr,
      required this.capacities});
  final String date;
  final String dayEn;
  final String dayAr;
  final List<int> capacities;
}

const adminBranches = <BranchRecord>[
  BranchRecord(
      name: 'Al-Yarmouk',
      locationLink: 'https://maps.app.goo.gl/zX2gUzzkbY1vwcj58',
      hours:
          'Our Yarmouk branch is currently closed until further notice. You can collect your orders from our Hessa Al Mubarak branch.',
      contact: '98700133',
      statusEn: 'Active',
      statusAr: 'نشط'),
  BranchRecord(
      name: 'AlHamra Tower - Premium',
      locationLink: 'https://maps.app.goo.gl/CrwaAmhQ4QhxB7CF7',
      hours: '10 am to 10 pm',
      contact: '99170282',
      statusEn: 'Active',
      statusAr: 'نشط'),
  BranchRecord(
      name: 'City Hypermarket - Dasma',
      locationLink: 'https://maps.app.goo.gl/Cr2GAN4Qfm1RpDV98',
      hours: '10 am to 10 pm',
      contact: '99798454',
      statusEn: 'Active',
      statusAr: 'نشط'),
  BranchRecord(
      name: 'Hessa AlMubarak District',
      locationLink: 'https://maps.app.goo.gl/tWoboCr2EhEWQYXPA',
      hours: '24 / 7',
      contact: '96957896',
      statusEn: 'Active',
      statusAr: 'نشط'),
  BranchRecord(
      name: 'Promenade Mall - Hawally',
      locationLink: 'https://maps.app.goo.gl/8KiTZcs4Sc3ByYdQ6',
      hours: '10 am to 10 pm',
      contact: '98774155',
      statusEn: 'Active',
      statusAr: 'نشط'),
  BranchRecord(
      name: 'Qortuba',
      locationLink: 'https://maps.app.goo.gl/imbpgBzihkcw2VpFA',
      hours: '10 am to 10 pm',
      contact: '98740699',
      statusEn: 'Active',
      statusAr: 'نشط'),
  BranchRecord(
      name: 'The Avenues - Al Rai',
      locationLink: 'https://maps.app.goo.gl/oLSD2Kh8WFmvgmFq7',
      hours: '10 am to 10 pm',
      contact: '98716137',
      statusEn: 'Active',
      statusAr: 'نشط'),
  BranchRecord(
      name: 'West Mishref',
      locationLink: 'https://maps.app.goo.gl/FdfvesvAtDAo8DzP6',
      hours: '10 am to 10 pm',
      contact: '98741904',
      statusEn: 'Active',
      statusAr: 'نشط'),
  BranchRecord(
      name: 'Zahra Complex - Salmiya',
      locationLink: 'https://maps.app.goo.gl/QdFCcnhsYDcUkS22A',
      hours: '10 am to 10 pm',
      contact: '98765532',
      statusEn: 'Active',
      statusAr: 'نشط'),
];

const adminPolicies = <PolicyRecord>[
  PolicyRecord(
    nameEn: 'Alteration & Repair',
    nameAr: 'التعديلات والإصلاحات',
    detailEn:
        'Thank you for choosing Tailor Express home service.\n\nWe are happy to serve you and we trust you will find quality and speed in our service.\n\nDear customer, we always aim for your satisfaction. Please review the services and measurements shown on the invoice and confirm that all registered information is correct.\n\nHome service fees include one visit only.\n\nIf an adjustment is needed for the same service, we will be happy to receive you at one of our branches for one free adjustment within 7 days from the receiving date.\n\nWhen the team arrives at the scheduled appointment, waiting time is limited to 10 minutes only. If no one is available, the team may leave and the paid amount is non-refundable.\n\nVisit rescheduling must be requested at least 3 hours before the appointment.\n\nThank you for your trust. We look forward to serving you.',
    detailAr:
        'شكراً لاختياركم خدمة تيلور اكسبرس المنزلية.\n\nنسعد بخدمتكم وبثقتكم في جودة وسرعة خدماتنا.\n\nعزيزنا العميل، نسعى دائماً لرضاكم، لذا نرجو مراجعة الخدمات والقياسات الموضحة في الفاتورة والتأكد من صحة جميع المعلومات المسجلة.\n\nرسوم الخدمة المنزلية تشمل زيارة واحدة فقط.\n\nفي حال الحاجة للتعديل على نفس الخدمة، يسعدنا استقبالكم في أحد فروعنا لإجراء تعديل مجاناً خلال 7 أيام من تاريخ الاستلام.\n\nعند وصول الفريق في الموعد المحدد يمكن الانتظار 10 دقائق فقط، وفي حال عدم التواجد يحق للفريق المغادرة ويعتبر المبلغ غير مسترد.\n\nتغيير موعد الزيارة يجب أن يكون قبل الموعد بـ 3 ساعات على الأقل.\n\nنشكركم على ثقتكم، ونتطلع دائماً لخدمتكم.',
  ),
  PolicyRecord(
    nameEn: 'Order Cancellation',
    nameAr: 'إلغاء الطلب',
    detailEn:
        'Acceptance of the invoice confirms the customer\'s agreement to all services, measurements, pricing, and policies.\n\nPayments are made in advance, and once tailoring or repair work has begun, order cancellations are not permitted.\n\nIn the event of service delays, cancellations are not allowed under any circumstances.',
    detailAr:
        'يعد قبول الفاتورة إقراراً من العميل بالموافقة على جميع الخدمات والمقاسات والأسعار والسياسات المعتمدة.\n\nتسدد الدفعات مقدماً، وبمجرد البدء في أعمال الخياطة أو الإصلاح، لا يسمح بإلغاء الطلب.\n\nفي حال حدوث أي تأخير في تنفيذ الخدمة، لا يسمح بالإلغاء تحت أي ظرف من الظروف.',
  ),
  PolicyRecord(
    nameEn: 'Appointment Rescheduling',
    nameAr: 'إعادة جدولة المواعيد',
    detailEn:
        'For home services, the customer will receive a confirmation link to confirm the appointment.\n\nA fixed home services fee applies and is determined by location.\n\nAppointments may be cancelled or rescheduled only if the request is made at least 3 hours before the scheduled time.\n\nRequests made after this period will not be eligible for changes or fee refunds.',
    detailAr:
        'في حال طلب خدمة منزلية، سيستلم العميل رابط تأكيد لتأكيد الموعد.\n\nيتم تطبيق رسوم ثابتة للخدمة المنزلية، ويتم تحديدها حسب الموقع.\n\nيمكن إلغاء الموعد أو إعادة جدولة الموعد فقط في حال تقديم الطلب قبل 3 ساعات على الأقل من الوقت المحدد.\n\nالطلبات المقدمة بعد هذه المدة لن تكون مؤهلة للتعديل أو استرداد الرسوم.',
  ),
  PolicyRecord(
    nameEn: 'Delivery & Pickup',
    nameAr: 'التوصيل والاستلام',
    detailEn:
        'Customers are responsible for collecting their items from the company\'s branches once services are completed.\n\nThe expected completion time may range from 15 minutes to two weeks, depending on the type and volume of services, and timelines may change without prior notice due to circumstances beyond the company\'s control.\n\nThe company disclaims all responsibility for any items that are not collected within 7 days from the completion or notification date.',
    detailAr:
        'يتحمل العملاء مسؤولية استلام قطعهم من فروع الشركة بعد إتمام الخدمات.\n\nقد تتراوح مدة الإنجاز المتوقعة من 15 دقيقة إلى أسبوعين، وذلك بحسب نوع وحجم الخدمة، وقد تتغير المدة دون إشعار مسبق بسبب ظروف خارجة عن إرادة الشركة.\n\nتخلي الشركة مسؤوليتها عن أي قطع لم يتم استلامها خلال 7 أيام من تاريخ الإنجاز أو الإخطار.',
  ),
  PolicyRecord(
    nameEn: 'Refund',
    nameAr: 'استرداد المبالغ',
    detailEn:
        'All service fees are non-refundable under any circumstances, including alterations, repairs, tailoring, delays, or unintentional damage.\n\nThe company does not provide compensation for the original value of items.\n\nHome service fees are also non-refundable, except in cases where the appointment is cancelled at least three hours before the scheduled time.',
    detailAr:
        'جميع رسوم الخدمات غير قابلة للاسترداد تحت أي ظرف من الظروف، بما في ذلك التعديلات، والإصلاحات، والخياطة، والتأخير، أو التلف غير المقصود.\n\nلا تتحمل الشركة مسؤولية أو تعويض القيمة الأصلية للقطع.\n\nرسوم الخدمة المنزلية غير قابلة للاسترداد أيضاً، باستثناء الحالات التي يتم فيها إلغاء الموعد قبل ثلاث ساعات على الأقل من الوقت المحدد.',
  ),
];

const scheduleRows = <ScheduleRow>[
  ScheduleRow(
      date: '31-07-2026',
      dayEn: 'Fri',
      dayAr: 'الجمعة',
      capacities: [1, 2, 2, 2, 2, 2, 2, 2, 2]),
  ScheduleRow(
      date: '30-07-2026',
      dayEn: 'Thu',
      dayAr: 'الخميس',
      capacities: [1, 2, 2, 2, 2, 2, 2, 2, 2]),
  ScheduleRow(
      date: '29-07-2026',
      dayEn: 'Wed',
      dayAr: 'الأربعاء',
      capacities: [1, 1, 0, 0, 0, 0, 0, 0, 0]),
];

Widget adminCard(BuildContext context,
        {required String title, required Widget child, Widget? action}) =>
    Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 12,
              runSpacing: 12,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                if (action != null) action,
              ]),
          const SizedBox(height: 14),
          child,
        ]),
      ),
    );

Widget settingsBlock(BuildContext context,
        {required String title, required Widget child, Widget? action}) =>
    Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6D9BE)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 12,
            runSpacing: 12,
            children: [
              Text(title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              if (action != null) action,
            ]),
        const SizedBox(height: 14),
        child,
      ]),
    );

Widget sectionChip(String label) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
          color: const Color(0xFFFFF1CF),
          borderRadius: BorderRadius.circular(999)),
      child: Text(label,
          style: const TextStyle(
              color: Color(0xFF8A6726), fontWeight: FontWeight.w700)),
    );

Widget smallSaveButton(VoidCallback onPressed) => ElevatedButton(
      style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
      onPressed: onPressed,
      child: const Text('SAVE'),
    );

Widget tinyActionButton(String label) => ElevatedButton(
      style: ElevatedButton.styleFrom(
          minimumSize: Size.zero,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
      onPressed: () {},
      child: Text(label),
    );

Widget compactTableButton({
  required String label,
  required VoidCallback? onPressed,
}) =>
    OutlinedButton(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.standard,
      ),
      onPressed: onPressed,
      child: Text(label, overflow: TextOverflow.ellipsis),
    );

DataColumn dataLabel(String label) => DataColumn(
    label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)));

Widget metric(String label, String value) => SizedBox(
    width: 220,
    child: Card(
        child: Padding(
            padding: const EdgeInsets.all(18),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(value,
                  style: const TextStyle(
                      fontSize: 26, fontWeight: FontWeight.w700, color: ink)),
              const SizedBox(height: 6),
              Text(label)
            ]))));
Widget bullet(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Icon(Icons.circle, size: 7, color: gold)),
      const SizedBox(width: 10),
      Expanded(child: Text(text))
    ]));
Widget badge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
        color: color.withOpacity(.12), borderRadius: BorderRadius.circular(12)),
    child: Text(text,
        style: TextStyle(color: color, fontWeight: FontWeight.w700)));
String buildTrackingLink(String id) {
  final origin = html.window.location.origin;
  return '$origin/track?order=${Uri.encodeComponent(id)}';
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

void main() => runApp(TailorWebApp(state: AppState()));

const gold = Color(0xFFC7A04B);
const ink = Color(0xFF17130E);
const sand = Color(0xFFF7F1E5);

enum Role { admin, employee, tailor, driver }
enum Stage { newBooking, assigned, onWay, tailoring, ready, delivered }

Role? roleFromSlug(String slug) {
  for (final role in Role.values) {
    if (role.name == slug) return role;
  }
  return null;
}

String roleLabel(Role role, bool ar) => switch (role) {
      Role.admin => ar ? 'الإدارة' : 'Admin',
      Role.employee => ar ? 'الموظف' : 'Employee',
      Role.tailor => ar ? 'الخياط' : 'Tailor',
      Role.driver => ar ? 'السائق' : 'Driver',
    };

String stageLabel(Stage stage, bool ar) => switch (stage) {
      Stage.newBooking => ar ? 'جديد' : 'New',
      Stage.assigned => ar ? 'تم التعيين' : 'Assigned',
      Stage.onWay => ar ? 'السائق في الطريق' : 'Driver on the way',
      Stage.tailoring => ar ? 'قيد الخياطة' : 'In tailoring',
      Stage.ready => ar ? 'جاهز للتسليم' : 'Ready for delivery',
      Stage.delivered => ar ? 'تم التسليم' : 'Delivered',
    };

Color stageColor(Stage stage) => switch (stage) {
      Stage.newBooking => const Color(0xFF977527),
      Stage.assigned => const Color(0xFF2D8AB1),
      Stage.onWay => const Color(0xFF2A63B5),
      Stage.tailoring => const Color(0xFF6D58A5),
      Stage.ready => const Color(0xFF3A9962),
      Stage.delivered => const Color(0xFF2D8A57),
    };

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
  final String driver;
  final String tailor;
  final Stage stage;
  final double lat;
  final double lng;
  final String notes;
  final List<String> timeline;

  String area(bool isArabic) => isArabic ? areaAr : areaEn;
}

class Complaint {
  const Complaint(this.orderId, this.customer, this.typeEn, this.typeAr, this.message, this.date);
  final String orderId;
  final String customer;
  final String typeEn;
  final String typeAr;
  final String message;
  final String date;
  String type(bool isArabic) => isArabic ? typeAr : typeEn;
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

const complaints = <Complaint>[
  Complaint('TE-2401', 'Sara Alhamad', 'Appointment delay', 'تأخير موعد', 'Customer asked for a tighter visit window before evening pickup.', '29-07-2026, 02:18 PM'),
  Complaint('TE-2402', 'Rana', 'Quality follow-up', 'متابعة الجودة', 'Customer wants confirmation before final delivery dispatch.', '28-07-2026, 09:54 PM'),
  Complaint('TE-2404', 'Abeer Alajmi', 'Order issue', 'مشكلة في الطلب', 'Requested an employee callback regarding fitting notes.', '27-07-2026, 03:31 PM'),
];

const seedOrders = <Order>[
  Order(
    id: 'TE-2401',
    customer: 'Sara Alhamad',
    mobile: '55868777',
    areaEn: 'North West Sulaibikhat',
    areaAr: 'شمال غرب الصليبيخات',
    address: 'North West Sulaibikhat, Block 4, Street 18, House 12',
    service: 'Alterations',
    preference: 'Women tailor',
    window: '29-07-2026, 7:30 PM - 8:00 PM',
    driver: 'Omar',
    tailor: 'AFROZ',
    stage: Stage.onWay,
    lat: 29.3606,
    lng: 47.9275,
    notes: 'Evening pickup and quick size check.',
    timeline: ['28-07-2026 08:12 PM • Booking approved', '29-07-2026 10:10 AM • Tailor assigned', '29-07-2026 06:58 PM • Driver dispatched'],
  ),
  Order(
    id: 'TE-2402',
    customer: 'Rana',
    mobile: '50904449',
    areaEn: 'Shaab',
    areaAr: 'الشعب',
    address: 'Shaab, Block 1, Street 10, Villa 6',
    service: 'Occasion fitting',
    preference: 'Women tailor',
    window: '29-07-2026, 5:00 PM - 5:30 PM',
    driver: 'Omar',
    tailor: 'AFROZ',
    stage: Stage.ready,
    lat: 29.3442,
    lng: 48.0045,
    notes: 'Evening dress fitting before travel.',
    timeline: ['27-07-2026 07:20 PM • Booking approved', '28-07-2026 01:15 PM • Tailoring in progress', '29-07-2026 03:40 PM • Ready for delivery'],
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
    timeline: ['26-07-2026 10:40 AM • Booking approved', '27-07-2026 04:15 PM • Tailoring in progress', '29-07-2026 03:02 PM • Delivered to customer'],
  ),
  Order(
    id: 'TE-2404',
    customer: 'Abeer Alajmi',
    mobile: '55881373',
    areaEn: 'West Abdullah Mubarak',
    areaAr: 'غرب عبدالله المبارك',
    address: 'West Abdullah Mubarak, Block 5, Street 512, House 230',
    service: 'Alterations',
    preference: 'No preference',
    window: '30-07-2026, 6:00 PM - 7:00 PM',
    driver: 'Pending assignment',
    tailor: 'AFROZ',
    stage: Stage.assigned,
    lat: 29.2857,
    lng: 47.8890,
    notes: 'Customer prefers a call before arrival.',
    timeline: ['29-07-2026 09:30 AM • Booking approved', '29-07-2026 11:00 AM • Tailor reserved'],
  ),
];

class AppState extends ChangeNotifier {
  bool isArabic = false;
  Role? role;
  String user = '';
  final List<Order> orders = List<Order>.from(seedOrders);

  String t(String en, String ar) => isArabic ? ar : en;
  TextDirection get dir => isArabic ? TextDirection.rtl : TextDirection.ltr;
  bool get signedIn => role != null;

  void toggleLang() {
    isArabic = !isArabic;
    notifyListeners();
  }

  bool login(Role nextRole, String name, String pass) {
    final ok = switch (nextRole) {
      Role.admin => name == 'admin' && pass == 'Admin123!',
      Role.employee => name == 'ops' && pass == 'Ops123!',
      Role.tailor => name == 'afroz' && pass == 'Tailor123!',
      Role.driver => name == 'omar' && pass == 'Driver123!',
    };
    if (!ok) return false;
    role = nextRole;
    user = name;
    notifyListeners();
    return true;
  }

  void logout() {
    role = null;
    user = '';
    notifyListeners();
  }

  bool canOpen(Role target) => role == target;

  Order? byId(String id) {
    for (final order in orders) {
      if (order.id.toLowerCase() == id.trim().toLowerCase()) return order;
    }
    return null;
  }

  Order createBooking({
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
  }) {
    final id = 'TE-${2400 + orders.length + 1}';
    final order = Order(
      id: id,
      customer: customer,
      mobile: mobile,
      areaEn: area.en,
      areaAr: area.ar,
      address: isArabic ? '${area.ar}، قطعة $block، شارع $street، مبنى $building' : '${area.en}, Block $block, Street $street, Building $building',
      service: service,
      preference: preference,
      window: window,
      driver: t('Pending assignment', 'بانتظار التعيين'),
      tailor: t('Pending assignment', 'بانتظار التعيين'),
      stage: Stage.newBooking,
      lat: 29.3759,
      lng: 47.9774,
      notes: notes,
      timeline: [t('Now • Booking submitted', 'الآن • تم إرسال الحجز'), t('Next • Operations will assign tailor and driver', 'لاحقاً • سيتم تعيين الخياط والسائق')],
    );
    orders.insert(0, order);
    notifyListeners();
    return order;
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
            colorScheme: ColorScheme.fromSeed(seedColor: gold),
            scaffoldBackgroundColor: sand,
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2D6BC))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: gold)),
            ),
          ),
          builder: (context, child) => Directionality(textDirection: state.dir, child: child ?? const SizedBox.shrink()),
          onGenerateRoute: (settings) {
            final uri = Uri.parse(settings.name ?? '/');
            return MaterialPageRoute(builder: (_) => routeFor(uri));
          },
        );
      },
    );
  }

  Widget routeFor(Uri uri) {
    final path = uri.path.isEmpty ? '/' : uri.path;
    if (path == '/' || path == '/booking') return BookingPage(state: state);
    if (path == '/track') return TrackPage(state: state, initialId: uri.queryParameters['order']);
    if (path == '/staff') return StaffHubPage(state: state);
    if (path.startsWith('/login/')) {
      final role = roleFromSlug(uri.pathSegments.length > 1 ? uri.pathSegments[1] : '');
      if (role != null) return LoginPage(state: state, role: role);
    }
    if (path.startsWith('/dashboard/')) {
      final role = roleFromSlug(uri.pathSegments.length > 1 ? uri.pathSegments[1] : '');
      if (role == null || !state.canOpen(role)) return LockedPage(state: state, role: role);
      return DashboardPage(state: state, role: role);
    }
    return BookingPage(state: state);
  }
}

class Shell extends StatelessWidget {
  const Shell({super.key, required this.state, required this.title, required this.subtitle, required this.body, this.public = false, this.role});
  final AppState state;
  final String title;
  final String subtitle;
  final Widget body;
  final bool public;
  final Role? role;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1240),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Wrap(alignment: WrapAlignment.spaceBetween, spacing: 12, runSpacing: 12, children: [
                  brand(),
                  Wrap(spacing: 10, runSpacing: 10, children: [
                    if (public) nav(context, state.t('Book Service', 'احجز الخدمة'), '/booking'),
                    if (public) nav(context, state.t('Track Order', 'تتبع الطلب'), '/track'),
                    if (role != null && state.signedIn) Chip(label: Text('${roleLabel(role!, state.isArabic)} • ${state.user}')),
                    OutlinedButton(onPressed: state.toggleLang, child: Text(state.isArabic ? 'EN' : 'AR')),
                    if (role != null && state.signedIn)
                      ElevatedButton(onPressed: () { final next = role!; state.logout(); Navigator.of(context).pushNamedAndRemoveUntil('/login/${next.name}', (r) => false); }, child: Text(state.t('Sign out', 'تسجيل الخروج'))),
                  ]),
                ]),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(28), gradient: const LinearGradient(colors: [Color(0xFF15110D), Color(0xFF302518)])),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('TAILOR EXPRESS', style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: 2)),
                    const SizedBox(height: 12),
                    Text(title, style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w700, height: 1.05)),
                    const SizedBox(height: 12),
                    Text(subtitle, style: const TextStyle(color: Color(0xFFE6D8BD), height: 1.5)),
                  ]),
                ),
                const SizedBox(height: 20),
                body,
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

Widget brand() => const Row(mainAxisSize: MainAxisSize.min, children: [
  Icon(Icons.content_cut, color: gold),
  SizedBox(width: 10),
  Text('TAILOR EXPRESS', style: TextStyle(color: ink, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
]);

Widget nav(BuildContext context, String label, String path) {
  final current = (ModalRoute.of(context)?.settings.name ?? '').startsWith(path) ||
      (path == '/booking' && (ModalRoute.of(context)?.settings.name == '/' || ModalRoute.of(context)?.settings.name == '/booking'));
  return OutlinedButton(
    style: OutlinedButton.styleFrom(backgroundColor: current ? const Color(0xFFFFF4DD) : Colors.white),
    onPressed: () => Navigator.of(context).pushReplacementNamed(path),
    child: Text(label),
  );
}

class BookingPage extends StatefulWidget {
  const BookingPage({super.key, required this.state});
  final AppState state;
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
  String service = 'Alterations';
  String preference = 'Women tailor';
  String window = '5:00 PM - 6:00 PM';

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
    return Shell(
      state: s,
      public: true,
      title: s.t('Public booking for all Kuwait areas with private staff portals behind separate links.', 'حجز عام لكل مناطق الكويت مع بوابات موظفين خاصة على روابط مستقلة.'),
      subtitle: s.t('Customers only see booking and tracking. Admin, employee, tailor and driver dashboards require different links and role credentials.', 'العميل يرى الحجز والتتبع فقط. أما الإدارة والموظف والخياط والسائق فلهم روابط مختلفة وبيانات دخول مستقلة.'),
      body: Wrap(spacing: 18, runSpacing: 18, children: [
        SizedBox(width: 760, child: Card(child: Padding(padding: const EdgeInsets.all(22), child: Form(key: form, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s.t('Book a home visit', 'احجز زيارة منزلية'), style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 14),
          Wrap(spacing: 12, runSpacing: 12, children: [
            field(name, s.t('Customer name', 'اسم العميل')),
            field(mobile, s.t('Mobile number', 'رقم الهاتف'), phone: true),
            SizedBox(width: 230, child: DropdownButtonFormField<Area>(value: area, menuMaxHeight: 380, decoration: InputDecoration(labelText: s.t('Area', 'المنطقة')), items: [for (final item in kuwaitAreas) DropdownMenuItem(value: item, child: Text(item.name(s.isArabic)))], onChanged: (v) => setState(() => area = v!))),
            field(block, s.t('Block', 'قطعة'), small: true),
            field(street, s.t('Street', 'شارع'), small: true),
            field(building, s.t('Building / House', 'مبنى / منزل'), small: true),
            drop(s, s.t('Service', 'الخدمة'), service, ['Alterations', 'Tailoring', 'Occasion fitting', 'Urgent repair'], (v) => setState(() => service = v!)),
            drop(s, s.t('Tailor preference', 'تفضيل الخياط'), preference, ['Women tailor', 'Men tailor', 'No preference'], (v) => setState(() => preference = v!)),
            drop(s, s.t('Visit window', 'موعد الزيارة'), window, ['12:00 PM - 1:00 PM', '2:00 PM - 3:00 PM', '4:00 PM - 5:00 PM', '5:00 PM - 6:00 PM', '7:00 PM - 8:00 PM'], (v) => setState(() => window = v!)),
          ]),
          const SizedBox(height: 12),
          TextFormField(controller: notes, maxLines: 4, decoration: InputDecoration(labelText: s.t('Notes', 'ملاحظات'))),
          const SizedBox(height: 16),
          Wrap(spacing: 12, runSpacing: 12, children: [
            ElevatedButton(onPressed: submit, child: Text(s.t('Review policy & pay', 'راجع السياسة وانتقل للدفع'))),
            OutlinedButton(onPressed: () => showPolicyPreview(), child: Text(s.t('Preview policies', 'عرض السياسات'))),
            OutlinedButton(onPressed: () => Navigator.of(context).pushReplacementNamed('/track'), child: Text(s.t('Open tracking', 'افتح التتبع'))),
          ]),
        ]))))),
        SizedBox(width: 430, child: Card(child: Padding(padding: const EdgeInsets.all(22), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s.t('What happens before payment', 'ما الذي يحدث قبل الدفع'), style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          bullet(s.t('Policies are shown before payment and must be accepted.', 'يتم عرض السياسات قبل الدفع ويجب الموافقة عليها.')) ,
          bullet(s.t('The customer moves to payment only after agreeing.', 'ينتقل العميل إلى الدفع فقط بعد الموافقة.')) ,
          bullet(s.t('Admin policy text is reused here automatically.', 'يتم استخدام نص سياسات الإدارة هنا تلقائياً.')) ,
          for (final policy in adminPolicies) bullet(s.isArabic ? policy.nameAr : policy.nameEn),
        ])))),
      ]),
    );
  }

  Widget field(TextEditingController c, String label, {bool phone = false, bool small = false}) => SizedBox(
    width: small ? 150 : 230,
    child: TextFormField(
      controller: c,
      keyboardType: phone ? TextInputType.phone : TextInputType.text,
      validator: (v) => v == null || v.trim().isEmpty ? widget.state.t('Required', 'مطلوب') : null,
      decoration: InputDecoration(labelText: label),
    ),
  );

  Widget drop(AppState s, String label, String value, List<String> items, ValueChanged<String?> onChanged) => SizedBox(
    width: 230,
    child: DropdownButtonFormField<String>(value: value, decoration: InputDecoration(labelText: label), items: [for (final item in items) DropdownMenuItem(value: item, child: Text(item))], onChanged: onChanged),
  );

  void submit() {
    if (!form.currentState!.validate()) return;
    showPolicyGate();
  }

  Future<void> showPolicyPreview() async {
    final s = widget.state;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.t('Policies before payment', 'السياسات قبل الدفع')),
        content: SizedBox(
          width: 860,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.t('The customer must review these policy items before moving to payment.', 'يجب على العميل مراجعة هذه السياسات قبل الانتقال إلى الدفع.')),
                const SizedBox(height: 14),
                for (final policy in adminPolicies) policyCard(policy),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(s.t('Close', 'إغلاق')),
          ),
        ],
      ),
    );
  }

  Future<void> showPolicyGate() async {
    final s = widget.state;
    var agreed = false;
    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(s.t('Review policy before payment', 'راجع السياسة قبل الدفع')),
          content: SizedBox(
            width: 860,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.t('Payment is locked until the customer agrees to the booking policies below.', 'يتم قفل الدفع حتى يوافق العميل على سياسات الحجز التالية.')),
                  const SizedBox(height: 14),
                  for (final policy in adminPolicies) policyCard(policy),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    value: agreed,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (value) => setDialogState(() => agreed = value ?? false),
                    title: Text(s.t('I have read and agree to these policies before payment.', 'لقد قرأت هذه السياسات وأوافق عليها قبل الدفع.')),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(s.t('Back', 'رجوع')),
            ),
            ElevatedButton(
              onPressed: agreed ? () => Navigator.of(context).pop(true) : null,
              child: Text(s.t('Proceed to payment', 'الانتقال إلى الدفع')),
            ),
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
    var method = 'KNET';
    final paid = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(s.t('Payment', 'الدفع')),
          content: SizedBox(
            width: 540,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.t('Choose a payment method after agreeing to the policies.', 'اختر طريقة الدفع بعد الموافقة على السياسات.')),
                const SizedBox(height: 14),
                RadioListTile<String>(
                  value: 'KNET',
                  groupValue: method,
                  onChanged: (value) => setDialogState(() => method = value ?? 'KNET'),
                  title: const Text('KNET'),
                ),
                RadioListTile<String>(
                  value: 'Visa / MasterCard',
                  groupValue: method,
                  onChanged: (value) => setDialogState(() => method = value ?? 'KNET'),
                  title: const Text('Visa / MasterCard'),
                ),
                RadioListTile<String>(
                  value: s.t('Cash on pickup', 'نقداً عند الاستلام'),
                  groupValue: method,
                  onChanged: (value) => setDialogState(() => method = value ?? 'KNET'),
                  title: Text(s.t('Cash on pickup', 'نقداً عند الاستلام')),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7E7),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.t('Home service visit', 'زيارة الخدمة المنزلية'), style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text(s.t('Demo amount: KD 3.500', 'المبلغ التجريبي: 3.500 د.ك')),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(s.t('Back', 'رجوع')),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(method),
              child: Text(s.t('Pay now', 'ادفع الآن')),
            ),
          ],
        ),
      ),
    );

    if (paid == null || !mounted) return;

    final paymentNote = s.isArabic ? 'الدفع: $paid' : 'Payment: $paid';
    final mergedNotes = notes.text.trim().isEmpty ? paymentNote : '${notes.text.trim()} | $paymentNote';
    final order = widget.state.createBooking(
      customer: name.text.trim(),
      mobile: mobile.text.trim(),
      area: area,
      block: block.text.trim(),
      street: street.text.trim(),
      building: building.text.trim(),
      service: service,
      preference: preference,
      window: window,
      notes: mergedNotes,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(s.t('Payment completed. Booking created.', 'تم الدفع وإنشاء الحجز.'))),
    );
    Navigator.of(context).pushReplacementNamed('/track?order=${order.id}');
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
        border: Border.all(color: const Color(0xFFE6D9BE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.isArabic ? policy.nameAr : policy.nameEn,
            style: const TextStyle(color: ink, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(s.isArabic ? policy.detailAr : policy.detailEn),
        ],
      ),
    );
  }
}
class TrackPage extends StatefulWidget {
  const TrackPage({super.key, required this.state, this.initialId});
  final AppState state;
  final String? initialId;
  @override
  State<TrackPage> createState() => _TrackPageState();
}

class _TrackPageState extends State<TrackPage> {
  late final TextEditingController id = TextEditingController(text: widget.initialId ?? '');
  Order? order;

  @override
  void initState() {
    super.initState();
    if ((widget.initialId ?? '').isNotEmpty) order = widget.state.byId(widget.initialId!);
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
      title: s.t('Customer-safe tracking page for pickup, tailoring and delivery status.', 'صفحة تتبع آمنة للعميل لحالة الاستلام والخياطة والتوصيل.'),
      subtitle: s.t('Drivers can share this route with customers. The customer still cannot see internal dashboards.', 'يمكن للسائق مشاركة هذا الرابط مع العميل، لكن العميل لا يمكنه رؤية اللوحات الداخلية.'),
      body: Wrap(spacing: 18, runSpacing: 18, children: [
        SizedBox(width: 360, child: Card(child: Padding(padding: const EdgeInsets.all(22), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s.t('Track order', 'تتبع الطلب'), style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          TextField(controller: id, decoration: InputDecoration(labelText: s.t('Order ID', 'رقم الطلب'))),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: search, child: Text(s.t('Search', 'بحث'))),
          const SizedBox(height: 12),
          Wrap(spacing: 8, children: [for (final item in widget.state.orders.take(4)) ActionChip(label: Text(item.id), onPressed: () { id.text = item.id; search(); })]),
        ])))),
        SizedBox(width: 820, child: Card(child: Padding(padding: const EdgeInsets.all(22), child: order == null ? Text(s.t('Search an order to show status, map links and assigned team.', 'ابحث عن طلب لإظهار الحالة وروابط الخريطة والفريق المخصص.')) : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 12, runSpacing: 12, children: [
            Text('${s.t('Order', 'الطلب')} ${order!.id}', style: Theme.of(context).textTheme.headlineSmall),
            badge(stageLabel(order!.stage, s.isArabic), stageColor(order!.stage)),
          ]),
          const SizedBox(height: 12),
          Text('${order!.customer} • ${order!.mobile}'),
          const SizedBox(height: 10),
          bullet('${s.t('Area', 'المنطقة')}: ${order!.area(s.isArabic)}'),
          bullet('${s.t('Address', 'العنوان')}: ${order!.address}'),
          bullet('${s.t('Service', 'الخدمة')}: ${order!.service}'),
          bullet('${s.t('Tailor', 'الخياط')}: ${order!.tailor}'),
          bullet('${s.t('Driver', 'السائق')}: ${order!.driver}'),
          bullet('${s.t('Visit window', 'موعد الزيارة')}: ${order!.window}'),
          const SizedBox(height: 12),
          Wrap(spacing: 12, runSpacing: 12, children: [
            ElevatedButton(onPressed: () => openMap(order!, true), child: const Text('Google Maps')),
            OutlinedButton(onPressed: () => openMap(order!, false), child: const Text('OpenStreetMap')),
            OutlinedButton(onPressed: () => copy(buildTrackingLink(order!.id), s.t('Tracking link copied.', 'تم نسخ رابط التتبع.')), child: Text(s.t('Copy tracking link', 'نسخ رابط التتبع'))),
          ]),
          const SizedBox(height: 18),
          Text(s.t('Timeline', 'خط سير الطلب'), style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          for (final step in order!.timeline) bullet(step),
        ])))),
      ]),
    );
  }

  void search() => setState(() => order = widget.state.byId(id.text));

  Future<void> copy(String text, String message) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> openMap(Order order, bool google) async {
    final url = google ? 'https://www.google.com/maps/search/?api=1&query=${order.lat},${order.lng}' : 'https://www.openstreetmap.org/?mlat=${order.lat}&mlon=${order.lng}#map=16/${order.lat}/${order.lng}';
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
      title: state.t('Protected staff links for admin, employee, tailor and driver.', 'روابط موظفين محمية للإدارة والموظف والخياط والسائق.'),
      subtitle: state.t('This hub is outside the customer flow. Each role has a different link and password.', 'هذه البوابة خارج مسار العميل. لكل دور رابط مختلف وكلمة مرور مختلفة.'),
      body: Wrap(spacing: 16, runSpacing: 16, children: [
        loginCard(context, Role.admin, 'admin / Admin123!'),
        loginCard(context, Role.employee, 'ops / Ops123!'),
        loginCard(context, Role.tailor, 'afroz / Tailor123!'),
        loginCard(context, Role.driver, 'omar / Driver123!'),
      ]),
    );
  }

  Widget loginCard(BuildContext context, Role role, String creds) => SizedBox(
    width: 280,
    child: Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(roleLabel(role, state.isArabic), style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      Text('/login/${role.name}'),
      const SizedBox(height: 6),
      Text(creds),
      const SizedBox(height: 14),
      ElevatedButton(onPressed: () => Navigator.of(context).pushReplacementNamed('/login/${role.name}'), child: Text(state.t('Open login', 'افتح صفحة الدخول'))),
    ]))),
  );
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.state, required this.role});
  final AppState state;
  final Role role;
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final form = GlobalKey<FormState>();
  final user = TextEditingController();
  final pass = TextEditingController();

  @override
  void dispose() { user.dispose(); pass.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    return Shell(
      state: s,
      title: s.t('${roleLabel(widget.role, false)} login on a separate private route.', 'تسجيل دخول ${roleLabel(widget.role, true)} عبر رابط خاص مستقل.'),
      subtitle: s.t('Customers cannot browse from booking into this dashboard. The correct role password is required.', 'لا يمكن للعميل الوصول من الحجز إلى هذه اللوحة. يجب استخدام كلمة مرور الدور الصحيح.'),
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
                    Text("${roleLabel(widget.role, s.isArabic)} ${s.t('Login', 'تسجيل الدخول')}", style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 14),
                    TextFormField(controller: user, validator: req, decoration: InputDecoration(labelText: s.t('Username', 'اسم المستخدم'))),
                    const SizedBox(height: 12),
                    TextFormField(controller: pass, validator: req, obscureText: true, decoration: InputDecoration(labelText: s.t('Password', 'كلمة المرور'))),
                    const SizedBox(height: 16),
                    ElevatedButton(onPressed: submit, child: Text(s.t('Enter dashboard', 'ادخل إلى اللوحة'))),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? req(String? v) => v == null || v.trim().isEmpty ? widget.state.t('Required', 'مطلوب') : null;

  void submit() {
    if (!form.currentState!.validate()) return;
    if (!widget.state.login(widget.role, user.text.trim(), pass.text)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.state.t('Incorrect credentials for this role.', 'بيانات الدخول غير صحيحة لهذا الدور.'))));
      return;
    }
    Navigator.of(context).pushNamedAndRemoveUntil('/dashboard/${widget.role.name}', (r) => false);
  }
}

class LockedPage extends StatelessWidget {
  const LockedPage({super.key, required this.state, required this.role});
  final AppState state;
  final Role? role;
  @override
  Widget build(BuildContext context) {
    final target = role ?? Role.admin;
    return Shell(
      state: state,
      title: state.t('Access denied.', 'تم رفض الوصول.'),
      subtitle: state.t('This dashboard needs the correct role login and stays hidden from customer pages.', 'هذه اللوحة تحتاج إلى تسجيل دخول الدور الصحيح وتبقى مخفية عن صفحات العميل.'),
      body: ElevatedButton(onPressed: () => Navigator.of(context).pushReplacementNamed('/login/${target.name}'), child: Text(state.t('Go to login', 'اذهب إلى الدخول'))),
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

    final active = state.orders.where((o) => o.stage != Stage.delivered).toList();
    final mine = switch (role) {
      Role.driver => state.orders.where((o) => o.driver.toLowerCase().contains('omar') || o.stage == Stage.onWay).toList(),
      Role.tailor => state.orders.where((o) => o.tailor.toLowerCase().contains('afroz')).toList(),
      _ => state.orders,
    };
    return Shell(
      state: state,
      role: role,
      title: state.t('${roleLabel(role, false)} dashboard on its own protected route.', 'لوحة ${roleLabel(role, true)} على رابطها المحمي الخاص.'),
      subtitle: state.t('This route is separated from the public customer pages and locked by role.', 'هذا الرابط منفصل عن صفحات العميل العامة ومقفل حسب الدور.'),
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 16, runSpacing: 16, children: [
          metric(state.t('All orders', 'كل الطلبات'), '${state.orders.length}'),
          metric(state.t('Active orders', 'الطلبات النشطة'), '${active.length}'),
          metric(state.t('Open complaints', 'الشكاوى المفتوحة'), '${complaints.length}'),
        ]),
        const SizedBox(height: 18),
        if (role == Role.employee)
          Card(child: Padding(padding: const EdgeInsets.all(22), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(state.t('Bookings overview', 'نظرة على الحجوزات'), style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            for (final o in state.orders.take(6)) ListTile(title: Text('${o.id} • ${o.customer}'), subtitle: Text('${o.area(state.isArabic)} • ${o.service}'), trailing: badge(stageLabel(o.stage, state.isArabic), stageColor(o.stage))),
          ]))),
        if (role == Role.tailor)
          Card(child: Padding(padding: const EdgeInsets.all(22), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(state.t('Assigned tailoring work', 'أعمال الخياطة المسندة'), style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            for (final o in mine.take(6)) ListTile(title: Text('${o.customer} • ${o.id}'), subtitle: Text('${o.service} • ${o.window}\n${o.notes}'), trailing: badge(stageLabel(o.stage, state.isArabic), stageColor(o.stage))),
          ]))),
        if (role == Role.driver)
          Card(child: Padding(padding: const EdgeInsets.all(22), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(state.t('Driver route', 'مسار السائق'), style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            for (final o in mine.take(6)) Padding(padding: const EdgeInsets.only(bottom: 12), child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE4D7BC))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${o.customer} • ${o.id}', style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(o.address),
              const SizedBox(height: 10),
              SelectableText(buildTrackingLink(o.id)),
              const SizedBox(height: 10),
              Wrap(spacing: 10, runSpacing: 10, children: [
                OutlinedButton(onPressed: () async { await Clipboard.setData(ClipboardData(text: buildTrackingLink(o.id))); if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.t('Tracking link copied.', 'تم نسخ رابط التتبع.')))); }, child: Text(state.t('Copy tracking link', 'نسخ رابط التتبع'))),
                ElevatedButton(onPressed: () => launchUrl(Uri.parse('https://www.google.com/maps/search/?api=1&query=${o.lat},${o.lng}'), webOnlyWindowName: '_blank'), child: const Text('Google Maps')),
              ]),
            ]))),
          ]))),
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
  final List<String> dayKeys = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
  final List<String> slotKeys = ['12pm', '1pm', '2pm', '3pm', '4pm', '5pm', '6pm', '7pm', '8pm'];
  Set<String> workingDays = {'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'};
  int selectedPolicyIndex = 0;

  AppState get s => widget.state;

  @override
  void initState() {
    super.initState();
    appointmentEnabled = true;
    slotListController = TextEditingController(text: '12pm,1pm,2pm,3pm,4pm,5pm,6pm,7pm,8pm');
    dateRangeController = TextEditingController(text: '29-07-2026 to 31-07-2026');
    branchSearchController = TextEditingController();
    policies = List<PolicyRecord>.from(adminPolicies);
    policyEnNameController = TextEditingController();
    policyArNameController = TextEditingController();
    policyEnDetailController = TextEditingController();
    policyArDetailController = TextEditingController();
    capacityControllers = [for (final _ in slotKeys) TextEditingController(text: '0')];
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
    final active = s.orders.where((o) => o.stage != Stage.delivered).length;
    return Shell(
      state: s,
      role: Role.admin,
      title: s.t('Admin dashboard with booking schedule, branches and policy settings.', 'لوحة الإدارة مع إعدادات جدول الحجوزات والفروع والسياسات.'),
      subtitle: s.t('This admin route now includes the same settings structure you showed: scheduling, branch management and bilingual policy editing.', 'هذا الرابط الإداري يتضمن الآن نفس هيكل الإعدادات الذي عرضته: الجدولة وإدارة الفروع وتحرير السياسات باللغتين.'),
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 16, runSpacing: 16, children: [
          metric(s.t('All orders', 'كل الطلبات'), '${s.orders.length}'),
          metric(s.t('Active orders', 'الطلبات النشطة'), '$active'),
          metric(s.t('Open complaints', 'الشكاوى المفتوحة'), '${complaints.length}'),
          metric(s.t('Branches', 'الفروع'), '${adminBranches.length}'),
        ]),
        const SizedBox(height: 18),
        Card(child: Padding(padding: const EdgeInsets.all(22), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 10, runSpacing: 10, children: [
            sectionChip(s.t('Dashboard', 'لوحة التحكم')),
            sectionChip(s.t('Booking Schedule', 'جدول الحجوزات')),
            sectionChip(s.t('Branches', 'الفروع')),
            sectionChip(s.t('Policies', 'السياسات')),
          ]),
          const SizedBox(height: 14),
          Text(s.t('Bookings overview', 'نظرة على الحجوزات'), style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          for (final o in s.orders.take(6)) ListTile(title: Text('${o.id} • ${o.customer}'), subtitle: Text('${o.area(s.isArabic)} • ${o.service}'), trailing: badge(stageLabel(o.stage, s.isArabic), stageColor(o.stage))),
        ]))),
        const SizedBox(height: 18),
        adminCard(
          context,
          title: s.t('Booking Schedule', 'جدول الحجوزات'),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            settingsBlock(
              context,
              title: s.t('Appointment Module', 'وحدة المواعيد'),
              action: smallSaveButton(() => notifySaved(s.t('Appointment module saved.', 'تم حفظ إعداد وحدة المواعيد.'))),
              child: SizedBox(
                width: 220,
                child: DropdownButtonFormField<bool>(
                  value: appointmentEnabled,
                  decoration: InputDecoration(labelText: s.t('Module status', 'حالة الوحدة')),
                  items: [
                    DropdownMenuItem(value: true, child: Text(s.t('ON', 'تشغيل'))),
                    DropdownMenuItem(value: false, child: Text(s.t('OFF', 'إيقاف'))),
                  ],
                  onChanged: (value) => setState(() => appointmentEnabled = value ?? true),
                ),
              ),
            ),
            const SizedBox(height: 16),
            settingsBlock(
              context,
              title: s.t('Time Slots', 'الفترات الزمنية'),
              action: smallSaveButton(() => notifySaved(s.t('Time slots saved.', 'تم حفظ الفترات الزمنية.'))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(
                  width: 420,
                  child: TextField(
                    controller: slotListController,
                    decoration: InputDecoration(labelText: s.t('Time slots', 'الفترات الزمنية'), hintText: '12pm,1pm,2pm,3pm'),
                  ),
                ),
                const SizedBox(height: 8),
                Text(s.t('Note: once you save new time slots, the previous setup will be removed.', 'ملاحظة: عند حفظ الفترات الجديدة سيتم استبدال الإعداد السابق.'), style: const TextStyle(color: Colors.black54)),
              ]),
            ),
            const SizedBox(height: 16),
            settingsBlock(
              context,
              title: s.t('Working Days', 'أيام العمل'),
              action: smallSaveButton(() => notifySaved(s.t('Working days saved.', 'تم حفظ أيام العمل.'))),
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
                        title: Text(dayLabel(day), style: const TextStyle(fontSize: 13)),
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
              action: OutlinedButton(onPressed: () => notifySaved(s.t('Rows generated for working days.', 'تم إنشاء الصفوف لأيام العمل.')), child: Text(s.t('Continue', 'متابعة'))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.t('Select a date range and click Continue to generate rows.', 'اختر نطاق التاريخ ثم اضغط متابعة لإنشاء الصفوف.'), style: const TextStyle(color: Colors.black54)),
                const SizedBox(height: 12),
                Wrap(spacing: 12, runSpacing: 12, children: [
                  SizedBox(width: 240, child: TextField(controller: dateRangeController, decoration: InputDecoration(labelText: s.t('Date range', 'نطاق التاريخ')))),
                  for (var i = 0; i < slotKeys.length; i++)
                    SizedBox(width: 105, child: TextField(controller: capacityControllers[i], decoration: InputDecoration(labelText: slotKeys[i]))),
                ]),
                const SizedBox(height: 10),
                Text(s.t('Note: only working days will be generated.', 'ملاحظة: سيتم إنشاء أيام العمل فقط.'), style: const TextStyle(color: Colors.black54)),
              ]),
            ),
            const SizedBox(height: 16),
            settingsBlock(
              context,
              title: s.t('Existing Schedule Records', 'سجلات الجدول الحالية'),
              action: smallSaveButton(() => notifySaved(s.t('Schedule records saved.', 'تم حفظ سجلات الجدول.'))),
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
                        for (final count in row.capacities) DataCell(SizedBox(width: 44, child: TextField(controller: TextEditingController(text: '$count'), decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8))))),
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
            SizedBox(width: 220, child: TextField(controller: branchSearchController, decoration: InputDecoration(labelText: s.t('Search', 'بحث')))),
            ElevatedButton(onPressed: () => notifySaved(s.t('Add branch flow is ready.', 'نموذج إضافة الفرع جاهز.')), child: Text(s.t('Add Branch', 'إضافة فرع'))),
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
                    DataCell(SizedBox(width: 210, child: Text(branch.locationLink, overflow: TextOverflow.ellipsis))),
                    DataCell(SizedBox(width: 220, child: Text(branch.hours))),
                    DataCell(Text(branch.contact)),
                    DataCell(Text(s.isArabic ? branch.statusAr : branch.statusEn)),
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
          action: OutlinedButton(onPressed: () => notifySaved(s.t('Back to policy list.', 'العودة إلى قائمة السياسات.')), child: Text(s.t('Back to list', 'العودة للقائمة'))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 10, runSpacing: 10, children: [
              for (var i = 0; i < policies.length; i++)
                ChoiceChip(
                  label: Text(s.isArabic ? policies[i].nameAr : policies[i].nameEn),
                  selected: selectedPolicyIndex == i,
                  selectedColor: const Color(0xFFFFF1CF),
                  onSelected: (_) => setState(() => _loadPolicy(i)),
                ),
            ]),
            const SizedBox(height: 18),
            Wrap(spacing: 16, runSpacing: 16, children: [
              SizedBox(
                width: 480,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  TextField(controller: policyEnNameController, decoration: InputDecoration(labelText: s.t('Policy Name (English)', 'اسم السياسة بالإنجليزية'))),
                  const SizedBox(height: 12),
                  TextField(controller: policyEnDetailController, maxLines: 16, decoration: InputDecoration(labelText: s.t('Detail (English)', 'التفاصيل بالإنجليزية'))),
                ]),
              ),
              SizedBox(
                width: 480,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  TextField(controller: policyArNameController, textAlign: TextAlign.right, decoration: InputDecoration(labelText: s.t('Policy Name (Arabic)', 'اسم السياسة بالعربية'))),
                  const SizedBox(height: 12),
                  TextField(controller: policyArDetailController, textAlign: TextAlign.right, maxLines: 16, decoration: InputDecoration(labelText: s.t('Detail (Arabic)', 'التفاصيل بالعربية'))),
                ]),
              ),
            ]),
            const SizedBox(height: 16),
            smallSaveButton(savePolicy),
          ]),
        ),
      ]),
    );
  }

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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
  const BranchRecord({required this.name, required this.locationLink, required this.hours, required this.contact, required this.statusEn, required this.statusAr});
  final String name;
  final String locationLink;
  final String hours;
  final String contact;
  final String statusEn;
  final String statusAr;
}

class PolicyRecord {
  const PolicyRecord({required this.nameEn, required this.nameAr, required this.detailEn, required this.detailAr});
  final String nameEn;
  final String nameAr;
  final String detailEn;
  final String detailAr;
}

class ScheduleRow {
  const ScheduleRow({required this.date, required this.dayEn, required this.dayAr, required this.capacities});
  final String date;
  final String dayEn;
  final String dayAr;
  final List<int> capacities;
}

const adminBranches = <BranchRecord>[
  BranchRecord(name: 'Al-Yarmouk', locationLink: 'https://maps.app.goo.gl/zX2gUzzkbY1vwcj58', hours: 'Our Yarmouk branch is currently closed until further notice. You can collect your orders from our Hessa Al Mubarak branch.', contact: '98700133', statusEn: 'Active', statusAr: 'نشط'),
  BranchRecord(name: 'AlHamra Tower - Premium', locationLink: 'https://maps.app.goo.gl/CrwaAmhQ4QhxB7CF7', hours: '10 am to 10 pm', contact: '99170282', statusEn: 'Active', statusAr: 'نشط'),
  BranchRecord(name: 'City Hypermarket - Dasma', locationLink: 'https://maps.app.goo.gl/Cr2GAN4Qfm1RpDV98', hours: '10 am to 10 pm', contact: '99798454', statusEn: 'Active', statusAr: 'نشط'),
  BranchRecord(name: 'Hessa AlMubarak District', locationLink: 'https://maps.app.goo.gl/tWoboCr2EhEWQYXPA', hours: '24 / 7', contact: '96957896', statusEn: 'Active', statusAr: 'نشط'),
  BranchRecord(name: 'Promenade Mall - Hawally', locationLink: 'https://maps.app.goo.gl/8KiTZcs4Sc3ByYdQ6', hours: '10 am to 10 pm', contact: '98774155', statusEn: 'Active', statusAr: 'نشط'),
  BranchRecord(name: 'Qortuba', locationLink: 'https://maps.app.goo.gl/imbpgBzihkcw2VpFA', hours: '10 am to 10 pm', contact: '98740699', statusEn: 'Active', statusAr: 'نشط'),
  BranchRecord(name: 'The Avenues - Al Rai', locationLink: 'https://maps.app.goo.gl/oLSD2Kh8WFmvgmFq7', hours: '10 am to 10 pm', contact: '98716137', statusEn: 'Active', statusAr: 'نشط'),
  BranchRecord(name: 'West Mishref', locationLink: 'https://maps.app.goo.gl/FdfvesvAtDAo8DzP6', hours: '10 am to 10 pm', contact: '98741904', statusEn: 'Active', statusAr: 'نشط'),
  BranchRecord(name: 'Zahra Complex - Salmiya', locationLink: 'https://maps.app.goo.gl/QdFCcnhsYDcUkS22A', hours: '10 am to 10 pm', contact: '98765532', statusEn: 'Active', statusAr: 'نشط'),
];

const adminPolicies = <PolicyRecord>[
  PolicyRecord(
    nameEn: 'Alteration & Repair',
    nameAr: 'التعديلات والإصلاحات',
    detailEn: 'Alterations and repairs change the original form of the clothing.\n\nRepaired or altered items cannot be reverted to the original model.\n\nThere may be changes that the customer may not anticipate in their requests due to their lack of expertise in tailoring.\n\nCustomers may review items upon cancellation and are entitled to one free minor adjustment to the same service.',
    detailAr: 'التعديلات والإصلاحات تؤدي إلى تغيير الشكل الأصلي للقطعة.\n\nلا يمكن إعادة القطع المعدلة أو المصلحة إلى حالتها أو تصميمها الأصلي.\n\nنظراً للطبيعة الفنية لأعمال الخياطة قد تطرأ بعض التغييرات التي قد لا يتوقعها العميل بسبب عدم الخبرة الفنية في هذا المجال.\n\nيحق للعميل معاينة القطعة عند الاستلام ويستحق تعديلاً بسيطاً واحداً مجانياً لنفس الخدمة.',
  ),
  PolicyRecord(
    nameEn: 'Order Cancellation',
    nameAr: 'إلغاء الطلب',
    detailEn: 'Acceptance of the invoice confirms the customer\'s agreement to all services, measurements, pricing, and policies.\n\nPayments are made in advance, and once tailoring or repair work has begun, order cancellations are not permitted.\n\nIn the event of service delays, cancellations are not allowed under any circumstances.',
    detailAr: 'يعد قبول الفاتورة إقراراً من العميل بالموافقة على جميع الخدمات والمقاسات والأسعار والسياسات المعتمدة.\n\nتسدد الدفعات مقدماً، وبمجرد البدء في أعمال الخياطة أو الإصلاح، لا يسمح بإلغاء الطلب.\n\nفي حال حدوث أي تأخير في تنفيذ الخدمة، لا يسمح بالإلغاء تحت أي ظرف من الظروف.',
  ),
  PolicyRecord(
    nameEn: 'Appointment Rescheduling',
    nameAr: 'إعادة جدولة المواعيد',
    detailEn: 'For home services, the customer will receive a confirmation link to confirm the appointment.\n\nA fixed home services fee applies and is determined by location.\n\nAppointments may be cancelled or rescheduled only if the request is made at least 3 hours before the scheduled time.\n\nRequests made after this period will not be eligible for changes or fee refunds.',
    detailAr: 'في حال طلب خدمة منزلية، سيستلم العميل رابط تأكيد لتأكيد الموعد.\n\nيتم تطبيق رسوم ثابتة للخدمة المنزلية، ويتم تحديدها حسب الموقع.\n\nيمكن إلغاء الموعد أو إعادة جدولة الموعد فقط في حال تقديم الطلب قبل 3 ساعات على الأقل من الوقت المحدد.\n\nالطلبات المقدمة بعد هذه المدة لن تكون مؤهلة للتعديل أو استرداد الرسوم.',
  ),
  PolicyRecord(
    nameEn: 'Delivery & Pickup',
    nameAr: 'التوصيل والاستلام',
    detailEn: 'Customers are responsible for collecting their items from the company\'s branches once services are completed.\n\nThe expected completion time may range from 15 minutes to two weeks, depending on the type and volume of services, and timelines may change without prior notice due to circumstances beyond the company\'s control.\n\nThe company disclaims all responsibility for any items that are not collected within 7 days from the completion or notification date.',
    detailAr: 'يتحمل العملاء مسؤولية استلام قطعهم من فروع الشركة بعد إتمام الخدمات.\n\nقد تتراوح مدة الإنجاز المتوقعة من 15 دقيقة إلى أسبوعين، وذلك بحسب نوع وحجم الخدمة، وقد تتغير المدة دون إشعار مسبق بسبب ظروف خارجة عن إرادة الشركة.\n\nتخلي الشركة مسؤوليتها عن أي قطع لم يتم استلامها خلال 7 أيام من تاريخ الإنجاز أو الإخطار.',
  ),
  PolicyRecord(
    nameEn: 'Refund',
    nameAr: 'استرداد المبالغ',
    detailEn: 'All service fees are non-refundable under any circumstances, including alterations, repairs, tailoring, delays, or unintentional damage.\n\nThe company does not provide compensation for the original value of items.\n\nHome service fees are also non-refundable, except in cases where the appointment is cancelled at least three hours before the scheduled time.',
    detailAr: 'جميع رسوم الخدمات غير قابلة للاسترداد تحت أي ظرف من الظروف، بما في ذلك التعديلات، والإصلاحات، والخياطة، والتأخير، أو التلف غير المقصود.\n\nلا تتحمل الشركة مسؤولية أو تعويض القيمة الأصلية للقطع.\n\nرسوم الخدمة المنزلية غير قابلة للاسترداد أيضاً، باستثناء الحالات التي يتم فيها إلغاء الموعد قبل ثلاث ساعات على الأقل من الوقت المحدد.',
  ),
];

const scheduleRows = <ScheduleRow>[
  ScheduleRow(date: '31-07-2026', dayEn: 'Fri', dayAr: 'الجمعة', capacities: [1, 2, 2, 2, 2, 2, 2, 2, 2]),
  ScheduleRow(date: '30-07-2026', dayEn: 'Thu', dayAr: 'الخميس', capacities: [1, 2, 2, 2, 2, 2, 2, 2, 2]),
  ScheduleRow(date: '29-07-2026', dayEn: 'Wed', dayAr: 'الأربعاء', capacities: [1, 1, 0, 0, 0, 0, 0, 0, 0]),
];

Widget adminCard(BuildContext context, {required String title, required Widget child, Widget? action}) => Card(
  child: Padding(
    padding: const EdgeInsets.all(22),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(alignment: WrapAlignment.spaceBetween, spacing: 12, runSpacing: 12, children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        if (action != null) action,
      ]),
      const SizedBox(height: 14),
      child,
    ]),
  ),
);

Widget settingsBlock(BuildContext context, {required String title, required Widget child, Widget? action}) => Container(
  padding: const EdgeInsets.all(18),
  decoration: BoxDecoration(
    color: const Color(0xFFFFFCF7),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: const Color(0xFFE6D9BE)),
  ),
  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Wrap(alignment: WrapAlignment.spaceBetween, spacing: 12, runSpacing: 12, children: [
      Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
      if (action != null) action,
    ]),
    const SizedBox(height: 14),
    child,
  ]),
);

Widget sectionChip(String label) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  decoration: BoxDecoration(color: const Color(0xFFFFF1CF), borderRadius: BorderRadius.circular(999)),
  child: Text(label, style: const TextStyle(color: Color(0xFF8A6726), fontWeight: FontWeight.w700)),
);

Widget smallSaveButton(VoidCallback onPressed) => ElevatedButton(
  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
  onPressed: onPressed,
  child: const Text('SAVE'),
);

Widget tinyActionButton(String label) => ElevatedButton(
  style: ElevatedButton.styleFrom(minimumSize: Size.zero, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
  onPressed: () {},
  child: Text(label),
);

DataColumn dataLabel(String label) => DataColumn(label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)));

Widget metric(String label, String value) => SizedBox(width: 220, child: Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: ink)), const SizedBox(height: 6), Text(label)]))));
Widget bullet(String text) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Padding(padding: EdgeInsets.only(top: 8), child: Icon(Icons.circle, size: 7, color: gold)), const SizedBox(width: 10), Expanded(child: Text(text))]));
Widget badge(String text, Color color) => Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: color.withOpacity(.12), borderRadius: BorderRadius.circular(12)), child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w700)));
String buildTrackingLink(String id) => '${Uri.base.toString().split('#').first}#/track?order=$id';

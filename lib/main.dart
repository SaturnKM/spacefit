import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui; // for ui.Image (the screen "photo")
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'; 
import 'package:flutter/services.dart'; 
import 'package:flutter_native_splash/flutter_native_splash.dart'; 
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  // Keep the opening screen (planet + SPACEFIT) on screen while the app loads.
  FlutterNativeSplash.preserve(widgetsBinding: binding);
  await store.load();
  themeMode.addListener(store.save);
  runApp(const SpacefitApp());
  // Show it for 2 seconds, then hide it.
  await Future.delayed(const Duration(seconds: 2));
  FlutterNativeSplash.remove();
}

// ───────── Palette (60 / 30 / 10) style ─────────
class P {
  final Color bg, card, text, muted, accent, onAccent, border;
  const P(this.bg, this.card, this.text, this.muted, this.accent, this.onAccent, this.border);
  static const dark = P(Color(0xFF1C1612), Color(0xFF2B2119), Color(0xFFF5E8D0),
      Color(0xFFBBA88E), Color(0xFFE0A06A), Color(0xFF1C1612), Color(0xFF4A3A2C));
  static const light = P(Color(0xFFF7EEDF), Color(0xFFE8D9BC), Color(0xFF1A1612),
      Color(0xFF6B5A47), Color(0xFF8B6240), Colors.white, Color(0xFF8B6240));
  static P of(BuildContext c) => Theme.of(c).brightness == Brightness.dark ? dark : light;
}

TextStyle serif(BuildContext c, double s) =>
    GoogleFonts.playfairDisplay(fontSize: s, color: P.of(c).text, fontWeight: FontWeight.w500);
TextStyle label(BuildContext c) => GoogleFonts.inter(
    fontSize: 10, letterSpacing: 1.6, fontWeight: FontWeight.w700, color: P.of(c).accent);

// ───────── Data / store ─────────
class Product {
  final int id;
  final String name, cat, blurb;
  final double price;
  final IconData icon;
  const Product(this.id, this.name, this.cat, this.price, this.icon, this.blurb);
  List<String> get sizes => switch (cat) {
        'Shoes' => ['38', '39', '40', '41', '42', '43', '44', '45'],
        'Bags' => ['One size'],
        _ => ['XS', 'S', 'M', 'L', 'XL'],
      };
}

const products = [
  Product(0, 'Orbit Crew Tee', 'Tops', 24, Icons.checkroom,
      'Soft cotton crew neck with a relaxed fit and a small ringed-planet mark at the chest. Easy to layer and easy to live in.'),
  Product(1, 'Eclipse Wrap Dress', 'Dresses', 59, Icons.dry_cleaning,
      'Wrap dress with a fluid drape and a deep-space hem.'),
  Product(2, 'Nova Low Sneakers', 'Shoes', 79, Icons.directions_walk,
      'Low-profile sneakers with a cushioned sole.'),
  Product(3, 'Ring Tote Bag', 'Bags', 45, Icons.shopping_bag, 'Roomy canvas tote with a ringed strap.'),
  Product(4, 'Comet Hoodie', 'Tops', 68, Icons.checkroom_outlined,
      'Heavyweight fleece hoodie with a brushed inside and a comet-tail print on the back.'),
  Product(5, 'Lunar Polo', 'Tops', 39, Icons.style,
      'Knit pique polo in a soft matte finish. Smart enough for dinner, easy enough for every day.'),
  Product(6, 'Stellar Tank', 'Tops', 19, Icons.man,
      'Lightweight ribbed tank that layers under anything.'),
  Product(7, 'Nebula Slip Dress', 'Dresses', 72, Icons.woman,
      'Satin-finish slip dress with adjustable straps and a gentle bias cut.'),
  Product(8, 'Aurora Midi', 'Dresses', 64, Icons.dry_cleaning_outlined,
      'Flowing midi with a pleated skirt that catches the light as you move.'),
  Product(9, 'Galaxy Maxi', 'Dresses', 85, Icons.woman_2,
      'Floor-length maxi with a swirl print and a relaxed waist tie.'),
  Product(10, 'Meteor High Tops', 'Shoes', 92, Icons.hiking,
      'High-top sneakers with a padded collar and a grippy rubber sole.'),
  Product(11, 'Cosmos Slides', 'Shoes', 29, Icons.snowshoeing,
      'Cushioned slides for the beach, the pool or the couch.'),
  Product(12, 'Pulsar Runner', 'Shoes', 98, Icons.directions_run,
      'Breathable mesh runner with responsive foam for long distances.'),
  Product(13, 'Orbit Backpack', 'Bags', 58, Icons.backpack,
      'Everyday backpack with a padded laptop sleeve and two side pockets.'),
  Product(14, 'Satellite Crossbody', 'Bags', 36, Icons.local_mall,
      'Compact crossbody with a magnetic flap and an adjustable strap.'),
  Product(15, 'Comet Pouch', 'Bags', 18, Icons.wallet,
      'Small zip pouch for cards, cables and keys.'),
]; //this was hard coded because you didn't specified the database or someting like that.

class Account {
  final String name, password;
  Account(this.name, this.password);
}

class Store extends ChangeNotifier {
  final accounts = <String, Account>{'test@example.com': Account('Test', '123456')};
  String? currentEmail;
  SharedPreferences? _prefs;

  Future<void> load() async {
    final p = _prefs = await SharedPreferences.getInstance();
    final acc = p.getString('accounts');
    if (acc != null) {
      final m = jsonDecode(acc) as Map<String, dynamic>;
      accounts.addAll(m.map((k, v) => MapEntry(k, Account(v['name'], v['password']))));
    }
    currentEmail = p.getString('email');
    if (currentEmail != null && !accounts.containsKey(currentEmail)) currentEmail = null;
    userName = p.getString('userName') ?? '';
    savedAddress = p.getString('addr');
    savedCity = p.getString('city');
    savedPostal = p.getString('postal');
    saveDetails = p.getBool('saveDetails') ?? false;
    loved.addAll((p.getStringList('loved') ?? []).map(int.parse));
    final c = p.getString('cart');
    if (c != null) {
      (jsonDecode(c) as Map<String, dynamic>).forEach((k, v) => cart[k] = v as int);
    }
    final t = p.getString('theme');
    if (t != null) themeMode.value = ThemeMode.values.byName(t);
  }

  void save() {
    final p = _prefs;
    if (p == null) return;
    p.setString('accounts',
        jsonEncode(accounts.map((k, v) => MapEntry(k, {'name': v.name, 'password': v.password}))));
    currentEmail == null ? p.remove('email') : p.setString('email', currentEmail!);
    p.setString('userName', userName);
    savedAddress == null ? p.remove('addr') : p.setString('addr', savedAddress!);
    savedCity == null ? p.remove('city') : p.setString('city', savedCity!);
    savedPostal == null ? p.remove('postal') : p.setString('postal', savedPostal!);
    p.setBool('saveDetails', saveDetails);
    p.setStringList('loved', loved.map((e) => '$e').toList());
    p.setString('cart', jsonEncode(cart));
    p.setString('theme', themeMode.value.name);
  }

  @override
  void notifyListeners() {
    super.notifyListeners();
    save();
  }

  String userName = '';
  String? savedAddress, savedCity, savedPostal;
  bool saveDetails = false;
  final loved = <int>{};
  final cart = <String, int>{}; // key: "id|size"
  void toggleLove(int id) {
    loved.contains(id) ? loved.remove(id) : loved.add(id);
    notifyListeners();
  }

  void add(int id, String size, int qty) {
    final k = '$id|$size';
    cart[k] = (cart[k] ?? 0) + qty;
    notifyListeners();
  }

  void setQty(String key, int q) {
    q <= 0 ? cart.remove(key) : cart[key] = q;
    notifyListeners();
  }

  int get count => cart.values.fold(0, (a, b) => a + b);
  double get total =>
      cart.entries.fold(0, (a, e) => a + products[int.parse(e.key.split('|')[0])].price * e.value);
  void clear() {
    cart.clear();
    notifyListeners();
  }
}

final themeMode = ValueNotifier<ThemeMode>(ThemeMode.system);

final store = Store();

// ───────── Notifications ─────────
final navKey = GlobalKey<NavigatorState>();
enum Kind { success, error, info }
OverlayEntry? _toast;

void notify(String msg, {Kind kind = Kind.info}) {
  final overlay = navKey.currentState?.overlay;
  if (overlay == null) return;
  _toast?.remove();
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _Toast(
      msg: msg,
      kind: kind,
      onDone: () {
        if (identical(_toast, entry)) {
          entry.remove();
          _toast = null;
        }
      },
    ),
  );
  _toast = entry;
  overlay.insert(entry);
}

class _Toast extends StatefulWidget {
  final String msg;
  final Kind kind;
  final VoidCallback onDone;
  const _Toast({required this.msg, required this.kind, required this.onDone});
  @override
  State<_Toast> createState() => _ToastState();
}

class _ToastState extends State<_Toast> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 250))..forward();
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer(const Duration(milliseconds: 2800), _close);
  }

  Future<void> _close() async {
    _t?.cancel();
    if (!mounted) return;
    await _c.reverse();
    widget.onDone();
  }

  @override
  void dispose() {
    _t?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = P.of(context);
    final (icon, color) = switch (widget.kind) {
      Kind.success => (Icons.check_circle, const Color(0xFF6FBF73)),
      Kind.error => (Icons.error, const Color(0xFFE57373)),
      Kind.info => (Icons.info, p.accent),
    };
    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, -1.2), end: Offset.zero)
            .animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic)),
        child: FadeTransition(
          opacity: _c,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: _close,
              onVerticalDragEnd: (_) => _close(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: p.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withOpacity(.6)),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 4))],
                ),
                child: Row(children: [
                  Icon(icon, color: color, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(widget.msg,
                          style: TextStyle(color: p.text, fontSize: 13, fontWeight: FontWeight.w600))),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void showAddedSheet(BuildContext context, Product pr, String size, int qty) {
  final p = P.of(context);
  showModalBottomSheet(
    context: context,
    backgroundColor: p.card,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            const Pop(trigger: 'added', child: Icon(Icons.check_circle, color: Color(0xFF6FBF73))), // ✨ JUICE
            const SizedBox(width: 8),
            Text('Added to cart', style: serif(sheet, 18)),
          ]),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: p.bg.withOpacity(.5), borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              Icon(pr.icon, size: 36, color: p.text),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(pr.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                Text('Size $size · Qty $qty', style: TextStyle(color: p.muted, fontSize: 11)),
              ])),
              Text(money(pr.price * qty),
                  style: TextStyle(color: p.accent, fontWeight: FontWeight.w700)),
            ]),
          ),
          const SizedBox(height: 16),
          PrimaryButton('Go to cart', () {
            Navigator.pop(sheet);
            go(context, const CartScreen());
          }),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: () {
                Navigator.pop(sheet);
                Navigator.pop(context);
              },
              style: OutlinedButton.styleFrom(
                  foregroundColor: p.text,
                  side: BorderSide(color: p.accent),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              child: const Text('Continue shopping', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ),
    ),
  );
}

// ───────── App ─────────
class SpacefitApp extends StatelessWidget {
  const SpacefitApp({super.key});

  static ThemeData _theme(P p, Brightness b) => ThemeData(
        brightness: b,
        scaffoldBackgroundColor: p.bg,
        colorScheme: ColorScheme.fromSeed(seedColor: p.accent, brightness: b, surface: p.bg),
        textTheme: GoogleFonts.interTextTheme(ThemeData(brightness: b).textTheme)
            .apply(bodyColor: p.text, displayColor: p.text),
      );
  static final _light = _theme(P.light, Brightness.light);
  static final _dark = _theme(P.dark, Brightness.dark);

  @override
  Widget build(BuildContext context) {
    // The first screen is decided once, when the app starts:
    // Home if logged in, otherwise Sign in. (The intro is now the phone's opening screen.)
    final Widget start = store.currentEmail != null ? const HomeScreen() : const AuthScreen();
    return ValueListenableBuilder<ThemeMode>(
        valueListenable: themeMode,
        builder: (_, mode, __) => MaterialApp(
          title: 'Spacefit',
          navigatorKey: navKey,
          debugShowCheckedModeBanner: false,
          themeMode: mode,
          theme: _light,
          darkTheme: _dark,
          themeAnimationDuration: Duration.zero,
          // it was laggy as hell thats why i used zero
          builder: (_, child) => RepaintBoundary(key: screenKey, child: child),
          home: start,
        ),
      );
  }
}


final screenKey = GlobalKey();
bool _switching = false; // stops double taps while the animation is running

Future<void> switchTheme(BuildContext context, Offset from) async {
  if (_switching) return;
  final dark = Theme.of(context).brightness == Brightness.dark;
  final newMode = dark ? ThemeMode.light : ThemeMode.dark;
  final boundary = screenKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  final overlay = navKey.currentState?.overlay;
  if (boundary == null || overlay == null) {
    themeMode.value = newMode; // fallback: just switch without animation
    return;
  }
  _switching = true;
  HapticFeedback.selectionClick();
  final ratio = MediaQuery.of(context).devicePixelRatio;
  await WidgetsBinding.instance.endOfFrame; // wait until the screen is fully drawn
  final photo = await boundary.toImage(pixelRatio: ratio); // step 1
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _ThemeReveal(
      photo: photo,
      ratio: ratio,
      from: from,
      onDone: () {
        entry.remove();
        photo.dispose();
        _switching = false;
      },
    ),
  );
  overlay.insert(entry); // step 3
  themeMode.value = newMode; // step 2
}

class _ThemeReveal extends StatefulWidget {
  final ui.Image photo;
  final double ratio;
  final Offset from;
  final VoidCallback onDone;
  const _ThemeReveal({required this.photo, required this.ratio, required this.from, required this.onDone});
  @override
  State<_ThemeReveal> createState() => _ThemeRevealState();
}

class _ThemeRevealState extends State<_ThemeReveal> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 650))
    ..forward().then((_) => widget.onDone());

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    // the circle must end big enough to cover the farthest corner of the screen
    final corners = [Offset.zero, Offset(size.width, 0), Offset(0, size.height), Offset(size.width, size.height)];
    final maxR = corners.map((c) => (c - widget.from).distance).reduce((a, b) => a > b ? a : b);
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, child) => ClipPath(
            clipper: _HoleClipper(widget.from, maxR * Curves.easeInOutCubic.transform(_c.value)),
            child: child,
          ),
          child: RawImage(image: widget.photo, scale: widget.ratio, fit: BoxFit.fill),
        ),
      ),
    );
  }
}

/// Keeps the whole screen EXCEPT a circle (the "hole").
class _HoleClipper extends CustomClipper<Path> {
  final Offset center;
  final double radius;
  _HoleClipper(this.center, this.radius);
  @override
  Path getClip(Size size) => Path()
    ..fillType = PathFillType.evenOdd // the overlapping part (the circle) becomes a hole
    ..addRect(Offset.zero & size)
    ..addOval(Rect.fromCircle(center: center, radius: radius));
  @override
  bool shouldReclip(_HoleClipper old) => old.radius != radius || old.center != center;
}

// ───────── Shared widgets ─────────
class Planet extends StatelessWidget {
  final double size;
  const Planet({super.key, this.size = 100});
  @override
  Widget build(BuildContext context) {
    final p = P.of(context);
    return SizedBox(
      width: size * 2.2,
      height: size * 1.2,
      child: CustomPaint(painter: _PlanetPainter(p.accent, p.border)),
    );
  }
}

class _PlanetPainter extends CustomPainter {
  final Color body, ring;
  _PlanetPainter(this.body, this.ring);
  @override
  void paint(Canvas c, Size s) {
    final center = s.center(Offset.zero);
    final r = s.height * 0.42;
    final ringPaint = Paint()
      ..color = ring
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    c.save();
    c.translate(center.dx, center.dy);
    c.rotate(-0.25);
    c.translate(-center.dx, -center.dy);
    c.drawOval(Rect.fromCenter(center: center, width: s.width * .95, height: s.height * .42), ringPaint);
    c.restore();
    c.drawCircle(center, r, Paint()..color = body);
    final stripe = Paint()..color = Colors.black.withOpacity(.18);
    c.drawRect(Rect.fromCenter(center: center.translate(0, -r * .2), width: r * 1.7, height: 5), stripe);
    c.drawRect(Rect.fromCenter(center: center.translate(0, r * .15), width: r * 1.8, height: 5), stripe);
  }

  @override
  bool shouldRepaint(covariant CustomPainter o) => false;
}

class Logo extends StatelessWidget {
  const Logo({super.key});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.public, size: 18, color: P.of(context).accent),
        const SizedBox(width: 6),
        Text('SPACEFIT',
            style: GoogleFonts.playfairDisplay(
                fontWeight: FontWeight.w800, letterSpacing: 1.5, fontSize: 15, color: P.of(context).text)),
      ]);
}

class ThemeButton extends StatelessWidget {
  const ThemeButton({super.key});
  @override
  Widget build(BuildContext context) {
    final p = P.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () {
        // find the middle of this button on the screen, the circle starts there
        final box = context.findRenderObject() as RenderBox;
        switchTheme(context, box.localToGlobal(box.size.center(Offset.zero)));
      },
      child: CircleAvatar(
          radius: 16,
          backgroundColor: p.card,
          // ✨ JUICE: sun/moon icon pops when you switch theme
          child: Pop(
              trigger: dark,
              child: Icon(dark ? Icons.light_mode : Icons.dark_mode, size: 16, color: p.accent))),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final IconData? icon;
  const PrimaryButton(this.text, this.onTap, {super.key, this.icon});
  @override
  Widget build(BuildContext context) {
    final p = P.of(context);
    return Pressable(
     child: SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton.icon(
        onPressed: onTap,
        icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 16),
        label: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
        style: FilledButton.styleFrom(
            backgroundColor: p.accent,
            foregroundColor: p.onAccent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
      ),
     ),
    );
  }
}

class Field extends StatelessWidget {
  final String title, hint;
  final TextEditingController? ctrl;
  final bool obscure;
  final String? Function(String?)? validator;
  const Field(this.title, this.hint, {super.key, this.ctrl, this.obscure = false, this.validator});
  @override
  Widget build(BuildContext context) {
    final p = P.of(context);
    OutlineInputBorder b(Color c) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: c));
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: p.text)),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          obscureText: obscure,
          validator: validator,
          style: TextStyle(color: p.text, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: p.muted.withOpacity(.7)),
            filled: true,
            fillColor: p.card,
            isDense: true,
            contentPadding: const EdgeInsets.all(14),
            enabledBorder: b(p.border.withOpacity(.5)),
            focusedBorder: b(p.accent),
            errorBorder: b(Colors.redAccent),
            focusedErrorBorder: b(Colors.redAccent),
          ),
        ),
      ]),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title, sub;
  const EmptyState(this.icon, this.title, this.sub, {super.key});
  @override
  Widget build(BuildContext context) {
    final p = P.of(context);
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: stagger([
        Floating(child: Pop(trigger: title, child: Icon(icon, size: 56, color: p.accent))),
        const SizedBox(height: 14),
        Text(title, style: serif(context, 22)),
        const SizedBox(height: 6),
        Text(sub, textAlign: TextAlign.center, style: TextStyle(color: p.muted, fontSize: 12)),
      ])),
    );
  }
}

AppBar bar(BuildContext c, String title, {String? sub, List<Widget>? actions}) => AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      leading: IconButton(
          icon: Icon(Icons.arrow_back, color: P.of(c).text), onPressed: () => Navigator.maybePop(c)),
      title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: serif(c, 20)),
        if (sub != null) Text(sub, style: TextStyle(fontSize: 11, color: P.of(c).muted)),
      ]),
      actions: actions,
    );

String money(num v) => '\$${v.toStringAsFixed(2)}';

void go(BuildContext c, Widget w) => Navigator.push(
      c,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 350),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (_, __, ___) => w,
        transitionsBuilder: (_, anim, __, child) {
          final a = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
          return FadeTransition(
            opacity: a,
            child: SlideTransition(
              position: Tween(begin: const Offset(0, .06), end: Offset.zero).animate(a),
              child: child,
            ),
          );
        },
      ),
    );


class Pressable extends StatefulWidget {
  final Widget child;
  const Pressable({super.key, required this.child});
  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool down = false; // is the finger on it right now?
  @override
  Widget build(BuildContext context) => Listener(
        onPointerDown: (_) => setState(() => down = true),
        onPointerUp: (_) => setState(() => down = false),
        onPointerCancel: (_) => setState(() => down = false),
        child: AnimatedScale(
          scale: down ? .95 : 1, // 95% size while pressed
          duration: const Duration(milliseconds: 120),
          child: widget.child,
        ),
      );
}

/// 2. FadeIn: fades in and slides up when it first appears.
/// A bigger [index] makes it last a bit longer, so a list appears one by one.
class FadeIn extends StatelessWidget {
  final Widget child;
  final int index;
  const FadeIn({super.key, required this.child, this.index = 0});
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1), // v goes from 0 to 1
        duration: Duration(milliseconds: 350 + index * 70),
        curve: Curves.easeOutCubic,
        builder: (_, v, child) => Opacity(
          opacity: v,
          child: Transform.translate(offset: Offset(0, 24 * (1 - v)), child: child),
        ),
        child: child,
      );
}

/// 3. Pop: does a quick bouncy "pop" every time [trigger] changes
/// (for example the cart count, or loved / not loved).
class Pop extends StatelessWidget {
  final Object? trigger;
  final Widget child;
  const Pop({super.key, required this.trigger, required this.child});
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        key: ValueKey(trigger), // new value = new key = the animation plays again
        tween: Tween(begin: .6, end: 1),
        duration: const Duration(milliseconds: 600),
        curve: Curves.elasticOut, // the "boing" effect
        builder: (_, s, child) => Transform.scale(scale: s, child: child),
        child: child,
      );
}

/// 4. Floating: gently moves up and down forever, like it's floating in space.
class Floating extends StatefulWidget {
  final Widget child;
  const Floating({super.key, required this.child});
  @override
  State<Floating> createState() => _FloatingState();
}

class _FloatingState extends State<Floating> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, child) => Transform.translate(
            offset: Offset(0, -8 * Curves.easeInOut.transform(_c.value)), // up to 8 px up
            child: child,
          ),
          child: RepaintBoundary(child: widget.child),
        ),
      );
}

/// 5. Pulse: slowly fades in and out forever. Used for the "loading" boxes.
class Pulse extends StatefulWidget {
  final Widget child;
  const Pulse({super.key, required this.child});
  @override
  State<Pulse> createState() => _PulseState();
}

class _PulseState extends State<Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900), lowerBound: .4, upperBound: 1)
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      RepaintBoundary(child: FadeTransition(opacity: _c, child: widget.child));
}

/// stagger(): give it a list of widgets, it wraps each one in FadeIn
/// so they appear one after another (top to bottom).
List<Widget> stagger(List<Widget> items) => [
      for (var i = 0; i < items.length; i++) FadeIn(index: i > 8 ? 8 : i, child: items[i]),
    ];

// ───────── Auth ─────────
class AuthScreen extends StatefulWidget {
  final bool signUp;
  const AuthScreen({super.key, this.signUp = false});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _key = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _name = TextEditingController();
  final _pass = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final p = P.of(context);
    final su = widget.signUp;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _key,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: stagger([
                  const Align(alignment: Alignment.centerRight, child: ThemeButton()),
                  Center(child: Floating(child: Planet(size: su ? 60 : 90))), // ✨ JUICE
                  const SizedBox(height: 24),
                  Text(su ? 'JOIN SPACEFIT' : 'SPACEFIT · OUTFITS FROM ORBIT', style: label(context)),
                  const SizedBox(height: 6),
                  Text(su ? 'Create your account.' : 'Wear the orbit.', style: serif(context, 30)),
                  if (!su)
                    Padding(
                      padding: const EdgeInsets.only(top: 6, bottom: 20),
                      child: Text('Sign in to browse the collection.',
                          style: TextStyle(color: p.muted, fontSize: 13)),
                    )
                  else
                    const SizedBox(height: 20),
                  if (su)
                    Field('Full name', 'Your name',
                        ctrl: _name,
                        validator: (v) => (v ?? '').trim().isEmpty ? 'Please choose a name.' : null),
                  Field('Email', 'you@example.com',
                      ctrl: _email,
                      validator: (v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v ?? '')
                          ? null
                          : 'Enter a valid email address.'),
                  Field('Password', 'At least 6 characters',
                      ctrl: _pass,
                      obscure: true,
                      validator: (v) => (v ?? '').length < 6 ? 'Password must be at least 6 characters.' : null),
                  if (su)
                    Field('Confirm password', 'Repeat your password',
                        obscure: true,
                        validator: (v) => v != _pass.text ? 'Passwords do not match.' : null),
                  const SizedBox(height: 6),
                  PrimaryButton(su ? 'Create account' : 'Sign in', () {
                    if (!_key.currentState!.validate()) return;
                    final email = _email.text.trim().toLowerCase();
                    final existing = store.accounts[email];
                    if (su) {
                      if (existing != null) {
                        Navigator.pushReplacement(
                            context, MaterialPageRoute(builder: (_) => const AuthScreen()));
                        notify('This account already exists. Please sign in.', kind: Kind.info);
                        return;
                      }
                      store.accounts[email] = Account(_name.text.trim(), _pass.text);
                      store.userName = _name.text.trim();
                    } else {
                      if (existing == null) {
                        notify('No account found for this email. Please create one.', kind: Kind.error);
                        return;
                      }
                      if (existing.password != _pass.text) {
                        notify('Incorrect password.', kind: Kind.error);
                        return;
                      }
                      store.userName = existing.name;
                    }
                    store.currentEmail = email;
                    store.save();
                    Navigator.pushReplacement(
                        context, MaterialPageRoute(builder: (_) => const HomeScreen()));
                    notify(su ? 'Account created. Welcome, ${store.userName}!' : 'Welcome back, ${store.userName}!',
                        kind: Kind.success);
                  }),
                  if (!su)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Center(
                          child: Text('Demo login: test@example.com / 123456',
                              style: TextStyle(fontSize: 10, color: p.muted))),
                    ),
                  const SizedBox(height: 16),
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.pushReplacement(context,
                          MaterialPageRoute(builder: (_) => AuthScreen(signUp: !su))),
                      child: Text(su ? 'Already have an account? Sign in' : 'New to Spacefit? Create an account',
                          style: TextStyle(color: p.accent, fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ])),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ───────── Home ─────────
enum LoadState { loading, error, ready }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  LoadState state = LoadState.loading;
  String cat = 'All', query = '';
  final cats = ['All', 'Tops', 'Dresses', 'Shoes', 'Bags'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => state = LoadState.loading);
    await Future.delayed(const Duration(milliseconds: 900));
    if (mounted) setState(() => state = LoadState.ready); // set LoadState.error to preview error state
  }

  @override
  Widget build(BuildContext context) {
    final p = P.of(context);
    final list = products
        .where((e) =>
            (cat == 'All' || e.cat == cat) && e.name.toLowerCase().contains(query.toLowerCase()))
        .toList();
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: store,
          builder: (_, __) => Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Logo(),
                const Spacer(),
                const ThemeButton(),
                const SizedBox(width: 8),
                _circle(context, Icons.favorite_border, () => go(context, const LovedScreen())),
                const SizedBox(width: 8),
                _circle(context, Icons.shopping_bag_outlined, () => go(context, const CartScreen()),
                    badge: store.count),
                const SizedBox(width: 8),
                _circle(context, Icons.logout, () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (d) => AlertDialog(
                      backgroundColor: p.card,
                      title: Text('Log out?', style: serif(d, 20)),
                      content: Text('You will need to sign in again.',
                          style: TextStyle(color: p.muted, fontSize: 13)),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(d, false),
                            child: Text('Cancel', style: TextStyle(color: p.muted))),
                        FilledButton(
                            onPressed: () => Navigator.pop(d, true),
                            style: FilledButton.styleFrom(
                                backgroundColor: p.accent, foregroundColor: p.onAccent),
                            child: const Text('Log out')),
                      ],
                    ),
                  );
                  if (ok == true && context.mounted) {
                    store.cart.clear();
                    store.currentEmail = null;
                    store.save();
                    Navigator.pushAndRemoveUntil(
                        context, MaterialPageRoute(builder: (_) => const AuthScreen()), (r) => false);
                    notify('You have been logged out.', kind: Kind.info);
                  }
                }),
              ]),
              const SizedBox(height: 14),
              if (state == LoadState.loading) Expanded(child: _skeleton(context)),
              if (state == LoadState.error)
                Expanded(
                  child: Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: stagger([
                      Pop(trigger: 'error', child: Icon(Icons.cancel_outlined, size: 56, color: p.accent)),
                      const SizedBox(height: 16),
                      Text('Lost signal.', style: serif(context, 22)),
                      const SizedBox(height: 6),
                      Text("We couldn't load the collection. Check your\nconnection and try again.",
                          textAlign: TextAlign.center, style: TextStyle(color: p.muted, fontSize: 12)),
                      const SizedBox(height: 16),
                      SizedBox(
                          width: 140,
                          child: PrimaryButton('Try again', _load, icon: Icons.refresh)),
                    ])), // ✨ JUICE: error message appears line by line
                  ),
                ),
              if (state == LoadState.ready) ...[
                // ✨ JUICE: search bar, categories and banner slide in one after another
                FadeIn(index: 0, child: TextField(
                  onChanged: (v) => setState(() => query = v),
                  style: TextStyle(color: p.text),
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.search, color: p.muted, size: 18),
                    hintText: 'Search the collection',
                    hintStyle: TextStyle(color: p.muted, fontSize: 13),
                    filled: true,
                    fillColor: p.card,
                    isDense: true,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                )),
                const SizedBox(height: 12),
                FadeIn(index: 1, child: SizedBox(
                  height: 34,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: cats
                        .map((c) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(c, style: const TextStyle(fontSize: 12)),
                                selected: cat == c,
                                showCheckmark: false,
                                selectedColor: p.accent,
                                backgroundColor: Colors.transparent,
                                labelStyle: TextStyle(color: cat == c ? p.onAccent : p.text),
                                side: BorderSide(color: p.accent),
                                shape: const StadiumBorder(),
                                onSelected: (_) => setState(() => cat = c),
                              ),
                            ))
                        .toList(),
                  ),
                )),
                const SizedBox(height: 12),
                Expanded(
                  child: CustomScrollView(slivers: [
                    if (query.isEmpty && cat == 'All')
                      SliverToBoxAdapter(
                        child: FadeIn(index: 2, child: Container(
                          padding: const EdgeInsets.all(14),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration:
                              BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(12)),
                          child: Row(children: [
                            Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('NEW SEASON', style: label(context)),
                              const SizedBox(height: 4),
                              Text('Outfits from orbit', style: serif(context, 16)),
                            ])),
                            const Planet(size: 24),
                          ]),
                        )),
                      ),
                    if (list.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          // ✨ JUICE: empty result appears line by line, icon pops
                          child: Column(mainAxisSize: MainAxisSize.min, children: stagger([
                            Pop(trigger: query, child: Icon(Icons.zoom_out, size: 44, color: p.accent)),
                            const SizedBox(height: 12),
                            Text('Nothing found', style: serif(context, 20)),
                            const SizedBox(height: 6),
                            Text('No pieces match "$query". Try another\nword or pick a category.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: p.muted, fontSize: 12)),
                            const SizedBox(height: 14),
                            OutlinedButton(
                                onPressed: () => setState(() {
                                      query = '';
                                      cat = 'All';
                                    }),
                                style: OutlinedButton.styleFrom(
                                    foregroundColor: p.text, side: BorderSide(color: p.accent)),
                                child: const Text('Clear search')),
                          ])),
                        ),
                      )
                    else
                      SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: .8),
                        delegate: SliverChildBuilderDelegate((_, i) => _card(context, list[i], i),
                            childCount: list.length),
                      ),
                  ]),
                ),
              ],
            ]),
          ),
        ),
      ),
    );
  }

  Widget _circle(BuildContext c, IconData i, VoidCallback t, {int badge = 0}) {
    final p = P.of(c);
    return GestureDetector(
      onTap: t,
      child: Stack(clipBehavior: Clip.none, children: [
        CircleAvatar(radius: 16, backgroundColor: p.card, child: Icon(i, size: 16, color: p.accent)),
        if (badge > 0)
          Positioned(
              right: -3,
              top: -3,
              // ✨ JUICE: the cart number pops when it changes
              child: Pop(
                trigger: badge,
                child: CircleAvatar(
                    radius: 7,
                    backgroundColor: p.accent,
                    child: Text('$badge', style: TextStyle(fontSize: 9, color: p.onAccent))),
              )),
      ]),
    );
  }

  Widget _skeleton(BuildContext c) {
    final p = P.of(c);
    // ✨ JUICE: loading boxes gently pulse (fade in and out)
    Widget box(double h) => Pulse(
        child: Container(
            height: h,
            decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(12))));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      box(40),
      const SizedBox(height: 10),
      Text('Loading the collection...', style: TextStyle(fontSize: 10, color: p.muted)),
      const SizedBox(height: 10),
      Expanded(
        child: GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: .8,
            children: List.generate(4, (_) => box(100))),
      ),
    ]);
  }

  Widget _card(BuildContext c, Product pr, int i) {
    final p = P.of(c);
    return FadeIn(
      key: ValueKey('$cat-${pr.id}'),
      index: i > 8 ? 8 : i,
      child: Pressable(
        child: GestureDetector(
          onTap: () => go(c, ProductScreen(pr)),
          child: Container(
            decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.all(10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                  child: Center(
                      child: Hero(
                          tag: 'product-${pr.id}', // same tag as on the product page
                          child: Icon(pr.icon, size: 56, color: p.text)))),
              Text(pr.cat, style: TextStyle(fontSize: 10, color: p.muted)),
              Text(pr.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              Text(money(pr.price),
                  style: TextStyle(fontSize: 12, color: p.accent, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      ),
    );
  }
}

// ───────── Product ─────────
class ProductScreen extends StatefulWidget {
  final Product pr;
  const ProductScreen(this.pr, {super.key});
  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  String? size;
  int qty = 1;

  @override
  void initState() {
    super.initState();
    if (widget.pr.sizes.length == 1) size = widget.pr.sizes.first;
  }

  @override
  Widget build(BuildContext context) {
    final p = P.of(context);
    final pr = widget.pr;
    return Scaffold(
      body: ListenableBuilder(
        listenable: store,
        builder: (_, __) => Column(children: [
          Container(
            height: 280,
            width: double.infinity,
            color: p.card,
            child: SafeArea(
              bottom: false,
              child: Stack(alignment: Alignment.center, children: [
                const Opacity(opacity: .5, child: Planet(size: 110)),
                // ✨ JUICE: Hero = the icon flies here from the home card. Floating = it bobs gently.
                Floating(
                    child: Hero(
                        tag: 'product-${pr.id}', child: Icon(pr.icon, size: 100, color: p.text))),
                Positioned(
                    left: 12,
                    top: 8,
                    child: IconButton.filled(
                        style: IconButton.styleFrom(backgroundColor: p.bg),
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.arrow_back, color: p.text))),
                Positioned(
                    right: 12,
                    top: 8,
                    child: IconButton.filled(
                        style: IconButton.styleFrom(backgroundColor: p.bg),
                        onPressed: () {
                          HapticFeedback.lightImpact(); // ✨ JUICE: small vibration
                          store.toggleLove(pr.id);
                        },
                        // ✨ JUICE: the heart pops when you love / unlove
                        icon: Pop(
                          trigger: store.loved.contains(pr.id),
                          child: Icon(
                              store.loved.contains(pr.id) ? Icons.favorite : Icons.favorite_border,
                              color: p.accent),
                        ))),
              ]),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: stagger([
                Text(pr.cat.toUpperCase(), style: label(context)),
                const SizedBox(height: 6),
                Text(pr.name, style: serif(context, 26)),
                const SizedBox(height: 4),
                Text(money(pr.price), style: serif(context, 20).copyWith(color: p.accent)),
                const SizedBox(height: 12),
                Text(pr.blurb, style: TextStyle(color: p.muted, fontSize: 13, height: 1.5)),
                const SizedBox(height: 18),
                Text('SIZE', style: label(context)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: pr.sizes
                      .map((z) => ChoiceChip(
                            label: Text(z),
                            selected: size == z,
                            showCheckmark: false,
                            selectedColor: p.accent,
                            backgroundColor: Colors.transparent,
                            labelStyle: TextStyle(color: size == z ? p.onAccent : p.text),
                            side: BorderSide(color: p.accent),
                            onSelected: (_) => setState(() => size = z),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 18),
                Text('QUANTITY', style: label(context)),
                const SizedBox(height: 4),
                Row(children: [
                  IconButton.outlined(
                      onPressed: qty > 1 ? () => setState(() => qty--) : null,
                      icon: const Icon(Icons.remove, size: 16)),
                  SizedBox(
                      width: 44,
                      // ✨ JUICE: the number pops when it changes
                      child: Center(child: Pop(trigger: qty, child: Text('$qty', style: const TextStyle(fontSize: 16))))),
                  IconButton.outlined(
                      onPressed: () => setState(() => qty++), icon: const Icon(Icons.add, size: 16)),
                ]),
              ])),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: PrimaryButton('Add to Cart · ${money(pr.price * qty)}', () {
                if (size == null) {
                  HapticFeedback.heavyImpact(); // ✨ JUICE: "nope" vibration
                  notify('Please select a size first.', kind: Kind.error);
                  return;
                }
                HapticFeedback.mediumImpact(); // ✨ JUICE: "added!" vibration
                store.add(pr.id, size!, qty);
                showAddedSheet(context, pr, size!, qty);
              }, icon: Icons.shopping_bag_outlined),
            ),
          ),
        ]),
      ),
    );
  }
}

// ───────── Loved ─────────
class LovedScreen extends StatelessWidget {
  const LovedScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final p = P.of(context);
    return ListenableBuilder(
      listenable: store,
      builder: (_, __) {
        final items = products.where((e) => store.loved.contains(e.id)).toList();
        return Scaffold(
          appBar: bar(context, 'Loved clothes', sub: '${items.length} pieces'),
          body: items.isEmpty
              ? const EmptyState(Icons.favorite_border, 'Nothing loved yet.', 'Tap the heart on any piece to save it here.')
              : ListView(
                  padding: const EdgeInsets.all(16),
                  // ✨ JUICE: loved items appear one after another
                  children: stagger(items
                      .map((e) => Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(10),
                            decoration:
                                BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(14)),
                            child: Row(children: [
                              Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                      color: p.bg.withOpacity(.4), borderRadius: BorderRadius.circular(10)),
                                  child: Icon(e.icon, size: 32)),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(e.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                Text(e.cat, style: TextStyle(color: p.muted, fontSize: 11)),
                                const SizedBox(height: 4),
                                Text(money(e.price),
                                    style: TextStyle(color: p.accent, fontWeight: FontWeight.w700)),
                              ])),
                              Column(children: [
                                IconButton(
                                    onPressed: () => store.toggleLove(e.id),
                                    icon: Icon(Icons.favorite, color: p.accent, size: 18)),
                                TextButton(
                                    onPressed: () => go(context, ProductScreen(e)),
                                    child: Text('Choose size',
                                        style: TextStyle(fontSize: 10, color: p.accent))),
                              ]),
                            ]),
                          ))
                      .toList())),
        );
      },
    );
  }
}

// ───────── Cart ─────────
class CartScreen extends StatelessWidget {
  const CartScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final p = P.of(context);
    return ListenableBuilder(
      listenable: store,
      builder: (_, __) => Scaffold(
        appBar: bar(context, 'Your cart', sub: '${store.count} items'),
        body: store.cart.isEmpty
            ? const EmptyState(Icons.shopping_bag_outlined, 'Your cart is empty.', 'Find something you like and add it here.')
            : Column(children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: stagger(store.cart.entries.map((en) {
                      final parts = en.key.split('|');
                      final e = products[int.parse(parts[0])];
                      return Dismissible(
                       key: ValueKey(en.key),
                       direction: DismissDirection.endToStart,
                       onDismissed: (_) {
                         HapticFeedback.lightImpact();
                         store.setQty(en.key, 0);
                       },
                       background: Container(
                         margin: const EdgeInsets.only(bottom: 12),
                         padding: const EdgeInsets.only(right: 20),
                         alignment: Alignment.centerRight,
                         decoration: BoxDecoration(
                             color: const Color(0xFFE57373), borderRadius: BorderRadius.circular(14)),
                         child: const Icon(Icons.delete_outline, color: Colors.white),
                       ),
                       child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(14)),
                        child: Row(children: [
                          Icon(e.icon, size: 36),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(e.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                            Text('${e.cat} · Size ${parts[1]}', style: TextStyle(color: p.muted, fontSize: 11)),
                            Row(children: [
                              IconButton(
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () => store.setQty(en.key, en.value - 1),
                                  icon: const Icon(Icons.remove, size: 16)),
                              Pop(trigger: en.value, child: Text('${en.value}')), // ✨ JUICE
                              IconButton(
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () => store.setQty(en.key, en.value + 1),
                                  icon: const Icon(Icons.add, size: 16)),
                            ]),
                          ])),
                          Column(children: [
                            IconButton(
                                onPressed: () => store.setQty(en.key, 0),
                                icon: Icon(Icons.delete_outline, size: 18, color: p.accent)),
                            Text(money(e.price * en.value),
                                style: TextStyle(color: p.accent, fontWeight: FontWeight.w700)),
                          ]),
                        ]),
                      ),
                      );
                    }).toList()),
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('Total', style: TextStyle(color: p.muted)),
                        // ✨ JUICE: total pops when it changes
                        Pop(trigger: store.total, child: Text(money(store.total), style: serif(context, 22))),
                      ]),
                      const SizedBox(height: 12),
                      PrimaryButton('Checkout', () => go(context, const CheckoutScreen())),
                    ]),
                  ),
                ),
              ]),
      ),
    );
  }
}

// ───────── Checkout ─────────
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});
  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _key = GlobalKey<FormState>();
  final _name = TextEditingController(text: store.userName);
  final _addr = TextEditingController(text: store.savedAddress ?? '');
  final _city = TextEditingController(text: store.savedCity ?? '');
  final _postal = TextEditingController(text: store.savedPostal ?? '');
  late bool _save = store.saveDetails;
  String? req(String? v) => (v ?? '').trim().isEmpty ? 'Required' : null;

  @override
  Widget build(BuildContext context) {
    final p = P.of(context);
    Widget row(String a, String b, {bool bold = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(a, style: TextStyle(fontSize: bold ? 14 : 12, color: bold ? p.text : p.muted)),
            Text(b, style: bold ? serif(context, 20) : TextStyle(fontSize: 12, color: p.muted)),
          ]),
        );
    return Scaffold(
      appBar: bar(context, 'Checkout'),
      body: Form(
        key: _key,
        child: ListView(padding: const EdgeInsets.all(16), children: stagger([
          Text('DELIVERY', style: label(context)),
          const SizedBox(height: 10),
          Field('Full name', 'Your name', ctrl: _name, validator: req),
          Field('Address', 'Street and number', ctrl: _addr, validator: req),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(flex: 2, child: Field('City', 'City', ctrl: _city, validator: req)),
            const SizedBox(width: 10),
            Expanded(child: Field('Postal code', '00000', ctrl: _postal, validator: req)),
          ]),
          CheckboxListTile(
            value: _save,
            onChanged: (v) => setState(() => _save = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            dense: true,
            activeColor: p.accent,
            checkColor: p.onAccent,
            title: const Text('Save my details for next purchase', style: TextStyle(fontSize: 13)),
          ),
          const SizedBox(height: 8),
          Text('PAYMENT', style: label(context)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: p.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: p.accent)),
            child: Row(children: [
              Icon(Icons.payments_outlined, size: 18, color: p.accent),
              const SizedBox(width: 10),
              const Expanded(child: Text('Pay on delivery', style: TextStyle(fontSize: 13))),
              Icon(Icons.check, size: 16, color: p.accent),
            ]),
          ),
          const SizedBox(height: 6),
          Text('Demo only: no real payment is taken.', style: TextStyle(fontSize: 10, color: p.muted)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              row('Subtotal (${store.count} items)', money(store.total)),
              row('Delivery', 'Free'),
              Divider(color: p.border),
              row('Total', money(store.total), bold: true),
            ]),
          ),
          const SizedBox(height: 20),
          PrimaryButton('Place order', () {
            if (!_key.currentState!.validate()) {
              notify('Please fill in the required fields.', kind: Kind.error);
              return;
            }
            store.saveDetails = _save;
            store.userName = _name.text.trim();
            store.savedAddress = _save ? _addr.text.trim() : null;
            store.savedCity = _save ? _city.text.trim() : null;
            store.savedPostal = _save ? _postal.text.trim() : null;
            final total = store.total, n = store.count;
            HapticFeedback.heavyImpact(); // ✨ JUICE: celebration vibration
            store.clear();
            Navigator.pushAndRemoveUntil(
                context, MaterialPageRoute(builder: (_) => ConfirmScreen(total, n)), (r) => false);
            notify('Order placed successfully.', kind: Kind.success);
          }),
        ])),
      ),
    );
  }
}

// ───────── Confirmation ─────────
class ConfirmScreen extends StatelessWidget {
  final double total;
  final int items;
  const ConfirmScreen(this.total, this.items, {super.key});
  @override
  Widget build(BuildContext context) {
    final p = P.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            const Spacer(),
            // ✨ JUICE: the check mark pops in, the planet floats,
            // then the texts fade in one by one (index 1, 2, 3)
            Floating(
              child: Stack(alignment: Alignment.center, children: [
                const Planet(size: 50),
                Pop(trigger: 'done', child: Icon(Icons.check_circle, size: 44, color: p.accent)),
              ]),
            ),
            const SizedBox(height: 20),
            FadeIn(index: 1, child: Text('ORDER CONFIRMED', style: label(context))),
            const SizedBox(height: 8),
            FadeIn(
                index: 2,
                child: Text('Your outfit is on its\nway.',
                    textAlign: TextAlign.center, style: serif(context, 26))),
            const SizedBox(height: 10),
            FadeIn(
              index: 3,
              child: Text(
                  'Order #SF-1042 · $items items · ${money(total)}. Pay on\ndelivery, arriving in 3 to 5 days.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: p.muted, fontSize: 12, height: 1.5)),
            ),
            const Spacer(),
            PrimaryButton('Continue shopping', () {
              Navigator.pushAndRemoveUntil(
                  context, MaterialPageRoute(builder: (_) => const HomeScreen()), (r) => false);
            }),
          ]),
        ),
      ),
    );
  }
}
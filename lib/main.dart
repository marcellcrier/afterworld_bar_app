import 'dart:io';
import 'dart:math';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(const AfterWorldBarApp());
}

class AfterWorldBarApp extends StatelessWidget {
  const AfterWorldBarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()..initialize()),
      ],
      child: MaterialApp(
        title: 'AfterWorld Bar',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
          useMaterial3: true,
        ),
        home: const AccountLoginScreen(),
      ),
    );
  }
}

enum Role { admin, chef1, chef2, staff }
String roleLabel(Role r) => switch (r) {
  Role.admin => "VA / Admin",
  Role.chef1 => "Chef-Bar 1",
  Role.chef2 => "Chef-Bar 2",
  Role.staff => "Mitarbeiter",
};

class Permissions {
  bool canSeeRevenue;
  bool canEditProducts;
  bool canDeleteProducts;
  bool canAddDeliveries;
  bool canSeeRecommendations;
  bool canConfigureSystem;
  bool canManageUsers;
  bool canAreaLock;
  bool canSeeInventory;
  Permissions({
    this.canSeeRevenue = false,
    this.canEditProducts = false,
    this.canDeleteProducts = false,
    this.canAddDeliveries = false,
    this.canSeeRecommendations = false,
    this.canConfigureSystem = false,
    this.canManageUsers = false,
    this.canAreaLock = false,
    this.canSeeInventory = false,
  });
}

class User {
  final String id;
  String name;
  Role role;
  String pin;
  Permissions perms;
  User({required this.id, required this.name, required this.role, required this.pin, Permissions? perms})
      : perms = perms ?? Permissions();
}

class AppState extends ChangeNotifier {
  // ---- Accounts/Auth ----
  final Map<String, User> users = {};
  String? currentUserId;
  User? get currentUser => currentUserId != null ? users[currentUserId] : null;
  Role? get currentRole => currentUser?.role;

  // ---- Festival / Pricing ----
  DateTime festivalStart = DateTime.now().subtract(const Duration(hours: 1));
  DateTime festivalEnd = DateTime.now().add(const Duration(hours: 8));

  // Areas / Kassenprofile
  final List<String> areas = const ["Alle", "Bar", "Schankwagen", "VIP"];
  String selectedArea = "Bar";

  // Pfandbeträge
  int becherPfandCents = 300; // 3€
  int glasPfandCents = 600;   // 6€
  int bootPfandCents = 2000;  // 20€

  // Happy Hour
  TimeOfDay? hhStart = const TimeOfDay(hour: 0, minute: 0);
  TimeOfDay? hhEnd = const TimeOfDay(hour: 1, minute: 0);

  // Produkte & Lager
  final Map<String, Product> products = {};
  final Map<String, int> inventory = {};
  final Map<String, int> packSize = {};
  int warningThresholdPercent = 25;
  final List<Sale> sales = [];
  final Map<String, int> cart = {};

  // Bereichssperre (pro Gerät)
  bool areaLockEnabled = false;
  String? lockedArea;

  // ---- Permissions helpers ----
  Permissions defaultPermissionsForRole(Role r) {
    switch (r) {
      case Role.admin:
        return Permissions(
          canSeeRevenue: true,
          canEditProducts: true,
          canDeleteProducts: true,
          canAddDeliveries: true,
          canSeeRecommendations: true,
          canConfigureSystem: true,
          canManageUsers: true,
          canAreaLock: true,
          canSeeInventory: true,
        );
      case Role.chef1:
      case Role.chef2:
        return Permissions(
          canSeeRevenue: false,
          canEditProducts: true,
          canDeleteProducts: true,
          canAddDeliveries: true,
          canSeeRecommendations: true,
          canConfigureSystem: false,
          canManageUsers: false,
          canAreaLock: false,
          canSeeInventory: true,
        );
      case Role.staff:
      default:
        return Permissions(
          canSeeRevenue: false,
          canEditProducts: false,
          canDeleteProducts: false,
          canAddDeliveries: false,
          canSeeRecommendations: false,
          canConfigureSystem: false,
          canManageUsers: false,
          canAreaLock: false,
          canSeeInventory: false,
        );
    }
  }

  bool get pCanSeeRevenue => currentUser?.perms.canSeeRevenue ?? false;
  bool get pCanEditProducts => currentUser?.perms.canEditProducts ?? false;
  bool get pCanDeleteProducts => currentUser?.perms.canDeleteProducts ?? false;
  bool get pCanAddDeliveries => currentUser?.perms.canAddDeliveries ?? false;
  bool get pCanSeeRecommendations => currentUser?.perms.canSeeRecommendations ?? false;
  bool get pCanConfigureSystem => currentUser?.perms.canConfigureSystem ?? false;
  bool get pCanManageUsers => currentUser?.perms.canManageUsers ?? false;
  bool get pCanAreaLock => currentUser?.perms.canAreaLock ?? false;
  bool get pCanSeeInventory => currentUser?.perms.canSeeInventory ?? false;

  // ---------- INIT ----------
  void initialize() {
    // Default Accounts
    users['admin'] = User(id: 'admin', name: 'VA/Admin', role: Role.admin, pin: '2025', perms: defaultPermissionsForRole(Role.admin));
    users['chef1'] = User(id: 'chef1', name: 'Chef 1', role: Role.chef1, pin: '1111', perms: defaultPermissionsForRole(Role.chef1));
    users['chef2'] = User(id: 'chef2', name: 'Chef 2', role: Role.chef2, pin: '2222', perms: defaultPermissionsForRole(Role.chef2));
    users['staff1'] = User(id: 'staff1', name: 'Mitarbeiter', role: Role.staff, pin: '0000', perms: defaultPermissionsForRole(Role.staff));

    // Seed Produkte/Lager
    upsertProduct(Product(id: 'beer', name: 'Hell 0,4', priceCents: 500, color: Colors.amber, area: "Schankwagen", category: "Bier"));
    upsertProduct(Product(id: 'beer', name: 'Radler 0,4', priceCents: 500, color: Colors.amber, area: "Schankwagen", category: "Bier"));
    upsertProduct(Product(id: 'wasser', name: 'Wasser medium 0,5', priceCents: 500, color: Colors.amber, area: "Schankwagen", category: "Softdrinks"));
    upsertProduct(Product(id: 'redbull', name: 'Red Bull 0,25', priceCents: 500, color: Colors.amber, area: "Schankwagen", category: "Softdrinks"));
    upsertProduct(Product(id: 'colamix', name: 'Cola Mix 0,5', priceCents: 400, color: Colors.brown, area: "Schankwagen", category: "Softdrinks"));
    
    upsertProduct(Product(id: 'vodkaosaft', name: 'Vodka O-Saft', priceCents: 700, color: Colors.red, area: "Bar", category: "Longdrinks"));
    upsertProduct(Product(id: 'eisteekorn', name: 'Eistee Korn', priceCents: 700, color: Colors.red, area: "Bar", category: "Longdrinks"));
    upsertProduct(Product(id: 'barcadicola', name: 'Barcadi Cola', priceCents: 700, color: Colors.red, area: "Bar", category: "Longdrinks"));
    upsertProduct(Product(id: 'havanacola', name: 'Havana Cola', priceCents: 700, color: Colors.red, area: "Bar", category: "Longdrinks"));
    upsertProduct(Product(id: 'malibumara', name: 'Malibu Maracuja', priceCents: 700, color: Colors.red, area: "Bar", category: "Longdrinks"));
    upsertProduct(Product(id: 'maliosaft', name: 'Malibu O-Saft', priceCents: 700, color: Colors.red, area: "Bar", category: "Longdrinks"));
    upsertProduct(Product(id: 'wasser', name: 'Wasser medium 0,5', priceCents: 500, color: Colors.amber, area: "Bar", category: "Softdrinks"));
    upsertProduct(Product(id: 'beer', name: 'Hell 0,4', priceCents: 500, color: Colors.amber, area: "Bar", category: "Bier"));
    upsertProduct(Product(id: 'beer', name: 'Radler 0,4', priceCents: 500, color: Colors.amber, area: "Bar", category: "Bier"));
    upsertProduct(Product(id: 'colamix', name: 'Cola Mix 0,5', priceCents: 400, color: Colors.brown, area: "Bar", category: "Softdrinks"));
    upsertProduct(Product(id: 'redbull', name: 'Red Bull 0,25', priceCents: 400, color: Colors.amber, area: "Bar", category: "Softdrinks"));
    upsertProduct(Product(id: 'wodka', name: 'Wodka Shot', priceCents: 300, color: Colors.red, area: "Bar", category: "Shots"));    
    upsertProduct(Product(id: 'pfeffi', name: 'Pfeffi Shot', priceCents: 300, color: Colors.red, area: "Bar", category: "Shots"));    
    upsertProduct(Product(id: 'jäger', name: 'Jäger Shot', priceCents: 300, color: Colors.red, area: "Bar", category: "Shots"));    
    upsertProduct(Product(id: 'ficken', name: 'Ficken Shot', priceCents: 300, color: Colors.red, area: "Bar", category: "Shots"));        
    
    inventory.addAll({'beer': 200, 'cola': 120, 'vodkaBull': 80, 'water': 150});
    packSize.addAll({'beer': 24, 'cola': 24, 'vodkaBull': 6, 'water': 12});

    // Pfand-„Produkte“ (wirken nicht aufs Lager)
    _createOrUpdateDepositProducts();
  }

  // ---------- Auth ----------
  bool loginWithPin(String userId, String pin) {
    final u = users[userId];
    if (u == null) return false;
    if (u.pin != pin) return false;
    currentUserId = userId;
    notifyListeners();
    return true;
  }

  void logout() {
    currentUserId = null;
    cart.clear();
    notifyListeners();
  }

  bool isAdmin() => currentRole == Role.admin;

  bool checkAdminPin(String pin) {
    final adminUser = users.values.firstWhere(
      (u) => u.role == Role.admin,
      orElse: () => User(id: 'admin', name: 'VA/Admin', role: Role.admin, pin: '2025'),
    );
    return pin == adminUser.pin;
  }

  void changeOwnPin({required String oldPin, required String newPin}) {
    final u = currentUser;
    if (u == null) return;
    if (u.pin != oldPin) throw Exception("Old PIN incorrect");
    u.pin = newPin;
    notifyListeners();
  }

  void adminResetPin({required String userId, required String newPin}) {
    final u = users[userId];
    if (u == null) return;
    u.pin = newPin;
    notifyListeners();
  }

  String createUser({required String name, required Role role, required String pin, Permissions? perms}) {
    String base = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
    if (base.isEmpty) base = "user";
    String id = base;
    int i = 1;
    while (users.containsKey(id)) { id = "$base$i"; i++; }
    users[id] = User(id: id, name: name, role: role, pin: pin, perms: perms ?? defaultPermissionsForRole(role));
    notifyListeners();
    return id;
  }

  void updateUser({required String userId, String? name, Role? role, Permissions? perms}) {
    final u = users[userId];
    if (u == null) return;
    if (name != null) u.name = name;
    if (role != null) u.role = role;
    if (perms != null) { u.perms = perms; }
    notifyListeners();
  }

  void deleteUser(String userId) {
    if (!users.containsKey(userId)) return;
    final isDeletingAdmin = users[userId]!.role == Role.admin;
    final admins = users.values.where((u) => u.role == Role.admin).length;
    if (isDeletingAdmin && admins <= 1) return;
    users.remove(userId);
    if (currentUserId == userId) { logout(); }
    notifyListeners();
  }

  // ---------- Produkte / POS ----------
  void _createOrUpdateDepositProducts() {
    upsertProduct(Product(id: 'pfand_becher', name: 'Becherpfand', priceCents: becherPfandCents, color: Colors.teal, affectsInventory: false, showInGrid: false, area: "Alle", category: "Pfand"));
    upsertProduct(Product(id: 'pfand_becher_back', name: 'Pfand zurück (Becher)', priceCents: -becherPfandCents, color: Colors.teal, affectsInventory: false, showInGrid: false, area: "Alle", category: "Pfand"));
    upsertProduct(Product(id: 'pfand_glas', name: 'Glaspfand', priceCents: glasPfandCents, color: Colors.indigo, affectsInventory: false, showInGrid: false, area: "Alle", category: "Pfand"));
    upsertProduct(Product(id: 'pfand_glas_back', name: 'Pfand zurück (Glas)', priceCents: -glasPfandCents, color: Colors.indigo, affectsInventory: false, showInGrid: false, area: "Alle", category: "Pfand"));
    upsertProduct(Product(id: 'pfand_boot', name: 'Boot-Pfand', priceCents: bootPfandCents, color: Colors.orange, affectsInventory: false, showInGrid: false, area: "VIP", category: "Pfand"));
    upsertProduct(Product(id: 'pfand_boot_back', name: 'Pfand zurück (Boot)', priceCents: -bootPfandCents, color: Colors.orange, affectsInventory: false, showInGrid: false, area: "VIP", category: "Pfand"));
  }

  void selectArea(String a) { if (areaLockEnabled) { return; } selectedArea = a; notifyListeners(); }

  void addToCart(String productId) { cart.update(productId, (v) => v + 1, ifAbsent: () => 1); notifyListeners(); }
  void addToCartMultiple(String productId, int count) { for (int i = 0; i < count; i++) { addToCart(productId); } }

  void removeFromCart(String productId) {
    if (!cart.containsKey(productId)) return;
    int q = cart[productId]!;
    if (q <= 1) { cart.remove(productId); } else { cart[productId] = q - 1; }
    notifyListeners();
  }

  int currentPriceCents(Product p) {
    if (p.happyHourPriceCents == null || hhStart == null || hhEnd == null) return p.priceCents;
    final now = TimeOfDay.fromDateTime(DateTime.now());
    bool geq(TimeOfDay a, TimeOfDay b) => a.hour > b.hour || (a.hour == b.hour && a.minute >= b.minute);
    bool lt(TimeOfDay a, TimeOfDay b) => a.hour < b.hour || (a.hour == b.hour && a.minute < b.minute);
    final start = hhStart!;
    final end = hhEnd!;
    bool inWindow = end.hour > start.hour || (end.hour == start.hour && end.minute > start.minute)
        ? (geq(now, start) && lt(now, end))
        : (geq(now, start) || lt(now, end)); // Overnight-Fenster
    return inWindow ? (p.happyHourPriceCents ?? p.priceCents) : p.priceCents;
  }

  int cartTotalCents() {
    int total = 0;
    cart.forEach((pid, qty) {
      final p = products[pid];
      total += ((p != null) ? currentPriceCents(p) : 0) * qty;
    });
    return total;
  }

  void checkout({String paymentMethod = "Token/Bar"}) {
    final now = DateTime.now();
    cart.forEach((pid, qty) {
      final prod = products[pid];
      if (prod == null) return;
      if (prod.affectsInventory) {
        inventory.update(pid, (v) => max(0, v - qty), ifAbsent: () => 0);
      }
      sales.add(Sale(productId: pid, quantity: qty, at: now, paymentMethod: paymentMethod, priceCentsAtSale: currentPriceCents(prod)));
    });
    cart.clear();
    notifyListeners();
  }

  void upsertProduct(Product p) {
    products[p.id] = p;
    if (p.affectsInventory) { inventory.putIfAbsent(p.id, () => 0); }
    if (p.packSizeUnits != null) { packSize[p.id] = p.packSizeUnits!; }
    notifyListeners();
  }

  void deleteProduct(String id) {
    final prod = products[id];
    if (prod == null) return;
    products.remove(id);
    if (prod.affectsInventory) { inventory.remove(id); }
    packSize.remove(id);
    cart.remove(id);
    notifyListeners();
  }

  void addDelivery(String productId, int qty) { inventory.update(productId, (v) => v + qty, ifAbsent: () => qty); notifyListeners(); }

  int totalUnitsSold(String productId) => sales.where((s) => s.productId == productId).fold(0, (sum, s) => sum + s.quantity);
  double hoursSinceStart() { final now = DateTime.now(); return now.difference(festivalStart).inMinutes / 60.0; }
  double hoursUntilEnd() { final now = DateTime.now(); return festivalEnd.isAfter(now) ? festivalEnd.difference(now).inMinutes / 60.0 : 0.0; }
  double ratePerHour(String productId) { final sold = totalUnitsSold(productId); final h = max(0.25, hoursSinceStart()); return sold / h; }

  int recommendationToOrder(String productId) {
    final prod = products[productId];
    if (prod == null || !prod.affectsInventory) return 0;
    final remainingHours = hoursUntilEnd();
    final rate = ratePerHour(productId);
    final expectedNeed = (rate * remainingHours).ceil();
    final have = inventory[productId] ?? 0;
    int needToOrder = expectedNeed - have;
    if (needToOrder <= 0) return 0;
    final pack = packSize[productId];
    if (pack != null && pack > 0) { final packs = (needToOrder / pack).ceil(); return packs * pack; }
    return needToOrder;
  }

  bool belowThreshold(String productId) {
    final prod = products[productId];
    if (prod == null || !prod.affectsInventory) return false;
    final have = inventory[productId] ?? 0;
    final sold = totalUnitsSold(productId);
    final totalHandled = have + sold;
    if (totalHandled == 0) return false;
    final percentLeft = (have / totalHandled) * 100.0;
    return percentLeft <= warningThresholdPercent;
  }

  void updateDepositAmounts({int? becher, int? glas, int? boot}) {
    if (becher != null) becherPfandCents = becher;
    if (glas != null) glasPfandCents = glas;
    if (boot != null) bootPfandCents = boot;
    _createOrUpdateDepositProducts();
    notifyListeners();
  }

  // ---------- CSV Import ----------
  Future<void> importCsv() async {
    final res = await FilePicker.platform.pickFiles(allowMultiple: true, type: FileType.custom, allowedExtensions: ['csv']);
    if (res == null) return;
    for (final file in res.files) {
      final path = file.path;
      if (path == null) continue;
      final content = await File(path).readAsString();
      final rows = const CsvToListConverter(eol: '\n', fieldDelimiter: ',', textDelimiter: '"').convert(content);
      if (rows.isEmpty) continue;
      final headers = rows.first.map((e) => e.toString().trim().toLowerCase()).toList();
      int idx(String name) => headers.indexOf(name.toLowerCase());
      int iArea = idx('area');
      int iCategory = idx('category');
      int iName = idx('name');
      int iVariant = idx('variant');
      int iVol = idx('volume_l');
      int iShots = idx('shots_cl');
      int iPrice = idx('price_eur');
      int iHh = idx('happy_hour_price_eur');
      int iNotes = idx('notes');
      int iPack = idx('pack_size_units');

      for (int r = 1; r < rows.length; r++) {
        final row = rows[r];
        String area = (iArea >= 0 && row.length > iArea) ? row[iArea].toString().trim() : "Bar";
        String category = (iCategory >= 0 && row.length > iCategory) ? row[iCategory].toString().trim() : "";
        String name = (iName >= 0 && row.length > iName) ? row[iName].toString().trim() : "";
        String variant = (iVariant >= 0 && row.length > iVariant) ? row[iVariant].toString().trim() : "";
        String vol = (iVol >= 0 && row.length > iVol) ? row[iVol].toString().trim() : "";
        String shots = (iShots >= 0 && row.length > iShots) ? row[iShots].toString().trim() : "";
        String price = (iPrice >= 0 && row.length > iPrice) ? row[iPrice].toString().trim() : "0";
        String hh = (iHh >= 0 && row.length > iHh) ? row[iHh].toString().trim() : "";
        String notes = (iNotes >= 0 && row.length > iNotes) ? row[iNotes].toString().trim() : "";
        String pack = (iPack >= 0 && row.length > iPack) ? row[iPack].toString().trim() : "";

        if (name.isEmpty) continue;
        int cents(String v) {
          final nv = v.replaceAll(',', '.').trim();
          if (nv.isEmpty) return 0;
          final d = double.tryParse(nv) ?? 0.0;
          return (d * 100).round();
        }

        int? packUnits = int.tryParse(pack);
        final idBase = (name + "_" + variant + "_" + vol).toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
        final id = "${area.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '')}_$idBase";

        final product = Product(
          id: id,
          name: variant.isNotEmpty ? "$name ($variant)" : name,
          priceCents: cents(price),
          happyHourPriceCents: hh.isNotEmpty ? cents(hh) : null,
          color: Colors.grey,
          area: area,
          category: category.isNotEmpty ? category : "Sonstiges",
          variant: variant,
          volumeLiters: double.tryParse(vol.replaceAll(',', '.')),
          shotsCl: double.tryParse(shots.replaceAll(',', '.')),
          notes: notes,
          packSizeUnits: packUnits,
        );
        upsertProduct(product);
      }
    }
  }

  // ---------- Area Lock ----------
  void enableAreaLock(String a) { areaLockEnabled = true; lockedArea = a; selectedArea = a; notifyListeners(); }
  void disableAreaLock() { areaLockEnabled = false; lockedArea = null; notifyListeners(); }
}

class Product {
  final String id;
  final String name;
  final int priceCents;
  final int? happyHourPriceCents;
  final Color color;
  final bool affectsInventory;
  final bool showInGrid;
  final String area;
  final String category;
  final String? variant;
  final double? volumeLiters;
  final double? shotsCl;
  final String? notes;
  final int? packSizeUnits;

  Product({
    required this.id,
    required this.name,
    required this.priceCents,
    this.happyHourPriceCents,
    this.color = Colors.grey,
    this.affectsInventory = true,
    this.showInGrid = true,
    this.area = "Bar",
    this.category = "Sonstiges",
    this.variant,
    this.volumeLiters,
    this.shotsCl,
    this.notes,
    this.packSizeUnits,
  });
}

class Sale {
  final String productId;
  final int quantity;
  final DateTime at;
  final String paymentMethod;
  final int priceCentsAtSale;
  Sale({required this.productId, required this.quantity, required this.at, required this.paymentMethod, required this.priceCentsAtSale});
}

// ----------------- Screens -----------------

class AccountLoginScreen extends StatelessWidget {
  const AccountLoginScreen({super.key});

  Future<void> _promptPinAndLogin(BuildContext context, String userId) async {
    final ctrl = TextEditingController();
    bool ok = false;
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('PIN eingeben'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'PIN'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
          FilledButton(
            onPressed: () {
              ok = context.read<AppState>().loginWithPin(userId, ctrl.text.trim());
              Navigator.pop(context);
            },
            child: const Text('Login'),
          ),
        ],
      ),
    );
    if (!context.mounted) return;
    if (ok) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeShell()));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Falsche PIN')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final users = context.watch<AppState>().users.values.toList();
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 24),
                  const Icon(Icons.local_bar, size: 72),
                  const SizedBox(height: 8),
                  const Text("AfterWorld Bar", textAlign: TextAlign.center, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  const Text("Bitte Account wählen", textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.separated(
                      itemCount: users.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final u = users[i];
                        return Card(
                          child: ListTile(
                            leading: Icon(
                              u.role == Role.admin ? Icons.verified_user :
                              u.role == Role.chef1 || u.role == Role.chef2 ? Icons.manage_accounts :
                              Icons.person,
                            ),
                            title: Text(u.name),
                            subtitle: Text(roleLabel(u.role)),
                            trailing: FilledButton(
                              onPressed: () => _promptPinAndLogin(context, u.id),
                              child: const Text("Anmelden"),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HomeShell extends StatefulWidget { const HomeShell({super.key}); @override State<HomeShell> createState() => _HomeShellState(); }
class _HomeShellState extends State<HomeShell> {
  int index = 0;
  @override
  Widget build(BuildContext context) {
    final tabs = <Widget>[
      const PosScreen(),
      if (context.watch<AppState>().pCanSeeInventory) const InventoryScreen(),
      if (context.watch<AppState>().pCanSeeRecommendations) const RecommendationsScreen(),
      const DashboardScreen(),
      if (context.watch<AppState>().pCanEditProducts || context.watch<AppState>().pCanManageUsers) const AdminScreen(),
      const SettingsScreen(),
    ];
    final labels = <String>[
      "Kasse",
      if (context.watch<AppState>().pCanSeeInventory) "Lager",
      if (context.watch<AppState>().pCanSeeRecommendations) "Nachorder",
      "Live",
      if (context.watch<AppState>().pCanEditProducts || context.watch<AppState>().pCanManageUsers) "Admin",
      "Einstellungen",
    ];
    return Scaffold(
      appBar: AppBar(title: Text("AfterWorld Bar • ${roleLabel(context.watch<AppState>().currentRole!)}")),
      body: SafeArea(child: tabs[index]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: labels.map((l) => NavigationDestination(icon: const Icon(Icons.circle_outlined), label: l)).toList(),
      ),
    );
  }
}

class PosScreen extends StatelessWidget {
  const PosScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final currency = NumberFormat.simpleCurrency(locale: "de_DE", name: "€");
    final gridProducts = app.products.values.where((p) => p.showInGrid && (app.selectedArea == "Alle" || p.area == app.selectedArea)).toList();
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              const Text("Bereich:", style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              if (app.areaLockEnabled) const Icon(Icons.lock, size: 18),
              const SizedBox(width: 4),
              DropdownButton<String>(
                value: app.areaLockEnabled && app.lockedArea != null ? app.lockedArea : app.selectedArea,
                items: app.areas.map((a) => DropdownMenuItem(value: a, child: Text(a))).toList(),
                onChanged: app.areaLockEnabled ? null : (v) { if (v != null) app.selectArea(v); },
              ),
              const Spacer(),
              Text("HH: ${app.hhStart?.format(context) ?? '-'} - ${app.hhEnd?.format(context) ?? '-'}"),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: GridView.count(
                    crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8,
                    children: gridProducts.map((p) => ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: p.color.withOpacity(0.15)),
                      onPressed: () => app.addToCart(p.id),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text(p.name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        Text(currency.format(app.currentPriceCents(p) / 100.0)),
                        if (p.affectsInventory) ...[const SizedBox(height: 6), Text("Lager: ${app.inventory[p.id] ?? 0}", style: const TextStyle(fontSize: 12))],
                      ]),
                    )).toList(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        const Text("Warenkorb", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          FilledButton.tonal(onPressed: () => app.addToCart('pfand_becher'), child: const Text("Becherpfand +")),
                          FilledButton.tonal(onPressed: () => app.addToCartMultiple('pfand_becher', 5), child: const Text("Becherpfand x5")),
                          FilledButton.tonal(onPressed: () => app.addToCart('pfand_becher_back'), child: const Text("Pfand zurück (Becher)")),
                          FilledButton.tonal(onPressed: () => app.addToCartMultiple('pfand_becher_back', 5), child: const Text("Zurück (Becher) x5")),
                          FilledButton.tonal(onPressed: () => app.addToCart('pfand_glas'), child: const Text("Glas-Pfand +")),
                          FilledButton.tonal(onPressed: () => app.addToCart('pfand_glas_back'), child: const Text("Pfand zurück (Glas)")),
                          if (app.selectedArea == "VIP") ...[
                            FilledButton.tonal(onPressed: () => app.addToCart('pfand_boot'), child: const Text("Boot-Pfand +")),
                            FilledButton.tonal(onPressed: () => app.addToCart('pfand_boot_back'), child: const Text("Pfand zurück (Boot)")),
                          ],
                        ]),
                        const SizedBox(height: 8),
                        Expanded(
                          child: ListView(
                            children: app.cart.entries.map((e) {
                              final p = app.products[e.key]!;
                              final qty = e.value;
                              return ListTile(
                                title: Text(p.name),
                                subtitle: Text("x$qty • ${currency.format((app.currentPriceCents(p)/100.0))}"),
                                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                                  IconButton(onPressed: () => app.removeFromCart(e.key), icon: const Icon(Icons.remove)),
                                  IconButton(onPressed: () => app.addToCart(e.key), icon: const Icon(Icons.add)),
                                ]),
                              );
                            }).toList(),
                          ),
                        ),
                        const Divider(),
                        Text("Summe: ${currency.format(app.cartTotalCents() / 100.0)}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        FilledButton(onPressed: app.cart.isEmpty ? null : () => app.checkout(), child: const Text("Abkassieren")),
                      ]),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final invProducts = app.products.values.where((p) => p.affectsInventory && (app.selectedArea == "Alle" || p.area == app.selectedArea)).toList();
    return Padding(
      padding: const EdgeInsets.all(12),
      child: ListView(
        children: invProducts.map((p) {
          final inv = app.inventory[p.id] ?? 0;
          final below = app.belowThreshold(p.id);
          return Card(
            child: ListTile(
              title: Text(p.name),
              subtitle: Text("${p.category} • Bestand: $inv"),
              leading: Icon(below ? Icons.warning_amber : Icons.local_drink),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                if (app.pCanAddDeliveries) IconButton(icon: const Icon(Icons.add_box_outlined), onPressed: () { _showAddDeliveryDialog(context, p.id); }),
                if (app.pCanEditProducts) IconButton(icon: const Icon(Icons.edit), onPressed: () { _showEditProductDialog(context, p); }),
                if (app.pCanDeleteProducts) IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => context.read<AppState>().deleteProduct(p.id)),
              ]),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showAddDeliveryDialog(BuildContext context, String productId) {
    final controller = TextEditingController();
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text("Lieferschein / Lieferung eintragen"),
      content: TextField(controller: controller, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Menge")),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Abbrechen")),
        FilledButton(onPressed: () { final qty = int.tryParse(controller.text.trim()) ?? 0; if (qty > 0) { context.read<AppState>().addDelivery(productId, qty); } Navigator.pop(context); }, child: const Text("Speichern")),
      ],
    ));
  }

  void _showEditProductDialog(BuildContext context, Product p) {
    final name = TextEditingController(text: p.name);
    final price = TextEditingController(text: (p.priceCents / 100.0).toStringAsFixed(2));
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text("Produkt bearbeiten"),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: name, decoration: const InputDecoration(labelText: "Name")),
        TextField(controller: price, decoration: const InputDecoration(labelText: "Preis (€)"), keyboardType: TextInputType.number),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Abbrechen")),
        FilledButton(onPressed: () {
          final cents = ((double.tryParse(price.text.replaceAll(',', '.')) ?? 0.0) * 100).round();
          context.read<AppState>().upsertProduct(Product(
            id: p.id, name: name.text.trim(), priceCents: cents, color: p.color, affectsInventory: p.affectsInventory, showInGrid: p.showInGrid,
            area: p.area, category: p.category, variant: p.variant, volumeLiters: p.volumeLiters, shotsCl: p.shotsCl, notes: p.notes, packSizeUnits: p.packSizeUnits,
          ));
          Navigator.pop(context);
        }, child: const Text("Speichern")),
      ],
    ));
  }
}

class RecommendationsScreen extends StatelessWidget {
  const RecommendationsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final canConfigure = app.pCanConfigureSystem;
    final invProducts = app.products.values.where((p) => p.affectsInventory && (app.selectedArea == "Alle" || p.area == app.selectedArea)).toList();
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text("Prognose bis: ${DateFormat.Hm().format(app.festivalEnd)}  •  Reststunden: ${app.hoursUntilEnd().toStringAsFixed(1)}")),
          if (canConfigure) FilledButton.tonal(onPressed: () async { await _showConfigDialog(context); }, child: const Text("Konfigurieren")),
        ]),
        const SizedBox(height: 8),
        Expanded(child: ListView(children: invProducts.map((p) {
          final have = app.inventory[p.id] ?? 0;
          final rate = app.ratePerHour(p.id);
          final toOrder = app.recommendationToOrder(p.id);
          final warning = app.belowThreshold(p.id);
          return Card(child: ListTile(
            title: Text(p.name),
            subtitle: Text("${p.category} • Rate: ${rate.toStringAsFixed(2)}/h • Bestand: $have"),
            trailing: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text("Nachorder: ${toOrder > 0 ? toOrder : 0}"),
              if (warning) const Text("⚠️ Schwelle erreicht", style: TextStyle(fontSize: 12)),
            ]),
          ));
        }).toList())),
      ]),
    );
  }

  Future<void> _showConfigDialog(BuildContext context) async {
    final app = context.read<AppState>();
    final thr = TextEditingController(text: app.warningThresholdPercent.toString());
    final becher = TextEditingController(text: (app.becherPfandCents/100).toStringAsFixed(2));
    final glas = TextEditingController(text: (app.glasPfandCents/100).toStringAsFixed(2));
    final boot = TextEditingController(text: (app.bootPfandCents/100).toStringAsFixed(2));

    TimeOfDay start = app.hhStart ?? const TimeOfDay(hour: 0, minute: 0);
    TimeOfDay end = app.hhEnd ?? const TimeOfDay(hour: 1, minute: 0);

    return showDialog(context: context, builder: (_) => StatefulBuilder(builder: (context, setState) {
      return AlertDialog(
        title: const Text("Konfiguration (nur VA)"),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(controller: thr, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Schwellenwert % (Warnung)")),
          const SizedBox(height: 8),
          const Text("Pfandbeträge (€)"),
          Row(children: [
            Expanded(child: TextField(controller: becher, decoration: const InputDecoration(labelText: "Becher"))),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: glas, decoration: const InputDecoration(labelText: "Glas"))),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: boot, decoration: const InputDecoration(labelText: "Boot"))),
          ]),
          const SizedBox(height: 12),
          const Text("Happy Hour Fenster"),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () { setState(() => start = TimeOfDay(hour: (start.hour + 23) % 24, minute: start.minute)); }, child: Text("Start: ${start.format(context)}  (tap: -1h)"))),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton(onPressed: () { setState(() => end = TimeOfDay(hour: (end.hour + 1) % 24, minute: end.minute)); }, child: Text("Ende: ${end.format(context)}  (tap: +1h)"))),
          ]),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Abbrechen")),
          FilledButton(onPressed: () {
            int? toCents(String v) { final d = double.tryParse(v.replaceAll(',', '.')); return d != null ? (d*100).round() : null; }
            app.warningThresholdPercent = int.tryParse(thr.text) ?? app.warningThresholdPercent;
            app.updateDepositAmounts(becher: toCents(becher.text), glas: toCents(glas.text), boot: toCents(boot.text));
            app.hhStart = start; app.hhEnd = end;
            app.notifyListeners();
            Navigator.pop(context);
          }, child: const Text("Speichern")),
        ],
      );
    }));
  }
}

class DashboardScreen extends StatelessWidget { const DashboardScreen({super.key});
  @override Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    int totalSales = app.sales.fold(0, (sum, s) => sum + s.quantity);
    return Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(spacing: 12, runSpacing: 12, children: [
        _InfoChip(label: "Verkäufe gesamt (Einheiten)", value: "$totalSales"),
        _InfoChip(label: "Produkte", value: "${app.products.length}"),
        _InfoChip(label: "Stunden seit Start", value: app.hoursSinceStart().toStringAsFixed(1)),
        _InfoChip(label: "Stunden bis Ende", value: app.hoursUntilEnd().toStringAsFixed(1)),
      ]),
      const SizedBox(height: 12),
      Expanded(child: ListView(children: app.products.values.map((p) {
        final sold = app.totalUnitsSold(p.id);
        final inv = p.affectsInventory ? " | Bestand: ${app.inventory[p.id] ?? 0}" : "";
        return ListTile(leading: const Icon(Icons.bar_chart), title: Text("${p.name} (${p.area})"), subtitle: Text(p.category), trailing: Text("verkauft: $sold$inv"));
      }).toList())),
    ]));
  }
}

class _InfoChip extends StatelessWidget { final String label; final String value; const _InfoChip({required this.label, required this.value});
  @override Widget build(BuildContext context) { return Chip(label: Text("$label\n$value", textAlign: TextAlign.center), padding: const EdgeInsets.all(12)); }
}

class AdminScreen extends StatelessWidget { const AdminScreen({super.key});
  @override Widget build(BuildContext context) {
    final app = context.watch<AppState>(); final name = TextEditingController(); final price = TextEditingController();

    return Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (context.watch<AppState>().pCanEditProducts) const Text("Produkt hinzufügen", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      if (context.watch<AppState>().pCanEditProducts) Row(children: [
        Expanded(child: TextField(controller: name, decoration: const InputDecoration(labelText: "Name"))),
        const SizedBox(width: 8),
        Expanded(child: TextField(controller: price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Preis (€)"))),
        const SizedBox(width: 8),
        FilledButton(onPressed: () {
          final id = name.text.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
          final cents = ((double.tryParse(price.text.replaceAll(',', '.')) ?? 0.0) * 100).round();
          if (id.isNotEmpty && cents != 0) { app.upsertProduct(Product(id: id, name: name.text.trim(), priceCents: cents, color: Colors.grey, area: app.selectedArea, category: "Manuell")); name.clear(); price.clear(); }
        }, child: const Text("Anlegen")),
      ]),
      const SizedBox(height: 16),
      Wrap(spacing: 8, runSpacing: 8, children: [
        if (context.watch<AppState>().pCanEditProducts) FilledButton.tonal(
          onPressed: () async {
            await app.importCsv();
            // ignore: use_build_context_synchronously
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("CSV importiert (siehe Produkte)")));
          },
          child: const Text("CSV importieren"),
        ),
        if (context.watch<AppState>().pCanManageUsers) FilledButton.tonal(
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const UserManagementScreen()));
          },
          child: const Text("Benutzer & Rechte"),
        ),
      ]),
      const SizedBox(height: 16),
      const Divider(),
      const Text("Export & Tools", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, children: [
        FilledButton.tonal(onPressed: () { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("CSV-Export (Stub) – Backend/Speicher folgt"))); }, child: const Text("CSV Export")),
      ]),
    ]));
  }
}

class SettingsScreen extends StatelessWidget { const SettingsScreen({super.key});
  @override Widget build(BuildContext context) {
    final app = context.watch<AppState>(); final start = DateFormat.yMd().add_Hm().format(app.festivalStart); final end = DateFormat.yMd().add_Hm().format(app.festivalEnd);
    return Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text("Einstellungen", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Text("Angemeldet: ${app.currentUser?.name ?? '-'} (${app.currentRole != null ? roleLabel(app.currentRole!) : '-'})"),
      const SizedBox(height: 8),
      Text("Festival-Start: $start"),
      Text("Festival-Ende:  $end"),
      const SizedBox(height: 8),
      Text("Pfand: Becher ${NumberFormat.simpleCurrency(locale: 'de_DE', name: '€').format(app.becherPfandCents/100)} • Glas ${NumberFormat.simpleCurrency(locale: 'de_DE', name: '€').format(app.glasPfandCents/100)} • Boot ${NumberFormat.simpleCurrency(locale: 'de_DE', name: '€').format(app.bootPfandCents/100)}"),
      const SizedBox(height: 8),
      Text("Happy Hour: ${app.hhStart?.format(context) ?? '-'} – ${app.hhEnd?.format(context) ?? '-'}"),
      const SizedBox(height: 8),
      Text("Aktiver Bereich: ${app.selectedArea}"),
      const SizedBox(height: 12),
      const Divider(),
      const Text("Meine PIN", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      const _SelfPinChangeCard(),
      const SizedBox(height: 12),
      if (app.pCanAreaLock) ...[
        const Divider(),
        const Text("Bereichssperre (nur VA)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const _AreaLockCard(),
      ],
      const Spacer(),
      FilledButton(onPressed: () { context.read<AppState>().logout(); Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const AccountLoginScreen()), (route) => false); }, child: const Text("Abmelden")),
    ]));
  }
}

class _SelfPinChangeCard extends StatefulWidget { const _SelfPinChangeCard({super.key}); @override State<_SelfPinChangeCard> createState() => _SelfPinChangeCardState(); }
class _SelfPinChangeCardState extends State<_SelfPinChangeCard> {
  final oldPin = TextEditingController();
  final newPin1 = TextEditingController();
  final newPin2 = TextEditingController();
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(controller: oldPin, keyboardType: TextInputType.number, obscureText: true, decoration: const InputDecoration(labelText: 'Aktuelle PIN')),
          const SizedBox(height: 8),
          TextField(controller: newPin1, keyboardType: TextInputType.number, obscureText: true, decoration: const InputDecoration(labelText: 'Neue PIN')),
          const SizedBox(height: 8),
          TextField(controller: newPin2, keyboardType: TextInputType.number, obscureText: true, decoration: const InputDecoration(labelText: 'Neue PIN bestätigen')),
          const SizedBox(height: 8),
          FilledButton.tonal(onPressed: () {
            try {
              if (newPin1.text.trim().isEmpty || newPin1.text.trim() != newPin2.text.trim()) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Neue PINs stimmen nicht')));
                return;
              }
              app.changeOwnPin(oldPin: oldPin.text.trim(), newPin: newPin1.text.trim());
              oldPin.clear(); newPin1.clear(); newPin2.clear();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN geändert')));
            } catch (_) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aktuelle PIN falsch')));
            }
          }, child: const Text('PIN ändern')),
        ]),
      ),
    );
  }
}

class _AreaLockCard extends StatefulWidget { const _AreaLockCard({super.key}); @override State<_AreaLockCard> createState() => _AreaLockCardState(); }
class _AreaLockCardState extends State<_AreaLockCard> {
  String? areaToLock;
  Future<String?> _askPin(BuildContext context) async {
    final ctrl = TextEditingController();
    String? pin;
    await showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('Admin-PIN eingeben'),
      content: TextField(controller: ctrl, keyboardType: TextInputType.number, obscureText: true, decoration: const InputDecoration(labelText: 'PIN')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
        FilledButton(onPressed: () { pin = ctrl.text.trim(); Navigator.pop(context); }, child: const Text('OK')),
      ],
    ));
    return pin;
  }
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    areaToLock ??= app.selectedArea;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (app.areaLockEnabled) ...[
            Text('Status: GESPERRT auf \"${app.lockedArea}\"'),
            const SizedBox(height: 8),
            FilledButton.tonal(onPressed: () async {
              final pin = await _askPin(context);
              if (pin == null) return;
              if (!app.checkAdminPin(pin)) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Falsche PIN'))); return; }
              app.disableAreaLock();
            }, child: const Text('Entsperren')),
          ] else ...[
            Row(children: [
              const Text('Sperren auf:'),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: areaToLock,
                items: app.areas.where((a) => a != 'Alle').map((a) => DropdownMenuItem(value: a, child: Text(a))).toList(),
                onChanged: (v) => setState(() => areaToLock = v),
              ),
            ]),
            const SizedBox(height: 8),
            FilledButton(onPressed: () async {
              final pin = await _askPin(context);
              if (pin == null) return;
              if (!app.checkAdminPin(pin)) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Falsche PIN'))); return; }
              app.enableAreaLock(areaToLock ?? app.selectedArea);
            }, child: const Text('Sperre aktivieren')),
            const SizedBox(height: 8),
            const Text('Hinweis: Bei aktiver Sperre ist der Bereichswechsel auf diesem Gerät deaktiviert.'),
          ],
        ]),
      ),
    );
  }
}

// ---------- User Management (Admin) ----------

class UserManagementScreen extends StatelessWidget {
  const UserManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    if (!(app.pCanManageUsers)) {
      return const Scaffold(body: Center(child: Text('Nur für VA/Admin')));
    }
    final users = app.users.values.toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Benutzer & Rechte')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () => _showCreateDialog(context),
                icon: const Icon(Icons.person_add),
                label: const Text('Neuen Account hinzufügen'),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                itemBuilder: (_, i) {
                  final u = users[i];
                  return Card(
                    child: ListTile(
                      leading: Icon(
                        u.role == Role.admin ? Icons.verified_user :
                        u.role == Role.chef1 || u.role == Role.chef2 ? Icons.manage_accounts :
                        Icons.person,
                      ),
                      title: Text(u.name),
                      subtitle: Text("${roleLabel(u.role)} • ID: ${u.id}"),
                      trailing: Wrap(
                        spacing: 8,
                        children: [
                          OutlinedButton(onPressed: () => _showEditDialog(context, u.id), child: const Text('Bearbeiten')),
                          OutlinedButton(onPressed: () => _showResetPinDialog(context, u.id), child: const Text('PIN zurücksetzen')),
                          IconButton(onPressed: () => _confirmDelete(context, u.id), icon: const Icon(Icons.delete_outline)),
                        ],
                      ),
                    ),
                  );
                },
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemCount: users.length,
              ),
            )
          ],
        ),
      ),
    );
  }

  void _showCreateDialog(BuildContext context) {
    final app = context.read<AppState>();
    final name = TextEditingController();
    Role role = Role.staff;
    final pin = TextEditingController();
    bool cSeeRev = false, cEdit = false, cDel = false, cDeliv = false, cReco = false, cCfg = false, cUsers = false, cLock = false, cInv = false;
    void setDefaultsForRole(Role r){
      if (r == Role.admin){ cSeeRev=true; cEdit=true; cDel=true; cDeliv=true; cReco=true; cCfg=true; cUsers=true; cLock=true; cInv=true; }
      else if (r == Role.chef1 || r == Role.chef2){ cSeeRev=false; cEdit=true; cDel=true; cDeliv=true; cReco=true; cCfg=false; cUsers=false; cLock=false; cInv=true; }
      else { cSeeRev=false; cEdit=false; cDel=false; cDeliv=false; cReco=false; cCfg=false; cUsers=false; cLock=false; cInv=false; }
    }
    setDefaultsForRole(role);
    showDialog(context: context, builder: (_) => StatefulBuilder(builder: (context, setState) {
      return AlertDialog(
        title: const Text('Neuen Account hinzufügen'),
        content: SingleChildScrollView(child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 8),
            DropdownButton<Role>(
              value: role,
              items: Role.values.map((r) => DropdownMenuItem(value: r, child: Text(roleLabel(r)))).toList(),
              onChanged: (v) => setState(() { if (v != null) { role = v; setDefaultsForRole(role);} }),
            ),
            const SizedBox(height: 8),
            TextField(controller: pin, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'PIN (4–6 Stellen)')),
            const Divider(),
            const Text('Rechte'),
            CheckboxListTile(value: cSeeRev, onChanged: (v){ setState(()=> cSeeRev = v ?? false); }, title: const Text('Umsätze sehen')),
            CheckboxListTile(value: cInv, onChanged: (v){ setState(()=> cInv = v ?? false); }, title: const Text('Lager sehen')),
            CheckboxListTile(value: cEdit, onChanged: (v){ setState(()=> cEdit = v ?? false); }, title: const Text('Produkte anlegen/ändern')),
            CheckboxListTile(value: cDel, onChanged: (v){ setState(()=> cDel = v ?? false); }, title: const Text('Produkte löschen')),
            CheckboxListTile(value: cDeliv, onChanged: (v){ setState(()=> cDeliv = v ?? false); }, title: const Text('Lieferscheine eintragen')),
            CheckboxListTile(value: cReco, onChanged: (v){ setState(()=> cReco = v ?? false); }, title: const Text('Nachorder sehen')),
            CheckboxListTile(value: cCfg, onChanged: (v){ setState(()=> cCfg = v ?? false); }, title: const Text('System konfigurieren')),
            CheckboxListTile(value: cUsers, onChanged: (v){ setState(()=> cUsers = v ?? false); }, title: const Text('Benutzer verwalten')),
            CheckboxListTile(value: cLock, onChanged: (v){ setState(()=> cLock = v ?? false); }, title: const Text('Bereichssperre bedienen')),
          ],
        )),
        actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
            FilledButton(onPressed: () {
              if (name.text.trim().isEmpty || pin.text.trim().isEmpty) return;
              final perms = Permissions(
                canSeeRevenue: cSeeRev, canEditProducts: cEdit, canDeleteProducts: cDel, canAddDeliveries: cDeliv,
                canSeeRecommendations: cReco, canConfigureSystem: cCfg, canManageUsers: cUsers, canAreaLock: cLock, canSeeInventory: cInv,
              );
              app.createUser(name: name.text.trim(), role: role, pin: pin.text.trim(), perms: perms);
              Navigator.pop(context);
            }, child: const Text('Anlegen')),
        ],
      );
    }));
  }

  void _showEditDialog(BuildContext context, String userId) {
    final app = context.read<AppState>();
    final u = app.users[userId]!;
    final name = TextEditingController(text: u.name);
    Role role = u.role;
    bool cSeeRev = u.perms.canSeeRevenue;
    bool cEdit = u.perms.canEditProducts;
    bool cDel = u.perms.canDeleteProducts;
    bool cDeliv = u.perms.canAddDeliveries;
    bool cReco = u.perms.canSeeRecommendations;
    bool cCfg = u.perms.canConfigureSystem;
    bool cUsers = u.perms.canManageUsers;
    bool cLock = u.perms.canAreaLock;
    bool cInv = u.perms.canSeeInventory;
    showDialog(context: context, builder: (_) => StatefulBuilder(builder: (context, setState) {
      return AlertDialog(
        title: const Text('Account bearbeiten'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
          const SizedBox(height: 8),
          DropdownButton<Role>(
            value: role,
            items: Role.values.map((r) => DropdownMenuItem(value: r, child: Text(roleLabel(r)))).toList(),
            onChanged: (v) => setState(() { if (v != null) role = v; }),
          ),
          const Divider(),
          const Text('Rechte'),
          CheckboxListTile(value: cSeeRev, onChanged: (v){ setState(()=> cSeeRev = v ?? false); }, title: const Text('Umsätze sehen')),
          CheckboxListTile(value: cInv, onChanged: (v){ setState(()=> cInv = v ?? false); }, title: const Text('Lager sehen')),
          CheckboxListTile(value: cEdit, onChanged: (v){ setState(()=> cEdit = v ?? false); }, title: const Text('Produkte anlegen/ändern')),
          CheckboxListTile(value: cDel, onChanged: (v){ setState(()=> cDel = v ?? false); }, title: const Text('Produkte löschen')),
          CheckboxListTile(value: cDeliv, onChanged: (v){ setState(()=> cDeliv = v ?? false); }, title: const Text('Lieferscheine eintragen')),
          CheckboxListTile(value: cReco, onChanged: (v){ setState(()=> cReco = v ?? false); }, title: const Text('Nachorder sehen')),
          CheckboxListTile(value: cCfg, onChanged: (v){ setState(()=> cCfg = v ?? false); }, title: const Text('System konfigurieren')),
          CheckboxListTile(value: cUsers, onChanged: (v){ setState(()=> cUsers = v ?? false); }, title: const Text('Benutzer verwalten')),
          CheckboxListTile(value: cLock, onChanged: (v){ setState(()=> cLock = v ?? false); }, title: const Text('Bereichssperre bedienen')),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
          FilledButton(onPressed: () {
            final perms = Permissions(
              canSeeRevenue: cSeeRev,
              canEditProducts: cEdit,
              canDeleteProducts: cDel,
              canAddDeliveries: cDeliv,
              canSeeRecommendations: cReco,
              canConfigureSystem: cCfg,
              canManageUsers: cUsers,
              canAreaLock: cLock,
              canSeeInventory: cInv,
            );
            app.updateUser(userId: userId, name: name.text.trim(), role: role, perms: perms);
            Navigator.pop(context);
          }, child: const Text('Speichern')),
        ],
      );
    }));
  }

  void _showResetPinDialog(BuildContext context, String userId) {
    final pin = TextEditingController();
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('PIN zurücksetzen'),
      content: TextField(controller: pin, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Neue PIN')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
        FilledButton(onPressed: () {
          context.read<AppState>().adminResetPin(userId: userId, newPin: pin.text.trim());
          Navigator.pop(context);
        }, child: const Text('Speichern')),
      ],
    ));
  }

  void _confirmDelete(BuildContext context, String userId) {
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('Account löschen?'),
      content: const Text('Achtung: Dieser Vorgang kann nicht rückgängig gemacht werden.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
        FilledButton(onPressed: () {
          context.read<AppState>().deleteUser(userId);
          Navigator.pop(context);
        }, child: const Text('Löschen')),
      ],
    ));
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

// ─────────────────────────────────────────────
// ENTRY POINT
// ─────────────────────────────────────────────
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  runApp(const GoalPayApp());
}

// ─────────────────────────────────────────────
// THEME & CONSTANTS
// ─────────────────────────────────────────────
const kSaffron = Color(0xFFE8720C);
const kSaffronLight = Color(0xFFFFF0E6);
const kSaffronMid = Color(0xFFF5A572);
const kNavy = Color(0xFF0F1B2D);
const kNavyMid = Color(0xFF1E3352);
const kGreen = Color(0xFF1A7A4A);
const kGreenLight = Color(0xFFE6F5EE);
const kBlue = Color(0xFF1E5FA5);
const kBlueLight = Color(0xFFE6F0FC);
const kYellow = Color(0xFFF5C518);
const kYellowLight = Color(0xFFFEFAE6);
const kBg = Color(0xFFF7F5F2);
const kSurface = Color(0xFFFFFFFF);
const kBorder = Color(0xFFE8E4DE);
const kMuted = Color(0xFF888780);

// ─────────────────────────────────────────────
// MODELS
// ─────────────────────────────────────────────
class Goal {
  final String id;
  String title;
  String emoji;
  double targetAmount;
  double savedAmount;
  DateTime deadline;
  String risk; // Safe / Balanced / Growth
  double dailyAmount;
  bool isPaused;
  List<DailySaving> history;

  Goal({
    required this.id,
    required this.title,
    required this.emoji,
    required this.targetAmount,
    required this.savedAmount,
    required this.deadline,
    required this.risk,
    required this.dailyAmount,
    this.isPaused = false,
    List<DailySaving>? history,
  }) : history = history ?? [];

  double get progress => (savedAmount / targetAmount).clamp(0.0, 1.0);

  int get daysLeft => deadline.difference(DateTime.now()).inDays.clamp(0, 9999);

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'emoji': emoji,
        'targetAmount': targetAmount,
        'savedAmount': savedAmount,
        'deadline': deadline.toIso8601String(),
        'risk': risk,
        'dailyAmount': dailyAmount,
        'isPaused': isPaused,
        'history': history.map((h) => h.toJson()).toList(),
      };

  factory Goal.fromJson(Map<String, dynamic> j) => Goal(
        id: j['id'],
        title: j['title'],
        emoji: j['emoji'],
        targetAmount: j['targetAmount'].toDouble(),
        savedAmount: j['savedAmount'].toDouble(),
        deadline: DateTime.parse(j['deadline']),
        risk: j['risk'],
        dailyAmount: j['dailyAmount'].toDouble(),
        isPaused: j['isPaused'] ?? false,
        history: (j['history'] as List<dynamic>? ?? [])
            .map((h) => DailySaving.fromJson(h))
            .toList(),
      );
}

class DailySaving {
  final DateTime date;
  final double amount;
  DailySaving({required this.date, required this.amount});
  Map<String, dynamic> toJson() =>
      {'date': date.toIso8601String(), 'amount': amount};
  factory DailySaving.fromJson(Map<String, dynamic> j) =>
      DailySaving(date: DateTime.parse(j['date']), amount: j['amount'].toDouble());
}

class AIGoalPlan {
  final String title;
  final String emoji;
  final double targetAmount;
  final int months;
  final double dailyAmount;
  final double inflationBuffer;
  final String risk;
  final String explanation;

  AIGoalPlan({
    required this.title,
    required this.emoji,
    required this.targetAmount,
    required this.months,
    required this.dailyAmount,
    required this.inflationBuffer,
    required this.risk,
    required this.explanation,
  });
}

// ─────────────────────────────────────────────
// STORAGE SERVICE
// ─────────────────────────────────────────────
class StorageService {
  static const _key = 'goalpay_goals';
  static const _streakKey = 'goalpay_streak';
  static const _lastInvestKey = 'goalpay_lastinvest';

  static Future<List<Goal>> loadGoals() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return _defaultGoals();
    final list = jsonDecode(raw) as List;
    return list.map((j) => Goal.fromJson(j)).toList();
  }

  static Future<void> saveGoals(List<Goal> goals) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(goals.map((g) => g.toJson()).toList()));
  }

  static Future<int> getStreak() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_streakKey) ?? 5;
  }

  static Future<void> setStreak(int v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_streakKey, v);
  }

  static Future<String?> getLastInvestDate() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastInvestKey);
  }

  static Future<void> setLastInvestDate(String d) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastInvestKey, d);
  }

  static List<Goal> _defaultGoals() => [
        Goal(
          id: const Uuid().v4(),
          title: 'Goa Trip',
          emoji: '🏖️',
          targetAmount: 15000,
          savedAmount: 8250,
          deadline: DateTime.now().add(const Duration(days: 120)),
          risk: 'Balanced',
          dailyAmount: 120,
          history: _generateHistory(8250, 70),
        ),
        Goal(
          id: const Uuid().v4(),
          title: 'iPhone 16',
          emoji: '📱',
          targetAmount: 85000,
          savedAmount: 6800,
          deadline: DateTime.now().add(const Duration(days: 240)),
          risk: 'Growth',
          dailyAmount: 290,
          history: _generateHistory(6800, 23),
        ),
        Goal(
          id: const Uuid().v4(),
          title: 'Activa Scooter',
          emoji: '🛵',
          targetAmount: 75000,
          savedAmount: 3370,
          deadline: DateTime.now().add(const Duration(days: 365)),
          risk: 'Balanced',
          dailyAmount: 195,
          isPaused: true,
          history: _generateHistory(3370, 17),
        ),
      ];

  static List<DailySaving> _generateHistory(double total, int days) {
    final rng = Random();
    final List<DailySaving> h = [];
    double cum = 0;
    final daily = total / days;
    for (int i = days; i >= 0; i--) {
      final amt = daily + (rng.nextDouble() * 40 - 20);
      cum += amt.clamp(0, double.infinity);
      h.add(DailySaving(
        date: DateTime.now().subtract(Duration(days: i)),
        amount: cum.clamp(0, total),
      ));
    }
    return h;
  }
}

// ─────────────────────────────────────────────
// AI SERVICE (uses free Gemini API / fallback)
// ─────────────────────────────────────────────
class AIService {
  // Using free Gemini API. User can add their own key in Settings.
  // Falls back to local rule-based parsing if API fails.
  static String _apiKey = ''; // Set via settings

  static final Map<String, Map<String, dynamic>> _priceDB = {
    'goa': {'amount': 15000, 'emoji': '🏖️'},
    'trip': {'amount': 15000, 'emoji': '✈️'},
    'iphone': {'amount': 85000, 'emoji': '📱'},
    'phone': {'amount': 25000, 'emoji': '📱'},
    'bike': {'amount': 75000, 'emoji': '🛵'},
    'scooter': {'amount': 75000, 'emoji': '🛵'},
    'activa': {'amount': 75000, 'emoji': '🛵'},
    'laptop': {'amount': 55000, 'emoji': '💻'},
    'macbook': {'amount': 120000, 'emoji': '💻'},
    'wedding': {'amount': 300000, 'emoji': '💍'},
    'emergency': {'amount': 60000, 'emoji': '🛡️'},
    'ps5': {'amount': 55000, 'emoji': '🎮'},
    'gaming': {'amount': 55000, 'emoji': '🎮'},
    'car': {'amount': 700000, 'emoji': '🚗'},
    'house': {'amount': 5000000, 'emoji': '🏠'},
    'education': {'amount': 200000, 'emoji': '📚'},
    'vacation': {'amount': 50000, 'emoji': '🌍'},
  };

  static void setApiKey(String key) => _apiKey = key;

  static Future<AIGoalPlan> parseGoal(String input) async {
    if (_apiKey.isNotEmpty) {
      try {
        return await _geminiParse(input);
      } catch (_) {}
    }
    return _localParse(input);
  }

  static Future<AIGoalPlan> _geminiParse(String input) async {
    final prompt = '''
You are a financial planning AI for Indians. Parse this goal and return ONLY valid JSON (no markdown, no backticks):
Goal: "$input"

Return exactly this JSON structure:
{
  "title": "short goal name",
  "emoji": "one emoji",
  "targetAmount": <number in INR>,
  "months": <number>,
  "risk": "Safe|Balanced|Growth",
  "explanation": "one friendly sentence explaining the plan in simple English or Hinglish"
}

Rules:
- targetAmount must be realistic for India (INR)
- months from the input or estimate sensibly
- risk: Safe for <3 months, Balanced for 3-12 months, Growth for >12 months
- explanation: friendly, simple, mention daily amount
''';

    final res = await http.post(
      Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$_apiKey'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {'parts': [{'text': prompt}]}
        ]
      }),
    ).timeout(const Duration(seconds: 10));

    final data = jsonDecode(res.body);
    final text = data['candidates'][0]['content']['parts'][0]['text'] as String;
    final clean = text.replaceAll(RegExp(r'```[a-z]*|```'), '').trim();
    final j = jsonDecode(clean);

    final amount = (j['targetAmount'] as num).toDouble();
    final months = (j['months'] as num).toInt();
    final inflation = amount * 0.03;
    final daily = (amount + inflation) / (months * 30);

    return AIGoalPlan(
      title: j['title'],
      emoji: j['emoji'],
      targetAmount: amount,
      months: months,
      dailyAmount: daily,
      inflationBuffer: inflation,
      risk: j['risk'],
      explanation: j['explanation'],
    );
  }

  static AIGoalPlan _localParse(String input) {
    final lower = input.toLowerCase();
    double amount = 20000;
    String emoji = '🎯';
    String title = 'My Goal';

    for (final entry in _priceDB.entries) {
      if (lower.contains(entry.key)) {
        amount = (entry.value['amount'] as num).toDouble();
        emoji = entry.value['emoji'];
        title = entry.key[0].toUpperCase() + entry.key.substring(1);
        break;
      }
    }

    // Extract amount from text e.g. "50000" or "50k" or "5 lakh"
    final amtMatch = RegExp(r'(\d+)\s*(k|lakh|l\b)', caseSensitive: false).firstMatch(lower);
    if (amtMatch != null) {
      final num = double.parse(amtMatch.group(1)!);
      final unit = amtMatch.group(2)!.toLowerCase();
      amount = unit == 'k' ? num * 1000 : num * 100000;
    }

    // Extract months
    int months = 6;
    final mMatch = RegExp(r'(\d+)\s*month').firstMatch(lower);
    final yMatch = RegExp(r'(\d+)\s*year').firstMatch(lower);
    if (mMatch != null) months = int.parse(mMatch.group(1)!);
    if (yMatch != null) months = int.parse(yMatch.group(1)!) * 12;

    final inflation = amount * 0.03;
    final daily = (amount + inflation) / (months * 30);
    final risk = months <= 3 ? 'Safe' : months <= 12 ? 'Balanced' : 'Growth';

    return AIGoalPlan(
      title: title,
      emoji: emoji,
      targetAmount: amount,
      months: months,
      dailyAmount: daily,
      inflationBuffer: inflation,
      risk: risk,
      explanation:
          'Great goal! Invest just ₹${daily.toStringAsFixed(0)}/day and you\'ll reach ₹${_fmt(amount)} in $months months. That\'s less than a cup of chai! ☕',
    );
  }

  static String _fmt(double v) =>
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(v);

  // ── AI Coach Chat ──
  static final Map<String, String> _coachFAQ = {
    'portfolio': 'Your portfolio is split between safe debt funds and growth equity SIPs. The debt portion protects your savings while equity gives you upside. For short-term goals (<6 months), we keep 80% in debt. For longer goals, we add more equity for better returns. 📊',
    'crash': 'No stress! Market crashes are temporary. Your GoalPay portfolio is protected:\n\n🛡️ Debt funds (liquid) don\'t crash with stock markets\n📈 SIP investments actually benefit from crashes — you buy more units at lower prices (rupee cost averaging)\n\nStay calm and keep investing! 💪',
    'increase': 'Looking at your goal progress... Increasing your daily amount by just ₹20-50 can significantly shorten your timeline. Want me to calculate a new plan? 🎯',
    'pause': 'Your investment is paused. This happens automatically when we detect low bank balance — protecting you from overdrafts. You can resume anytime from the goal detail screen. ⏸️',
    'return': 'Expected returns:\n\n🛡️ Safe (Liquid funds): 6-7% annually\n⚖️ Balanced (Debt+Equity): 9-11% annually\n🚀 Growth (Equity SIP): 12-15% annually\n\nActual returns vary based on market conditions.',
    'tax': 'Tax on your investments:\n\n• Debt funds (held <3 years): taxed as per your slab\n• Equity funds (held >1 year): 10% LTCG above ₹1 lakh\n• Short-term equity: 15% STCG\n\nConsult a CA for personal advice! 📋',
  };

  static Future<String> chat(String message, List<Goal> goals) async {
    if (_apiKey.isNotEmpty) {
      try {
        return await _geminiChat(message, goals);
      } catch (_) {}
    }
    return _localChat(message, goals);
  }

  static Future<String> _geminiChat(String message, List<Goal> goals) async {
    final goalSummary = goals.map((g) =>
        '${g.emoji} ${g.title}: saved ₹${g.savedAmount.toStringAsFixed(0)} of ₹${g.targetAmount.toStringAsFixed(0)}, ${g.daysLeft} days left').join('\n');

    final prompt = '''
You are GoalPay's friendly AI financial coach for Indian millennials and Gen Z. Keep responses short (3-5 lines max), friendly, and practical. You can use Hindi/Hinglish when appropriate. Use emojis sparingly.

User's goals:
$goalSummary

User asks: "$message"

Respond helpfully about their specific goals and investments.
''';

    final res = await http.post(
      Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$_apiKey'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {'parts': [{'text': prompt}]}
        ]
      }),
    ).timeout(const Duration(seconds: 10));

    final data = jsonDecode(res.body);
    return data['candidates'][0]['content']['parts'][0]['text'] as String;
  }

  static String _localChat(String message, List<Goal> goals) {
    final lower = message.toLowerCase();
    for (final entry in _coachFAQ.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    if (lower.contains('goa') || lower.contains('trip')) {
      final g = goals.firstWhere((g) => g.title.toLowerCase().contains('goa'),
          orElse: () => goals.first);
      return '🏖️ Your ${g.title} goal is ${(g.progress * 100).toStringAsFixed(0)}% complete! You\'ve saved ₹${_fmt(g.savedAmount)} of ₹${_fmt(g.targetAmount)}. ${g.daysLeft} days to go — you\'re on track! Keep it up! 🎉';
    }
    if (lower.contains('namaste') || lower.contains('hello') || lower.contains('hi')) {
      return 'Namaste! 👋 Main aapka GoalPay AI coach hoon. Ask me about your goals, portfolio, returns, or anything about investing!';
    }
    if (lower.contains('how') && lower.contains('doing')) {
      final total = goals.fold(0.0, (s, g) => s + g.savedAmount);
      return 'You\'re doing great! 🌟 Total saved: ₹${_fmt(total)} across ${goals.length} goals. Stay consistent and you\'ll smash every target!';
    }
    return 'Great question! Based on your current goals and saving patterns, I recommend staying consistent with your daily contributions. Small daily amounts compound into big results over time. 💪\n\nAsk me about specific goals, returns, tax, or portfolio allocation!';
  }
}

// ─────────────────────────────────────────────
// APP ROOT
// ─────────────────────────────────────────────
class GoalPayApp extends StatelessWidget {
  const GoalPayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GoalPay',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: kSaffron, brightness: Brightness.light),
        textTheme: GoogleFonts.dmSansTextTheme(),
        scaffoldBackgroundColor: kBg,
        useMaterial3: true,
      ),
      home: const MainShell(),
    );
  }
}

// ─────────────────────────────────────────────
// MAIN SHELL (Bottom Nav)
// ─────────────────────────────────────────────
class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tab = 0;
  List<Goal> goals = [];
  int streak = 5;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    goals = await StorageService.loadGoals();
    streak = await StorageService.getStreak();
    setState(() => loading = false);
  }

  Future<void> _saveGoal(Goal g) async {
    setState(() {
      final idx = goals.indexWhere((x) => x.id == g.id);
      if (idx >= 0) goals[idx] = g;
      else goals.insert(0, g);
    });
    await StorageService.saveGoals(goals);
  }

  Future<void> _invest(Goal g, double amount) async {
    g.savedAmount = (g.savedAmount + amount).clamp(0, g.targetAmount);
    g.history.add(DailySaving(date: DateTime.now(), amount: g.savedAmount));
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final last = await StorageService.getLastInvestDate();
    if (last != today) {
      streak += 1;
      await StorageService.setStreak(streak);
      await StorageService.setLastInvestDate(today);
    }
    await _saveGoal(g);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        backgroundColor: kBg,
        body: Center(child: CircularProgressIndicator(color: kSaffron)),
      );
    }

    final screens = [
      HomeScreen(goals: goals, streak: streak, onInvest: _invest,
          onGoToCreate: () => setState(() => _tab = 1)),
      CreateGoalScreen(onGoalCreated: (g) async {
        await _saveGoal(g);
        setState(() => _tab = 0);
      }),
      ProgressScreen(goals: goals, onInvest: _invest),
      CoachScreen(goals: goals),
    ];

    return Scaffold(
      body: IndexedStack(index: _tab, children: screens),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: kSurface,
          border: Border(top: BorderSide(color: kBorder, width: 0.5)),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 60,
            child: Row(
              children: [
                _NavTab(icon: Icons.home_rounded, label: 'Home', active: _tab == 0, onTap: () => setState(() => _tab = 0)),
                _NavTab(icon: Icons.add_circle_rounded, label: 'New Goal', active: _tab == 1, onTap: () => setState(() => _tab = 1)),
                _NavTab(icon: Icons.bar_chart_rounded, label: 'Progress', active: _tab == 2, onTap: () => setState(() => _tab = 2)),
                _NavTab(icon: Icons.chat_bubble_rounded, label: 'AI Coach', active: _tab == 3, onTap: () => setState(() => _tab = 3)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _NavTab({required this.icon, required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: active ? kSaffron : kMuted, size: 22),
            const SizedBox(height: 3),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    color: active ? kSaffron : kMuted,
                    fontWeight: active ? FontWeight.w600 : FontWeight.normal)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// HOME SCREEN
// ─────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  final List<Goal> goals;
  final int streak;
  final Future<void> Function(Goal, double) onInvest;
  final VoidCallback onGoToCreate;
  const HomeScreen({super.key, required this.goals, required this.streak, required this.onInvest, required this.onGoToCreate});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _nudgeDismissed = false;
  final _fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  double get _totalSaved => widget.goals.fold(0.0, (s, g) => s + g.savedAmount);
  double get _totalTarget => widget.goals.fold(0.0, (s, g) => s + g.targetAmount);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Column(
          children: [
            // NAV
            _buildNav(),
            Expanded(
              child: RefreshIndicator(
                color: kSaffron,
                onRefresh: () async => setState(() {}),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      _buildHero(),
                      const SizedBox(height: 12),
                      if (!_nudgeDismissed) _buildNudge(),
                      _buildSectionHeader('My Goals', onTap: widget.onGoToCreate),
                      ...widget.goals.map((g) => _GoalCard(
                            goal: g,
                            onTap: () => _openDetail(g),
                          )),
                      const SizedBox(height: 12),
                      _buildStreakCard(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNav() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: kSurface,
      child: Row(
        children: [
          Text('Goal', style: GoogleFonts.syne(fontSize: 22, fontWeight: FontWeight.w800, color: kSaffron)),
          Text('Pay', style: GoogleFonts.syne(fontSize: 22, fontWeight: FontWeight.w800, color: kNavy)),
          const Spacer(),
          GestureDetector(
            onTap: () => setState(() => _nudgeDismissed = false),
            child: Container(
              width: 34, height: 34,
              decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(17), border: Border.all(color: kBorder)),
              child: const Icon(Icons.notifications_outlined, size: 17, color: kMuted),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(color: kSaffron, borderRadius: BorderRadius.circular(17)),
            child: const Center(child: Text('AK', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600))),
          ),
        ],
      ),
    );
  }

  Widget _buildHero() {
    final progress = (_totalSaved / _totalTarget).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: kNavy, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Total saved across goals', style: TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 6),
          Text(_fmt.format(_totalSaved),
              style: GoogleFonts.syne(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('${widget.goals.length} goals active',
              style: const TextStyle(color: Colors.white60, fontSize: 13)),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Since Jan 2025', style: TextStyle(color: Colors.white38, fontSize: 11)),
              Text('${(progress * 100).toStringAsFixed(0)}% of total target',
                  style: const TextStyle(color: Colors.white38, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNudge() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kYellowLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kYellow.withOpacity(0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('⚡', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('You missed yesterday.',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: kNavy)),
                const SizedBox(height: 2),
                const Text('Invest ₹25 extra today to stay on track for your Goa trip?',
                    style: TextStyle(fontSize: 13, color: kNavy, height: 1.4)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _SmallButton(label: 'Invest now', onTap: () async {
                      final g = widget.goals.firstWhere((g) => g.title.contains('Goa'));
                      await widget.onInvest(g, 25);
                      setState(() => _nudgeDismissed = true);
                      if (mounted) _showSnack('₹25 invested in Goa Trip! 🎉');
                    }),
                    const SizedBox(width: 8),
                    _SmallButton(label: 'Skip', muted: true, onTap: () => setState(() => _nudgeDismissed = true)),
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, {VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: GoogleFonts.syne(fontSize: 16, fontWeight: FontWeight.w700, color: kNavy)),
          if (onTap != null)
            GestureDetector(
              onTap: onTap,
              child: const Text('+ New goal', style: TextStyle(fontSize: 13, color: kSaffron, fontWeight: FontWeight.w500)),
            ),
        ],
      ),
    );
  }

  Widget _buildStreakCard() {
    final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final today = DateTime.now().weekday - 1;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(14), border: Border.all(color: kBorder, width: 0.5)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Weekly streak 🔥', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: kNavy)),
              Text('${widget.streak} days', style: const TextStyle(fontSize: 13, color: kSaffron, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(7, (i) {
              final done = i < today;
              final isToday = i == today;
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  height: 32,
                  decoration: BoxDecoration(
                    color: isToday ? kSaffron : done ? kSaffronLight : kBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: isToday ? kSaffron : done ? kSaffronMid : kBorder, width: 0.5),
                  ),
                  child: Center(
                    child: Text(days[i],
                        style: TextStyle(fontSize: 11, color: isToday ? Colors.white : done ? kSaffron : kMuted,
                            fontWeight: FontWeight.w500)),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  void _openDetail(Goal g) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => GoalDetailScreen(goal: g, onInvest: widget.onInvest)));
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: kGreen,
      duration: const Duration(seconds: 2),
    ));
  }
}

// ─────────────────────────────────────────────
// GOAL CARD
// ─────────────────────────────────────────────
class _GoalCard extends StatelessWidget {
  final Goal goal;
  final VoidCallback onTap;
  const _GoalCard({required this.goal, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final pct = (goal.progress * 100).toStringAsFixed(0);
    final color = goal.isPaused ? kMuted : (goal.progress < 0.3 ? kBlue : (goal.progress < 0.7 ? kSaffron : kGreen));

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kBorder, width: 0.5),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(10)),
                  child: Center(child: Text(goal.emoji, style: const TextStyle(fontSize: 20))),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(goal.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: kNavy)),
                      Text('${fmt.format(goal.savedAmount)} of ${fmt.format(goal.targetAmount)} · ${goal.daysLeft} days left',
                          style: const TextStyle(fontSize: 12, color: kMuted)),
                    ],
                  ),
                ),
                Text('$pct%', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color)),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: goal.progress,
                backgroundColor: kBg,
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 7,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text('₹${goal.dailyAmount.toStringAsFixed(0)}/day',
                    style: const TextStyle(fontSize: 12, color: kMuted)),
                const SizedBox(width: 8),
                if (goal.isPaused)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(99)),
                    child: const Text('Auto-paused', style: TextStyle(fontSize: 11, color: Colors.orange)),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: kGreenLight, borderRadius: BorderRadius.circular(99)),
                    child: const Text('On track ✓', style: TextStyle(fontSize: 11, color: kGreen)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// CREATE GOAL SCREEN
// ─────────────────────────────────────────────
class CreateGoalScreen extends StatefulWidget {
  final Future<void> Function(Goal) onGoalCreated;
  const CreateGoalScreen({super.key, required this.onGoalCreated});

  @override
  State<CreateGoalScreen> createState() => _CreateGoalScreenState();
}

class _CreateGoalScreenState extends State<CreateGoalScreen> {
  final _controller = TextEditingController();
  bool _loading = false;
  AIGoalPlan? _plan;
  String _selectedRisk = 'Balanced';
  bool _activated = false;
  final _fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  final List<Map<String, String>> _chips = [
    {'label': '🏖️ Trip to Goa', 'text': 'Trip to Goa in 5 months'},
    {'label': '📱 iPhone', 'text': 'Buy iPhone in 8 months'},
    {'label': '🛡️ Emergency fund', 'text': 'Emergency fund in 1 year'},
    {'label': '💍 Wedding', 'text': 'Wedding fund in 2 years'},
    {'label': '🛵 Bike', 'text': 'Buy a bike in 10 months'},
    {'label': '💻 Laptop', 'text': 'Laptop in 3 months'},
  ];

  Future<void> _analyze() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() { _loading = true; _plan = null; });
    try {
      final plan = await AIService.parseGoal(text);
      setState(() { _plan = plan; _selectedRisk = plan.risk; });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not analyze goal. Try again.'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  Map<String, dynamic> _getAllocation() {
    return switch (_selectedRisk) {
      'Safe' => {'debt': 80, 'equity': 20, 'debtLabel': 'Liquid debt funds', 'equityLabel': 'Conservative equity'},
      'Growth' => {'debt': 30, 'equity': 70, 'debtLabel': 'Short-term debt', 'equityLabel': 'Equity SIP (small-cap)'},
      _ => {'debt': 60, 'equity': 40, 'debtLabel': 'Liquid debt funds', 'equityLabel': 'Equity SIP'},
    };
  }

  Future<void> _activate() async {
    if (_plan == null) return;
    final g = Goal(
      id: const Uuid().v4(),
      title: _plan!.title,
      emoji: _plan!.emoji,
      targetAmount: _plan!.targetAmount + _plan!.inflationBuffer,
      savedAmount: 0,
      deadline: DateTime.now().add(Duration(days: _plan!.months * 30)),
      risk: _selectedRisk,
      dailyAmount: _plan!.dailyAmount,
    );
    await widget.onGoalCreated(g);
    setState(() => _activated = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Column(
          children: [
            _NavBar(title: 'New goal'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("What's your dream?",
                        style: GoogleFonts.syne(fontSize: 22, fontWeight: FontWeight.w700, color: kNavy)),
                    const SizedBox(height: 4),
                    const Text("Type anything — our AI figures it out",
                        style: TextStyle(fontSize: 13, color: kMuted)),
                    const SizedBox(height: 16),
                    _buildInput(),
                    const SizedBox(height: 8),
                    const Text('Popular goals', style: TextStyle(fontSize: 12, color: kMuted)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: _chips.map((c) => GestureDetector(
                        onTap: () { _controller.text = c['text']!; _analyze(); },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: kSurface, borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: kBorder),
                          ),
                          child: Text(c['label']!, style: const TextStyle(fontSize: 13, color: kMuted)),
                        ),
                      )).toList(),
                    ),
                    const SizedBox(height: 20),
                    if (_loading) const Center(child: CircularProgressIndicator(color: kSaffron)),
                    if (_plan != null) _buildPlan(),
                    if (_activated)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: kGreenLight, borderRadius: BorderRadius.circular(12)),
                        child: Row(children: [
                          const Icon(Icons.check_circle, color: kGreen),
                          const SizedBox(width: 10),
                          Text('Goal activated! Autopay enabled 🎉',
                              style: TextStyle(color: kGreen, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kSaffron, width: 1.5),
      ),
      child: Row(
        children: [
          const Text('✨', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _controller,
              style: const TextStyle(fontSize: 15, color: kNavy),
              decoration: const InputDecoration(
                hintText: 'e.g. "Trip to Goa in 6 months"',
                hintStyle: TextStyle(color: kMuted),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
              onSubmitted: (_) => _analyze(),
            ),
          ),
          TextButton(
            onPressed: _analyze,
            style: TextButton.styleFrom(
              backgroundColor: kSaffron,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            child: const Text('Ask AI', style: TextStyle(color: Colors.white, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildPlan() {
    final alloc = _getAllocation();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: kSaffronLight, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kSaffronMid.withOpacity(0.4))),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('🤖', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              Expanded(child: Text(_plan!.explanation,
                  style: const TextStyle(fontSize: 13, color: kNavy, height: 1.5))),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _PlanCard(children: [
          _PlanRow('Target amount', _fmt.format(_plan!.targetAmount)),
          _PlanRow('Timeline', '${_plan!.months} months'),
          _PlanRow('Daily contribution', '₹${_plan!.dailyAmount.toStringAsFixed(0)}/day', highlight: true),
          _PlanRow('Inflation buffer', '+${_fmt.format(_plan!.inflationBuffer)} (3%)'),
          _PlanRow('Total target', _fmt.format(_plan!.targetAmount + _plan!.inflationBuffer)),
        ]),
        const SizedBox(height: 12),
        const Text('Choose your risk comfort',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: kNavy)),
        const SizedBox(height: 10),
        Row(
          children: ['Safe', 'Balanced', 'Growth'].map((r) {
            final icons = {'Safe': '🛡️', 'Balanced': '⚖️', 'Growth': '🚀'};
            final descs = {'Safe': 'FD-like returns', 'Balanced': 'Debt + Equity', 'Growth': 'Higher equity'};
            final sel = _selectedRisk == r;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedRisk = r),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: sel ? kSaffronLight : kSurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: sel ? kSaffron : kBorder, width: sel ? 1.5 : 0.5),
                  ),
                  child: Column(children: [
                    Text(icons[r]!, style: const TextStyle(fontSize: 18)),
                    const SizedBox(height: 4),
                    Text(r, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: sel ? kSaffron : kNavy)),
                    Text(descs[r]!, style: const TextStyle(fontSize: 10, color: kMuted), textAlign: TextAlign.center),
                  ]),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        _PlanCard(children: [
          _AllocBar(debt: alloc['debt'], equity: alloc['equity']),
          const SizedBox(height: 8),
          _LegendItem(color: kBlue, label: '${alloc['debtLabel']} — ${alloc['debt']}%'),
          _LegendItem(color: kSaffron, label: '${alloc['equityLabel']} — ${alloc['equity']}%'),
        ]),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: kGreenLight, borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kGreen.withOpacity(0.3))),
          child: Row(children: [
            const Icon(Icons.shield_outlined, color: kGreen, size: 16),
            const SizedBox(width: 8),
            const Expanded(child: Text('Emergency safety layer: auto-pauses if balance < ₹500',
                style: TextStyle(fontSize: 12, color: kGreen))),
          ]),
        ),
        const SizedBox(height: 14),
        ElevatedButton(
          onPressed: _activated ? null : _activate,
          style: ElevatedButton.styleFrom(
            backgroundColor: kSaffron,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          child: const Text('Activate goal & enable autopay', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  final List<Widget> children;
  const _PlanCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kBorder, width: 0.5)),
      child: Column(children: children),
    );
  }
}

class _PlanRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;
  const _PlanRow(this.label, this.value, {this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: kMuted)),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
              color: highlight ? kSaffron : kNavy)),
        ],
      ),
    );
  }
}

class _AllocBar extends StatelessWidget {
  final int debt;
  final int equity;
  const _AllocBar({required this.debt, required this.equity});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: Row(
        children: [
          Flexible(flex: debt, child: Container(height: 8, color: kBlue)),
          const SizedBox(width: 2),
          Flexible(flex: equity, child: Container(height: 8, color: kSaffron)),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 13, color: kNavy)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────
// GOAL DETAIL SCREEN
// ─────────────────────────────────────────────
class GoalDetailScreen extends StatefulWidget {
  final Goal goal;
  final Future<void> Function(Goal, double) onInvest;
  const GoalDetailScreen({super.key, required this.goal, required this.onInvest});

  @override
  State<GoalDetailScreen> createState() => _GoalDetailScreenState();
}

class _GoalDetailScreenState extends State<GoalDetailScreen> {
  final _fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
  bool _nudgeDismissed = false;

  @override
  Widget build(BuildContext context) {
    final g = widget.goal;
    final pct = (g.progress * 100);
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Column(
          children: [
            _NavBar(title: g.title, showBack: true),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildHero(g, pct),
                    const SizedBox(height: 12),
                    _buildStats(g),
                    if (!_nudgeDismissed) _buildTopUpNudge(g),
                    _buildChart(g),
                    const SizedBox(height: 12),
                    _buildPortfolio(g),
                    const SizedBox(height: 12),
                    _buildSafety(),
                    const SizedBox(height: 12),
                    _buildInvestButton(g),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHero(Goal g, double pct) {
    final milestones = [25.0, 50.0, 75.0, 100.0];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: kNavy, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${g.emoji} ${g.title}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(_fmt.format(g.savedAmount),
                  style: GoogleFonts.syne(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
              const SizedBox(width: 8),
              Text('of ${_fmt.format(g.targetAmount)}',
                  style: const TextStyle(color: Colors.white54, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: milestones.map((m) {
              final done = pct >= m;
              final active = pct < m && pct >= (m - 25);
              return Column(children: [
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done ? Colors.white : (active ? Colors.white24 : Colors.white12),
                    border: Border.all(color: done ? Colors.white : Colors.white38, width: active ? 2 : 1),
                  ),
                  child: Center(
                    child: Text(done ? '✓' : (active ? '→' : '${m.toInt()}'),
                        style: TextStyle(fontSize: 10, color: done ? kNavy : Colors.white,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 4),
                Text('${m.toInt()}%', style: const TextStyle(fontSize: 10, color: Colors.white38)),
              ]);
            }).toList(),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: g.progress,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 6),
          Text('${pct.toStringAsFixed(0)}% complete · ${g.daysLeft} days left',
              style: const TextStyle(fontSize: 11, color: Colors.white38)),
        ],
      ),
    );
  }

  Widget _buildStats(Goal g) {
    final remaining = g.targetAmount - g.savedAmount;
    final est = g.savedAmount * 0.082;
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.2,
      children: [
        _StatBox(label: 'Daily auto-invest', value: '₹${g.dailyAmount.toStringAsFixed(0)}', color: kSaffron),
        _StatBox(label: 'Streak', value: '5 days 🔥', color: kSaffron),
        _StatBox(label: 'Est. returns', value: '+${_fmt.format(est)}', color: kGreen),
        _StatBox(label: 'To complete', value: _fmt.format(remaining)),
      ],
    );
  }

  Widget _buildTopUpNudge(Goal g) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kYellowLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kYellow.withOpacity(0.5)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('📈', style: TextStyle(fontSize: 18)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Salary credited today!', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: kNavy)),
          const SizedBox(height: 2),
          const Text('Invest ₹500 extra to reach your next milestone faster?',
              style: TextStyle(fontSize: 13, color: kNavy, height: 1.4)),
          const SizedBox(height: 10),
          Row(children: [
            _SmallButton(label: 'Invest ₹500', onTap: () async {
              await widget.onInvest(g, 500);
              setState(() => _nudgeDismissed = true);
            }),
            const SizedBox(width: 8),
            _SmallButton(label: 'Not now', muted: true, onTap: () => setState(() => _nudgeDismissed = true)),
          ]),
        ])),
      ]),
    );
  }

  Widget _buildChart(Goal g) {
    if (g.history.isEmpty) return const SizedBox.shrink();
    final spots = g.history.asMap().entries.map((e) =>
        FlSpot(e.key.toDouble(), e.value.amount)).toList();

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kBorder, width: 0.5)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Savings over time', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: kNavy)),
          const SizedBox(height: 14),
          SizedBox(
            height: 140,
            child: LineChart(
              LineChartData(
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: kSaffron,
                    barWidth: 2.5,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: kSaffron.withOpacity(0.08),
                    ),
                  ),
                ],
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(color: kBorder, strokeWidth: 0.5),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 44,
                      getTitlesWidget: (v, _) => Text(
                        '₹${(v / 1000).toStringAsFixed(0)}k',
                        style: const TextStyle(fontSize: 10, color: kMuted),
                      ),
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPortfolio(Goal g) {
    final alloc = switch (g.risk) {
      'Safe' => {'debt': 80, 'equity': 20},
      'Growth' => {'debt': 30, 'equity': 70},
      _ => {'debt': 60, 'equity': 40},
    };
    final debtAmt = g.savedAmount * alloc['debt']! / 100;
    final eqAmt = g.savedAmount * alloc['equity']! / 100;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kBorder, width: 0.5)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Portfolio breakdown', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: kNavy)),
          const SizedBox(height: 10),
          _AllocBar(debt: alloc['debt']!, equity: alloc['equity']!),
          const SizedBox(height: 10),
          _LegendItem(color: kBlue, label: 'Liquid debt funds · ${alloc['debt']}% · ${_fmt.format(debtAmt)}'),
          const SizedBox(height: 4),
          _LegendItem(color: kSaffron, label: 'Equity SIP · ${alloc['equity']}% · ${_fmt.format(eqAmt)}'),
        ],
      ),
    );
  }

  Widget _buildSafety() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: kGreenLight, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kGreen.withOpacity(0.3))),
      child: Row(children: [
        const Icon(Icons.shield_outlined, color: kGreen, size: 18),
        const SizedBox(width: 10),
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Safety layer active', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kGreen)),
          SizedBox(height: 2),
          Text('Auto-pause triggers if your account falls below ₹500.',
              style: TextStyle(fontSize: 12, color: kGreen)),
        ])),
      ]),
    );
  }

  Widget _buildInvestButton(Goal g) {
    return ElevatedButton.icon(
      onPressed: () => _showInvestSheet(g),
      style: ElevatedButton.styleFrom(
        backgroundColor: kSaffron,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
      icon: const Icon(Icons.add, size: 18),
      label: const Text('Invest now', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
    );
  }

  void _showInvestSheet(Goal g) {
    double amount = g.dailyAmount;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setBS) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Invest in ${g.title}',
                  style: GoogleFonts.syne(fontSize: 18, fontWeight: FontWeight.w700, color: kNavy)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [50.0, 100.0, 200.0, 500.0].map((v) => GestureDetector(
                  onTap: () => setBS(() => amount = v),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: amount == v ? kSaffronLight : kBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: amount == v ? kSaffron : kBorder),
                    ),
                    child: Text('₹${v.toInt()}', style: TextStyle(
                        color: amount == v ? kSaffron : kMuted, fontWeight: FontWeight.w600)),
                  ),
                )).toList(),
              ),
              const SizedBox(height: 16),
              TextField(
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  prefixText: '₹ ',
                  hintText: 'Enter custom amount',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: kBorder)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: kSaffron)),
                ),
                onChanged: (v) { final n = double.tryParse(v); if (n != null) setBS(() => amount = n); },
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await widget.onInvest(g, amount);
                  setState(() {});
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('₹${amount.toStringAsFixed(0)} invested! 🎉'), backgroundColor: kGreen),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: kSaffron,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: Text('Confirm ₹${amount.toStringAsFixed(0)} via UPI',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _StatBox({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: kMuted)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: color ?? kNavy)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// PROGRESS SCREEN
// ─────────────────────────────────────────────
class ProgressScreen extends StatelessWidget {
  final List<Goal> goals;
  final Future<void> Function(Goal, double) onInvest;
  const ProgressScreen({super.key, required this.goals, required this.onInvest});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final total = goals.fold(0.0, (s, g) => s + g.savedAmount);
    final target = goals.fold(0.0, (s, g) => s + g.targetAmount);

    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Column(
          children: [
            _NavBar(title: 'Progress'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: kBorder, width: 0.5)),
                      child: Column(children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              const Text('Total saved', style: TextStyle(fontSize: 12, color: kMuted)),
                              Text(fmt.format(total),
                                  style: GoogleFonts.syne(fontSize: 24, fontWeight: FontWeight.w800, color: kNavy)),
                            ]),
                            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                              const Text('Total target', style: TextStyle(fontSize: 12, color: kMuted)),
                              Text(fmt.format(target),
                                  style: GoogleFonts.syne(fontSize: 24, fontWeight: FontWeight.w800, color: kSaffron)),
                            ]),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: LinearProgressIndicator(
                            value: (total / target).clamp(0.0, 1.0),
                            backgroundColor: kBg,
                            valueColor: const AlwaysStoppedAnimation<Color>(kSaffron),
                            minHeight: 10,
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 16),
                    ...goals.map((g) => GestureDetector(
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => GoalDetailScreen(goal: g, onInvest: onInvest))),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: kBorder, width: 0.5)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Text(g.emoji, style: const TextStyle(fontSize: 22)),
                            const SizedBox(width: 10),
                            Expanded(child: Text(g.title,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: kNavy))),
                            Text('${(g.progress * 100).toStringAsFixed(0)}%',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: kSaffron)),
                          ]),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: LinearProgressIndicator(
                              value: g.progress,
                              backgroundColor: kBg,
                              valueColor: const AlwaysStoppedAnimation<Color>(kSaffron),
                              minHeight: 8,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            Text(fmt.format(g.savedAmount),
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: kNavy)),
                            Text(fmt.format(g.targetAmount),
                                style: const TextStyle(fontSize: 13, color: kMuted)),
                          ]),
                        ]),
                      ),
                    )),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// AI COACH SCREEN
// ─────────────────────────────────────────────
class CoachScreen extends StatefulWidget {
  final List<Goal> goals;
  const CoachScreen({super.key, required this.goals});

  @override
  State<CoachScreen> createState() => _CoachScreenState();
}

class _ChatMsg {
  final String text;
  final bool isUser;
  _ChatMsg({required this.text, required this.isUser});
}

class _CoachScreenState extends State<CoachScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final List<_ChatMsg> _msgs = [
    _ChatMsg(text: "Namaste! 👋 I'm your GoalPay AI Coach. Ask me about your goals, portfolio, returns, or market conditions. You can also ask in Hindi!", isUser: false),
  ];
  bool _thinking = false;

  final List<String> _chips = [
    'Why this portfolio?',
    'Market crash hoga toh?',
    'Should I increase amount?',
    'How am I doing?',
  ];

  Future<void> _send(String text) async {
    if (text.trim().isEmpty) return;
    _controller.clear();
    setState(() {
      _msgs.add(_ChatMsg(text: text, isUser: true));
      _thinking = true;
    });
    _scrollDown();

    final reply = await AIService.chat(text, widget.goals);
    setState(() {
      _msgs.add(_ChatMsg(text: reply, isUser: false));
      _thinking = false;
    });
    _scrollDown();
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Column(
          children: [
            _NavBar(title: 'AI Coach', subtitle: 'Powered by Gemini'),
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.all(16),
                itemCount: _msgs.length + (_thinking ? 1 : 0),
                itemBuilder: (_, i) {
                  if (i == _msgs.length) return _buildTyping();
                  final m = _msgs[i];
                  return _buildMsg(m);
                },
              ),
            ),
            // Quick chips
            Container(
              height: 44,
              margin: const EdgeInsets.only(bottom: 4),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _chips.length,
                itemBuilder: (_, i) => GestureDetector(
                  onTap: () => _send(_chips[i]),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: kSurface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: kBorder),
                    ),
                    child: Text(_chips[i], style: const TextStyle(fontSize: 12, color: kMuted)),
                  ),
                ),
              ),
            ),
            // Input bar
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              color: kSurface,
              child: Row(children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: kBg,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: kBorder),
                    ),
                    child: TextField(
                      controller: _controller,
                      style: const TextStyle(fontSize: 14, color: kNavy),
                      decoration: const InputDecoration(
                        hintText: 'Ask anything about your goals...',
                        hintStyle: TextStyle(color: kMuted, fontSize: 13),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                      onSubmitted: _send,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _send(_controller.text),
                  child: Container(
                    width: 40, height: 40,
                    decoration: const BoxDecoration(color: kSaffron, shape: BoxShape.circle),
                    child: const Icon(Icons.arrow_upward, color: Colors.white, size: 18),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMsg(_ChatMsg m) {
    return Align(
      alignment: m.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        decoration: BoxDecoration(
          color: m.isUser ? kSaffron : kSurface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(m.isUser ? 14 : 4),
            bottomRight: Radius.circular(m.isUser ? 4 : 14),
          ),
          border: m.isUser ? null : Border.all(color: kBorder, width: 0.5),
        ),
        child: Text(m.text,
            style: TextStyle(
                fontSize: 14,
                color: m.isUser ? Colors.white : kNavy,
                height: 1.5)),
      ),
    );
  }

  Widget _buildTyping() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(14), topRight: Radius.circular(14), bottomRight: Radius.circular(14),
          ),
          border: Border.all(color: kBorder, width: 0.5),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          ...List.generate(3, (i) => AnimatedContainer(
            duration: Duration(milliseconds: 300 + i * 150),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: 7, height: 7,
            decoration: const BoxDecoration(color: kMuted, shape: BoxShape.circle),
          )),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// SHARED WIDGETS
// ─────────────────────────────────────────────
class _NavBar extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool showBack;
  const _NavBar({required this.title, this.subtitle, this.showBack = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: kSurface,
        border: Border(bottom: BorderSide(color: kBorder, width: 0.5)),
      ),
      child: Row(
        children: [
          if (showBack)
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Padding(
                padding: EdgeInsets.only(right: 10),
                child: Icon(Icons.arrow_back_ios, size: 18, color: kNavy),
              ),
            ),
          Text('Goal', style: GoogleFonts.syne(fontSize: 18, fontWeight: FontWeight.w800, color: kSaffron)),
          Text('Pay', style: GoogleFonts.syne(fontSize: 18, fontWeight: FontWeight.w800, color: kNavy)),
          const SizedBox(width: 12),
          if (subtitle != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: kSaffronLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(subtitle!, style: const TextStyle(fontSize: 11, color: kSaffron, fontWeight: FontWeight.w500)),
            ),
          const Spacer(),
          if (!showBack)
            Text(title, style: const TextStyle(fontSize: 13, color: kMuted)),
        ],
      ),
    );
  }
}

class _SmallButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool muted;
  const _SmallButton({required this.label, required this.onTap, this.muted = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: muted ? kBg : kSaffronLight,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label, style: TextStyle(fontSize: 13, color: muted ? kMuted : kSaffron, fontWeight: FontWeight.w500)),
      ),
    );
  }
}
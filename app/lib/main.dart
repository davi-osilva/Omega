import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:mediapipe_face_mesh/mediapipe_face_mesh.dart';

import 'drowsiness_detector.dart';

void main() {
  runApp(const OmegaApp());
}

// ============================================================
// CORES
// ============================================================

const Color omegaBlue = Color(0xFF2563EB);
const Color omegaBlueLight = Color(0xFF60A5FA);
const Color omegaBackground = Color(0xFF08111C);
const Color omegaSurface = Color(0xFF101C2A);
const Color omegaSurfaceLight = Color(0xFF17283A);
const Color omegaText = Color(0xFFF3F6F8);
const Color omegaTextSecondary = Color(0xFF8FA1B2);

const Color statusGreen = Color(0xFF35A866);
const Color statusYellow = Color(0xFFF2B84B);
const Color statusOrange = Color(0xFFF47B20);
const Color statusRed = Color(0xFFE05252);

// ============================================================
// MODELO DE RISCO
// ============================================================

enum RiskLevel { baixo, medio, alto, critico }

class RiskInfo {
  final RiskLevel level;
  final Color color;
  final String label;

  const RiskInfo(this.level, this.color, this.label);

  factory RiskInfo.fromScore(double score) {
    if (score < 40) {
      return const RiskInfo(
        RiskLevel.baixo,
        statusGreen,
        'Baixo',
      );
    }

    if (score < 65) {
      return const RiskInfo(
        RiskLevel.medio,
        statusYellow,
        'Médio',
      );
    }

    if (score < 85) {
      return const RiskInfo(
        RiskLevel.alto,
        statusOrange,
        'Alto',
      );
    }

    return const RiskInfo(
      RiskLevel.critico,
      statusRed,
      'Crítico',
    );
  }

  String get description {
    switch (level) {
      case RiskLevel.baixo:
        return 'Condições normais de operação.';

      case RiskLevel.medio:
        return 'Parâmetros levemente fora do padrão. Acompanhe.';

      case RiskLevel.alto:
        return 'Risco elevado — recomenda-se verificar a máquina.';

      case RiskLevel.critico:
        return 'Risco crítico — intervenção imediata recomendada.';
    }
  }
}

// ============================================================
// FAIXAS DA ESCALA
// ============================================================

class RiskBand {
  final Color color;
  final double weight;
  final String label;

  const RiskBand(
    this.color,
    this.weight,
    this.label,
  );
}

const List<RiskBand> riskBands = [
  RiskBand(statusGreen, 0.40, 'Baixo'),
  RiskBand(statusYellow, 0.25, 'Médio'),
  RiskBand(statusOrange, 0.20, 'Alto'),
  RiskBand(statusRed, 0.15, 'Crítico'),
];

// ============================================================
// APP
// ============================================================

class OmegaApp extends StatelessWidget {
  const OmegaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Omega',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: omegaBackground,
        colorScheme: ColorScheme.fromSeed(
          seedColor: omegaBlue,
          brightness: Brightness.dark,
        ),
        fontFamily: 'Arial',
        appBarTheme: const AppBarTheme(
          backgroundColor: omegaBackground,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          foregroundColor: omegaText,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: omegaText,
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.1,
          ),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

// ============================================================
// SPLASH SCREEN
//
// Logo em omega.png entrando com fade + leve "estouro" de
// escala (easeOutBack) — depois de um instante, some com fade
// pra HOME. Lembre de declarar o asset no pubspec.yaml:
//
//   flutter:
//     assets:
//       - omega.png
// ============================================================

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();

    // Escala com um leve "estouro" (easeOutBack passa de 1.0 e
    // volta) — dá uma sensação de logo "assentando" na tela, em
    // vez de só crescer de forma mecânica.
    _scale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    // O fade-in termina mais cedo que a escala, pra logo já estar
    // visível enquanto ainda está "assentando".
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    _goToHome();
  }

  Future<void> _goToHome() async {
    // Tempo total na splash: dá pra acompanhar a animação
    // completa antes de seguir pro app.
    await Future.delayed(const Duration(milliseconds: 1900));
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (_, __, ___) => const OmegaHome(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: omegaBackground,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Opacity(
              opacity: _opacity.value,
              child: Transform.scale(
                scale: _scale.value,
                child: Image.asset(
                  'omega.png',
                  width: 360,
                  height: 360,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ============================================================
// HOME
// ============================================================

class OmegaHome extends StatefulWidget {
  const OmegaHome({super.key});

  @override
  State<OmegaHome> createState() => _OmegaHomeState();
}

class _OmegaHomeState extends State<OmegaHome> {
  int currentIndex = 0;

  // Controla se a aba de Monitoramento já foi visitada alguma vez
  // nesta sessão. Ela só entra no IndexedStack (e portanto só é
  // construída) depois da primeira visita — abrir a aba sozinha
  // continua não ligando a câmera, isso só acontece quando o
  // operador aperta o botão de tela cheia (ver MonitoringPage).
  bool _monitoringVisited = false;

  @override
  Widget build(BuildContext context) {
    if (currentIndex == 1) {
      _monitoringVisited = true;
    }

    // IndexedStack (em vez da reconstrução via ternário que havia
    // antes) preserva o estado de cada aba ao trocar entre elas —
    // sem isso, o Painel (MachinePage) perdia score/telemetria e
    // reiniciava do zero toda vez que o operador saía e voltava
    // pra ela.
    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: [
          const MachinePage(),
          if (_monitoringVisited)
            const MonitoringPage()
          else
            const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            currentIndex = index;
          });
        },
        backgroundColor: omegaSurface,
        indicatorColor: omegaBlue.withValues(alpha: 0.18),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.agriculture_outlined),
            selectedIcon: Icon(Icons.agriculture),
            label: 'Máquina',
          ),
          NavigationDestination(
            icon: Icon(Icons.visibility_outlined),
            selectedIcon: Icon(Icons.visibility),
            label: 'Monitoramento',
          ),
        ],
      ),
    );
  }
}

// ============================================================
// CARD BASE
// ============================================================

class OmegaCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  const OmegaCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 20,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: omegaSurface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: Colors.white10,
        ),
      ),
      child: child,
    );
  }
}

class SectionLabel extends StatelessWidget {
  final String text;

  const SectionLabel(
    this.text, {
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 2,
        color: omegaTextSecondary,
      ),
    );
  }
}

// ============================================================
// HEADER DO OPERADOR
// ============================================================

class OperatorHeader extends StatelessWidget {
  final String name;

  const OperatorHeader({
    super.key,
    this.name = 'João da Silva',
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: omegaSurfaceLight,
            border: Border.all(
              color: Colors.white10,
            ),
          ),
          child: const Icon(
            Icons.person_outline,
            color: omegaTextSecondary,
            size: 25,
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'OPERADOR',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.3,
                color: omegaTextSecondary,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: omegaText,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ============================================================
// PÁGINA DA MÁQUINA
// ============================================================

class MachinePage extends StatefulWidget {
  const MachinePage({super.key});

  @override
  State<MachinePage> createState() => _MachinePageState();
}

class _MachinePageState extends State<MachinePage> {
  double? riskScore;
  double? temperature;
  double? humidity;
  DateTime? lastUpdate;
  bool loading = false;

  Future<void> _refresh() async {
    setState(() {
      loading = true;
    });

    await Future.delayed(
      const Duration(milliseconds: 600),
    );

    if (!mounted) return;

    setState(() {
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Painel'),
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: _refresh,
          color: omegaBlue,
          backgroundColor: omegaSurface,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              22,
              18,
              22,
              30,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const OperatorHeader(),
                const SizedBox(height: 26),
                const SectionLabel(
                  'RISCO OPERACIONAL',
                ),
                const SizedBox(height: 11),
                RiskScoreCard(
                  score: riskScore,
                  lastUpdate: lastUpdate,
                  loading: loading,
                ),
                const SizedBox(height: 26),
                const SectionLabel(
                  'TELEMETRIA',
                ),
                const SizedBox(height: 11),
                Row(
                  children: [
                    Expanded(
                      child: _TelemetryCard(
                        icon: Icons.thermostat_outlined,
                        title: 'TEMPERATURA',
                        value:
                            temperature?.toStringAsFixed(1) ?? '—',
                        unit: '°C',
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: _TelemetryCard(
                        icon: Icons.water_drop_outlined,
                        title: 'UMIDADE',
                        value:
                            humidity?.toStringAsFixed(0) ?? '—',
                        unit: '%',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// CARD DE SCORE DE RISCO
// ============================================================

class RiskScoreCard extends StatelessWidget {
  final double? score;
  final DateTime? lastUpdate;
  final bool loading;

  const RiskScoreCard({
    super.key,
    required this.score,
    this.lastUpdate,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasScore = score != null;
    final risk = hasScore
        ? RiskInfo.fromScore(score!)
        : null;

    final fillFraction = hasScore
        ? (score!.clamp(0, 100) / 100)
        : 0.0;

    return OmegaCard(
      padding: const EdgeInsets.all(26),
      radius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'SCORE DE RISCO',
                style: TextStyle(
                  fontSize: 11,
                  color: omegaTextSecondary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              if (loading)
                const Text(
                  'Atualizando…',
                  style: TextStyle(
                    fontSize: 12,
                    color: omegaTextSecondary,
                  ),
                )
              else if (lastUpdate != null)
                Text(
                  'há ${_minutesAgo(lastUpdate!)} min',
                  style: const TextStyle(
                    fontSize: 12,
                    color: omegaTextSecondary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              RiskGauge(
                score: score,
                risk: risk,
                size: 132,
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color:
                            (risk?.color ??
                                    omegaTextSecondary)
                                .withValues(alpha: 0.14),
                        borderRadius:
                            BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize:
                            MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration:
                                BoxDecoration(
                              shape: BoxShape.circle,
                              color: risk?.color ??
                                  omegaTextSecondary,
                            ),
                          ),
                          const SizedBox(width: 7),
                          Text(
                            hasScore
                                ? risk!.label
                                    .toUpperCase()
                                : 'SEM DADO',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight:
                                  FontWeight.bold,
                              letterSpacing: 0.6,
                              color: risk?.color ??
                                  omegaTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      hasScore
                          ? risk!.description
                          : 'Sensor desconectado.',
                      style: const TextStyle(
                        fontSize: 13.5,
                        height: 1.45,
                        color: omegaTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          RiskScale(
            fraction: fillFraction,
            hasScore: hasScore,
          ),
        ],
      ),
    );
  }

  static int _minutesAgo(DateTime time) {
    return DateTime.now()
        .difference(time)
        .inMinutes;
  }
}

// ============================================================
// GAUGE
// ============================================================

class RiskGauge extends StatelessWidget {
  final double? score;
  final RiskInfo? risk;
  final double size;

  const RiskGauge({
    super.key,
    required this.score,
    required this.risk,
    this.size = 120,
  });

  @override
  Widget build(BuildContext context) {
    final hasScore = score != null;

    final fraction = hasScore
        ? (score!.clamp(0, 100) / 100)
        : 0.0;

    final color =
        risk?.color ?? omegaTextSecondary;

    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(
          begin: 0,
          end: fraction,
        ),
        duration:
            const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) {
          return Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: size,
                height: size,
                child:
                    const CircularProgressIndicator(
                  value: 1,
                  strokeWidth: 11,
                  strokeCap: StrokeCap.round,
                  valueColor:
                      AlwaysStoppedAnimation(
                    Colors.white10,
                  ),
                ),
              ),
              if (hasScore)
                SizedBox(
                  width: size,
                  height: size,
                  child:
                      CircularProgressIndicator(
                    value: value,
                    strokeWidth: 11,
                    strokeCap: StrokeCap.round,
                    valueColor:
                        AlwaysStoppedAnimation(
                      color,
                    ),
                  ),
                ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    hasScore
                        ? score!.toStringAsFixed(0)
                        : '—',
                    style: TextStyle(
                      fontSize: size * 0.30,
                      fontWeight:
                          FontWeight.w800,
                      color: omegaText,
                      height: 1,
                    ),
                  ),
                  Text(
                    '/ 100',
                    style: TextStyle(
                      fontSize: size * 0.095,
                      fontWeight:
                          FontWeight.w600,
                      color:
                          omegaTextSecondary,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

// ============================================================
// ESCALA
// ============================================================

class RiskScale extends StatelessWidget {
  final double fraction;
  final bool hasScore;

  const RiskScale({
    super.key,
    required this.fraction,
    required this.hasScore,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            const markerSize = 16.0;

            return SizedBox(
              height: markerSize,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    top:
                        (markerSize - 8) / 2,
                    left: 0,
                    right: 0,
                    child: Row(
                      children:
                          List.generate(
                        riskBands.length,
                        (i) {
                          final band =
                              riskBands[i];

                          final isFirst =
                              i == 0;

                          final isLast =
                              i ==
                                  riskBands
                                      .length -
                                      1;

                          return Expanded(
                            flex:
                                (band.weight *
                                        1000)
                                    .round(),
                            child: Container(
                              height: 8,
                              margin:
                                  EdgeInsets.only(
                                right: isLast
                                    ? 0
                                    : 2,
                              ),
                              decoration:
                                  BoxDecoration(
                                color:
                                    band.color,
                                borderRadius:
                                    BorderRadius
                                        .horizontal(
                                  left: isFirst
                                      ? const Radius
                                          .circular(
                                          6,
                                        )
                                      : Radius.zero,
                                  right: isLast
                                      ? const Radius
                                          .circular(
                                          6,
                                        )
                                      : Radius.zero,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  if (hasScore)
                    AnimatedPositioned(
                      duration:
                          const Duration(
                        milliseconds: 700,
                      ),
                      curve:
                          Curves.easeOutCubic,
                      left:
                          (width * fraction -
                                  markerSize /
                                      2)
                              .clamp(
                        0,
                        width -
                            markerSize,
                      ),
                      top: 0,
                      child: Container(
                        width: markerSize,
                        height: markerSize,
                        decoration:
                            BoxDecoration(
                          shape:
                              BoxShape.circle,
                          color:
                              omegaBackground,
                          border:
                              Border.all(
                            color:
                                omegaText,
                            width: 2.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 9),
        Row(
          mainAxisAlignment:
              MainAxisAlignment
                  .spaceBetween,
          children: riskBands
              .map(
                (b) => Text(
                  b.label,
                  style:
                      const TextStyle(
                    fontSize: 10.5,
                    color:
                        omegaTextSecondary,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

// ============================================================
// MONITORAMENTO — TAB (LANÇADOR)
//
// Essa página NÃO toca em câmera nem em MediaPipe. Ela só mostra
// um cartão explicando o que vai acontecer e um botão. A câmera
// só é criada e a permissão do sistema só é pedida quando o
// operador aperta esse botão e entra na tela cheia
// (MonitoringFullscreenPage). Assim, abrir a aba de Monitoramento
// nunca liga a câmera sozinho.
// ============================================================

class MonitoringPage extends StatefulWidget {
  const MonitoringPage({super.key});

  @override
  State<MonitoringPage> createState() => _MonitoringPageState();
}

class _MonitoringPageState extends State<MonitoringPage> {
  bool _opening = false;

  Future<void> _openFullscreenMonitoring() async {
    if (_opening) return;

    setState(() {
      _opening = true;
    });

    // O push só retorna quando o operador sai da tela cheia — e
    // nesse ponto o monitoramento e a câmera já foram desligados
    // dentro do próprio MonitoringFullscreenPage (dispose/pop).
    await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const MonitoringFullscreenPage(),
      ),
    );

    if (!mounted) return;

    setState(() {
      _opening = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monitoramento'),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const OperatorHeader(),
              const SizedBox(height: 26),
              const SectionLabel('MONITORAMENTO'),
              const SizedBox(height: 11),
              OmegaCard(
                padding: const EdgeInsets.all(26),
                radius: 24,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: omegaBlue.withValues(alpha: 0.14),
                      ),
                      child: const Icon(
                        Icons.visibility_outlined,
                        color: omegaBlueLight,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'ANTES DE COMEÇAR',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: omegaTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const _ChecklistItem(
                      icon: Icons.center_focus_strong_outlined,
                      text: 'Posicione o celular de frente para o rosto',
                    ),
                    const SizedBox(height: 12),
                    const _ChecklistItem(
                      icon: Icons.wb_sunny_outlined,
                      text: 'Garanta um ambiente bem iluminado',
                    ),
                    const SizedBox(height: 12),
                    const _ChecklistItem(
                      icon: Icons.cleaning_services_outlined,
                      text: 'Verifique se a lente da câmera está limpa',
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton.icon(
                        onPressed:
                            _opening ? null : _openFullscreenMonitoring,
                        icon: _opening
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.fullscreen),
                        label: Text(
                          _opening
                              ? 'ABRINDO CÂMERA…'
                              : 'INICIAR MONITORAMENTO',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: omegaBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'A câmera só liga depois que você autorizar, e desliga sozinha assim que você sair da tela cheia.',
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.4,
                        color: omegaTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// ITEM DO CHECKLIST — ícone pequeno + texto curto, sem inventar
// mais estilo do que isso precisa.
// ============================================================

class _ChecklistItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _ChecklistItem({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          margin: const EdgeInsets.only(top: 1),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: omegaSurfaceLight,
          ),
          child: Icon(
            icon,
            size: 14,
            color: omegaBlueLight,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              height: 1.35,
              color: omegaText,
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// MONITORAMENTO — TELA CHEIA
//
// Aqui mora tudo: pedido de permissão, câmera, MediaPipe e a
// lógica de start/stop. A câmera só é criada em initState() desta
// página (ou seja, só quando o operador realmente entrou aqui), e
// tudo é desligado e liberado ao sair (botão fechar, gesto de
// voltar, ou o app indo pra segundo plano).
// ============================================================

class MonitoringFullscreenPage extends StatefulWidget {
  const MonitoringFullscreenPage({super.key});

  @override
  State<MonitoringFullscreenPage> createState() =>
      _MonitoringFullscreenPageState();
}

class _MonitoringFullscreenPageState extends State<MonitoringFullscreenPage>
    with WidgetsBindingObserver {
  CameraController? _cameraController;
  CameraDescription? _camera;

  FaceDetectorProcessor? _faceDetector;
  FaceMeshProcessor? _faceMesh;
  FaceMeshInferencePipeline? _pipeline;
  FaceMeshInferenceStreamProcessor? _streamProcessor;

  StreamController<FaceMeshNv21Image>? _frameController;
  StreamSubscription<FaceMeshInferenceResult>? _inferenceSubscription;

  // Watchdog do frame em processamento: se _handleInferenceResult
  // (ou _handleInferenceError) nunca disparar para o frame que
  // acabou de ser enviado — por exemplo, se a pipeline descartar
  // um frame sem emitir nada — _processingFrame ficaria travado
  // em `true` para sempre, e nenhum frame novo seria processado
  // pelo resto da sessão. Esse timer é uma rede de segurança que
  // libera o processamento se isso acontecer.
  Timer? _frameWatchdog;

  bool _initializing = true;
  bool _monitoring = false;
  bool _processingFrame = false;
  bool _busy = false;

  String _status = 'Preparando câmera…';
  String? _permissionError;

  double _attention = 100;
  double _drowsiness = 0;
  DrowsinessStatus _drowsinessStatus = DrowsinessStatus.normal;

  // Dimensões reais do frame analisado (já considerando rotação),
  // usadas para converter os landmarks normalizados em escala de
  // pixel antes de calcular EAR/MAR — ver DrowsinessDetector.
  int? _frameWidth;
  int? _frameHeight;

  DateTime? _lastAlertSound;
  DateTime? _lastAttentionSpeech;

  final FlutterTts _tts = FlutterTts();

  final DrowsinessDetector _detector = DrowsinessDetector();

  // ==========================================================
  // INIT
  // ==========================================================

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeSpeech();
    // Modo imersivo: some com status bar/nav bar pra tela ficar
    // realmente "limpa" enquanto o operador está sendo monitorado.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    // A câmera fica montada deitada no painel/trator, então a tela
    // de monitoramento é sempre em paisagem — landscapeLeft e
    // landscapeRight ficam liberados pra funcionar com o aparelho
    // montado de qualquer um dos dois lados.
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _initializeAndStart();
  }

  // ==========================================================
  // INICIALIZA CÂMERA (só acontece aqui, ao entrar na tela cheia)
  // ==========================================================

  Future<void> _disposePreviousCameraAndPipeline() async {
    try {
      await _cameraController?.dispose();
    } catch (e) {
      debugPrint('Erro liberando câmera de tentativa anterior: $e');
    }
    _cameraController = null;
    _camera = null;

    // close() do FaceDetectorProcessor/FaceMeshProcessor é síncrono
    // (void) neste pacote — sem await, igual ao dispose() já fazia.
    try {
      _faceDetector?.close();
    } catch (e) {
      debugPrint('Erro liberando face detector de tentativa anterior: $e');
    }
    _faceDetector = null;

    try {
      _faceMesh?.close();
    } catch (e) {
      debugPrint('Erro liberando face mesh de tentativa anterior: $e');
    }
    _faceMesh = null;

    _pipeline = null;
    _streamProcessor = null;
  }

  Future<void> _initializeAndStart() async {
    // Se já existir uma câmera/pipeline de uma tentativa anterior
    // (por exemplo, vindo do botão "Tentar novamente" depois de um
    // erro que aconteceu já com a câmera aberta), libera tudo antes
    // de criar uma instância nova — senão essa tentativa pode
    // falhar com a câmera "já em uso", ou vazar a instância antiga.
    await _disposePreviousCameraAndPipeline();

    try {
      final cameras = await availableCameras();

      if (cameras.isEmpty) {
        if (!mounted) return;
        setState(() {
          _initializing = false;
          _permissionError = 'Nenhuma câmera encontrada neste aparelho.';
        });
        return;
      }

      CameraDescription selected = cameras.first;

      for (final camera in cameras) {
        if (camera.lensDirection == CameraLensDirection.front) {
          selected = camera;
          break;
        }
      }

      final controller = CameraController(
        selected,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      // controller.initialize() é quem dispara o diálogo de
      // permissão do sistema. Enquanto ele não resolver (permitido
      // ou negado), não existe controller utilizável nem preview
      // nenhum na tela — é exatamente o "só ativa depois que o
      // sistema permitir" que a gente quer.
      await controller.initialize();

      // Trava o preview na orientação atual do aparelho (que já
      // deve estar em paisagem, por causa do setPreferredOrientations
      // do initState). Sem isso, em vários aparelhos o preview
      // continua vindo "em pé" mesmo com a tela deitada, porque o
      // sensor da câmera tem uma orientação nativa própria.
      try {
        await controller.lockCaptureOrientation();
      } catch (e) {
        debugPrint('Não foi possível travar a orientação da câmera: $e');
      }

      _camera = selected;
      _cameraController = controller;

      await _initializeMediaPipe();

      if (!mounted) return;

      setState(() {
        _initializing = false;
      });

      // Entrar na tela cheia já inicia o monitoramento — não tem
      // um segundo botão de "play" escondido atrás da câmera.
      await _startMonitoring();
    } catch (e) {
      debugPrint('Erro inicializando câmera: $e');

      if (!mounted) return;

      setState(() {
        _initializing = false;
        _permissionError =
            'Não foi possível acessar a câmera. Verifique a permissão do app nas configurações do aparelho.';
      });
    }
  }

  // Deixa o operador tentar de novo sem sair da tela cheia — útil
  // depois de ajustar a permissão da câmera nas configurações do
  // aparelho, por exemplo.
  Future<void> _retry() async {
    if (!mounted) return;
    setState(() {
      _initializing = true;
      _permissionError = null;
    });
    await _initializeAndStart();
  }

  // ==========================================================
  // INICIALIZA MEDIAPIPE
  // ==========================================================

  Future<void> _initializeMediaPipe() async {
    _faceDetector = await FaceDetectorProcessor.create(
      delegate: FaceMeshDelegate.xnnpack,
      minDetectionConfidence: 0.15,
    );

    _faceMesh = await FaceMeshProcessor.create(
      model: FaceMeshModel.v2,
      delegate: FaceMeshDelegate.xnnpack,
      minDetectionConfidence: 0.15,
      minTrackingConfidence: 0.15,
      minFacePresenceConfidence: 0.15,
      enableSmoothing: true,
    );

    _pipeline = FaceMeshInferencePipeline(
      detector: _faceDetector!,
      mesh: _faceMesh!,
      landmarkSmoothing: LandmarkSmoothingOptions(),
    );

    _streamProcessor = FaceMeshInferenceStreamProcessor(_pipeline!);
  }

  // ==========================================================
  // START / STOP
  // ==========================================================

  Future<void> _startMonitoring() async {
    if (_cameraController == null || _streamProcessor == null || _busy) {
      return;
    }

    _busy = true;
    try {
      _resetDetection();

      _frameController = StreamController<FaceMeshNv21Image>();

      _inferenceSubscription = _streamProcessor!
          .processNv21(
        _frameController!.stream,
        runMeshResolver: (_) => true,
        rotationDegrees: _camera!.sensorOrientation,
        mirrorHorizontal: true,
      )
          .listen(
        _handleInferenceResult,
        onError: _handleInferenceError,
      );

      await _cameraController!.startImageStream(_handleCameraFrame);

      if (!mounted) return;

      setState(() {
        _monitoring = true;
        _status = 'Monitoramento ativo';
      });
    } catch (e) {
      debugPrint('Erro iniciando monitoramento: $e');

      // Se chegamos aqui depois de já ter criado a inscrição de
      // inferência e o frame controller (por exemplo, porque
      // startImageStream() foi quem falhou), eles ficariam
      // vazando sem nunca ser fechados — e uma nova tentativa de
      // _startMonitoring() criaria um segundo par por cima do
      // primeiro. Desfaz os dois antes de sair.
      await _inferenceSubscription?.cancel();
      _inferenceSubscription = null;
      await _frameController?.close();
      _frameController = null;

      if (mounted) {
        setState(() {
          _monitoring = false;
          _status = 'Erro ao iniciar monitoramento';
        });
      }
    } finally {
      _busy = false;
    }
  }

  Future<void> _stopMonitoring() async {
    // Cada etapa tem seu próprio try/catch: se qualquer uma
    // lançar, as demais ainda rodam e o setState final sempre
    // acontece — assim a tela nunca fica presa "monitorando" com a
    // câmera já parada por trás.
    try {
      if (_cameraController != null &&
          _cameraController!.value.isStreamingImages) {
        await _cameraController!.stopImageStream();
      }
    } catch (e) {
      debugPrint('Erro parando câmera: $e');
    }

    try {
      await _inferenceSubscription?.cancel();
    } catch (e) {
      debugPrint('Erro cancelando inferência: $e');
    }
    _inferenceSubscription = null;

    try {
      await _frameController?.close();
    } catch (e) {
      debugPrint('Erro fechando frame controller: $e');
    }
    _frameController = null;

    _frameWatchdog?.cancel();
    _frameWatchdog = null;
    _processingFrame = false;
    await _tts.stop();

    if (!mounted) return;

    setState(() {
      _monitoring = false;
      _status = 'Monitoramento parado';
    });
  }

  // ==========================================================
  // FRAME DA CÂMERA
  // ==========================================================

  void _handleCameraFrame(CameraImage image) {
    if (!_monitoring) return;
    if (_processingFrame) return;
    if (_frameController == null) return;
    if (image.planes.length < 3) return;

    final rotation = _camera?.sensorOrientation ?? 0;
    final rotated = rotation % 180 != 0;
    _frameWidth = rotated ? image.height : image.width;
    _frameHeight = rotated ? image.width : image.height;

    try {
      final yPlane = FaceMeshImagePlane(
        bytes: image.planes[0].bytes,
        bytesPerRow: image.planes[0].bytesPerRow,
        bytesPerPixel: image.planes[0].bytesPerPixel,
      );

      final uPlane = FaceMeshImagePlane(
        bytes: image.planes[1].bytes,
        bytesPerRow: image.planes[1].bytesPerRow,
        bytesPerPixel: image.planes[1].bytesPerPixel,
      );

      final vPlane = FaceMeshImagePlane(
        bytes: image.planes[2].bytes,
        bytesPerRow: image.planes[2].bytesPerRow,
        bytesPerPixel: image.planes[2].bytesPerPixel,
      );

      final nv21 = FaceMeshNv21Image.tryFromYuv420Planes(
        width: image.width,
        height: image.height,
        yPlane: yPlane,
        uPlane: uPlane,
        vPlane: vPlane,
      );

      if (nv21 == null) return;

      _processingFrame = true;
      _frameWatchdog?.cancel();
      _frameWatchdog = Timer(const Duration(seconds: 3), () {
        debugPrint('Frame sem resposta da pipeline — destravando.');
        _processingFrame = false;
      });
      _frameController!.add(nv21);
    } catch (e) {
      debugPrint('Erro processando frame: $e');
      _processingFrame = false;
    }
  }

  // ==========================================================
  // RESULTADO MEDIAPIPE
  // ==========================================================

  void _handleInferenceResult(FaceMeshInferenceResult result) {
    _frameWatchdog?.cancel();
    _processingFrame = false;

    if (!_monitoring) return;

    final mesh = result.meshResult;

    if (mesh == null || mesh.landmarks.length < 468) {
      if (mounted) {
        setState(() {
          _status = 'Rosto não identificado';
        });
      }
      return;
    }

    _processFace(mesh);
  }

  void _handleInferenceError(Object error) {
    _frameWatchdog?.cancel();
    _processingFrame = false;
    debugPrint('MediaPipe error: $error');
  }

  // ==========================================================
  // PROCESSAMENTO DO ROSTO
  // ==========================================================

  void _processFace(FaceMeshResult result) {
    final landmarks = result.landmarks;

    if (landmarks.length < 468) return;
    if (_frameWidth == null || _frameHeight == null) return;

    final xs = <double>[for (final lm in landmarks) lm.x];
    final ys = <double>[for (final lm in landmarks) lm.y];

    final frame = _detector.processFrame(
      xs: xs,
      ys: ys,
      frameWidth: _frameWidth!.toDouble(),
      frameHeight: _frameHeight!.toDouble(),
    );

    if (!mounted) return;

    final currentAttention = (100 - frame.score).clamp(0, 100).toDouble();
    final attentionDropped = currentAttention < _attention - 0.5;
    final enteredLowAttention =
        _drowsinessStatus == DrowsinessStatus.normal &&
        frame.status != DrowsinessStatus.normal;
    final shouldSpeak =
        frame.status != DrowsinessStatus.normal &&
        (enteredLowAttention || attentionDropped);

    setState(() {
      _drowsiness = frame.score;
      _attention = currentAttention;
      _status = _statusMessage(frame);
      _drowsinessStatus = frame.status;
    });

    if (shouldSpeak) {
      _playAlertFeedback(frame.status);
    }
  }

  Future<void> _initializeSpeech() async {
    await _tts.setLanguage('pt-BR');
    await _tts.setSpeechRate(0.44);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);

    final voices = await _tts.getVoices;
    final portugueseVoices = voices
        .whereType<Map>()
        .map((voice) => Map<String, dynamic>.from(voice))
        .where((voice) {
          final locale = '${voice['locale']}'.toLowerCase().replaceAll('_', '-');
          return locale == 'pt-br' || locale.startsWith('pt-br-');
        })
        .toList();

    final maleVoice = portugueseVoices.where((voice) {
      final description = '${voice['name']} ${voice['gender']}'.toLowerCase();
      return description.contains('male') ||
          description.contains('mascul') ||
          description.contains('homem');
    }).firstOrNull;

    if (maleVoice != null) {
      await _tts.setVoice(maleVoice);
    }
  }

  // Som + vibração do alerta, com um cooldown pra não virar ruído
  // constante enquanto o estado de alerta persiste por vários
  // frames seguidos.
  void _playAlertFeedback(DrowsinessStatus status) {
    final now = DateTime.now();

    if (status == DrowsinessStatus.alerta &&
        (_lastAlertSound == null ||
            now.difference(_lastAlertSound!) >= const Duration(seconds: 4))) {
      _lastAlertSound = now;
      SystemSound.play(SystemSoundType.alert);
      HapticFeedback.heavyImpact();
    }

    if (_lastAttentionSpeech == null ||
        now.difference(_lastAttentionSpeech!) >= const Duration(seconds: 8)) {
      _lastAttentionSpeech = now;
      final message = status == DrowsinessStatus.alerta
          ? 'Atenção. Sonolência detectada.'
          : 'Atenção baixa. Mantenha o foco.';
      _tts.stop();
      _tts.speak(message);
    }
  }

  String _statusMessage(DrowsinessFrameResult frame) {
    switch (frame.status) {
      case DrowsinessStatus.alerta:
        return frame.poseDifficult
            ? 'Sonolência — ajuste o ângulo da câmera'
            : 'Sonolência detectada';
      case DrowsinessStatus.atencao:
        return 'Atenção necessária';
      case DrowsinessStatus.normal:
        return frame.poseDifficult
            ? 'Monitorando (ajuste o ângulo da câmera)'
            : 'Monitorando';
    }
  }

  Color get _statusColor {
    switch (_drowsinessStatus) {
      case DrowsinessStatus.alerta:
        return statusRed;
      case DrowsinessStatus.atencao:
        return statusOrange;
      case DrowsinessStatus.normal:
        return statusGreen;
    }
  }

  // ==========================================================
  // RESET
  // ==========================================================

  void _resetDetection() {
    _detector.reset();
    _frameWidth = null;
    _frameHeight = null;
    _attention = 100;
    _drowsiness = 0;
    _drowsinessStatus = DrowsinessStatus.normal;
    _lastAlertSound = null;
    _lastAttentionSpeech = null;
  }

  // ==========================================================
  // CICLO DE VIDA / SAÍDA
  // ==========================================================

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      if (_monitoring) {
        _stopMonitoring();
      }
    }
  }

  // Sai da tela cheia. O pop em si é sempre permitido (canPop:
  // true no PopScope abaixo) — quem garante que a câmera não fica
  // rodando por trás é o dispose(), chamado quando a rota
  // realmente é removida (ver PopScope.onPopInvokedWithResult, mais
  // abaixo, para o motivo de não chamarmos _stopMonitoring() aqui).
  void _exitFullscreen() {
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    // O resto do app (Máquina / lançador do Monitoramento) foi
    // desenhado em pé — só a tela cheia da câmera é deitada.
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _frameWatchdog?.cancel();
    _inferenceSubscription?.cancel();
    _frameController?.close();
    _cameraController?.dispose();
    _faceDetector?.close();
    _faceMesh?.close();
    _tts.stop();
    super.dispose();
  }

  // ==========================================================
  // UI
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // canPop: true — o botão fechar, o gesto de voltar e o botão
      // físico de voltar do Android todos saem imediatamente da
      // tela. Antes a gente bloqueava o pop (canPop: false) pra
      // parar a câmera primeiro, mas isso também bloqueava o
      // Navigator.pop() disparado pelo próprio botão fechar — ele
      // nunca conseguia sair de fato.
      canPop: true,
      // Não chamamos _stopMonitoring() aqui de propósito: ele é
      // assíncrono (stopImageStream, cancelamento da inscrição
      // etc.), e o dispose() desta página pode disparar antes
      // dessas operações terminarem, chamando
      // _cameraController!.dispose() por cima de um
      // stopImageStream() ainda em andamento — uma corrida que já
      // causou exceções do plugin de câmera em alguns aparelhos.
      // dispose() sozinho já cancela a inscrição, fecha o frame
      // controller e libera a câmera (CameraController.dispose()
      // lida com um stream ativo internamente), então ele é quem
      // cuida do teardown na saída por pop.
      onPopInvokedWithResult: (didPop, _) {},
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // ================================================
            // CÂMERA (preenche a tela toda)
            // ================================================
            if (_cameraController != null &&
                _cameraController!.value.isInitialized)
              Positioned.fill(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _cameraController!.value.previewSize?.width ?? 1,
                    height: _cameraController!.value.previewSize?.height ?? 1,
                    child: CameraPreview(_cameraController!),
                  ),
                ),
              )
            else
              const Center(
                child: Icon(
                  Icons.videocam_off_outlined,
                  size: 72,
                  color: Colors.white24,
                ),
              ),

            // Gradiente escuro sutil só pra garantir contraste do
            // texto sobre qualquer fundo de câmera.
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x59000000),
                      Color(0x00000000),
                      Color(0x8C000000),
                    ],
                    stops: [0.0, 0.4, 1.0],
                  ),
                ),
              ),
            ),

            // ================================================
            // LOADING (esperando permissão/câmera)
            // ================================================
            if (_initializing)
              const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Aguardando permissão da câmera…',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              )

            // ================================================
            // ERRO (permissão negada / sem câmera)
            // ================================================
            else if (_permissionError != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.no_photography_outlined,
                        color: Colors.white54,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _permissionError!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          OutlinedButton(
                            onPressed: _exitFullscreen,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white38),
                            ),
                            child: const Text('Voltar'),
                          ),
                          const SizedBox(width: 12),
                          FilledButton(
                            onPressed: _retry,
                            child: const Text('Tentar novamente'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

            // ================================================
            // BOTÃO FECHAR (sempre para o monitoramento antes)
            // ================================================
            Positioned(
              top: 12,
              left: 12,
              child: SafeArea(
                child: _RoundIconButton(
                  icon: Icons.close,
                  onTap: _exitFullscreen,
                ),
              ),
            ),

            // ================================================
            // OVERLAY INFERIOR — clean, um status + um número
            // ================================================
            if (!_initializing && _permissionError == null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 22),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                width: 9,
                                height: 9,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _monitoring
                                      ? _statusColor
                                      : Colors.white38,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _status,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        _AttentionRing(
                          value: _attention,
                          color: _statusColor,
                        ),
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
}

// ============================================================
// BOTÃO REDONDO (fechar tela cheia)
// ============================================================

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _RoundIconButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black45,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

// ============================================================
// ANEL DE ATENÇÃO — um número só, sem poluir a tela
// ============================================================

class _AttentionRing extends StatelessWidget {
  final double value;
  final Color color;

  const _AttentionRing({
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 54,
      height: 54,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const SizedBox(
            width: 54,
            height: 54,
            child: CircularProgressIndicator(
              value: 1,
              strokeWidth: 5,
              strokeCap: StrokeCap.round,
              valueColor: AlwaysStoppedAnimation(Colors.white24),
            ),
          ),
          SizedBox(
            width: 54,
            height: 54,
            child: TweenAnimationBuilder<double>(
              tween: Tween(
                begin: 0,
                end: (value.clamp(0, 100)) / 100,
              ),
              duration: const Duration(milliseconds: 400),
              builder: (context, v, _) => CircularProgressIndicator(
                value: v,
                strokeWidth: 5,
                strokeCap: StrokeCap.round,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ),
          Text(
            value.toStringAsFixed(0),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// CARD DE TELEMETRIA
// ============================================================

class _TelemetryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String unit;

  const _TelemetryCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return OmegaCard(
      padding: const EdgeInsets.all(17),
      radius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 21,
            color: omegaTextSecondary,
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              fontSize: 9,
              color: omegaTextSecondary,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 5),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w700,
                  color: omegaText,
                ),
              ),
              const SizedBox(width: 3),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  unit,
                  style: const TextStyle(
                    fontSize: 11,
                    color: omegaTextSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

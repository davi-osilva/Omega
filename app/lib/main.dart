import 'package:flutter/material.dart';

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
// Os 4 níveis espelham os 3 LEDs do ESP32 (baixo/médio/alto) +
// um patamar crítico, que é quando o buzzer do firmware dispara.
// ============================================================

enum RiskLevel { baixo, medio, alto, critico }

class RiskInfo {
  final RiskLevel level;
  final Color color;
  final String label;

  const RiskInfo(this.level, this.color, this.label);

  factory RiskInfo.fromScore(double score) {
    if (score < 40) return const RiskInfo(RiskLevel.baixo, statusGreen, 'Baixo');
    if (score < 65) return const RiskInfo(RiskLevel.medio, statusYellow, 'Médio');
    if (score < 85) return const RiskInfo(RiskLevel.alto, statusOrange, 'Alto');
    return const RiskInfo(RiskLevel.critico, statusRed, 'Crítico');
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
// FAIXAS DA ESCALA (usadas no gauge e na barra segmentada)
// ============================================================

class RiskBand {
  final Color color;
  final double weight; // proporção da faixa na escala 0-100
  final String label;
  const RiskBand(this.color, this.weight, this.label);
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
        // OBS: 'Arial' não é empacotada pelo Flutter — sem
        // declarar o asset em pubspec.yaml (ou usar google_fonts),
        // o Flutter ignora silenciosamente e cai na fonte padrão
        // da plataforma.
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
      home: const OmegaHome(),
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

  final List<Widget> pages = const [
    MachinePage(),
    MonitoringPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: pages,
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
// CARD BASE REUTILIZÁVEL
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
        border: Border.all(color: Colors.white10),
      ),
      child: child,
    );
  }
}

class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});

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
  const OperatorHeader({super.key, this.name = 'João da Silva'});

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
            border: Border.all(color: Colors.white10),
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
  // Placeholder de estado — quando a API/RDS estiver pronta, isso
  // vira um FutureBuilder/StreamBuilder alimentado pelo endpoint
  // do Lambda. null = "sem dado ainda", 0-100 = score do XGBoost.
  double? riskScore;
  double? temperature;
  double? humidity;
  DateTime? lastUpdate;
  bool loading = false;

  Future<void> _refresh() async {
    setState(() => loading = true);
    // TODO: chamada real ao endpoint (API Gateway -> Lambda -> RDS)
    await Future.delayed(const Duration(milliseconds: 600));
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Painel')),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: _refresh,
          color: omegaBlue,
          backgroundColor: omegaSurface,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const OperatorHeader(),
                const SizedBox(height: 26),

                const SectionLabel('RISCO OPERACIONAL'),
                const SizedBox(height: 11),
                RiskScoreCard(
                  score: riskScore,
                  lastUpdate: lastUpdate,
                  loading: loading,
                ),

                const SizedBox(height: 26),

                const SectionLabel('TELEMETRIA'),
                const SizedBox(height: 11),
                Row(
                  children: [
                    Expanded(
                      child: _TelemetryCard(
                        icon: Icons.thermostat_outlined,
                        title: 'TEMPERATURA',
                        value: temperature?.toStringAsFixed(1) ?? '—',
                        unit: '°C',
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: _TelemetryCard(
                        icon: Icons.water_drop_outlined,
                        title: 'UMIDADE',
                        value: humidity?.toStringAsFixed(0) ?? '—',
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
// Card maior e mais respirado (mais padding, gauge circular como
// elemento principal, badge de nível, descrição curta e escala
// segmentada com marcador) em vez da versão compacta anterior.
// ============================================================

class RiskScoreCard extends StatelessWidget {
  final double? score; // 0-100, null = sem dado
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
    final risk = hasScore ? RiskInfo.fromScore(score!) : null;
    final fillFraction = hasScore ? (score!.clamp(0, 100) / 100) : 0.0;

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
                  style: TextStyle(fontSize: 12, color: omegaTextSecondary),
                )
              else if (lastUpdate != null)
                Text(
                  'há ${_minutesAgo(lastUpdate!)} min',
                  style: const TextStyle(fontSize: 12, color: omegaTextSecondary),
                ),
            ],
          ),

          const SizedBox(height: 24),

          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              RiskGauge(score: score, risk: risk, size: 132),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: (risk?.color ?? omegaTextSecondary)
                            .withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: risk?.color ?? omegaTextSecondary,
                            ),
                          ),
                          const SizedBox(width: 7),
                          Text(
                            hasScore ? risk!.label.toUpperCase() : 'SEM DADO',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.6,
                              color: risk?.color ?? omegaTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      hasScore ? risk!.description : 'Sensor desconectado.',
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

          RiskScale(fraction: fillFraction, hasScore: hasScore),
        ],
      ),
    );
  }

  static int _minutesAgo(DateTime time) =>
      DateTime.now().difference(time).inMinutes;
}

/// Gauge circular do score — track cinza de fundo + arco colorido
/// proporcional ao valor, com o número grande centralizado.
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
    final fraction = hasScore ? (score!.clamp(0, 100) / 100) : 0.0;
    final color = risk?.color ?? omegaTextSecondary;

    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: fraction),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) {
          return Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: size,
                height: size,
                child: const CircularProgressIndicator(
                  value: 1,
                  strokeWidth: 11,
                  strokeCap: StrokeCap.round,
                  valueColor: AlwaysStoppedAnimation(Colors.white10),
                ),
              ),
              if (hasScore)
                SizedBox(
                  width: size,
                  height: size,
                  child: CircularProgressIndicator(
                    value: value,
                    strokeWidth: 11,
                    strokeCap: StrokeCap.round,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    hasScore ? score!.toStringAsFixed(0) : '—',
                    style: TextStyle(
                      fontSize: size * 0.30,
                      fontWeight: FontWeight.w800,
                      color: omegaText,
                      height: 1,
                    ),
                  ),
                  Text(
                    '/ 100',
                    style: TextStyle(
                      fontSize: size * 0.095,
                      fontWeight: FontWeight.w600,
                      color: omegaTextSecondary,
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

/// Barra segmentada mostrando as 4 faixas de risco, com um
/// marcador na posição exata do score — mesma lógica de "onde
/// estou na escala" comum em medidores de score/crédito.
class RiskScale extends StatelessWidget {
  final double fraction;
  final bool hasScore;

  const RiskScale({super.key, required this.fraction, required this.hasScore});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
                    top: (markerSize - 8) / 2,
                    left: 0,
                    right: 0,
                    child: Row(
                      children: List.generate(riskBands.length, (i) {
                        final band = riskBands[i];
                        final isFirst = i == 0;
                        final isLast = i == riskBands.length - 1;
                        return Expanded(
                          flex: (band.weight * 1000).round(),
                          child: Container(
                            height: 8,
                            margin: EdgeInsets.only(
                              right: isLast ? 0 : 2,
                            ),
                            decoration: BoxDecoration(
                              color: band.color,
                              borderRadius: BorderRadius.horizontal(
                                left: isFirst ? const Radius.circular(6) : Radius.zero,
                                right: isLast ? const Radius.circular(6) : Radius.zero,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  if (hasScore)
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeOutCubic,
                      left: (width * fraction - markerSize / 2)
                          .clamp(0, width - markerSize),
                      top: 0,
                      child: Container(
                        width: markerSize,
                        height: markerSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: omegaBackground,
                          border: Border.all(color: omegaText, width: 2.5),
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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: riskBands
              .map((b) => Text(
                    b.label,
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: omegaTextSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }
}

// ============================================================
// MONITORAMENTO
// Sem headline explicando o que a tela faz — o AppBar já
// contextualiza, como em apps profissionais de monitoramento.
// ============================================================

class MonitoringPage extends StatelessWidget {
  const MonitoringPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Monitoramento')),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFF050A0F),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Stack(
                    children: [
                      const Center(
                        child: Icon(
                          Icons.videocam_outlined,
                          size: 72,
                          color: Colors.white24,
                        ),
                      ),
                      Positioned(
                        top: 15,
                        left: 15,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.circle, color: statusGreen, size: 8),
                              SizedBox(width: 7),
                              Text(
                                'CÂMERA',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 15,
                        left: 15,
                        right: 15,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'A câmera será ativada na próxima etapa.',
                            style: TextStyle(fontSize: 12, color: Colors.white70),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              OmegaCard(
                padding: const EdgeInsets.all(18),
                radius: 18,
                child: Row(
                  children: [
                    Container(
                      width: 45,
                      height: 45,
                      decoration: BoxDecoration(
                        color: omegaBlue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(
                        Icons.monitor_heart_outlined,
                        color: omegaBlueLight,
                      ),
                    ),
                    const SizedBox(width: 13),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'STATUS',
                            style: TextStyle(
                              fontSize: 10,
                              color: omegaTextSecondary,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Monitoramento parado',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: omegaText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _Metric(
                      icon: Icons.remove_red_eye_outlined,
                      title: 'ATENÇÃO',
                      value: '—',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Metric(
                      icon: Icons.bedtime_outlined,
                      title: 'SONOLÊNCIA',
                      value: '—',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'A câmera será ativada na próxima etapa.',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text(
                    'INICIAR MONITORAMENTO',
                    style: TextStyle(
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
            ],
          ),
        ),
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
          Icon(icon, size: 21, color: omegaTextSecondary),
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
                  style: const TextStyle(fontSize: 11, color: omegaTextSecondary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================
// MÉTRICA
// ============================================================

class _Metric extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _Metric({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 14),
      decoration: BoxDecoration(
        color: omegaSurfaceLight.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          Icon(icon, size: 19, color: omegaTextSecondary),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 8,
                    color: omegaTextSecondary,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: omegaText,
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
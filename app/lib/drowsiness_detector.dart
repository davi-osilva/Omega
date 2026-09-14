import 'dart:collection';
import 'dart:math' as math;

// ============================================================
// DETECTOR DE SONOLÊNCIA
//
// Lógica com EAR + blink + MAR + yaw + histórico temporal + 
// PERCLOS ponderado por tempo + Mecanismo de Alívio (Destravamento).
// ============================================================

enum DrowsinessStatus { normal, atencao, alerta }

enum EyeEvidence { earStrong, earPlusBlink, blink, open }

class EyeAnalysis {
  final double ear;
  final bool closed;
  final bool closedStrong;
  final double blink;
  final EyeEvidence evidence;
  final String eyeUsed; // 'ESQ' | 'DIR' | 'MEDIO'
  final double widthDifference;

  const EyeAnalysis({
    required this.ear,
    required this.closed,
    required this.closedStrong,
    required this.blink,
    required this.evidence,
    required this.eyeUsed,
    required this.widthDifference,
  });
}

class DrowsinessFrameResult {
  final double earLeft;
  final double earRight;
  final EyeAnalysis eyes;
  final double mar;
  final bool mouthOpen;
  final double yaw;
  final bool poseDifficult;
  final double perclos;
  final double eyeClosureDuration;
  final int blinksPerMinute;
  final int yawnsPerMinute;
  final double score;
  final DrowsinessStatus status;

  const DrowsinessFrameResult({
    required this.earLeft,
    required this.earRight,
    required this.eyes,
    required this.mar,
    required this.mouthOpen,
    required this.yaw,
    required this.poseDifficult,
    required this.perclos,
    required this.eyeClosureDuration,
    required this.blinksPerMinute,
    required this.yawnsPerMinute,
    required this.score,
    required this.status,
  });
}

class _EyeSample {
  final DateTime timestamp;
  final bool closed;
  const _EyeSample(this.timestamp, this.closed);
}

class DrowsinessDetector {
  // ----------------------------------------------------------
  // LIMIARES DE OLHO
  // ----------------------------------------------------------
  static const double earClosed = 0.20;
  static const double earStrongClosed = 0.17;
  static const double blinkThreshold = 0.50;
  static const double blinkStrong = 0.70;

  // ----------------------------------------------------------
  // LIMIARES DE SONOLÊNCIA
  // ----------------------------------------------------------
  static const double prolongedClosureSeconds = 1.0;
  static const double criticalClosureSeconds = 2.0;
  static const double perclosWindowSeconds = 30.0;
  static const double perclosAttention = 0.15;
  static const double perclosAlert = 0.30;
  static const int highBlinkRate = 25;

  static const double scoreAtencaoThreshold = 30.0;
  static const double scoreAlertaThreshold = 60.0;

  // ----------------------------------------------------------
  // MAR / BOCEJO
  // ----------------------------------------------------------
  static const double marThreshold = 0.60;
  static const double yawnMinSeconds = 0.8;

  // ----------------------------------------------------------
  // POSE
  // ----------------------------------------------------------
  static const double eyeWidthDifferenceThreshold = 0.35;
  static const double yawPoseDifficult = 0.55;

  // ----------------------------------------------------------
  // LANDMARKS (MediaPipe Face Mesh, 468 pontos)
  // ----------------------------------------------------------
  static const List<int> leftEyeIndices = [362, 385, 387, 263, 373, 380];
  static const List<int> rightEyeIndices = [33, 160, 158, 133, 153, 144];
  static const List<int> mouthIndices = [78, 81, 13, 311, 308, 402, 14, 178];
  static const int noseYawIndex = 1;
  static const int leftEyeCornerYawIndex = 263;
  static const int rightEyeCornerYawIndex = 33;

  // ----------------------------------------------------------
  // ESTADO / HISTÓRICO TEMPORAL
  // ----------------------------------------------------------
  final Queue<_EyeSample> _eyeSamples = Queue();
  final Queue<DateTime> _blinkTimes = Queue();
  final Queue<DateTime> _yawnTimes = Queue();

  DateTime? _eyeClosedSince;
  DateTime? _mouthOpenSince;
  bool _lastEyeClosed = false;

  DateTime? _lastFrameTime;
  double _smoothClosureDuration = 0.0;
  
  // Nova variável para o Alívio de Atenção (destravamento do score)
  double _continuousOpenDuration = 0.0;

  /// Limpa todo o histórico temporal.
  void reset() {
    _eyeSamples.clear();
    _blinkTimes.clear();
    _yawnTimes.clear();
    _eyeClosedSince = null;
    _mouthOpenSince = null;
    _lastEyeClosed = false;
    _lastFrameTime = null;
    _smoothClosureDuration = 0.0;
    _continuousOpenDuration = 0.0;
  }

  // ----------------------------------------------------------
  // GEOMETRIA
  // ----------------------------------------------------------
  static double _distance(double x1, double y1, double x2, double y2) {
    final dx = x1 - x2;
    final dy = y1 - y2;
    return math.sqrt(dx * dx + dy * dy);
  }

  static (double, double) _calculateEar(
    List<double> xs,
    List<double> ys,
    List<int> indices,
  ) {
    final p = indices.map((i) => (xs[i], ys[i])).toList();
    final vertical1 = _distance(p[1].$1, p[1].$2, p[5].$1, p[5].$2);
    final vertical2 = _distance(p[2].$1, p[2].$2, p[4].$1, p[4].$2);
    final horizontal = _distance(p[0].$1, p[0].$2, p[3].$1, p[3].$2);
    if (horizontal <= 0) return (0.0, 0.0);
    final ear = (vertical1 + vertical2) / (2.0 * horizontal);
    return (ear, horizontal);
  }

  static double _calculateMar(List<double> xs, List<double> ys) {
    final p = mouthIndices.map((i) => (xs[i], ys[i])).toList();
    final horizontal = _distance(p[0].$1, p[0].$2, p[3].$1, p[3].$2);
    if (horizontal <= 0) return 0.0;
    final vertical1 = _distance(p[1].$1, p[1].$2, p[7].$1, p[7].$2);
    final vertical2 = _distance(p[2].$1, p[2].$2, p[6].$1, p[6].$2);
    final vertical3 = _distance(p[4].$1, p[4].$2, p[5].$1, p[5].$2);
    return (vertical1 + vertical2 + vertical3) / (3.0 * horizontal);
  }

  static double _calculateYaw(List<double> xs, List<double> ys) {
    final noseX = xs[noseYawIndex];
    final leftX = xs[leftEyeCornerYawIndex];
    final rightX = xs[rightEyeCornerYawIndex];
    final xMin = math.min(leftX, rightX);
    final xMax = math.max(leftX, rightX);
    final eyesWidth = xMax - xMin;
    if (eyesWidth <= 0) return 0.0;
    final center = (xMin + xMax) / 2.0;
    return (noseX - center) / eyesWidth;
  }

  // ----------------------------------------------------------
  // ANÁLISE DOS OLHOS
  // ----------------------------------------------------------
  static EyeAnalysis _analyzeEyes({
    required double earLeft,
    required double earRight,
    required double widthLeft,
    required double widthRight,
    double? blinkLeft,
    double? blinkRight,
  }) {
    final safeWidthLeft = widthLeft <= 0 ? 1.0 : widthLeft;
    final safeWidthRight = widthRight <= 0 ? 1.0 : widthRight;

    final difference = (safeWidthLeft - safeWidthRight).abs() /
        math.max(safeWidthLeft, safeWidthRight);

    double ear;
    String eyeUsed;
    double blink;

    if (difference > eyeWidthDifferenceThreshold) {
      if (safeWidthLeft >= safeWidthRight) {
        ear = earLeft;
        eyeUsed = 'ESQ';
        blink = blinkLeft ?? 0.0;
      } else {
        ear = earRight;
        eyeUsed = 'DIR';
        blink = blinkRight ?? 0.0;
      }
    } else {
      ear = (earLeft + earRight) / 2.0;
      eyeUsed = 'MEDIO';
      blink = math.max(blinkLeft ?? 0.0, blinkRight ?? 0.0);
    }

    final closedByEar = ear < earClosed;
    final closedStrong = ear < earStrongClosed;
    final blinkDetected = blink >= blinkThreshold;
    final blinkStrongDetected = blink >= blinkStrong;

    bool closed;
    EyeEvidence evidence;

    if (closedStrong) {
      closed = true;
      evidence = EyeEvidence.earStrong;
    } else if (closedByEar && blinkDetected) {
      closed = true;
      evidence = EyeEvidence.earPlusBlink;
    } else if (blinkStrongDetected) {
      closed = true;
      evidence = EyeEvidence.blink;
    } else {
      closed = false;
      evidence = EyeEvidence.open;
    }

    return EyeAnalysis(
      ear: ear,
      closed: closed,
      closedStrong: closedStrong,
      blink: blink,
      evidence: evidence,
      eyeUsed: eyeUsed,
      widthDifference: difference,
    );
  }

  // ----------------------------------------------------------
  // PERCLOS PONDERADO POR TEMPO
  // ----------------------------------------------------------
  double _calculatePerclos() {
    if (_eyeSamples.length < 2) return 0.0;

    double closedSeconds = 0.0;
    double totalSeconds = 0.0;
    DateTime? previousTime;
    bool previousClosed = false;

    for (final sample in _eyeSamples) {
      if (previousTime != null) {
        final interval = math.max(
          0.0,
          sample.timestamp.difference(previousTime).inMicroseconds / 1e6,
        );
        totalSeconds += interval;
        if (previousClosed) closedSeconds += interval;
      }
      previousTime = sample.timestamp;
      previousClosed = sample.closed;
    }

    if (totalSeconds <= 0) return 0.0;
    return (closedSeconds / totalSeconds).clamp(0.0, 1.0);
  }

  // ----------------------------------------------------------
  // SCORE DE SONOLÊNCIA
  // ----------------------------------------------------------
  static double _calculateScore({
    required double perclos,
    required double closureDuration,
    required int blinksPerMinute,
    required int yawnsPerMinute,
  }) {
    double score = 0.0;

    // 1. Rampa contínua de PERCLOS
    if (perclos > 0) {
      if (perclos <= perclosAttention) { 
        score += 20.0 * (perclos / perclosAttention); 
      } else if (perclos <= perclosAlert) { 
        final ratio = (perclos - perclosAttention) / (perclosAlert - perclosAttention);
        score += 20.0 + (35.0 * ratio); 
      } else { 
        final ratio = (perclos - perclosAlert) / (1.0 - perclosAlert);
        score += 55.0 + (45.0 * ratio);
      }
    }

    // 2. Rampa contínua de Fechamento Ocular
    if (closureDuration > 0) {
      if (closureDuration <= prolongedClosureSeconds) {
        score += 20.0 * (closureDuration / prolongedClosureSeconds);
      } else if (closureDuration <= criticalClosureSeconds) { 
        final ratio = (closureDuration - prolongedClosureSeconds) / (criticalClosureSeconds - prolongedClosureSeconds);
        score += 20.0 + (20.0 * ratio); 
      } else { 
        final ratio = (closureDuration - criticalClosureSeconds) / (3.0 - criticalClosureSeconds);
        score += 40.0 + (20.0 * ratio); 
      }
    }

    // 3. Frequência de Piscadas
    if (blinksPerMinute >= highBlinkRate) {
      score += 10.0;
    } else if (blinksPerMinute >= 18) {
      score += 5.0;
    }

    // 4. Bocejos
    if (yawnsPerMinute >= 3) {
      score += 15.0;
    } else if (yawnsPerMinute >= 1) {
      score += 7.0;
    }

    return score.clamp(0.0, 100.0);
  }

  static DrowsinessStatus _classify(double score) {
    if (score >= scoreAlertaThreshold) return DrowsinessStatus.alerta;
    if (score >= scoreAtencaoThreshold) return DrowsinessStatus.atencao;
    return DrowsinessStatus.normal;
  }

  // ----------------------------------------------------------
  // PROCESSAMENTO DE UM FRAME
  // ----------------------------------------------------------
  DrowsinessFrameResult processFrame({
    required List<double> xs,
    required List<double> ys,
    required double frameWidth,
    required double frameHeight,
    double? blinkLeft,
    double? blinkRight,
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now();

    final safeWidth = frameWidth > 0 ? frameWidth : 1.0;
    final safeHeight = frameHeight > 0 ? frameHeight : 1.0;
    final scaledXs = [for (final x in xs) x * safeWidth];
    final scaledYs = [for (final y in ys) y * safeHeight];

    final (earLeft, widthLeft) =
        _calculateEar(scaledXs, scaledYs, leftEyeIndices);
    final (earRight, widthRight) =
        _calculateEar(scaledXs, scaledYs, rightEyeIndices);

    final eyes = _analyzeEyes(
      earLeft: earLeft,
      earRight: earRight,
      widthLeft: widthLeft,
      widthRight: widthRight,
      blinkLeft: blinkLeft,
      blinkRight: blinkRight,
    );

    final mar = _calculateMar(scaledXs, scaledYs);
    final yaw = _calculateYaw(scaledXs, scaledYs);
    final mouthOpen = mar >= marThreshold;

    _updateHistory(
      timestamp: timestamp,
      eyeClosed: eyes.closed,
      mouthOpen: mouthOpen,
    );

    double delta = 0.0;
    if (_lastFrameTime != null) {
      delta = math.max(0.0, timestamp.difference(_lastFrameTime!).inMicroseconds / 1e6);
    }
    _lastFrameTime = timestamp;

    if (eyes.closed) {
      _smoothClosureDuration = math.min(3.0, _smoothClosureDuration + delta);
      _continuousOpenDuration = 0.0; 
    } else {
      _smoothClosureDuration = math.max(0.0, _smoothClosureDuration - (delta * 2.0));
      _continuousOpenDuration += delta;
      
      // ALÍVIO DE ATENÇÃO: Desarma o PERCLOS preso.
      // Se ficou >3.5s com o olho aberto continuamente, drena o histórico mais rápido.
      if (_continuousOpenDuration > 3.5 && _eyeSamples.isNotEmpty) {
        // Drena até 10 frames antigos por iteração (faz o score voltar para 0 em ~3 segundos)
        int drops = 10;
        while (drops > 0 && _eyeSamples.isNotEmpty) {
          _eyeSamples.removeFirst();
          drops--;
        }
      }
    }

    final perclos = _calculatePerclos();
    final closureDuration = _smoothClosureDuration;
    final blinksPerMinute = _countRecent(_blinkTimes, timestamp);
    final yawnsPerMinute = _countRecent(_yawnTimes, timestamp);

    final score = _calculateScore(
      perclos: perclos,
      closureDuration: closureDuration,
      blinksPerMinute: blinksPerMinute,
      yawnsPerMinute: yawnsPerMinute,
    );

    return DrowsinessFrameResult(
      earLeft: earLeft,
      earRight: earRight,
      eyes: eyes,
      mar: mar,
      mouthOpen: mouthOpen,
      yaw: yaw,
      poseDifficult: yaw.abs() > yawPoseDifficult,
      perclos: perclos,
      eyeClosureDuration: closureDuration,
      blinksPerMinute: blinksPerMinute,
      yawnsPerMinute: yawnsPerMinute,
      score: score,
      status: _classify(score),
    );
  }

  void _updateHistory({
    required DateTime timestamp,
    required bool eyeClosed,
    required bool mouthOpen,
  }) {
    _eyeSamples.add(_EyeSample(timestamp, eyeClosed));
    final perclosLimit = timestamp.subtract(
      Duration(milliseconds: (perclosWindowSeconds * 1000).round()),
    );
    while (
        _eyeSamples.isNotEmpty && _eyeSamples.first.timestamp.isBefore(perclosLimit)) {
      _eyeSamples.removeFirst();
    }

    if (eyeClosed && !_lastEyeClosed) {
      _eyeClosedSince = timestamp;
    }

    if (!eyeClosed && _lastEyeClosed && _eyeClosedSince != null) {
      final duration =
          timestamp.difference(_eyeClosedSince!).inMicroseconds / 1e6;
      if (duration >= 0.05 && duration < prolongedClosureSeconds) {
        _blinkTimes.add(timestamp);
      }
      _eyeClosedSince = null;
    }
    _lastEyeClosed = eyeClosed;

    if (mouthOpen) {
      _mouthOpenSince ??= timestamp;
    } else if (_mouthOpenSince != null) {
      final duration =
          timestamp.difference(_mouthOpenSince!).inMicroseconds / 1e6;
      if (duration >= yawnMinSeconds) {
        _yawnTimes.add(timestamp);
      }
      _mouthOpenSince = null;
    }

    _trimOld(_blinkTimes, timestamp);
    _trimOld(_yawnTimes, timestamp);
  }

  static void _trimOld(Queue<DateTime> queue, DateTime now) {
    final limit = now.subtract(const Duration(seconds: 60));
    while (queue.isNotEmpty && queue.first.isBefore(limit)) {
      queue.removeFirst();
    }
  }

  static int _countRecent(Queue<DateTime> queue, DateTime now) {
    final limit = now.subtract(const Duration(seconds: 60));
    return queue.where((t) => !t.isBefore(limit)).length;
  }
}

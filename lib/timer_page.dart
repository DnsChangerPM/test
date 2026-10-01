import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'system_cleanup.dart';
import 'theme.dart';

enum TimerMode { stopwatch, countdown }

enum TimerStatus { idle, running, paused, finished }

class TimerPage extends StatefulWidget {
  const TimerPage({
    super.key,
    required this.currentTheme,
    required this.onThemeChanged,
  });

  final AppTheme currentTheme;
  final ValueChanged<AppTheme> onThemeChanged;

  @override
  State<TimerPage> createState() => _TimerPageState();
}

class _TimerPageState extends State<TimerPage> with TickerProviderStateMixin {
  Timer? _ticker;
  final Stopwatch _stopwatch = Stopwatch();

  TimerMode _mode = TimerMode.countdown;
  TimerStatus _status = TimerStatus.idle;

  int _hours = 0;
  int _minutes = 5;
  int _seconds = 0;

  Duration _total = Duration.zero;
  Duration _remaining = Duration.zero;
  DateTime? _endTime;

  bool _deleting = false;

  late final AnimationController _particleController;
  late final List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat();
    _particles = List.generate(70, (_) => _Particle.random());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _particleController.dispose();
    super.dispose();
  }

  AppTheme get _theme => widget.currentTheme;

  Duration get _selectedDuration => Duration(
        hours: _hours,
        minutes: _minutes,
        seconds: _seconds,
      );

  bool get _canEditFields =>
      _mode == TimerMode.countdown &&
      (_status == TimerStatus.idle || _status == TimerStatus.finished);

  bool get _canStart {
    if (_deleting) return false;
    if (_mode == TimerMode.stopwatch) return true;
    if (_status == TimerStatus.running) return true;
    if (_status == TimerStatus.paused) return _remaining > Duration.zero;
    return _selectedDuration > Duration.zero;
  }

  String get _primaryButtonLabel {
    if (_status == TimerStatus.running) return 'Pause';
    if (_status == TimerStatus.paused) return 'Resume';
    if (_status == TimerStatus.finished) return 'Restart';
    return 'Start';
  }

  IconData get _primaryButtonIcon {
    if (_status == TimerStatus.running) return Icons.pause_rounded;
    if (_status == TimerStatus.paused) return Icons.play_arrow_rounded;
    if (_status == TimerStatus.finished) return Icons.replay_rounded;
    return Icons.play_arrow_rounded;
  }

  void _ensureTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 100), _onTick);
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  void _switchMode(TimerMode mode) {
    if (mode == _mode) return;
    _reset();
    setState(() => _mode = mode);
  }

  Future<void> _playFinishSound() async {
    if (!Platform.isWindows) return;
    try {
      await Process.run('powershell', [
        '-c',
        r'(New-Object Media.SoundPlayer "C:\Windows\Media\Windows Notify Calendar.wav").PlaySync();',
      ]);
    } catch (_) {
      try {
        SystemSound.play(SystemSoundType.alert);
      } catch (_) {}
    }
  }

  void _startOrResume() {
    if (!_canStart) return;

    setState(() {
      if (_mode == TimerMode.stopwatch) {
        _stopwatch.start();
        _status = TimerStatus.running;
        _ensureTicker();
        return;
      }

      if (_status == TimerStatus.idle || _status == TimerStatus.finished) {
        _total = _selectedDuration;
        _remaining = _total;
      }

      if (_remaining <= Duration.zero) return;

      _endTime = DateTime.now().add(_remaining);
      _status = TimerStatus.running;
      _ensureTicker();
    });
  }

  void _pause() {
    if (_status != TimerStatus.running) return;

    _stopTicker();

    setState(() {
      if (_mode == TimerMode.stopwatch) {
        _stopwatch.stop();
      } else {
        if (_endTime != null) {
          final now = DateTime.now();
          _remaining = _endTime!.difference(now);
          if (_remaining < Duration.zero) _remaining = Duration.zero;
        }
        _endTime = null;
      }
      _status = TimerStatus.paused;
    });
  }

  void _reset() {
    _stopTicker();
    _stopwatch
      ..reset()
      ..stop();

    setState(() {
      _status = TimerStatus.idle;
      _endTime = null;
      _total = Duration.zero;
      _remaining = Duration.zero;
    });
  }

  Duration _clampDuration(Duration value) {
    const max = Duration(hours: 23, minutes: 59, seconds: 59);
    if (value < Duration.zero) return Duration.zero;
    if (value > max) return max;
    return value;
  }

  void _setSelected(Duration value) {
    final clamped = _clampDuration(value);
    setState(() {
      _hours = clamped.inHours;
      _minutes = clamped.inMinutes.remainder(60);
      _seconds = clamped.inSeconds.remainder(60);
    });
  }

  void _addTime(Duration delta) {
    if (_mode != TimerMode.countdown || _deleting) return;

    setState(() {
      if (_status == TimerStatus.running && _endTime != null) {
        _endTime = _endTime!.add(delta);
        _total += delta;
        _remaining = _endTime!.difference(DateTime.now());
        if (_remaining < Duration.zero) _remaining = Duration.zero;
      } else if (_status == TimerStatus.paused) {
        _remaining += delta;
        _total += delta;
        if (_remaining < Duration.zero) _remaining = Duration.zero;
      } else {
        final clamped = _clampDuration(_selectedDuration + delta);
        _hours = clamped.inHours;
        _minutes = clamped.inMinutes.remainder(60);
        _seconds = clamped.inSeconds.remainder(60);
      }
    });
  }

  void _onTick(Timer timer) {
    if (!mounted) return;

    if (_mode == TimerMode.countdown &&
        _status == TimerStatus.running &&
        _endTime != null) {
      final remaining = _endTime!.difference(DateTime.now());

      setState(() {
        if (remaining <= Duration.zero) {
          _remaining = Duration.zero;
          _status = TimerStatus.finished;
          _endTime = null;
          _stopTicker();
          _playFinishSound();
        } else {
          _remaining = remaining;
        }
      });
      return;
    }

    if (_mode == TimerMode.stopwatch && _status == TimerStatus.running) {
      setState(() {});
    }
  }

  Duration get _display {
    if (_mode == TimerMode.stopwatch) return _stopwatch.elapsed;
    if (_status == TimerStatus.idle) return _selectedDuration;
    if (_status == TimerStatus.finished) return Duration.zero;
    return _remaining;
  }

  double get _progress {
    if (_mode != TimerMode.countdown) return 0;
    if (_status == TimerStatus.idle) {
      return _selectedDuration > Duration.zero ? 1 : 0;
    }
    if (_status == TimerStatus.finished) return 0;
    if (_total <= Duration.zero) return 0;
    return (_remaining.inMilliseconds / _total.inMilliseconds).clamp(0.0, 1.0);
  }

  Future<bool?> _showDeleteConfirmDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _theme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: _theme.danger.withAlpha(80)),
        ),
        title: Text(
          'Delete app completely',
          style: TextStyle(color: _theme.danger),
        ),
        content: const Text(
          'This closes the app and removes all files/data from this Windows user profile. '
          'If installed, it runs the uninstaller silently.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _theme.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCompletely() async {
    final confirmed = await _showDeleteConfirmDialog();
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);

    try {
      await SystemCleanup.deleteCompletely();
    } catch (e) {
      if (mounted) {
        setState(() => _deleting = false);
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: _theme.surface,
            title: const Text('Error'),
            content: Text(e.toString()),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = _theme;
    final display = _display;
    final isRunning = _status == TimerStatus.running;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          _AnimatedBackground(
            controller: _particleController,
            particles: _particles,
            theme: theme,
          ),
          SafeArea(
            child: Column(
              children: [
                _AppBar(
                  theme: theme,
                  onDelete: _deleting ? null : _deleteCompletely,
                ),
                _ThemeSwitcher(
                  themes: appThemes,
                  current: theme,
                  onChanged: widget.onThemeChanged,
                )
                    .animate()
                    .fadeIn(duration: 600.ms, delay: 100.ms)
                    .slideY(begin: -0.2, end: 0),
                const SizedBox(height: 4),
                _ModeSelector(
                  mode: _mode,
                  onChanged: _switchMode,
                  theme: theme,
                ).animate().fadeIn(duration: 600.ms, delay: 200.ms),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 820),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 12),
                            _FlipClock(
                              duration: display,
                              theme: theme,
                              isFinished: _status == TimerStatus.finished,
                            )
                                .animate()
                                .fadeIn(duration: 800.ms, delay: 300.ms)
                                .scale(begin: const Offset(0.9, 0.9)),
                            const SizedBox(height: 32),
                            _GlowingRing(
                              progress: _progress,
                              theme: theme,
                              mode: _mode,
                              child: _StatusIndicator(
                                status: _status,
                                mode: _mode,
                                theme: theme,
                              ),
                            )
                                .animate()
                                .fadeIn(duration: 800.ms, delay: 400.ms)
                                .scale(begin: const Offset(0.9, 0.9)),
                            const SizedBox(height: 32),
                            _ControlButtons(
                              theme: theme,
                              isRunning: isRunning,
                              canStart: _canStart,
                              deleting: _deleting,
                              primaryLabel: _primaryButtonLabel,
                              primaryIcon: _primaryButtonIcon,
                              onPrimary:
                                  isRunning ? _pause : _startOrResume,
                              onReset: _reset,
                            )
                                .animate()
                                .fadeIn(duration: 600.ms, delay: 500.ms)
                                .slideY(begin: 0.3, end: 0),
                            const SizedBox(height: 24),
                            if (_mode == TimerMode.countdown) ...[
                              _TimeInputsPanel(
                                hours: _hours,
                                minutes: _minutes,
                                seconds: _seconds,
                                enabled: _canEditFields,
                                theme: theme,
                                onChanged: (h, m, s) => _setSelected(
                                  Duration(hours: h, minutes: m, seconds: s),
                                ),
                              )
                                  .animate()
                                  .fadeIn(duration: 600.ms, delay: 600.ms)
                                  .slideY(begin: 0.3, end: 0),
                              const SizedBox(height: 16),
                              _PresetChips(
                                theme: theme,
                                enabled:
                                    _mode == TimerMode.countdown && !_deleting,
                                onAddTime: _addTime,
                              )
                                  .animate()
                                  .fadeIn(duration: 600.ms, delay: 700.ms)
                                  .slideY(begin: 0.3, end: 0),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_deleting)
            Container(
              color: Colors.black.withAlpha(180),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: theme.primary)
                        .animate()
                        .shimmer(color: theme.primary),
                    const SizedBox(height: 16),
                    Text(
                      'Uninstalling...',
                      style: TextStyle(color: theme.onSurface),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ========================== Particles ==========================

class _Particle {
  Offset position;
  Offset velocity;
  double size;
  double baseOpacity;

  _Particle({
    required this.position,
    required this.velocity,
    required this.size,
    required this.baseOpacity,
  });

  factory _Particle.random() {
    final random = math.Random();
    return _Particle(
      position: Offset(
        random.nextDouble() * 2000,
        random.nextDouble() * 2000,
      ),
      velocity: Offset(
        (random.nextDouble() - 0.5) * 0.4,
        (random.nextDouble() - 0.5) * 0.4,
      ),
      size: random.nextDouble() * 2.5 + 0.8,
      baseOpacity: random.nextDouble() * 0.5 + 0.2,
    );
  }
}

class _AnimatedBackground extends StatelessWidget {
  const _AnimatedBackground({
    required this.controller,
    required this.particles,
    required this.theme,
  });

  final AnimationController controller;
  final List<_Particle> particles;
  final AppTheme theme;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [theme.bgTop, theme.bgBottom],
            ),
          ),
        ),
        ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            return CustomPaint(
              size: MediaQuery.of(context).size,
              painter: _ParticlePainter(
                particles: particles,
                theme: theme,
                time: controller.value,
              ),
            );
          },
        ),
        IgnorePointer(
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.2,
                colors: [
                  theme.primary.withAlpha(20),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ParticlePainter extends CustomPainter {
  _ParticlePainter({
    required this.particles,
    required this.theme,
    required this.time,
  });

  final List<_Particle> particles;
  final AppTheme theme;
  final double time;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final glowPaint = Paint()..style = PaintingStyle.fill;

    for (final particle in particles) {
      particle.position += particle.velocity;

      if (particle.position.dx < 0 || particle.position.dx > size.width) {
        particle.velocity = Offset(-particle.velocity.dx, particle.velocity.dy);
        particle.position = Offset(
          particle.position.dx.clamp(0.0, size.width),
          particle.position.dy,
        );
      }
      if (particle.position.dy < 0 || particle.position.dy > size.height) {
        particle.velocity = Offset(particle.velocity.dx, -particle.velocity.dy);
        particle.position = Offset(
          particle.position.dx,
          particle.position.dy.clamp(0.0, size.height),
        );
      }

      final pulse =
          (math.sin(time * math.pi * 2 + particle.position.dx * 0.005) + 1) /
              2;
      final opacity = particle.baseOpacity * (0.6 + pulse * 0.4);

      paint.color = theme.primary.withAlpha((opacity * 255).round());
      canvas.drawCircle(particle.position, particle.size, paint);

      glowPaint.color = theme.primary.withAlpha((opacity * 80).round());
      canvas.drawCircle(particle.position, particle.size * 3, glowPaint);
    }

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;

    for (int i = 0; i < particles.length; i++) {
      for (int j = i + 1; j < particles.length; j++) {
        final distance =
            (particles[i].position - particles[j].position).distance;
        if (distance < 130) {
          final alpha = ((1 - distance / 130) * 40).round();
          linePaint.color = theme.primary.withAlpha(alpha);
          canvas.drawLine(
            particles[i].position,
            particles[j].position,
            linePaint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) => true;
}

// ========================== App Bar ==========================

class _AppBar extends StatelessWidget {
  const _AppBar({
    required this.theme,
    required this.onDelete,
  });

  final AppTheme theme;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.primary.withAlpha(50),
                  theme.secondary.withAlpha(50),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.primary.withAlpha(80)),
              boxShadow: [
                BoxShadow(
                  color: theme.primary.withAlpha(40),
                  blurRadius: 12,
                ),
              ],
            ),
            child: Icon(Icons.timer_outlined, color: theme.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Advanced Timer',
                  style: TextStyle(
                    color: theme.onSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
                Text(
                  'PRO EDITION',
                  style: TextStyle(
                    color: theme.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.8,
                  ),
                ),
              ],
            ),
          ),
          _IconCircleButton(
            icon: Icons.delete_forever_rounded,
            color: theme.danger,
            tooltip: 'Delete completely from system',
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _IconCircleButton extends StatefulWidget {
  const _IconCircleButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  State<_IconCircleButton> createState() => _IconCircleButtonState();
}

class _IconCircleButtonState extends State<_IconCircleButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onPressed == null;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Tooltip(
        message: widget.tooltip,
        child: GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: disabled
                  ? Colors.grey.withAlpha(30)
                  : (widget.color.withAlpha(_hovered ? 60 : 30)),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: disabled
                    ? Colors.grey.withAlpha(40)
                    : (widget.color.withAlpha(_hovered ? 180 : 80)),
              ),
            ),
            child: Icon(
              widget.icon,
              color: disabled
                  ? Colors.grey
                  : (widget.color.withAlpha(_hovered ? 255 : 200)),
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}

// ========================== Theme Switcher ==========================

class _ThemeSwitcher extends StatelessWidget {
  const _ThemeSwitcher({
    required this.themes,
    required this.current,
    required this.onChanged,
  });

  final List<AppTheme> themes;
  final AppTheme current;
  final ValueChanged<AppTheme> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: themes.map((theme) {
          final isSelected = theme.name == current.name;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: InkWell(
              onTap: () => onChanged(theme),
              borderRadius: BorderRadius.circular(20),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: isSelected ? theme.primaryGradient : null,
                  color: isSelected ? null : Colors.black.withAlpha(60),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? Colors.transparent
                        : Colors.white.withAlpha(30),
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: theme.primary.withAlpha(100),
                            blurRadius: 16,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      theme.icon,
                      size: 16,
                      color: isSelected
                          ? Colors.white
                          : Colors.white.withAlpha(180),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      theme.name,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : Colors.white.withAlpha(200),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ========================== Mode Selector ==========================

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({
    required this.mode,
    required this.onChanged,
    required this.theme,
  });

  final TimerMode mode;
  final ValueChanged<TimerMode> onChanged;
  final AppTheme theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(60),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ModeButton(
            label: 'Countdown',
            icon: Icons.timer_outlined,
            isSelected: mode == TimerMode.countdown,
            theme: theme,
            onTap: () => onChanged(TimerMode.countdown),
          ),
          const SizedBox(width: 4),
          _ModeButton(
            label: 'Stopwatch',
            icon: Icons.hourglass_bottom_outlined,
            isSelected: mode == TimerMode.stopwatch,
            theme: theme,
            onTap: () => onChanged(TimerMode.stopwatch),
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatefulWidget {
  const _ModeButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.theme,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final AppTheme theme;
  final VoidCallback onTap;

  @override
  State<_ModeButton> createState() => _ModeButtonState();
}

class _ModeButtonState extends State<_ModeButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            gradient: widget.isSelected ? widget.theme.primaryGradient : null,
            color: widget.isSelected
                ? null
                : (_hovered
                    ? Colors.white.withAlpha(20)
                    : Colors.transparent),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 18,
                color: widget.isSelected
                    ? Colors.white
                    : Colors.white.withAlpha(180),
              ),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: TextStyle(
                  color: widget.isSelected
                      ? Colors.white
                      : Colors.white.withAlpha(200),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ========================== Flip Clock ==========================

class _FlipClock extends StatelessWidget {
  const _FlipClock({
    required this.duration,
    required this.theme,
    required this.isFinished,
  });

  final Duration duration;
  final AppTheme theme;
  final bool isFinished;

  String _two(int value) => value.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final h = duration.inHours;
    final m = duration.inMinutes.remainder(60);
    final s = duration.inSeconds.remainder(60);

    final parts = <Widget>[];
    if (h > 0) {
      parts.add(_DigitGroup(
        digit1: _two(h)[0],
        digit2: _two(h)[1],
        theme: theme,
      ));
      parts.add(_Separator(theme: theme));
    }
    parts.add(_DigitGroup(
      digit1: _two(m)[0],
      digit2: _two(m)[1],
      theme: theme,
    ));
    parts.add(_Separator(theme: theme));
    parts.add(_DigitGroup(
      digit1: _two(s)[0],
      digit2: _two(s)[1],
      theme: theme,
    ));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(80),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isFinished
              ? theme.danger.withAlpha(120)
              : theme.primary.withAlpha(60),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isFinished
                ? theme.danger.withAlpha(80)
                : theme.primary.withAlpha(40),
            blurRadius: 40,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: parts),
    )
        .animate(onPlay: (c) => c.repeat())
        .shimmer(
          duration: 2500.ms,
          color: isFinished ? theme.danger : theme.primary,
          size: 0.25,
        );
  }
}

class _DigitGroup extends StatelessWidget {
  const _DigitGroup({
    required this.digit1,
    required this.digit2,
    required this.theme,
  });

  final String digit1;
  final String digit2;
  final AppTheme theme;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _FlipDigit(digit: digit1, theme: theme),
        _FlipDigit(digit: digit2, theme: theme),
      ],
    );
  }
}

class _FlipDigit extends StatelessWidget {
  const _FlipDigit({
    required this.digit,
    required this.theme,
  });

  final String digit;
  final AppTheme theme;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -0.8),
            end: Offset.zero,
          ).animate(animation),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      child: Text(
        digit,
        key: ValueKey(digit),
        style: TextStyle(
          fontFamily: 'Consolas',
          fontSize: 76,
          fontWeight: FontWeight.w200,
          color: theme.onSurface,
          height: 1,
          shadows: [
            Shadow(color: theme.primary.withAlpha(150), blurRadius: 24),
            Shadow(color: theme.primary.withAlpha(80), blurRadius: 48),
          ],
        ),
      ),
    );
  }
}

class _Separator extends StatelessWidget {
  const _Separator({required this.theme});

  final AppTheme theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        ':',
        style: TextStyle(
          fontFamily: 'Consolas',
          fontSize: 76,
          fontWeight: FontWeight.w200,
          color: theme.primary.withAlpha(160),
          height: 1,
          shadows: [
            Shadow(color: theme.primary.withAlpha(120), blurRadius: 16),
          ],
        ),
      ).animate(onPlay: (c) => c.repeat(reverse: true)).fadeIn(duration: 800.ms),
    );
  }
}

// ========================== Glowing Ring ==========================

class _GlowingRing extends StatelessWidget {
  const _GlowingRing({
    required this.progress,
    required this.theme,
    required this.mode,
    required this.child,
  });

  final double progress;
  final AppTheme theme;
  final TimerMode mode;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      height: 260,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(260, 260),
            painter: _RingGlowPainter(
              progress: progress,
              theme: theme,
              mode: mode,
            ),
          ),
          CustomPaint(
            size: const Size(260, 260),
            painter: _RingPainter(
              progress: progress,
              theme: theme,
              mode: mode,
            ),
          ),
          SizedBox(width: 180, height: 180, child: child),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.theme,
    required this.mode,
  });

  final double progress;
  final AppTheme theme;
  final TimerMode mode;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 20;

    final bgPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..color = Colors.white.withAlpha(30)
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    if (mode == TimerMode.countdown) {
      final rect = Rect.fromCircle(center: center, radius: radius);
      final shader = ui.Gradient.sweep(
        center,
        [theme.primary, theme.secondary, theme.primary],
      );
      final fgPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round
        ..shader = shader;

      canvas.drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * progress.clamp(0.0, 1.0),
        false,
        fgPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.theme != theme ||
      oldDelegate.mode != mode;
}

class _RingGlowPainter extends CustomPainter {
  _RingGlowPainter({
    required this.progress,
    required this.theme,
    required this.mode,
  });

  final double progress;
  final AppTheme theme;
  final TimerMode mode;

  @override
  void paint(Canvas canvas, Size size) {
    if (mode != TimerMode.countdown) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 20;
    final rect = Rect.fromCircle(center: center, radius: radius);

    for (int i = 1; i <= 3; i++) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8.0 + i * 4
        ..strokeCap = StrokeCap.round
        ..color = theme.primary.withAlpha((60 / i).round())
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, i * 8.0);

      canvas.drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * progress.clamp(0.0, 1.0),
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingGlowPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.theme != theme ||
      oldDelegate.mode != mode;
}

class _StatusIndicator extends StatelessWidget {
  const _StatusIndicator({
    required this.status,
    required this.mode,
    required this.theme,
  });

  final TimerStatus status;
  final TimerMode mode;
  final AppTheme theme;

  @override
  Widget build(BuildContext context) {
    String label;
    IconData icon;
    Color color;

    if (mode == TimerMode.stopwatch) {
      label = 'STOPWATCH';
      icon = Icons.hourglass_bottom_rounded;
      color = theme.primary;
    } else if (status == TimerStatus.finished) {
      label = 'TIME UP!';
      icon = Icons.check_circle_rounded;
      color = theme.danger;
    } else if (status == TimerStatus.running) {
      label = 'RUNNING';
      icon = Icons.play_circle_rounded;
      color = theme.primary;
    } else if (status == TimerStatus.paused) {
      label = 'PAUSED';
      icon = Icons.pause_circle_rounded;
      color = theme.secondary;
    } else {
      label = 'READY';
      icon = Icons.circle_outlined;
      color = theme.onSurfaceMuted;
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 48)
            .animate(onPlay: (c) => c.repeat())
            .shimmer(duration: 1500.ms, color: color, size: 0.5),
        const SizedBox(height: 10),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.5,
            shadows: [
              Shadow(color: color.withAlpha(120), blurRadius: 8),
            ],
          ),
        ),
      ],
    );
  }
}

// ========================== Control Buttons ==========================

class _ControlButtons extends StatelessWidget {
  const _ControlButtons({
    required this.theme,
    required this.isRunning,
    required this.canStart,
    required this.deleting,
    required this.primaryLabel,
    required this.primaryIcon,
    required this.onPrimary,
    required this.onReset,
  });

  final AppTheme theme;
  final bool isRunning;
  final bool canStart;
  final bool deleting;
  final String primaryLabel;
  final IconData primaryIcon;
  final VoidCallback? onPrimary;
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _GlassButton(
          label: primaryLabel,
          icon: primaryIcon,
          gradient: theme.primaryGradient,
          isPrimary: true,
          onPressed: onPrimary,
          theme: theme,
        ),
        const SizedBox(width: 16),
        _GlassButton(
          label: 'Reset',
          icon: Icons.refresh_rounded,
          gradient: LinearGradient(
            colors: [theme.surfaceVariant, theme.surface],
          ),
          isPrimary: false,
          onPressed: deleting ? null : onReset,
          theme: theme,
        ),
      ],
    );
  }
}

class _GlassButton extends StatefulWidget {
  const _GlassButton({
    required this.label,
    required this.icon,
    required this.gradient,
    required this.isPrimary,
    required this.onPressed,
    required this.theme,
  });

  final String label;
  final IconData icon;
  final Gradient gradient;
  final bool isPrimary;
  final VoidCallback? onPressed;
  final AppTheme theme;

  @override
  State<_GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<_GlassButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.onPressed == null;
    final primaryColor = (widget.gradient as LinearGradient).colors.first;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          transform: _isHovered && !isDisabled
              ? Matrix4.translationValues(0.0, -2.0, 0.0)
              : Matrix4.identity(),
          decoration: BoxDecoration(
            gradient: isDisabled ? null : widget.gradient,
            color: isDisabled ? Colors.grey.withAlpha(60) : null,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDisabled
                  ? Colors.transparent
                  : Colors.white.withAlpha(
                      widget.isPrimary
                          ? (_isHovered ? 120 : 60)
                          : (_isHovered ? 60 : 30),
                    ),
              width: 1.5,
            ),
            boxShadow: isDisabled
                ? null
                : [
                    if (widget.isPrimary)
                      BoxShadow(
                        color: primaryColor.withAlpha(
                          _isHovered ? 140 : 80,
                        ),
                        blurRadius: _isHovered ? 24 : 16,
                        spreadRadius: _isHovered ? 2 : 0,
                      ),
                  ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 20,
                color: isDisabled ? Colors.grey : Colors.white,
              ),
              const SizedBox(width: 10),
              Text(
                widget.label,
                style: TextStyle(
                  color: isDisabled ? Colors.grey : Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ========================== Time Inputs ==========================

class _TimeInputsPanel extends StatelessWidget {
  const _TimeInputsPanel({
    required this.hours,
    required this.minutes,
    required this.seconds,
    required this.enabled,
    required this.theme,
    required this.onChanged,
  });

  final int hours;
  final int minutes;
  final int seconds;
  final bool enabled;
  final AppTheme theme;
  final void Function(int hours, int minutes, int seconds) onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(60),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha(30)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _TimeDropdown(
            label: 'HOURS',
            value: hours,
            items: List<int>.generate(24, (i) => i),
            enabled: enabled,
            theme: theme,
            onChanged: (v) => onChanged(v ?? hours, minutes, seconds),
          ),
          const SizedBox(width: 16),
          _TimeDropdown(
            label: 'MINUTES',
            value: minutes,
            items: List<int>.generate(60, (i) => i),
            enabled: enabled,
            theme: theme,
            onChanged: (v) => onChanged(hours, v ?? minutes, seconds),
          ),
          const SizedBox(width: 16),
          _TimeDropdown(
            label: 'SECONDS',
            value: seconds,
            items: List<int>.generate(60, (i) => i),
            enabled: enabled,
            theme: theme,
            onChanged: (v) => onChanged(hours, minutes, v ?? seconds),
          ),
        ],
      ),
    );
  }
}

class _TimeDropdown extends StatelessWidget {
  const _TimeDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.enabled,
    required this.theme,
    required this.onChanged,
  });

  final String label;
  final int value;
  final List<int> items;
  final bool enabled;
  final AppTheme theme;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: theme.onSurfaceMuted,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.8,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(80),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: enabled
                  ? theme.primary.withAlpha(80)
                  : Colors.white.withAlpha(30),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: value,
              isDense: true,
              dropdownColor: theme.surface,
              icon: Icon(
                Icons.arrow_drop_down_rounded,
                color: enabled ? theme.primary : theme.onSurfaceMuted,
              ),
              style: TextStyle(
                color: enabled ? theme.onSurface : theme.onSurfaceMuted,
                fontSize: 20,
                fontWeight: FontWeight.w600,
                fontFamily: 'Consolas',
              ),
              items: items
                  .map(
                    (e) => DropdownMenuItem<int>(
                      value: e,
                      child: Text(e.toString().padLeft(2, '0')),
                    ),
                  )
                  .toList(),
              onChanged: enabled ? onChanged : null,
            ),
          ),
        ),
      ],
    );
  }
}

// ========================== Preset Chips ==========================

class _PresetChips extends StatelessWidget {
  const _PresetChips({
    required this.theme,
    required this.enabled,
    required this.onAddTime,
  });

  final AppTheme theme;
  final bool enabled;
  final void Function(Duration delta) onAddTime;

  @override
  Widget build(BuildContext context) {
    const presets = [
      _Preset('+10s', Duration(seconds: 10)),
      _Preset('+1m', Duration(minutes: 1)),
      _Preset('+5m', Duration(minutes: 5)),
      _Preset('+10m', Duration(minutes: 10)),
      _Preset('+30m', Duration(minutes: 30)),
      _Preset('+1h', Duration(hours: 1)),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: presets
          .map(
            (p) => _PresetChip(
              label: p.label,
              delta: p.delta,
              theme: theme,
              enabled: enabled,
              onTap: () => onAddTime(p.delta),
            ),
          )
          .toList(),
    );
  }
}

class _Preset {
  const _Preset(this.label, this.delta);
  final String label;
  final Duration delta;
}

class _PresetChip extends StatefulWidget {
  const _PresetChip({
    required this.label,
    required this.delta,
    required this.theme,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final Duration delta;
  final AppTheme theme;
  final bool enabled;
  final VoidCallback onTap;

  @override
  State<_PresetChip> createState() => _PresetChipState();
}

class _PresetChipState extends State<_PresetChip> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.enabled ? widget.onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: widget.enabled
                ? (_isHovered
                    ? widget.theme.primary.withAlpha(80)
                    : Colors.black.withAlpha(60))
                : Colors.grey.withAlpha(40),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.enabled
                  ? (_isHovered
                      ? widget.theme.primary
                      : widget.theme.primary.withAlpha(80))
                  : Colors.grey.withAlpha(40),
            ),
            boxShadow: widget.enabled && _isHovered
                ? [
                    BoxShadow(
                      color: widget.theme.primary.withAlpha(60),
                      blurRadius: 10,
                    ),
                  ]
                : null,
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color: widget.enabled
                  ? (_isHovered ? Colors.white : widget.theme.onSurface)
                  : Colors.grey,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

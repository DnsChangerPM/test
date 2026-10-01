import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

void main() => runApp(const AdvancedTimerApp());

class AdvancedTimerApp extends StatelessWidget {
  const AdvancedTimerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Advanced Timer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4F46E5),
          brightness: Brightness.dark,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      home: const TimerPage(),
    );
  }
}

enum TimerMode { stopwatch, countdown }

enum TimerStatus { idle, running, paused, finished }

class TimerPage extends StatefulWidget {
  const TimerPage({super.key});

  @override
  State<TimerPage> createState() => _TimerPageState();
}

class _TimerPageState extends State<TimerPage> {
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

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

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

    return (_remaining.inMilliseconds / _total.inMilliseconds)
        .clamp(0.0, 1.0);
  }

  String _two(int value) => value.toString().padLeft(2, '0');

  String _format(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);

    if (h > 0) return '${_two(h)}:${_two(m)}:${_two(s)}';
    return '${_two(m)}:${_two(s)}';
  }

  Future<Set<String>> _userDataPaths() async {
    final paths = <String>{};

    void addIfValid(String? path) {
      if (path != null && path.trim().isNotEmpty) paths.add(path);
    }

    final appData = Platform.environment['APPDATA'];
    final localAppData = Platform.environment['LOCALAPPDATA'];

    if (appData != null && appData.trim().isNotEmpty) {
      addIfValid(p.join(appData, 'AdvancedTimer'));
      addIfValid(p.join(appData, 'advanced_timer'));
    }

    if (localAppData != null && localAppData.trim().isNotEmpty) {
      addIfValid(p.join(localAppData, 'AdvancedTimer'));
      addIfValid(p.join(localAppData, 'advanced_timer'));
    }

    try {
      final support = await getApplicationSupportDirectory();
      addIfValid(support.path);
    } catch (_) {}

    return paths;
  }

  bool _isUnder(String child, String? parent) {
    if (parent == null || parent.trim().isEmpty) return false;

    final c = p.normalize(child).toLowerCase();
    final par = p.normalize(parent).toLowerCase();

    return c == par || c.startsWith('$par${p.separator}');
  }

  bool _isProtectedDirectory(String dir) {
    final env = Platform.environment;

    if (p.equals(dir, p.rootPrefix(dir))) return true;

    return _isUnder(dir, env['WINDIR']) ||
        _isUnder(dir, env['SystemRoot']) ||
        _isUnder(dir, env['ProgramFiles']) ||
        _isUnder(dir, env['ProgramFiles(x86)']);
  }

  Future<bool?> _showDeleteConfirmDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete app completely'),
        content: const Text(
          'This closes the app and removes app files/data from this Windows user profile. '
          'If installed, it runs the uninstaller.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
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
      if (kDebugMode) {
        throw StateError(
          'Delete is disabled in debug mode. Build/run release version.',
        );
      }

      if (!Platform.isWindows) {
        throw UnsupportedError('This delete action is Windows-only.');
      }

      final exePath = Platform.resolvedExecutable;
      final exeDir = p.dirname(exePath);
      final uninstaller = File(p.join(exeDir, 'unins000.exe'));
      final dataPaths = await _userDataPaths();

      final batPath = p.join(
        Directory.systemTemp.path,
        'advanced_timer_delete_${DateTime.now().millisecondsSinceEpoch}.bat',
      );

      final lines = <String>[
        '@echo off',
        'chcp 65001 >nul',
        'setlocal',
        'ping 127.0.0.1 -n 3 >nul',
      ];

      if (uninstaller.existsSync()) {
        lines.add(
          'start "" /WAIT "${uninstaller.path}" /VERYSILENT /SUPPRESSMSGBOXES /NORESTART',
        );
        lines.add('if %ERRORLEVEL% NEQ 0 exit /b %ERRORLEVEL%');

        for (final path in dataPaths) {
          lines.add('if exist "$path" rmdir /s /q "$path"');
        }
      } else {
        if (_isProtectedDirectory(exeDir)) {
          throw StateError(
            'Portable delete is blocked in protected/system folders. '
            'Use Windows uninstaller.',
          );
        }

        lines.add('if exist "$exePath" del /f /q "$exePath"');

        for (final path in dataPaths) {
          lines.add('if exist "$path" rmdir /s /q "$path"');
        }

        lines.add('if exist "$exeDir" rmdir /s /q "$exeDir"');
      }

      await File(batPath).writeAsString(lines.join('\r\n'), flush: true);

      await Process.start(
        'cmd.exe',
        ['/c', batPath],
        mode: ProcessStartMode.detached,
      );

      await Future.delayed(const Duration(milliseconds: 350));
      exit(0);
    } catch (e) {
      if (mounted) {
        setState(() => _deleting = false);

        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
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
    final theme = Theme.of(context);
    final display = _display;
    final isRunning = _status == TimerStatus.running;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Advanced Timer'),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.delete_forever,
              color: Colors.redAccent,
            ),
            tooltip: 'Delete completely from system',
            onPressed: _deleting ? null : _deleteCompletely,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            children: [
              const SizedBox(height: 16),
              SegmentedButton<TimerMode>(
                segments: const [
                  ButtonSegment(
                    value: TimerMode.countdown,
                    label: Text('Countdown'),
                    icon: Icon(Icons.timer),
                  ),
                  ButtonSegment(
                    value: TimerMode.stopwatch,
                    label: Text('Stopwatch'),
                    icon: Icon(Icons.hourglass_bottom),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (selection) =>
                    _switchMode(selection.first),
                showSelectedIcon: false,
              ),
              const SizedBox(height: 24),
              if (_mode == TimerMode.countdown) ...[
                _buildTimeInputs(),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    _presetChip('+10s', const Duration(seconds: 10)),
                    _presetChip('+1m', const Duration(minutes: 1)),
                    _presetChip('+5m', const Duration(minutes: 5)),
                    _presetChip('+10m', const Duration(minutes: 10)),
                    _presetChip('+30m', const Duration(minutes: 30)),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (_mode == TimerMode.countdown)
                      SizedBox(
                        width: 300,
                        height: 300,
                        child: CustomPaint(
                          painter: _RingPainter(
                            progress: _progress,
                            color: theme.colorScheme.primary,
                          ),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    Text(
                      _format(display),
                      style: theme.textTheme.displayMedium?.copyWith(
                        fontFamily: 'Consolas',
                      ),
                    ),
                    if (_mode == TimerMode.countdown &&
                        _status == TimerStatus.finished)
                      Positioned(
                        bottom: 18,
                        child: Text(
                          'Time finished',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: isRunning
                        ? _pause
                        : (_canStart ? _startOrResume : null),
                    icon: Icon(
                      isRunning ? Icons.pause : Icons.play_arrow,
                    ),
                    label: Text(_primaryButtonLabel),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _deleting ? null : _reset,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reset'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (_deleting)
                const LinearProgressIndicator()
              else
                const SizedBox(height: 4),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeInputs() {
    final hours = List<int>.generate(24, (i) => i);
    final minutes = List<int>.generate(60, (i) => i);
    final seconds = List<int>.generate(60, (i) => i);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _timeDropdown(
          label: 'Hours',
          value: _hours,
          items: hours,
          enabled: _canEditFields,
          onChanged: (v) => _setSelected(
            Duration(
              hours: v ?? _hours,
              minutes: _minutes,
              seconds: _seconds,
            ),
          ),
        ),
        const SizedBox(width: 8),
        _timeDropdown(
          label: 'Minutes',
          value: _minutes,
          items: minutes,
          enabled: _canEditFields,
          onChanged: (v) => _setSelected(
            Duration(
              hours: _hours,
              minutes: v ?? _minutes,
              seconds: _seconds,
            ),
          ),
        ),
        const SizedBox(width: 8),
        _timeDropdown(
          label: 'Seconds',
          value: _seconds,
          items: seconds,
          enabled: _canEditFields,
          onChanged: (v) => _setSelected(
            Duration(
              hours: _hours,
              minutes: _minutes,
              seconds: v ?? _seconds,
            ),
          ),
        ),
      ],
    );
  }

  Widget _timeDropdown({
    required String label,
    required int value,
    required List<int> items,
    required bool enabled,
    required ValueChanged<int?> onChanged,
  }) {
    return SizedBox(
      width: 120,
      child: DropdownButtonFormField<int>(
        decoration: InputDecoration(labelText: label),
        value: value,
        isExpanded: true,
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
    );
  }

  Widget _presetChip(String label, Duration delta) {
    return ActionChip(
      label: Text(label),
      onPressed:
          _mode == TimerMode.countdown && !_deleting ? () => _addTime(delta) : null,
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.color,
  });

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;

    final bgPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..color = color.withAlpha(38);

    final fgPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..color = color;

    canvas.drawCircle(center, radius, bgPaint);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

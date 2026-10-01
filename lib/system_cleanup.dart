import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class SystemCleanup {
  static Future<Set<String>> userDataPaths() async {
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

  static bool _isUnder(String child, String? parent) {
    if (parent == null || parent.trim().isEmpty) return false;
    final c = p.normalize(child).toLowerCase();
    final par = p.normalize(parent).toLowerCase();
    return c == par || c.startsWith('$par${p.separator}');
  }

  static bool isProtectedDirectory(String dir) {
    final env = Platform.environment;
    if (p.equals(dir, p.rootPrefix(dir))) return true;
    return _isUnder(dir, env['WINDIR']) ||
        _isUnder(dir, env['SystemRoot']) ||
        _isUnder(dir, env['ProgramFiles']) ||
        _isUnder(dir, env['ProgramFiles(x86)']);
  }

  static Future<void> deleteCompletely() async {
    if (kDebugMode) {
      throw StateError('Delete is disabled in debug mode.');
    }
    if (!Platform.isWindows) {
      throw UnsupportedError('This delete action is Windows-only.');
    }

    final exePath = Platform.resolvedExecutable;
    final exeDir = p.dirname(exePath);
    final uninstaller = File(p.join(exeDir, 'unins000.exe'));
    final dataPaths = await userDataPaths();

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
      if (isProtectedDirectory(exeDir)) {
        throw StateError(
          'Portable delete is blocked in protected/system folders.',
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
  }
}

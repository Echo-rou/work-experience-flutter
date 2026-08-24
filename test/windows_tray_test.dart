import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Windows close keeps LAN sync alive in the system tray', () async {
    final window = await File('windows/runner/win32_window.cpp').readAsString();
    final main = await File('windows/runner/main.cpp').readAsString();

    expect(window, contains('case WM_CLOSE:'));
    expect(window, contains('ShowWindow(hwnd, SW_HIDE)'));
    expect(window, contains('Shell_NotifyIconW(NIM_ADD'));
    expect(window, contains('Shell_NotifyIconW(NIM_DELETE'));
    final cmake = await File('windows/runner/CMakeLists.txt').readAsString();
    expect(cmake, contains('"shell32.lib"'));
    expect(window, contains('Exit completely'));
    expect(main, contains('CreateMutexW'));
    expect(main, contains('ERROR_ALREADY_EXISTS'));
    expect(main, contains('FindWindowW'));
  });
}

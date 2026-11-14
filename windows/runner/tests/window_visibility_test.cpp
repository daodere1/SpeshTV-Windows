// Exercises the runner against real Win32 parent/child windows. The standalone
// harness supplies only FlutterDesktopGetDpiForMonitor; visibility is not mocked.
#include "../win32_window.h"

#include <cstdio>

unsigned int FlutterDesktopGetDpiForMonitor(HMONITOR) { return 96; }

int main() {
  Win32Window runner;
  if (!runner.Create(L"Moonfin window visibility test", {50000, 50000},
                     {320, 200})) {
    std::fprintf(stderr, "Could not create test runner\n");
    return 1;
  }
  HWND parent = runner.GetHandle();
  HWND child = CreateWindowW(L"STATIC", L"content", WS_CHILD, 0, 0, 320,
                             200, parent, nullptr, GetModuleHandleW(nullptr),
                             nullptr);
  if (child == nullptr) {
    std::fprintf(stderr, "Could not create hidden child\n");
    return 1;
  }

  runner.SetChildContent(child);
  if (IsWindowVisible(parent)) {
    std::fprintf(stderr, "Attaching content exposed the parent too early\n");
    return 1;
  }
  runner.Show();
  if (!IsWindowVisible(parent) || !IsWindowVisible(child)) {
    std::fprintf(stderr, "FAIL: first show left the content hidden\n");
    return 1;
  }

  auto onScreen = [parent]() {
    RECT bounds{};
    MONITORINFO monitor{};
    monitor.cbSize = sizeof(monitor);
    if (!GetWindowRect(parent, &bounds) ||
        !GetMonitorInfo(MonitorFromWindow(parent, MONITOR_DEFAULTTONEAREST),
                        &monitor)) return false;
    const RECT& area = monitor.rcWork;
    return bounds.left >= area.left && bounds.top >= area.top &&
           bounds.right <= area.right && bounds.bottom <= area.bottom;
  };
  if (!onScreen()) {
    std::fprintf(stderr, "FAIL: first show left the runner off screen\n");
    return 1;
  }
  SetWindowPos(parent, nullptr, -50000, -50000, 320, 200,
               SWP_NOZORDER | SWP_NOACTIVATE);
  if (!onScreen()) {
    std::fprintf(stderr, "FAIL: asynchronously restored bounds stayed off screen\n");
    return 1;
  }
  SetWindowPos(parent, nullptr, 10, -180, 320, 200,
               SWP_NOZORDER | SWP_NOACTIVATE);
  if (!onScreen()) {
    std::fprintf(stderr, "FAIL: partially visible window left its title bar unreachable\n");
    return 1;
  }

  // A plugin can show the native parent without calling the runner's Show().
  SendMessage(parent, WM_ENTERSIZEMOVE, 0, 0);
  SetWindowPos(parent, nullptr, 50000, 50000, 320, 200,
               SWP_NOZORDER | SWP_NOACTIVATE);
  if (onScreen()) {
    std::fprintf(stderr, "FAIL: safeguard interfered with interactive dragging\n");
    return 1;
  }
  SendMessage(parent, WM_EXITSIZEMOVE, 0, 0);
  if (!onScreen()) {
    std::fprintf(stderr, "FAIL: completing a drag left the window unreachable\n");
    return 1;
  }

  const LONG_PTR style = GetWindowLongPtr(parent, GWL_STYLE);
  SetWindowLongPtr(parent, GWL_STYLE, style & ~WS_CAPTION);
  SetWindowPos(parent, nullptr, 50000, 50000, 320, 200,
               SWP_NOZORDER | SWP_NOACTIVATE);
  if (onScreen()) {
    std::fprintf(stderr, "FAIL: safeguard changed borderless playback bounds\n");
    return 1;
  }
  SetWindowLongPtr(parent, GWL_STYLE, style);
  // window_manager fullscreen keeps the caption bits but drops this frame.
  SetWindowLongPtr(parent, GWL_STYLE, style & ~(WS_THICKFRAME | WS_MAXIMIZEBOX));
  SetWindowPos(parent, nullptr, 50000, 50000, 320, 200,
               SWP_NOZORDER | SWP_NOACTIVATE);
  if (onScreen()) {
    std::fprintf(stderr, "FAIL: safeguard changed plugin fullscreen bounds\n");
    return 1;
  }
  SetWindowLongPtr(parent, GWL_STYLE, style);
  SendMessage(parent, WM_DISPLAYCHANGE, 0, 0);
  if (!onScreen()) {
    std::fprintf(stderr, "FAIL: display change did not recover the normal window\n");
    return 1;
  }

  ShowWindow(parent, SW_HIDE);
  ShowWindow(child, SW_HIDE);
  ShowWindow(parent, SW_SHOWNOACTIVATE);
  if (!IsWindowVisible(child)) {
    std::fprintf(stderr, "FAIL: direct parent show left the content hidden\n");
    return 1;
  }

  // Showing an already-visible parent does not emit WM_SHOWWINDOW again.
  ShowWindow(child, SW_HIDE);
  runner.Show();
  if (!IsWindowVisible(child)) {
    std::fprintf(stderr, "FAIL: repeated runner show left the content hidden\n");
    return 1;
  }

  // Content can be attached after the parent has already been presented.
  HWND replacement = CreateWindowW(L"STATIC", L"replacement", WS_CHILD,
                                   0, 0, 320, 200, parent, nullptr,
                                   GetModuleHandleW(nullptr), nullptr);
  runner.SetChildContent(replacement);
  if (!IsWindowVisible(replacement)) {
    std::fprintf(stderr, "FAIL: attaching content to visible runner hid it\n");
    return 1;
  }

  runner.Destroy();
  std::puts("PASS: hidden parent preserved; first show, direct show, repeated "
            "show and late attachment display content");
  return 0;
}

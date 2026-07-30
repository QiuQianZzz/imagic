#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <string>
#include <thread>

#include "flutter_window.h"
#include "utils.h"

namespace {

// Global named mutex for single-instance detection.
// The OS ensures only one process can hold the mutex at a time.
constexpr const wchar_t* kSingleInstanceMutexName =
    L"Imagic.SingleInstance.Mutex.QiuQianZzz";

// Named pipe used by secondary instances to send the file path
// to the already-running primary instance.
constexpr const wchar_t* kSingleInstancePipeName =
    L"\\\\.\\pipe\\Imagic.SingleInstance.Pipe.QiuQianZzz";

// Custom window message: notify FlutterWindow that an external file
// path has arrived via the named pipe.
constexpr UINT kWM_OPEN_EXTERNAL_FILE = WM_APP + 1;

// Primary instance: start a named pipe server that listens for file paths
// sent by secondary instances. When a path arrives, post a custom message
// to the UI thread so it can be forwarded to Flutter via MethodChannel.
void StartPipeServer(HWND target_window) {
  std::thread([target_window]() {
    while (true) {
      HANDLE pipe = CreateNamedPipeW(
          kSingleInstancePipeName,
          PIPE_ACCESS_INBOUND,
          PIPE_TYPE_MESSAGE | PIPE_READMODE_MESSAGE | PIPE_WAIT,
          1,                // Max instances (single-instance server)
          64 * 1024,        // Outbound buffer (unused, INBOUND only)
          64 * 1024,        // Inbound buffer
          0,                // Default timeout
          nullptr);         // Default security descriptor (same user only)
      if (pipe == INVALID_HANDLE_VALUE) {
        Sleep(1000);
        continue;
      }

      // Block until a client connects.
      if (ConnectNamedPipe(pipe, nullptr) ||
          GetLastError() == ERROR_PIPE_CONNECTED) {
        // Windows MAX_PATH is 260, but long-path (\\?\) can reach 32767.
        // Use a 32 KB stack buffer to cover all legitimate paths.
        char buffer[32768] = {0};
        DWORD bytes_read = 0;
        if (ReadFile(pipe, buffer, sizeof(buffer) - 1, &bytes_read,
                     nullptr) &&
            bytes_read > 0) {
          std::string path(buffer, bytes_read);
          // Transfer string ownership to the UI thread via heap allocation.
          // PostMessage is async; the receiver is responsible for deleting it.
          char* heap_path = new char[path.size() + 1];
          memcpy(heap_path, path.c_str(), path.size() + 1);
          if (!PostMessage(target_window, kWM_OPEN_EXTERNAL_FILE, 0,
                           reinterpret_cast<LPARAM>(heap_path))) {
            // Window has been destroyed; reclaim the allocation to avoid
            // leaking memory during shutdown.
            delete[] heap_path;
          }
        }
      }
      CloseHandle(pipe);
    }
  }).detach();
}

// Secondary instance: send the file path to the primary instance via the
// named pipe. Returns true on success.
bool SendPathToPrimaryInstance(const std::string& path) {
  // Wait up to 3 seconds for the pipe to become available.
  if (!WaitNamedPipeW(kSingleInstancePipeName, 3000)) {
    return false;
  }
  HANDLE pipe = CreateFileW(
      kSingleInstancePipeName,
      GENERIC_WRITE,
      0,
      nullptr,
      OPEN_EXISTING,
      0,
      nullptr);
  if (pipe == INVALID_HANDLE_VALUE) {
    return false;
  }
  DWORD written = 0;
  BOOL ok = WriteFile(pipe, path.c_str(),
                      static_cast<DWORD>(path.size() + 1), &written, nullptr);
  CloseHandle(pipe);
  return ok && written > 0;
}

// Find the already-running primary window and bring it to the foreground.
// Uses the registered window class name (not the window title) so that
// runtime title changes (e.g. via windowManager.setTitle) don't break
// single-instance activation.
void ActivatePrimaryWindow() {
  HWND hwnd = FindWindowW(Win32Window::GetWindowClassName(), nullptr);
  if (hwnd != nullptr) {
    if (IsIconic(hwnd)) {
      ShowWindow(hwnd, SW_RESTORE);
    }
    SetForegroundWindow(hwnd);
  }
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t* command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  std::vector<std::string> command_line_arguments = GetCommandLineArguments();

  // Single-instance detection: try to create a global named mutex.
  HANDLE mutex = CreateMutexW(nullptr, TRUE, kSingleInstanceMutexName);
  bool is_primary;
  if (mutex == nullptr) {
    // Mutex creation failed (extreme: out of memory / kernel quota).
    // Conservatively continue as the primary instance so the app still
    // launches, rather than silently exiting.
    is_primary = true;
  } else {
    is_primary = (GetLastError() != ERROR_ALREADY_EXISTS);
  }

  if (!is_primary) {
    // A primary instance is already running. Forward the file path (if any)
    // to it via the named pipe, activate its window, then exit.
    if (!command_line_arguments.empty()) {
      SendPathToPrimaryInstance(command_line_arguments[0]);
    }
    ActivatePrimaryWindow();
    ::CoUninitialize();
    if (mutex) CloseHandle(mutex);
    return EXIT_SUCCESS;
  }

  // Primary instance: continue starting Flutter.
  flutter::DartProject project(L"data");
  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"imagic", origin, size)) {
    if (mutex) CloseHandle(mutex);
    ::CoUninitialize();
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  // Start the named pipe server to receive future "open file" requests.
  StartPipeServer(window.GetHandle());

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    // Intercept the custom "external file open" message and forward it to
    // FlutterWindow, which will push it to Dart via MethodChannel.
    if (msg.message == kWM_OPEN_EXTERNAL_FILE) {
      char* path = reinterpret_cast<char*>(msg.lParam);
      std::string path_str(path);
      delete[] path;
      window.OnExternalFileOpen(path_str);
      continue;
    }
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  if (mutex) CloseHandle(mutex);
  return EXIT_SUCCESS;
}

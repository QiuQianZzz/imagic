#include "flutter_window.h"

#include <optional>

#include "flutter/generated_plugin_registrant.h"

// Single-instance MethodChannel name. Must match the Dart side.
static constexpr const char* kSingleInstanceChannelName =
    "imagic/single_instance";

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  // Create the single-instance MethodChannel used to push externally received
  // file paths to the Dart side.
  single_instance_channel_ = new flutter::MethodChannel<flutter::EncodableValue>(
      flutter_controller_->engine()->messenger(),
      kSingleInstanceChannelName,
      &flutter::StandardMethodCodec::GetInstance());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  // Null the channel pointer BEFORE deleting the object so that any
  // concurrent OnExternalFileOpen call (posted during shutdown) sees a null
  // pointer and bails out instead of touching freed memory.
  auto* channel = single_instance_channel_;
  single_instance_channel_ = nullptr;
  if (channel) {
    delete channel;
  }
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

void FlutterWindow::OnExternalFileOpen(const std::string& path) {
  // Read the pointer once; OnDestroy may null it concurrently during shutdown.
  auto* channel = single_instance_channel_;
  if (!channel) return;
  channel->InvokeMethod(
      "onExternalFileOpen",
      std::make_unique<flutter::EncodableValue>(flutter::EncodableValue(path)));
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }

    // Handle messages that require a live Flutter engine. Guarded by the
    // outer flutter_controller_ check so we never touch a destroyed engine
    // during shutdown (e.g. WM_FONTCHANGE broadcast after the controller
    // has been reset to nullptr).
    switch (message) {
      case WM_FONTCHANGE:
        flutter_controller_->engine()->ReloadSystemFonts();
        break;
    }
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}

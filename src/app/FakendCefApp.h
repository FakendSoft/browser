#pragma once

#include "include/cef_app.h"

class FakendCefApp final : public CefApp, public CefBrowserProcessHandler {
 public:
  FakendCefApp() = default;

  CefRefPtr<CefBrowserProcessHandler> GetBrowserProcessHandler() override;
  void OnBeforeCommandLineProcessing(const CefString& process_type,
                                     CefRefPtr<CefCommandLine> command_line) override;
  void OnScheduleMessagePumpWork(int64_t delay_ms) override;

 private:
  IMPLEMENT_REFCOUNTING(FakendCefApp);

  FakendCefApp(const FakendCefApp&) = delete;
  FakendCefApp& operator=(const FakendCefApp&) = delete;
};


#include "FakendCefApp.h"

#include <dispatch/dispatch.h>

#include "include/cef_command_line.h"

CefRefPtr<CefBrowserProcessHandler> FakendCefApp::GetBrowserProcessHandler() {
  return this;
}

void FakendCefApp::OnBeforeCommandLineProcessing(
    const CefString& process_type,
    CefRefPtr<CefCommandLine> command_line) {
  (void)process_type;

  command_line->AppendSwitch("disable-background-networking");
  command_line->AppendSwitch("disable-component-update");
  command_line->AppendSwitchWithValue("disable-features",
                                      "Translate,AutofillServerCommunication");
  command_line->AppendSwitch("enable-gpu-rasterization");
}

void FakendCefApp::OnScheduleMessagePumpWork(int64_t delay_ms) {
  const int64_t clamped_delay = delay_ms < 0 ? 0 : delay_ms;
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, clamped_delay * NSEC_PER_MSEC),
                 dispatch_get_main_queue(), ^{
                   CefDoMessageLoopWork();
                 });
}

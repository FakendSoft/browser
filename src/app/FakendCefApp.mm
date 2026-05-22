#include "FakendCefApp.h"

#include <atomic>
#include <dispatch/dispatch.h>

#include "include/cef_command_line.h"

namespace {

constexpr int64_t kMaxTimerDelayMs = 1000 / 30;
std::atomic<uint64_t> g_messagePumpGeneration{0};
bool g_messagePumpActive = false;
bool g_reentrancyDetected = false;
bool g_timerPending = false;

void DoMessagePumpWork();

void ScheduleMessagePumpWorkOnMain(int64_t delay_ms) {
  dispatch_async(dispatch_get_main_queue(), ^{
    const uint64_t generation = ++g_messagePumpGeneration;
    g_timerPending = delay_ms > 0;

    if (delay_ms <= 0) {
      DoMessagePumpWork();
      return;
    }

    const int64_t clamped_delay = delay_ms > kMaxTimerDelayMs ? kMaxTimerDelayMs : delay_ms;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, clamped_delay * NSEC_PER_MSEC),
                   dispatch_get_main_queue(), ^{
                     if (g_messagePumpGeneration.load() != generation) {
                       return;
                     }

                     g_timerPending = false;
                     DoMessagePumpWork();
                   });
  });
}

void DoMessagePumpWork() {
  if (g_messagePumpActive) {
    g_reentrancyDetected = true;
    return;
  }

  g_reentrancyDetected = false;
  g_messagePumpActive = true;
  CefDoMessageLoopWork();
  g_messagePumpActive = false;

  if (g_reentrancyDetected) {
    ScheduleMessagePumpWorkOnMain(0);
  } else if (!g_timerPending) {
    ScheduleMessagePumpWorkOnMain(kMaxTimerDelayMs);
  }
}

}  // namespace

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
  command_line->AppendSwitch("force-dark-mode");
#if defined(OS_MAC)
  command_line->AppendSwitch("use-mock-keychain");
#endif
}

void FakendCefApp::OnScheduleMessagePumpWork(int64_t delay_ms) {
  ScheduleMessagePumpWorkOnMain(delay_ms < 0 ? 0 : delay_ms);
}

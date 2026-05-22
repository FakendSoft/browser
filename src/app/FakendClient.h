#pragma once

#include "include/cef_client.h"

@class BrowserTab;

class FakendClient final : public CefClient,
                           public CefDisplayHandler,
                           public CefLifeSpanHandler,
                           public CefLoadHandler {
 public:
  explicit FakendClient(BrowserTab* tab);

  CefRefPtr<CefDisplayHandler> GetDisplayHandler() override;
  CefRefPtr<CefLifeSpanHandler> GetLifeSpanHandler() override;
  CefRefPtr<CefLoadHandler> GetLoadHandler() override;

  void OnAfterCreated(CefRefPtr<CefBrowser> browser) override;
  bool DoClose(CefRefPtr<CefBrowser> browser) override;
  void OnBeforeClose(CefRefPtr<CefBrowser> browser) override;
  void OnTitleChange(CefRefPtr<CefBrowser> browser,
                     const CefString& title) override;
  void OnAddressChange(CefRefPtr<CefBrowser> browser,
                       CefRefPtr<CefFrame> frame,
                       const CefString& url) override;

 private:
  __weak BrowserTab* tab_;

  IMPLEMENT_REFCOUNTING(FakendClient);

  FakendClient(const FakendClient&) = delete;
  FakendClient& operator=(const FakendClient&) = delete;
};


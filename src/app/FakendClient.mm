#include "FakendClient.h"

#import "BrowserTab.h"

#include "include/wrapper/cef_helpers.h"

FakendClient::FakendClient(BrowserTab* tab) : tab_(tab) {}

CefRefPtr<CefDisplayHandler> FakendClient::GetDisplayHandler() {
  return this;
}

CefRefPtr<CefLifeSpanHandler> FakendClient::GetLifeSpanHandler() {
  return this;
}

CefRefPtr<CefLoadHandler> FakendClient::GetLoadHandler() {
  return this;
}

void FakendClient::OnAfterCreated(CefRefPtr<CefBrowser> browser) {
  CEF_REQUIRE_UI_THREAD();
  [tab_ bindBrowser:browser];
}

bool FakendClient::DoClose(CefRefPtr<CefBrowser> browser) {
  (void)browser;
  CEF_REQUIRE_UI_THREAD();
  return false;
}

void FakendClient::OnBeforeClose(CefRefPtr<CefBrowser> browser) {
  (void)browser;
  CEF_REQUIRE_UI_THREAD();
  [tab_ browserClosed];
}

void FakendClient::OnTitleChange(CefRefPtr<CefBrowser> browser,
                                 const CefString& title) {
  (void)browser;
  CEF_REQUIRE_UI_THREAD();
  [tab_ updateTitleFromCEF:title];
}

void FakendClient::OnAddressChange(CefRefPtr<CefBrowser> browser,
                                   CefRefPtr<CefFrame> frame,
                                   const CefString& url) {
  (void)browser;
  CEF_REQUIRE_UI_THREAD();
  if (frame && frame->IsMain()) {
    [tab_ updateAddressFromCEF:url];
  }
}


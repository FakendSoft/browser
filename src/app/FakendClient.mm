#include "FakendClient.h"

#import "BrowserTab.h"

#include "include/wrapper/cef_helpers.h"

FakendClient::FakendClient(BrowserTab* tab) : tab_(tab) {}

CefRefPtr<CefDisplayHandler> FakendClient::GetDisplayHandler() {
  return this;
}

CefRefPtr<CefDownloadHandler> FakendClient::GetDownloadHandler() {
  return this;
}

CefRefPtr<CefLifeSpanHandler> FakendClient::GetLifeSpanHandler() {
  return this;
}

CefRefPtr<CefLoadHandler> FakendClient::GetLoadHandler() {
  return this;
}

CefRefPtr<CefPermissionHandler> FakendClient::GetPermissionHandler() {
  return this;
}

CefRefPtr<CefRequestHandler> FakendClient::GetRequestHandler() {
  return this;
}

void FakendClient::OnAfterCreated(CefRefPtr<CefBrowser> browser) {
  CEF_REQUIRE_UI_THREAD();
  [tab_ bindBrowser:browser];
}

bool FakendClient::OnBeforePopup(CefRefPtr<CefBrowser> browser,
                                 CefRefPtr<CefFrame> frame,
                                 int popup_id,
                                 const CefString& target_url,
                                 const CefString& target_frame_name,
                                 WindowOpenDisposition target_disposition,
                                 bool user_gesture,
                                 const CefPopupFeatures& popupFeatures,
                                 CefWindowInfo& windowInfo,
                                 CefRefPtr<CefClient>& client,
                                 CefBrowserSettings& settings,
                                 CefRefPtr<CefDictionaryValue>& extra_info,
                                 bool* no_javascript_access) {
  (void)browser;
  (void)frame;
  (void)popup_id;
  (void)target_url;
  (void)target_frame_name;
  (void)target_disposition;
  (void)user_gesture;
  (void)popupFeatures;
  (void)windowInfo;
  (void)client;
  (void)settings;
  (void)extra_info;
  (void)no_javascript_access;
  CEF_REQUIRE_UI_THREAD();
  return true;
}

bool FakendClient::DoClose(CefRefPtr<CefBrowser> browser) {
  CEF_REQUIRE_UI_THREAD();
  return [tab_ handleBrowserDoClose:browser];
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

bool FakendClient::CanDownload(CefRefPtr<CefBrowser> browser,
                               const CefString& url,
                               const CefString& request_method) {
  (void)browser;
  (void)url;
  (void)request_method;
  CEF_REQUIRE_UI_THREAD();
  return false;
}

bool FakendClient::OnBeforeDownload(
    CefRefPtr<CefBrowser> browser,
    CefRefPtr<CefDownloadItem> download_item,
    const CefString& suggested_name,
    CefRefPtr<CefBeforeDownloadCallback> callback) {
  (void)browser;
  (void)download_item;
  (void)suggested_name;
  (void)callback;
  CEF_REQUIRE_UI_THREAD();
  return false;
}

bool FakendClient::OnRequestMediaAccessPermission(
    CefRefPtr<CefBrowser> browser,
    CefRefPtr<CefFrame> frame,
    const CefString& requesting_origin,
    uint32_t requested_permissions,
    CefRefPtr<CefMediaAccessCallback> callback) {
  (void)browser;
  (void)frame;
  (void)requesting_origin;
  (void)requested_permissions;
  CEF_REQUIRE_UI_THREAD();
  if (callback) {
    callback->Cancel();
  }
  return true;
}

bool FakendClient::OnShowPermissionPrompt(
    CefRefPtr<CefBrowser> browser,
    uint64_t prompt_id,
    const CefString& requesting_origin,
    uint32_t requested_permissions,
    CefRefPtr<CefPermissionPromptCallback> callback) {
  (void)browser;
  (void)prompt_id;
  (void)requesting_origin;
  (void)requested_permissions;
  CEF_REQUIRE_UI_THREAD();
  if (callback) {
    callback->Continue(CEF_PERMISSION_RESULT_DENY);
  }
  return true;
}

CefRefPtr<CefResourceRequestHandler> FakendClient::GetResourceRequestHandler(
    CefRefPtr<CefBrowser> browser,
    CefRefPtr<CefFrame> frame,
    CefRefPtr<CefRequest> request,
    bool is_navigation,
    bool is_download,
    const CefString& request_initiator,
    bool& disable_default_handling) {
  (void)browser;
  (void)frame;
  (void)request;
  (void)is_navigation;
  (void)is_download;
  (void)request_initiator;
  (void)disable_default_handling;
  CEF_REQUIRE_IO_THREAD();
  return this;
}

void FakendClient::OnProtocolExecution(CefRefPtr<CefBrowser> browser,
                                       CefRefPtr<CefFrame> frame,
                                       CefRefPtr<CefRequest> request,
                                       bool& allow_os_execution) {
  (void)browser;
  (void)frame;
  (void)request;
  CEF_REQUIRE_IO_THREAD();
  allow_os_execution = false;
}

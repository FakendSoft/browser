#import "BrowserTab.h"

#include <string>

#include "FakendClient.h"
#include "include/cef_browser.h"
#include "include/cef_request_context.h"
#include "include/cef_request_context_handler.h"

@interface BrowserTab ()

@property(nonatomic, strong, readwrite) NSView *containerView;
@property(nonatomic, copy, readwrite) NSString *identifier;
@property(nonatomic, copy, readwrite) NSString *title;
@property(nonatomic, copy, readwrite) NSString *displayURL;

@end

@implementation BrowserTab {
  CefRefPtr<CefBrowser> _browser;
  CefRefPtr<FakendClient> _client;
  CefRefPtr<CefRequestContext> _requestContext;
}

- (instancetype)initWithFrame:(NSRect)frame
                   initialURL:(NSString *)initialURL
                  storageRoot:(NSString *)storageRoot {
  self = [super init];
  if (!self) {
    return nil;
  }

  _identifier = [@"Tab-" stringByAppendingString:[NSUUID UUID].UUIDString];
  _title = @"New Tab";
  _displayURL = initialURL;
  _containerView = [[NSView alloc] initWithFrame:frame];
  _containerView.wantsLayer = YES;
  _containerView.layer.backgroundColor = NSColor.blackColor.CGColor;

  NSString *tabStoragePath = [storageRoot stringByAppendingPathComponent:_identifier];

  CefRequestContextSettings requestSettings;
  CefString(&requestSettings.cache_path).FromString(std::string(tabStoragePath.UTF8String));
  requestSettings.persist_session_cookies = false;
  _requestContext = CefRequestContext::CreateContext(requestSettings, nullptr);

  _client = new FakendClient(self);

  CefWindowInfo windowInfo;
  CefRect browserRect(0, 0, static_cast<int>(NSWidth(frame)), static_cast<int>(NSHeight(frame)));
  windowInfo.SetAsChild((__bridge CefWindowHandle)_containerView, browserRect);

  CefBrowserSettings browserSettings;
  CefBrowserHost::CreateBrowser(windowInfo,
                                _client,
                                std::string(initialURL.UTF8String),
                                browserSettings,
                                nullptr,
                                _requestContext);

  return self;
}

- (void)resizeToFrame:(NSRect)frame {
  self.containerView.frame = frame;
  if (_browser) {
    _browser->GetHost()->WasResized();
  }
}

- (void)loadURLString:(NSString *)urlString {
  NSString *normalized = [self normalizedURLString:urlString];
  self.displayURL = normalized;
  if (_browser) {
    _browser->GetMainFrame()->LoadURL(std::string(normalized.UTF8String));
  }
}

- (void)goBack {
  if (_browser && _browser->CanGoBack()) {
    _browser->GoBack();
  }
}

- (void)goForward {
  if (_browser && _browser->CanGoForward()) {
    _browser->GoForward();
  }
}

- (void)reload {
  if (_browser) {
    _browser->Reload();
  }
}

- (void)close {
  if (_browser) {
    _browser->GetHost()->CloseBrowser(false);
    return;
  }
  [self.delegate browserTabDidClose:self];
}

- (void)bindBrowser:(CefRefPtr<CefBrowser>)browser {
  _browser = browser;
}

- (void)browserClosed {
  _browser = nullptr;
  [self.delegate browserTabDidClose:self];
}

- (void)updateTitleFromCEF:(const CefString &)title {
  std::string titleString = title.ToString();
  self.title = titleString.empty() ? @"New Tab" : [NSString stringWithUTF8String:titleString.c_str()];
  [self.delegate browserTabDidUpdate:self];
}

- (void)updateAddressFromCEF:(const CefString &)url {
  std::string urlString = url.ToString();
  self.displayURL = [NSString stringWithUTF8String:urlString.c_str()];
  [self.delegate browserTabDidUpdate:self];
}

- (NSString *)normalizedURLString:(NSString *)urlString {
  NSString *trimmed = [urlString stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
  if (trimmed.length == 0) {
    return @"about:blank";
  }

  if ([trimmed containsString:@"://"] || [trimmed hasPrefix:@"about:"]) {
    return trimmed;
  }

  if ([trimmed containsString:@"."] && ![trimmed containsString:@" "]) {
    return [@"https://" stringByAppendingString:trimmed];
  }

  NSString *escaped = [trimmed stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLQueryAllowedCharacterSet];
  return [@"https://www.google.com/search?q=" stringByAppendingString:escaped ?: @""];
}

@end

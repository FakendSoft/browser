#import "BrowserTab.h"

#include <string>

#include "FakendClient.h"
#include "include/cef_browser.h"
#include "include/cef_request_context.h"
#include "include/cef_request_context_handler.h"

@interface NewTabDragOverlayView : NSView

@property(nonatomic, strong) NSTextField *messageLabel;

@end

@implementation NewTabDragOverlayView

- (instancetype)initWithFrame:(NSRect)frame {
  self = [super initWithFrame:frame];
  if (!self) {
    return nil;
  }

  self.wantsLayer = YES;
  self.layer.backgroundColor = NSColor.blackColor.CGColor;

  _messageLabel = [NSTextField labelWithString:@"Open a fakend URL"];
  _messageLabel.alignment = NSTextAlignmentCenter;
  _messageLabel.font = [NSFont systemFontOfSize:16 weight:NSFontWeightRegular];
  _messageLabel.textColor = [NSColor colorWithCalibratedWhite:0.20 alpha:1.0];
  [_messageLabel setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow
                                          forOrientation:NSLayoutConstraintOrientationHorizontal];
  [self addSubview:_messageLabel];

  return self;
}

- (void)layout {
  [super layout];
  CGFloat labelHeight = 24.0;
  self.messageLabel.frame = NSMakeRect(0,
                                       floor((NSHeight(self.bounds) - labelHeight) / 2.0),
                                       NSWidth(self.bounds),
                                       labelHeight);
}

- (BOOL)isOpaque {
  return YES;
}

- (BOOL)acceptsFirstMouse:(NSEvent *)event {
  (void)event;
  return YES;
}

- (NSView *)hitTest:(NSPoint)point {
  return NSPointInRect(point, self.bounds) ? self : nil;
}

- (BOOL)mouseDownCanMoveWindow {
  return YES;
}

- (void)mouseDown:(NSEvent *)event {
  [self.window performWindowDragWithEvent:event];
}

@end

@interface BrowserTab ()

@property(nonatomic, strong, readwrite) NSView *containerView;
@property(nonatomic, copy, readwrite) NSString *identifier;
@property(nonatomic, copy, readwrite) NSString *title;
@property(nonatomic, copy, readwrite) NSString *displayURL;
@property(nonatomic, strong) NSView *blankPageDragOverlayView;

- (void)updateNewTabDragOverlay;

@end

@implementation BrowserTab {
  CefRefPtr<CefBrowser> _browser;
  CefRefPtr<FakendClient> _client;
  CefRefPtr<CefRequestContext> _requestContext;
  BOOL _browserCreationPending;
  BOOL _browserCloseNotified;
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
  _blankPageDragOverlayView = [[NewTabDragOverlayView alloc] initWithFrame:_containerView.bounds];
  _blankPageDragOverlayView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  _blankPageDragOverlayView.hidden = NO;
  [_containerView addSubview:_blankPageDragOverlayView];

  NSString *tabStoragePath = [storageRoot stringByAppendingPathComponent:_identifier];
  [[NSFileManager defaultManager] createDirectoryAtPath:tabStoragePath
                            withIntermediateDirectories:YES
                                             attributes:nil
                                                  error:nil];

  CefRequestContextSettings requestSettings;
  CefString(&requestSettings.cache_path).FromString(std::string(tabStoragePath.UTF8String));
  requestSettings.persist_session_cookies = false;
  _requestContext = CefRequestContext::CreateContext(requestSettings, nullptr);
  _requestContext->SetChromeColorScheme(CEF_COLOR_VARIANT_DARK,
                                        CefColorSetARGB(0xFF, 0, 0, 0));

  _client = new FakendClient(self);

  return self;
}

- (void)ensureBrowserCreated {
  if (_browser || _browserCreationPending) {
    return;
  }

  CefWindowInfo windowInfo;
  CefRect browserRect(0,
                      0,
                      static_cast<int>(NSWidth(self.containerView.bounds)),
                      static_cast<int>(NSHeight(self.containerView.bounds)));
  windowInfo.SetAsChild((__bridge CefWindowHandle)_containerView, browserRect);
  windowInfo.runtime_style = CEF_RUNTIME_STYLE_ALLOY;

  CefBrowserSettings browserSettings;
  browserSettings.background_color = CefColorSetARGB(0xFF, 0, 0, 0);
  NSString *url = self.displayURL ?: @"about:blank";
  NSString *navigationURL = [self navigationURLForDisplayURL:url];
  _browserCreationPending = YES;
  if (!CefBrowserHost::CreateBrowser(windowInfo,
                                     _client,
                                     std::string(navigationURL.UTF8String),
                                     browserSettings,
                                     nullptr,
                                     _requestContext)) {
    _browserCreationPending = NO;
  }
  [self updateNewTabDragOverlay];
}

- (BOOL)isBrowserReady {
  return _browser != nullptr;
}

- (void)resizeToFrame:(NSRect)frame {
  self.containerView.frame = frame;
  [self updateNewTabDragOverlay];
  if (_browser) {
    _browser->GetHost()->WasResized();
  }
}

- (void)loadURLString:(NSString *)urlString {
  NSString *normalized = [self normalizedURLString:urlString];
  self.displayURL = normalized;
  [self updateNewTabDragOverlay];
  if (_browser) {
    CefRefPtr<CefFrame> frame = _browser->GetMainFrame();
    if (frame && frame->IsValid()) {
      NSString *navigationURL = [self navigationURLForDisplayURL:normalized];
      frame->LoadURL(std::string(navigationURL.UTF8String));
    }
  }
}

- (BOOL)canGoBack {
  return _browser && _browser->CanGoBack();
}

- (BOOL)canGoForward {
  return _browser && _browser->CanGoForward();
}

- (void)goBack {
  if ([self canGoBack]) {
    _browser->GoBack();
  }
}

- (void)goForward {
  if ([self canGoForward]) {
    _browser->GoForward();
  }
}

- (void)reload {
  if ([self isBrowserReady]) {
    _browser->Reload();
  }
}

- (void)close {
  if (_browser) {
    _browser->GetHost()->CloseBrowser(true);
    return;
  }
  [self.delegate browserTabDidClose:self];
}

- (void)openURLInNewTab:(NSString *)urlString {
  if (urlString.length == 0) {
    return;
  }

  [self.delegate browserTab:self openURLInNewTab:urlString];
}

- (void)bindBrowser:(CefRefPtr<CefBrowser>)browser {
  _browserCreationPending = NO;
  _browserCloseNotified = NO;
  _browser = browser;
  [self updateNewTabDragOverlay];
}

- (BOOL)handleBrowserDoClose:(CefRefPtr<CefBrowser>)browser {
  if (!_browser || !browser || !browser->IsSame(_browser)) {
    return NO;
  }

  NSView *browserView = (__bridge NSView *)browser->GetHost()->GetWindowHandle();
  [browserView removeFromSuperview];
  [self browserClosed];
  return YES;
}

- (void)browserClosed {
  if (_browserCloseNotified) {
    return;
  }

  _browserCloseNotified = YES;
  _browserCreationPending = NO;
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
  NSString *displayURL = [NSString stringWithUTF8String:urlString.c_str()];
  if ([displayURL isEqualToString:[self newTabPageURL]]) {
    displayURL = @"about:blank";
  }
  self.displayURL = displayURL;
  [self updateNewTabDragOverlay];
  [self.delegate browserTabDidUpdate:self];
}

- (NSString *)navigationURLForDisplayURL:(NSString *)displayURL {
  if ([displayURL isEqualToString:@"about:blank"]) {
    return [self newTabPageURL];
  }
  return displayURL;
}

- (NSString *)newTabPageURL {
  NSString *html =
      @"<!doctype html>"
       "<html>"
       "<head>"
       "<meta charset=\"utf-8\">"
       "<title>New Tab</title>"
       "<style>"
       "html,body{width:100%;height:100%;margin:0;background:#000;}"
       "body{display:grid;place-items:center;color:#333;font:16px -apple-system,BlinkMacSystemFont,"
       "\"Segoe UI\",sans-serif;-webkit-app-region:drag;user-select:none;}"
       "</style>"
       "</head>"
       "<body>Open a fakend URL</body>"
       "</html>";
  NSData *data = [html dataUsingEncoding:NSUTF8StringEncoding];
  return [@"data:text/html;base64," stringByAppendingString:[data base64EncodedStringWithOptions:0]];
}

- (void)updateNewTabDragOverlay {
  if (!self.blankPageDragOverlayView) {
    return;
  }

  self.blankPageDragOverlayView.frame = self.containerView.bounds;
  BOOL shouldShowOverlay = [self.displayURL isEqualToString:@"about:blank"];
  if (shouldShowOverlay) {
    self.blankPageDragOverlayView.hidden = NO;
    [self.containerView addSubview:self.blankPageDragOverlayView positioned:NSWindowAbove relativeTo:nil];
  } else {
    [self.blankPageDragOverlayView removeFromSuperview];
  }
}

- (NSString *)normalizedURLString:(NSString *)urlString {
  NSString *trimmed = [urlString stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
  if (trimmed.length == 0) {
    return @"about:blank";
  }

  if ([trimmed hasPrefix:@"about:"]) {
    return trimmed;
  }

  if ([trimmed containsString:@"://"]) {
    NSURLComponents *components = [NSURLComponents componentsWithString:trimmed];
    if ([self shouldTreatAsWebURLComponents:components] && components.path.length == 0) {
      components.path = @"/";
      return components.string ?: trimmed;
    }
    return trimmed;
  }

  if ([self shouldTreatAsBareHost:trimmed]) {
    NSString *scheme = [self shouldUseHTTPForBareHost:trimmed] ? @"http://" : @"https://";
    NSString *candidate = [scheme stringByAppendingString:trimmed];
    NSURLComponents *components = [NSURLComponents componentsWithString:candidate];
    if ([self shouldTreatAsWebURLComponents:components] && components.path.length == 0) {
      components.path = @"/";
      return components.string ?: candidate;
    }
    return candidate;
  }

  NSString *escaped = [trimmed stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLQueryAllowedCharacterSet];
  return [@"https://www.google.com/search?q=" stringByAppendingString:escaped ?: @""];
}

- (BOOL)shouldTreatAsBareHost:(NSString *)value {
  if ([value containsString:@" "] || [value containsString:@"@"]) {
    return NO;
  }

  NSString *hostCandidate = value;
  NSRange delimiterRange = [hostCandidate rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"/?#"]];
  if (delimiterRange.location != NSNotFound) {
    hostCandidate = [hostCandidate substringToIndex:delimiterRange.location];
  }

  NSURLComponents *components = [NSURLComponents componentsWithString:[@"http://" stringByAppendingString:hostCandidate]];
  if ([components.host.lowercaseString isEqualToString:@"localhost"]) {
    return YES;
  }

  return [hostCandidate containsString:@"."];
}

- (BOOL)shouldUseHTTPForBareHost:(NSString *)value {
  NSString *hostCandidate = value;
  NSRange delimiterRange = [hostCandidate rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"/?#"]];
  if (delimiterRange.location != NSNotFound) {
    hostCandidate = [hostCandidate substringToIndex:delimiterRange.location];
  }

  NSURLComponents *components = [NSURLComponents componentsWithString:[@"http://" stringByAppendingString:hostCandidate]];
  return [components.host.lowercaseString isEqualToString:@"localhost"];
}

- (BOOL)shouldTreatAsWebURLComponents:(NSURLComponents *)components {
  if (!components.host.length) {
    return NO;
  }

  NSString *scheme = components.scheme.lowercaseString;
  return [scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"];
}

@end

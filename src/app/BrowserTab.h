#import <Cocoa/Cocoa.h>

#ifdef __cplusplus
#include "include/cef_browser.h"
#include "include/cef_request_context.h"
#include "include/internal/cef_string_wrappers.h"
#endif

@class BrowserTab;

@protocol BrowserTabDelegate <NSObject>

- (void)browserTabDidUpdate:(BrowserTab *)tab;
- (void)browserTabDidClose:(BrowserTab *)tab;
- (void)browserTab:(BrowserTab *)tab openURLInNewTab:(NSString *)urlString;

@end

@interface BrowserTab : NSObject

@property(nonatomic, weak) id<BrowserTabDelegate> delegate;
@property(nonatomic, strong, readonly) NSView *containerView;
@property(nonatomic, copy, readonly) NSString *identifier;
@property(nonatomic, copy, readonly) NSString *title;
@property(nonatomic, copy, readonly) NSString *displayURL;

- (instancetype)initWithFrame:(NSRect)frame
                   initialURL:(NSString *)initialURL
                  storageRoot:(NSString *)storageRoot;
- (void)ensureBrowserCreated;
- (BOOL)isBrowserReady;
- (void)resizeToFrame:(NSRect)frame;
- (void)loadURLString:(NSString *)urlString;
- (BOOL)canGoBack;
- (BOOL)canGoForward;
- (void)goBack;
- (void)goForward;
- (void)reload;
- (void)close;
- (void)openURLInNewTab:(NSString *)urlString;

#ifdef __cplusplus
- (void)bindBrowser:(CefRefPtr<CefBrowser>)browser;
- (BOOL)handleBrowserDoClose:(CefRefPtr<CefBrowser>)browser;
- (void)browserClosed;
- (void)updateTitleFromCEF:(const CefString &)title;
- (void)updateAddressFromCEF:(const CefString &)url;
#endif

@end

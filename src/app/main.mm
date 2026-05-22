#import <Cocoa/Cocoa.h>

#include <cstdlib>
#include <string>

#import "AppDelegate.h"
#include "FakendCefApp.h"
#include "include/cef_application_mac.h"
#include "include/cef_app.h"
#include "include/wrapper/cef_library_loader.h"

@interface FakendApplication : NSApplication <CefAppProtocol> {
 @private
  BOOL handlingSendEvent_;
}
@end

@implementation FakendApplication

- (BOOL)isHandlingSendEvent {
  return handlingSendEvent_;
}

- (void)setHandlingSendEvent:(BOOL)handlingSendEvent {
  handlingSendEvent_ = handlingSendEvent;
}

- (void)sendEvent:(NSEvent *)event {
  CefScopedSendingEvent sendingEventScoper;
  [super sendEvent:event];
}

@end

namespace {

std::string ToString(NSString *value) {
  return value ? std::string(value.UTF8String) : std::string();
}

NSString *ApplicationSupportRoot() {
  const char *overrideRoot = std::getenv("FAKEND_BROWSER_USER_DATA_DIR");
  if (overrideRoot && overrideRoot[0] != '\0') {
    NSString *root = [NSString stringWithUTF8String:overrideRoot];
    [[NSFileManager defaultManager] createDirectoryAtPath:root
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];
    return root;
  }

  NSArray<NSURL *> *urls = [[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory
                                                                  inDomains:NSUserDomainMask];
  NSString *root = [urls.firstObject.path stringByAppendingPathComponent:@"Fakend Browser"];
  [[NSFileManager defaultManager] createDirectoryAtPath:root
                            withIntermediateDirectories:YES
                                             attributes:nil
                                                  error:nil];
  return root;
}

NSString *HelperExecutablePath() {
  NSString *frameworksPath = NSBundle.mainBundle.privateFrameworksPath;
  return [frameworksPath stringByAppendingPathComponent:@"Fakend Browser Helper.app/Contents/MacOS/Fakend Browser Helper"];
}
}  // namespace

int main(int argc, char *argv[]) {
  @autoreleasepool {
    CefScopedLibraryLoader libraryLoader;
    if (!libraryLoader.LoadInMain()) {
      return 1;
    }

    CefMainArgs mainArgs(argc, argv);
    CefRefPtr<FakendCefApp> cefApp(new FakendCefApp());
    NSApplication *application = [FakendApplication sharedApplication];

    NSString *supportRoot = ApplicationSupportRoot();
    NSString *cacheRoot = [supportRoot stringByAppendingPathComponent:@"CEF"];
    [[NSFileManager defaultManager] createDirectoryAtPath:cacheRoot
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];

    CefSettings settings;
    settings.external_message_pump = true;
    settings.no_sandbox = true;
    settings.remote_debugging_port = 9222;
    CefString(&settings.root_cache_path).FromString(ToString(cacheRoot));
    CefString(&settings.cache_path).FromString(ToString([cacheRoot stringByAppendingPathComponent:@"Global"]));
    CefString(&settings.log_file).FromString(ToString([supportRoot stringByAppendingPathComponent:@"cef.log"]));

    if (!CefInitialize(mainArgs, settings, cefApp.get(), nullptr)) {
      return 1;
    }

    application.activationPolicy = NSApplicationActivationPolicyRegular;

    AppDelegate *delegate = [[AppDelegate alloc] init];
    application.delegate = delegate;
    [application run];

    CefShutdown();
  }

  return 0;
}

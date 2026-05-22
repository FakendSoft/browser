#import <Cocoa/Cocoa.h>

#import "BrowserTab.h"

@interface BrowserWindowController : NSWindowController <BrowserTabDelegate, NSTextFieldDelegate, NSMenuItemValidation, NSWindowDelegate>

- (void)newTab:(id)sender;
- (void)closeTab:(id)sender;
- (void)focusLocation:(id)sender;
- (void)reload:(id)sender;
- (void)goBack:(id)sender;
- (void)goForward:(id)sender;

@end

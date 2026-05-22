#import "AppDelegate.h"

#import "BrowserWindowController.h"

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
  (void)notification;

  self.browserWindowController = [[BrowserWindowController alloc] init];
  [self installMainMenu];
  [self.browserWindowController showWindow:nil];
  [NSApp activateIgnoringOtherApps:YES];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
  (void)sender;
  return YES;
}

- (void)installMainMenu {
  NSMenu *mainMenu = [[NSMenu alloc] initWithTitle:@""];
  NSMenuItem *appMenuItem = [[NSMenuItem alloc] initWithTitle:@"" action:nil keyEquivalent:@""];
  NSMenuItem *fileMenuItem = [[NSMenuItem alloc] initWithTitle:@"" action:nil keyEquivalent:@""];
  NSMenuItem *editMenuItem = [[NSMenuItem alloc] initWithTitle:@"" action:nil keyEquivalent:@""];
  NSMenuItem *navigateMenuItem = [[NSMenuItem alloc] initWithTitle:@"" action:nil keyEquivalent:@""];

  [mainMenu addItem:appMenuItem];
  [mainMenu addItem:fileMenuItem];
  [mainMenu addItem:editMenuItem];
  [mainMenu addItem:navigateMenuItem];

  NSMenu *appMenu = [[NSMenu alloc] initWithTitle:@"Fakend Browser"];
  [appMenu addItemWithTitle:@"Quit Fakend Browser" action:@selector(terminate:) keyEquivalent:@"q"];
  appMenuItem.submenu = appMenu;

  NSMenu *fileMenu = [[NSMenu alloc] initWithTitle:@"File"];
  NSMenuItem *newTabItem = [fileMenu addItemWithTitle:@"New Tab" action:@selector(newTab:) keyEquivalent:@"t"];
  newTabItem.target = self.browserWindowController;
  NSMenuItem *closeTabItem = [fileMenu addItemWithTitle:@"Close Tab" action:@selector(closeTab:) keyEquivalent:@"w"];
  closeTabItem.target = self.browserWindowController;
  fileMenuItem.submenu = fileMenu;

  NSMenu *editMenu = [[NSMenu alloc] initWithTitle:@"Edit"];
  [editMenu addItemWithTitle:@"Select All" action:@selector(selectAll:) keyEquivalent:@"a"];
  editMenuItem.submenu = editMenu;

  NSMenu *navigateMenu = [[NSMenu alloc] initWithTitle:@"Navigate"];
  NSMenuItem *focusLocationItem = [navigateMenu addItemWithTitle:@"Focus Location" action:@selector(focusLocation:) keyEquivalent:@"l"];
  focusLocationItem.target = self.browserWindowController;
  NSMenuItem *reloadItem = [navigateMenu addItemWithTitle:@"Reload" action:@selector(reload:) keyEquivalent:@"r"];
  reloadItem.target = self.browserWindowController;
  [navigateMenu addItem:[NSMenuItem separatorItem]];
  NSMenuItem *backItem = [navigateMenu addItemWithTitle:@"Back" action:@selector(goBack:) keyEquivalent:@"["];
  backItem.target = self.browserWindowController;
  NSMenuItem *forwardItem = [navigateMenu addItemWithTitle:@"Forward" action:@selector(goForward:) keyEquivalent:@"]"];
  forwardItem.target = self.browserWindowController;
  navigateMenuItem.submenu = navigateMenu;

  NSApp.mainMenu = mainMenu;
}

@end

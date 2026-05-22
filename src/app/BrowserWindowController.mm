#import "BrowserWindowController.h"

#include <cstdlib>

namespace {
constexpr CGFloat kToolbarHeight = 42.0;
constexpr CGFloat kTabWidth = 168.0;
constexpr CGFloat kTabStripWidth = 408.0;
constexpr CGFloat kButtonSize = 28.0;
constexpr CGFloat kToolbarButtonY = 7.0;
constexpr CGFloat kWindowControlsReservedWidth = 84.0;
constexpr CGFloat kToolbarGap = 8.0;
}

@interface BrowserWindow : NSWindow

@property(nonatomic, weak) BrowserWindowController *browserController;

@end

@implementation BrowserWindow

- (BOOL)performKeyEquivalent:(NSEvent *)event {
  NSEventModifierFlags modifiers =
      event.modifierFlags & NSEventModifierFlagDeviceIndependentFlagsMask;
  NSString *characters = event.charactersIgnoringModifiers.lowercaseString;
  if (event.type == NSEventTypeKeyDown &&
      modifiers == NSEventModifierFlagCommand &&
      [characters isEqualToString:@"w"]) {
    [self.browserController closeTab:nil];
    return YES;
  }

  return [super performKeyEquivalent:event];
}

@end

@interface BrowserWindowController ()

@property(nonatomic, strong) NSView *rootView;
@property(nonatomic, strong) NSView *toolbarView;
@property(nonatomic, strong) NSStackView *tabStrip;
@property(nonatomic, strong) NSTextField *locationField;
@property(nonatomic, strong) NSView *browserHostView;
@property(nonatomic, strong) NSMutableArray<BrowserTab *> *tabs;
@property(nonatomic) NSInteger selectedIndex;
@property(nonatomic, copy) NSString *storageRoot;
@property(nonatomic) BOOL didCreateInitialTabs;
@property(nonatomic) BOOL updatingLocationField;
@property(nonatomic) BOOL closingWindow;

@end

@implementation BrowserWindowController

- (instancetype)init {
  NSRect frame = NSMakeRect(0, 0, 1280, 820);
  BrowserWindow *window = [[BrowserWindow alloc] initWithContentRect:frame
                                                           styleMask:NSWindowStyleMaskTitled |
                                                                     NSWindowStyleMaskClosable |
                                                                     NSWindowStyleMaskMiniaturizable |
                                                                     NSWindowStyleMaskResizable |
                                                                     NSWindowStyleMaskFullSizeContentView
                                                             backing:NSBackingStoreBuffered
                                                               defer:NO];
  window.title = @"Fakend Browser";
  window.titleVisibility = NSWindowTitleHidden;
  window.titlebarAppearsTransparent = YES;
  window.backgroundColor = NSColor.blackColor;
  window.minSize = NSMakeSize(760, 460);

  self = [super initWithWindow:window];
  if (!self) {
    return nil;
  }

  _tabs = [NSMutableArray array];
  _selectedIndex = NSNotFound;
  _storageRoot = [self applicationSupportPath];
  window.browserController = self;
  window.delegate = self;
  [self buildInterface];

  return self;
}

- (void)showWindow:(id)sender {
  [super showWindow:sender];
  [self createInitialTabsIfNeeded];
}

- (void)windowDidLoad {
  [super windowDidLoad];
  [self.window center];
}

- (void)windowWillClose:(NSNotification *)notification {
  (void)notification;
  self.closingWindow = YES;
}

- (void)createInitialTabsIfNeeded {
  if (self.didCreateInitialTabs) {
    return;
  }

  self.didCreateInitialTabs = YES;
  [self newTabWithURL:@"https://example.com"];

  NSInteger initialTabCount = [self initialTabCount];
  for (NSInteger index = 1; index < initialTabCount; index += 1) {
    [self newTabWithURL:@"about:blank"];
  }
  [self selectTabAtIndex:0];
}

- (void)buildInterface {
  self.rootView = [[NSView alloc] initWithFrame:self.window.contentView.bounds];
  self.rootView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  self.rootView.wantsLayer = YES;
  self.rootView.layer.backgroundColor = NSColor.blackColor.CGColor;

  self.toolbarView = [[NSView alloc] initWithFrame:NSMakeRect(0,
                                                              NSHeight(self.rootView.bounds) - kToolbarHeight,
                                                              NSWidth(self.rootView.bounds),
                                                              kToolbarHeight)];
  self.toolbarView.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;
  self.toolbarView.wantsLayer = YES;
  self.toolbarView.layer.backgroundColor = [NSColor colorWithCalibratedWhite:0.035 alpha:1.0].CGColor;

  const CGFloat backButtonX = kWindowControlsReservedWidth + kToolbarGap;
  const CGFloat forwardButtonX = backButtonX + kButtonSize + 4.0;
  const CGFloat reloadButtonX = forwardButtonX + kButtonSize + 4.0;
  const CGFloat tabStripX = reloadButtonX + kButtonSize + kToolbarGap;
  const CGFloat newTabButtonX = tabStripX + kTabStripWidth + kToolbarGap;
  const CGFloat locationFieldX = newTabButtonX + kButtonSize + kToolbarGap;

  self.tabStrip = [[NSStackView alloc] initWithFrame:NSMakeRect(tabStripX,
                                                                kToolbarButtonY,
                                                                kTabStripWidth,
                                                                28)];
  self.tabStrip.orientation = NSUserInterfaceLayoutOrientationHorizontal;
  self.tabStrip.spacing = 6.0;
  self.tabStrip.distribution = NSStackViewDistributionGravityAreas;

  NSButton *backButton = [self iconButton:@"chevron.left" action:@selector(goBack:)];
  backButton.frame = NSMakeRect(backButtonX, kToolbarButtonY, kButtonSize, kButtonSize);
  NSButton *forwardButton = [self iconButton:@"chevron.right" action:@selector(goForward:)];
  forwardButton.frame = NSMakeRect(forwardButtonX, kToolbarButtonY, kButtonSize, kButtonSize);
  NSButton *reloadButton = [self iconButton:@"arrow.clockwise" action:@selector(reload:)];
  reloadButton.frame = NSMakeRect(reloadButtonX, kToolbarButtonY, kButtonSize, kButtonSize);
  NSButton *newTabButton = [self iconButton:@"plus" action:@selector(newTab:)];
  newTabButton.frame = NSMakeRect(newTabButtonX, kToolbarButtonY, kButtonSize, kButtonSize);

  self.locationField = [[NSTextField alloc] initWithFrame:NSMakeRect(locationFieldX,
                                                                     kToolbarButtonY,
                                                                     NSWidth(self.toolbarView.bounds) -
                                                                         locationFieldX - 12,
                                                                     28)];
  self.locationField.autoresizingMask = NSViewWidthSizable;
  self.locationField.delegate = self;
  self.locationField.bezelStyle = NSTextFieldRoundedBezel;
  self.locationField.font = [NSFont systemFontOfSize:13 weight:NSFontWeightRegular];
  self.locationField.textColor = NSColor.whiteColor;
  self.locationField.backgroundColor = [NSColor colorWithCalibratedWhite:0.10 alpha:1.0];
  self.locationField.placeholderString = @"Search or enter address";

  self.browserHostView = [[NSView alloc] initWithFrame:NSMakeRect(0,
                                                                  0,
                                                                  NSWidth(self.rootView.bounds),
                                                                  NSHeight(self.rootView.bounds) - kToolbarHeight)];
  self.browserHostView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  self.browserHostView.wantsLayer = YES;
  self.browserHostView.layer.backgroundColor = NSColor.blackColor.CGColor;

  [self.toolbarView addSubview:backButton];
  [self.toolbarView addSubview:forwardButton];
  [self.toolbarView addSubview:reloadButton];
  [self.toolbarView addSubview:self.tabStrip];
  [self.toolbarView addSubview:newTabButton];
  [self.toolbarView addSubview:self.locationField];
  [self.rootView addSubview:self.browserHostView];
  [self.rootView addSubview:self.toolbarView];
  self.window.contentView = self.rootView;
}

- (NSButton *)iconButton:(NSString *)symbolName action:(SEL)action {
  NSButton *button = [[NSButton alloc] initWithFrame:NSMakeRect(0, 0, kButtonSize, kButtonSize)];
  button.bezelStyle = NSBezelStyleTexturedRounded;
  button.target = self;
  button.action = action;
  button.image = [NSImage imageWithSystemSymbolName:symbolName accessibilityDescription:nil];
  button.imagePosition = NSImageOnly;
  button.contentTintColor = NSColor.whiteColor;
  return button;
}

- (NSString *)applicationSupportPath {
  NSString *root = nil;
  const char *overrideRoot = std::getenv("FAKEND_BROWSER_USER_DATA_DIR");
  if (overrideRoot && overrideRoot[0] != '\0') {
    root = [NSString stringWithUTF8String:overrideRoot];
  } else {
    NSArray<NSURL *> *urls = [[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory
                                                                    inDomains:NSUserDomainMask];
    root = [urls.firstObject.path stringByAppendingPathComponent:@"Fakend Browser"];
  }

  NSString *cefRoot = [root stringByAppendingPathComponent:@"CEF"];
  [[NSFileManager defaultManager] createDirectoryAtPath:cefRoot
                            withIntermediateDirectories:YES
                                             attributes:nil
                                                  error:nil];
  return cefRoot;
}

- (NSInteger)initialTabCount {
  const char *tabCountValue = std::getenv("FAKEND_BROWSER_INITIAL_TAB_COUNT");
  if (!tabCountValue || tabCountValue[0] == '\0') {
    return 1;
  }

  NSString *tabCountString = [NSString stringWithUTF8String:tabCountValue];
  NSInteger tabCount = tabCountString.integerValue;
  return MIN(MAX(tabCount, 1), 8);
}

- (void)newTab:(id)sender {
  (void)sender;
  [self newTabWithURL:@"about:blank"];
}

- (void)newTabWithURL:(NSString *)url {
  BrowserTab *tab = [[BrowserTab alloc] initWithFrame:self.browserHostView.bounds
                                           initialURL:url
                                          storageRoot:self.storageRoot];
  tab.delegate = self;
  [self.tabs addObject:tab];
  [self selectTabAtIndex:self.tabs.count - 1];
  [self reloadTabStrip];
}

- (void)selectTabButton:(NSButton *)sender {
  [self selectTabAtIndex:sender.tag];
}

- (void)selectTabAtIndex:(NSInteger)index {
  if (index < 0 || index >= static_cast<NSInteger>(self.tabs.count)) {
    return;
  }

  if (self.selectedIndex != NSNotFound) {
    BrowserTab *current = self.tabs[self.selectedIndex];
    [current.containerView removeFromSuperview];
  }

  self.selectedIndex = index;
  BrowserTab *selected = self.tabs[index];
  [selected resizeToFrame:self.browserHostView.bounds];
  [self.browserHostView addSubview:selected.containerView];
  dispatch_async(dispatch_get_main_queue(), ^{
    if (selected == self.selectedTab && selected.containerView.superview == self.browserHostView) {
      [selected ensureBrowserCreated];
    }
  });
  [self updateLocationFieldForTab:selected];
  [self reloadTabStrip];
}

- (BrowserTab *)selectedTab {
  if (self.selectedIndex == NSNotFound || self.selectedIndex >= static_cast<NSInteger>(self.tabs.count)) {
    return nil;
  }
  return self.tabs[self.selectedIndex];
}

- (void)reloadTabStrip {
  for (NSView *view in self.tabStrip.arrangedSubviews) {
    [self.tabStrip removeArrangedSubview:view];
    [view removeFromSuperview];
  }

  [self.tabs enumerateObjectsUsingBlock:^(BrowserTab *tab, NSUInteger index, BOOL *stop) {
    (void)stop;
    NSButton *button = [[NSButton alloc] initWithFrame:NSMakeRect(0, 0, kTabWidth, 28)];
    button.tag = static_cast<NSInteger>(index);
    button.target = self;
    button.action = @selector(selectTabButton:);
    button.title = tab.title.length > 0 ? tab.title : @"New Tab";
    button.font = [NSFont systemFontOfSize:12 weight:NSFontWeightMedium];
    button.lineBreakMode = NSLineBreakByTruncatingTail;
    button.bezelStyle = index == static_cast<NSUInteger>(self.selectedIndex)
                            ? NSBezelStyleTexturedRounded
                            : NSBezelStyleRegularSquare;
    [button setContentHuggingPriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationHorizontal];
    [button.widthAnchor constraintEqualToConstant:kTabWidth].active = YES;
    [button.heightAnchor constraintEqualToConstant:28].active = YES;
    [self.tabStrip addArrangedSubview:button];
  }];
}

- (void)goBack:(id)sender {
  (void)sender;
  [self.selectedTab goBack];
}

- (void)goForward:(id)sender {
  (void)sender;
  [self.selectedTab goForward];
}

- (void)reload:(id)sender {
  (void)sender;
  BrowserTab *tab = self.selectedTab;
  if (tab && [tab isBrowserReady]) {
    [tab reload];
  }
}

- (void)closeTab:(id)sender {
  (void)sender;
  [self.selectedTab close];
}

- (void)focusLocation:(id)sender {
  (void)sender;
  [self.window makeFirstResponder:self.locationField];
  [self.locationField selectText:nil];
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
  SEL action = menuItem.action;
  BrowserTab *tab = self.selectedTab;
  if (action == @selector(goBack:)) {
    return tab && [tab canGoBack];
  }
  if (action == @selector(goForward:)) {
    return tab && [tab canGoForward];
  }
  if (action == @selector(closeTab:) || action == @selector(reload:) || action == @selector(focusLocation:)) {
    return tab != nil;
  }
  return YES;
}

- (BOOL)control:(NSControl *)control
       textView:(NSTextView *)textView
doCommandBySelector:(SEL)commandSelector {
  (void)textView;
  if (control != self.locationField) {
    return NO;
  }

  if (commandSelector == @selector(insertNewline:)) {
    [self commitLocationField];
    return YES;
  }

  if (commandSelector == @selector(cancelOperation:)) {
    [self updateLocationFieldForTab:self.selectedTab];
    [self.window makeFirstResponder:nil];
    return YES;
  }

  return NO;
}

- (void)controlTextDidEndEditing:(NSNotification *)notification {
  (void)notification;
}

- (void)commitLocationField {
  if (self.updatingLocationField) {
    return;
  }

  BrowserTab *tab = self.selectedTab;
  if (!tab) {
    return;
  }

  [tab loadURLString:self.locationField.stringValue];
  [self updateLocationFieldForTab:tab];
  [self.window makeFirstResponder:nil];
}

- (void)updateLocationFieldForTab:(BrowserTab *)tab {
  self.updatingLocationField = YES;
  self.locationField.stringValue = tab.displayURL ?: @"";
  self.updatingLocationField = NO;
}

- (void)browserTabDidUpdate:(BrowserTab *)tab {
  if (tab == self.selectedTab) {
    [self updateLocationFieldForTab:tab];
  }
  [self reloadTabStrip];
}

- (void)browserTabDidClose:(BrowserTab *)tab {
  NSUInteger index = [self.tabs indexOfObject:tab];
  if (index == NSNotFound) {
    return;
  }

  [tab.containerView removeFromSuperview];
  [self.tabs removeObjectAtIndex:index];
  if (self.tabs.count == 0) {
    if (self.closingWindow) {
      [self.window close];
    } else {
      self.selectedIndex = NSNotFound;
      [self newTabWithURL:@"about:blank"];
    }
    return;
  }

  NSInteger nextIndex = MIN(static_cast<NSInteger>(index), static_cast<NSInteger>(self.tabs.count - 1));
  self.selectedIndex = NSNotFound;
  [self selectTabAtIndex:nextIndex];
}

@end

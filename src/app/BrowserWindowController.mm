#import "BrowserWindowController.h"

#include <cstdlib>

namespace {
constexpr CGFloat kToolbarHeight = 42.0;
constexpr CGFloat kButtonSize = 28.0;
constexpr CGFloat kToolbarButtonY = 7.0;
constexpr CGFloat kWindowControlsReservedWidth = 84.0;
constexpr CGFloat kToolbarGap = 8.0;
constexpr CGFloat kToolbarSidePadding = 12.0;
constexpr CGFloat kLocationFieldMinWidth = 260.0;
constexpr CGFloat kLocationFieldMaxWidth = 560.0;
constexpr CGFloat kTabStripMinWidth = 120.0;
constexpr CGFloat kWindowControlOffset = 5.0;
constexpr CGFloat kLocationFieldCornerRadius = 6.0;
constexpr CGFloat kLocationFieldHorizontalPadding = 10.0;
constexpr CGFloat kMouseDragThreshold = 4.0;

BOOL EventMovedPastDragThreshold(NSEvent *event, NSPoint startPoint) {
  CGFloat deltaX = event.locationInWindow.x - startPoint.x;
  CGFloat deltaY = event.locationInWindow.y - startPoint.y;
  return deltaX * deltaX + deltaY * deltaY >= kMouseDragThreshold * kMouseDragThreshold;
}

BOOL WindowPointIsInsideView(NSView *view, NSPoint windowPoint) {
  NSPoint localPoint = [view convertPoint:windowPoint fromView:nil];
  return NSPointInRect(localPoint, view.bounds);
}
}

@protocol TabDragDelegate <NSObject>

- (NSInteger)tabIndexForWindowPoint:(NSPoint)windowPoint;
- (NSInteger)moveTabFromIndex:(NSInteger)fromIndex toIndex:(NSInteger)toIndex;
- (void)selectTabAtIndex:(NSInteger)index;
- (void)closeTabAtIndex:(NSInteger)index;

@end

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

@interface WindowDragView : NSView
@end

@implementation WindowDragView

- (BOOL)mouseDownCanMoveWindow {
  return YES;
}

@end

@interface WindowDragButton : NSButton
@end

@implementation WindowDragButton

- (BOOL)acceptsFirstMouse:(NSEvent *)event {
  (void)event;
  return YES;
}

- (void)mouseDown:(NSEvent *)event {
  if (!self.window) {
    [super mouseDown:event];
    return;
  }

  NSPoint startPoint = event.locationInWindow;
  self.highlighted = YES;

  while (true) {
    NSEvent *nextEvent = [self.window nextEventMatchingMask:NSEventMaskLeftMouseDragged | NSEventMaskLeftMouseUp];
    if (!nextEvent) {
      break;
    }

    if (nextEvent.type == NSEventTypeLeftMouseDragged && EventMovedPastDragThreshold(nextEvent, startPoint)) {
      self.highlighted = NO;
      [self.window performWindowDragWithEvent:event];
      return;
    }

    if (nextEvent.type == NSEventTypeLeftMouseUp) {
      BOOL shouldPerformClick = self.enabled && WindowPointIsInsideView(self, nextEvent.locationInWindow);
      self.highlighted = NO;
      if (shouldPerformClick) {
        [NSApp sendAction:self.action to:self.target from:self];
      }
      return;
    }
  }

  self.highlighted = NO;
}

@end

@interface TabButton : NSButton

@property(nonatomic, weak) id<TabDragDelegate> dragDelegate;

@end

@implementation TabButton

- (BOOL)acceptsFirstMouse:(NSEvent *)event {
  (void)event;
  return YES;
}

- (void)mouseDown:(NSEvent *)event {
  if (!self.window || !self.dragDelegate) {
    [super mouseDown:event];
    return;
  }

  NSPoint startPoint = event.locationInWindow;
  NSInteger currentIndex = self.tag;
  BOOL didDrag = NO;
  self.highlighted = YES;

  while (true) {
    NSEvent *nextEvent = [self.window nextEventMatchingMask:NSEventMaskLeftMouseDragged | NSEventMaskLeftMouseUp];
    if (!nextEvent) {
      break;
    }

    if (nextEvent.type == NSEventTypeLeftMouseDragged && EventMovedPastDragThreshold(nextEvent, startPoint)) {
      didDrag = YES;
      NSInteger targetIndex = [self.dragDelegate tabIndexForWindowPoint:nextEvent.locationInWindow];
      if (targetIndex != NSNotFound && targetIndex != currentIndex) {
        currentIndex = [self.dragDelegate moveTabFromIndex:currentIndex toIndex:targetIndex];
      }
      continue;
    }

    if (nextEvent.type == NSEventTypeLeftMouseUp) {
      BOOL shouldSelectTab = !didDrag && WindowPointIsInsideView(self, nextEvent.locationInWindow);
      self.highlighted = NO;
      if (shouldSelectTab) {
        [self.dragDelegate selectTabAtIndex:self.tag];
      }
      return;
    }
  }

  self.highlighted = NO;
}

- (void)otherMouseDown:(NSEvent *)event {
  if (event.buttonNumber == 2 && self.dragDelegate) {
    [self.dragDelegate closeTabAtIndex:self.tag];
    return;
  }

  [super otherMouseDown:event];
}

@end

@interface LocationTextFieldCell : NSTextFieldCell
@end

@implementation LocationTextFieldCell

- (NSRect)textRectForBounds:(NSRect)rect {
  NSRect textRect = NSInsetRect(rect, kLocationFieldHorizontalPadding, 0.0);
  NSSize textSize = self.cellSize;
  textRect.origin.y += floor((NSHeight(textRect) - textSize.height) / 2.0);
  textRect.size.height = textSize.height;
  return textRect;
}

- (NSRect)drawingRectForBounds:(NSRect)rect {
  return [self textRectForBounds:rect];
}

- (void)editWithFrame:(NSRect)rect
               inView:(NSView *)controlView
               editor:(NSText *)textObj
             delegate:(id)delegate
                event:(NSEvent *)event {
  if ([textObj isKindOfClass:NSTextView.class]) {
    NSTextView *textView = (NSTextView *)textObj;
    textView.drawsBackground = NO;
    textView.textColor = NSColor.whiteColor;
    textView.insertionPointColor = NSColor.whiteColor;
  }
  [super editWithFrame:[self textRectForBounds:rect]
                inView:controlView
                editor:textObj
              delegate:delegate
                 event:event];
}

- (void)selectWithFrame:(NSRect)rect
                 inView:(NSView *)controlView
                 editor:(NSText *)textObj
               delegate:(id)delegate
                  start:(NSInteger)start
                 length:(NSInteger)length {
  if ([textObj isKindOfClass:NSTextView.class]) {
    NSTextView *textView = (NSTextView *)textObj;
    textView.drawsBackground = NO;
    textView.textColor = NSColor.whiteColor;
    textView.insertionPointColor = NSColor.whiteColor;
  }
  [super selectWithFrame:[self textRectForBounds:rect]
                  inView:controlView
                  editor:textObj
                delegate:delegate
                   start:start
                  length:length];
}

@end

@interface LocationTextField : NSTextField
@end

@implementation LocationTextField

- (BOOL)allowsVibrancy {
  return NO;
}

- (void)viewDidMoveToWindow {
  [super viewDidMoveToWindow];
  self.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
}

- (BOOL)acceptsFirstMouse:(NSEvent *)event {
  (void)event;
  return YES;
}

- (BOOL)mouseDownCanMoveWindow {
  return NO;
}

- (void)mouseDown:(NSEvent *)event {
  BOOL wasEditing = self.currentEditor && self.window.firstResponder == self.currentEditor;
  [self.window makeFirstResponder:self];
  [super mouseDown:event];
  if (wasEditing) {
    return;
  }

  dispatch_async(dispatch_get_main_queue(), ^{
    [self selectText:nil];
  });
}

@end

@interface BrowserWindowController () <TabDragDelegate>

@property(nonatomic, strong) NSView *rootView;
@property(nonatomic, strong) NSView *toolbarView;
@property(nonatomic, strong) NSButton *backButton;
@property(nonatomic, strong) NSButton *forwardButton;
@property(nonatomic, strong) NSButton *reloadButton;
@property(nonatomic, strong) NSStackView *tabStrip;
@property(nonatomic, strong) NSButton *addTabButton;
@property(nonatomic, strong) NSTextField *locationField;
@property(nonatomic, strong) NSView *browserHostView;
@property(nonatomic, strong) NSMutableArray<BrowserTab *> *tabs;
@property(nonatomic) NSInteger selectedIndex;
@property(nonatomic, copy) NSString *storageRoot;
@property(nonatomic) BOOL didCreateInitialTabs;
@property(nonatomic) BOOL updatingLocationField;
@property(nonatomic) BOOL closingWindow;
@property(nonatomic) BOOL didOffsetWindowControls;

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
  window.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
  window.movableByWindowBackground = YES;
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
  [self offsetWindowControlsIfNeeded];
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

- (void)windowDidResize:(NSNotification *)notification {
  (void)notification;
  [self layoutToolbarControls];
}

- (void)createInitialTabsIfNeeded {
  if (self.didCreateInitialTabs) {
    return;
  }

  self.didCreateInitialTabs = YES;
  [self newTabWithURL:@"about:blank"];

  NSInteger initialTabCount = [self initialTabCount];
  for (NSInteger index = 1; index < initialTabCount; index += 1) {
    [self newTabWithURL:@"about:blank"];
  }
  [self selectTabAtIndex:0];
}

- (void)buildInterface {
  self.rootView = [[WindowDragView alloc] initWithFrame:self.window.contentView.bounds];
  self.rootView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  self.rootView.wantsLayer = YES;
  self.rootView.layer.backgroundColor = NSColor.blackColor.CGColor;

  self.toolbarView = [[WindowDragView alloc] initWithFrame:NSMakeRect(0,
                                                                      NSHeight(self.rootView.bounds) - kToolbarHeight,
                                                                      NSWidth(self.rootView.bounds),
                                                                      kToolbarHeight)];
  self.toolbarView.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;
  self.toolbarView.wantsLayer = YES;
  self.toolbarView.layer.backgroundColor = [NSColor colorWithCalibratedWhite:0.035 alpha:1.0].CGColor;

  self.tabStrip = [[NSStackView alloc] initWithFrame:NSZeroRect];
  self.tabStrip.orientation = NSUserInterfaceLayoutOrientationHorizontal;
  self.tabStrip.spacing = 6.0;
  self.tabStrip.distribution = NSStackViewDistributionFillEqually;

  self.backButton = [self iconButton:@"chevron.left" action:@selector(goBack:)];
  self.forwardButton = [self iconButton:@"chevron.right" action:@selector(goForward:)];
  self.reloadButton = [self iconButton:@"arrow.clockwise" action:@selector(reload:)];
  self.addTabButton = [self iconButton:@"plus" action:@selector(newTab:)];

  self.locationField = [[LocationTextField alloc] initWithFrame:NSZeroRect];
  self.locationField.cell = [[LocationTextFieldCell alloc] initTextCell:@""];
  self.locationField.delegate = self;
  self.locationField.editable = YES;
  self.locationField.selectable = YES;
  self.locationField.bezeled = NO;
  self.locationField.bordered = NO;
  self.locationField.drawsBackground = NO;
  self.locationField.focusRingType = NSFocusRingTypeNone;
  self.locationField.wantsLayer = YES;
  self.locationField.layer.backgroundColor = [NSColor colorWithCalibratedWhite:0.10 alpha:1.0].CGColor;
  self.locationField.layer.borderColor = [NSColor colorWithCalibratedWhite:0.16 alpha:1.0].CGColor;
  self.locationField.layer.borderWidth = 1.0;
  self.locationField.layer.cornerRadius = kLocationFieldCornerRadius;
  self.locationField.layer.masksToBounds = YES;
  self.locationField.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
  self.locationField.font = [NSFont systemFontOfSize:13 weight:NSFontWeightRegular];
  self.locationField.textColor = NSColor.whiteColor;
  self.locationField.placeholderAttributedString =
      [[NSAttributedString alloc] initWithString:@"Search or enter address"
                                      attributes:@{
                                        NSForegroundColorAttributeName :
                                            [NSColor colorWithCalibratedWhite:0.50 alpha:1.0]
                                      }];

  self.browserHostView = [[NSView alloc] initWithFrame:NSMakeRect(0,
                                                                  0,
                                                                  NSWidth(self.rootView.bounds),
                                                                  NSHeight(self.rootView.bounds) - kToolbarHeight)];
  self.browserHostView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  self.browserHostView.wantsLayer = YES;
  self.browserHostView.layer.backgroundColor = NSColor.blackColor.CGColor;

  [self.toolbarView addSubview:self.backButton];
  [self.toolbarView addSubview:self.forwardButton];
  [self.toolbarView addSubview:self.reloadButton];
  [self.toolbarView addSubview:self.tabStrip];
  [self.toolbarView addSubview:self.addTabButton];
  [self.toolbarView addSubview:self.locationField];
  [self.rootView addSubview:self.browserHostView];
  [self.rootView addSubview:self.toolbarView];
  self.window.contentView = self.rootView;
  [self layoutToolbarControls];
}

- (void)layoutToolbarControls {
  const CGFloat toolbarWidth = NSWidth(self.toolbarView.bounds);
  const CGFloat backButtonX = kWindowControlsReservedWidth + kToolbarGap;
  const CGFloat forwardButtonX = backButtonX + kButtonSize + 4.0;
  const CGFloat reloadButtonX = forwardButtonX + kButtonSize + 4.0;
  const CGFloat tabStripX = reloadButtonX + kButtonSize + kToolbarGap;

  CGFloat locationFieldWidth = MIN(kLocationFieldMaxWidth, toolbarWidth * 0.42);
  locationFieldWidth = MAX(kLocationFieldMinWidth, locationFieldWidth);
  CGFloat locationFieldX = toolbarWidth - kToolbarSidePadding - locationFieldWidth;
  CGFloat newTabButtonX = locationFieldX - kToolbarGap - kButtonSize;
  CGFloat tabStripWidth = newTabButtonX - kToolbarGap - tabStripX;

  if (tabStripWidth < kTabStripMinWidth) {
    tabStripWidth = kTabStripMinWidth;
    newTabButtonX = tabStripX + tabStripWidth + kToolbarGap;
    locationFieldX = newTabButtonX + kButtonSize + kToolbarGap;
    locationFieldWidth = MAX(kLocationFieldMinWidth,
                             toolbarWidth - locationFieldX - kToolbarSidePadding);
  }

  self.backButton.frame = NSMakeRect(backButtonX, kToolbarButtonY, kButtonSize, kButtonSize);
  self.forwardButton.frame = NSMakeRect(forwardButtonX, kToolbarButtonY, kButtonSize, kButtonSize);
  self.reloadButton.frame = NSMakeRect(reloadButtonX, kToolbarButtonY, kButtonSize, kButtonSize);
  self.tabStrip.frame = NSMakeRect(tabStripX, kToolbarButtonY, tabStripWidth, 28.0);
  self.addTabButton.frame = NSMakeRect(newTabButtonX, kToolbarButtonY, kButtonSize, kButtonSize);
  self.locationField.frame = NSMakeRect(locationFieldX, kToolbarButtonY, locationFieldWidth, 28.0);
}

- (void)offsetWindowControlsIfNeeded {
  if (self.didOffsetWindowControls) {
    return;
  }

  NSArray<NSNumber *> *buttonTypes = @[
    @((NSInteger)NSWindowCloseButton),
    @((NSInteger)NSWindowMiniaturizeButton),
    @((NSInteger)NSWindowZoomButton),
  ];

  for (NSNumber *buttonType in buttonTypes) {
    NSButton *button = [self.window standardWindowButton:(NSWindowButton)buttonType.integerValue];
    NSView *superview = button.superview;
    if (!superview) {
      continue;
    }

    NSRect frame = button.frame;
    frame.origin.x += kWindowControlOffset;
    frame.origin.y += superview.isFlipped ? kWindowControlOffset : -kWindowControlOffset;
    button.frame = frame;
  }

  self.didOffsetWindowControls = YES;
}

- (NSButton *)iconButton:(NSString *)symbolName action:(SEL)action {
  NSButton *button = [[WindowDragButton alloc] initWithFrame:NSMakeRect(0, 0, kButtonSize, kButtonSize)];
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
    TabButton *button = [[TabButton alloc] initWithFrame:NSMakeRect(0, 0, 0, 28)];
    button.tag = static_cast<NSInteger>(index);
    button.dragDelegate = self;
    button.title = tab.title.length > 0 ? tab.title : @"New Tab";
    button.font = [NSFont systemFontOfSize:12 weight:NSFontWeightMedium];
    button.lineBreakMode = NSLineBreakByTruncatingTail;
    button.bezelStyle = index == static_cast<NSUInteger>(self.selectedIndex)
                            ? NSBezelStyleTexturedRounded
                            : NSBezelStyleRegularSquare;
    [button setContentHuggingPriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];
    [button setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow
                                    forOrientation:NSLayoutConstraintOrientationHorizontal];
    [button.heightAnchor constraintEqualToConstant:28].active = YES;
    [self.tabStrip addArrangedSubview:button];
  }];
}

- (void)updateTabButtonState {
  NSArray<NSView *> *buttons = self.tabStrip.arrangedSubviews;
  [buttons enumerateObjectsUsingBlock:^(NSView *view, NSUInteger index, BOOL *stop) {
    (void)stop;
    if (![view isKindOfClass:NSButton.class] || index >= self.tabs.count) {
      return;
    }

    NSButton *button = (NSButton *)view;
    BrowserTab *tab = self.tabs[index];
    button.tag = static_cast<NSInteger>(index);
    button.title = tab.title.length > 0 ? tab.title : @"New Tab";
    button.bezelStyle = index == static_cast<NSUInteger>(self.selectedIndex)
                            ? NSBezelStyleTexturedRounded
                            : NSBezelStyleRegularSquare;
  }];
}

- (NSInteger)tabIndexForWindowPoint:(NSPoint)windowPoint {
  NSUInteger tabCount = self.tabStrip.arrangedSubviews.count;
  if (tabCount == 0) {
    return NSNotFound;
  }

  NSPoint tabStripPoint = [self.tabStrip convertPoint:windowPoint fromView:nil];
  NSArray<NSView *> *buttons = self.tabStrip.arrangedSubviews;
  for (NSUInteger index = 0; index < tabCount; index += 1) {
    NSView *button = buttons[index];
    if (tabStripPoint.x < NSMidX(button.frame)) {
      return static_cast<NSInteger>(index);
    }
  }
  return static_cast<NSInteger>(tabCount - 1);
}

- (NSInteger)moveTabFromIndex:(NSInteger)fromIndex toIndex:(NSInteger)toIndex {
  NSInteger tabCount = static_cast<NSInteger>(self.tabs.count);
  if (fromIndex < 0 || fromIndex >= tabCount || toIndex < 0 || toIndex >= tabCount) {
    return fromIndex;
  }

  if (fromIndex == toIndex) {
    return fromIndex;
  }

  BrowserTab *tab = self.tabs[fromIndex];
  [self.tabs removeObjectAtIndex:fromIndex];
  [self.tabs insertObject:tab atIndex:toIndex];

  NSView *tabButton = self.tabStrip.arrangedSubviews[fromIndex];
  [self.tabStrip removeArrangedSubview:tabButton];
  [self.tabStrip insertArrangedSubview:tabButton atIndex:toIndex];

  if (self.selectedIndex == fromIndex) {
    self.selectedIndex = toIndex;
  } else if (fromIndex < self.selectedIndex && toIndex >= self.selectedIndex) {
    self.selectedIndex -= 1;
  } else if (fromIndex > self.selectedIndex && toIndex <= self.selectedIndex) {
    self.selectedIndex += 1;
  }

  [self updateTabButtonState];
  [self.tabStrip layoutSubtreeIfNeeded];
  return toIndex;
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
  [self closeTabAtIndex:self.selectedIndex];
}

- (void)closeTabAtIndex:(NSInteger)index {
  if (index < 0 || index >= static_cast<NSInteger>(self.tabs.count)) {
    return;
  }

  [self.tabs[index] close];
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

  if (commandSelector == @selector(selectAll:)) {
    [textView selectAll:nil];
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

  BrowserTab *selectedBeforeClose = self.selectedTab;
  BOOL didCloseSelectedTab = tab == selectedBeforeClose;
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

  if (!didCloseSelectedTab && selectedBeforeClose) {
    NSUInteger selectedIndex = [self.tabs indexOfObject:selectedBeforeClose];
    if (selectedIndex != NSNotFound) {
      self.selectedIndex = static_cast<NSInteger>(selectedIndex);
      [self reloadTabStrip];
      return;
    }
  }

  NSInteger nextIndex = MIN(static_cast<NSInteger>(index), static_cast<NSInteger>(self.tabs.count - 1));
  self.selectedIndex = NSNotFound;
  [self selectTabAtIndex:nextIndex];
}

@end

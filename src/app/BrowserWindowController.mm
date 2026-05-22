#import "BrowserWindowController.h"

#include <cstdlib>

namespace {
constexpr CGFloat kToolbarHeight = 42.0;
constexpr CGFloat kTabWidth = 168.0;
constexpr CGFloat kButtonSize = 28.0;
}

@interface BrowserWindowController ()

@property(nonatomic, strong) NSView *rootView;
@property(nonatomic, strong) NSView *toolbarView;
@property(nonatomic, strong) NSStackView *tabStrip;
@property(nonatomic, strong) NSTextField *locationField;
@property(nonatomic, strong) NSView *browserHostView;
@property(nonatomic, strong) NSMutableArray<BrowserTab *> *tabs;
@property(nonatomic) NSInteger selectedIndex;
@property(nonatomic, copy) NSString *storageRoot;

@end

@implementation BrowserWindowController

- (instancetype)init {
  NSRect frame = NSMakeRect(0, 0, 1280, 820);
  NSWindow *window = [[NSWindow alloc] initWithContentRect:frame
                                                 styleMask:NSWindowStyleMaskTitled |
                                                           NSWindowStyleMaskClosable |
                                                           NSWindowStyleMaskMiniaturizable |
                                                           NSWindowStyleMaskResizable |
                                                           NSWindowStyleMaskFullSizeContentView
                                                   backing:NSBackingStoreBuffered
                                                     defer:NO];
  window.title = @"Fakend Browser";
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
  [self buildInterface];
  [self newTabWithURL:@"https://example.com"];

  return self;
}

- (void)windowDidLoad {
  [super windowDidLoad];
  [self.window center];
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

  self.tabStrip = [[NSStackView alloc] initWithFrame:NSMakeRect(80, 7, 520, 28)];
  self.tabStrip.orientation = NSUserInterfaceLayoutOrientationHorizontal;
  self.tabStrip.spacing = 6.0;
  self.tabStrip.distribution = NSStackViewDistributionGravityAreas;

  NSButton *backButton = [self iconButton:@"chevron.left" action:@selector(goBack:)];
  backButton.frame = NSMakeRect(8, 7, kButtonSize, kButtonSize);
  NSButton *forwardButton = [self iconButton:@"chevron.right" action:@selector(goForward:)];
  forwardButton.frame = NSMakeRect(40, 7, kButtonSize, kButtonSize);
  NSButton *newTabButton = [self iconButton:@"plus" action:@selector(newTab:)];
  newTabButton.frame = NSMakeRect(608, 7, kButtonSize, kButtonSize);

  self.locationField = [[NSTextField alloc] initWithFrame:NSMakeRect(646,
                                                                     7,
                                                                     NSWidth(self.toolbarView.bounds) - 658,
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
  self.locationField.stringValue = selected.displayURL ?: @"";
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

- (void)controlTextDidEndEditing:(NSNotification *)notification {
  if (notification.object == self.locationField) {
    [self.selectedTab loadURLString:self.locationField.stringValue];
  }
}

- (void)browserTabDidUpdate:(BrowserTab *)tab {
  if (tab == self.selectedTab) {
    self.locationField.stringValue = tab.displayURL ?: @"";
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
    [self.window close];
    return;
  }

  NSInteger nextIndex = MIN(static_cast<NSInteger>(index), static_cast<NSInteger>(self.tabs.count - 1));
  self.selectedIndex = NSNotFound;
  [self selectTabAtIndex:nextIndex];
}

@end

/**
 * AppController.mm
 * ScintillaTest
 *
 * Created by Mike Lischke on 01.04.09.
 * Copyright 2009 Sun Microsystems, Inc. All rights reserved.
 * This file is dual licensed under LGPL v2.1 and the Scintilla license (http://www.scintilla.org/License.txt).
 */

#import "AppController.h"
#include <dispatch/dispatch.h>
#include <string.h>

@interface NPPDocument : NSObject
@property(nonatomic, retain) ScintillaView *editor;
@property(nonatomic, retain) NSTabViewItem *tabItem;
@property(nonatomic, retain) NSString *filePath;
@property(nonatomic, assign) NSStringEncoding encoding;
@property(nonatomic, assign) BOOL dirty;
@property(nonatomic, assign) BOOL metadataDirty;
@property(nonatomic, assign) BOOL untitled;
@property(nonatomic, assign) NSUInteger untitledIndex;
@end

@implementation NPPDocument
@synthesize editor;
@synthesize tabItem;
@synthesize filePath;
@synthesize encoding;
@synthesize dirty;
@synthesize metadataDirty;
@synthesize untitled;
@synthesize untitledIndex;

- (void) dealloc
{
	[editor release];
	[tabItem release];
	[filePath release];
	[super dealloc];
}
@end

//--------------------------------------------------------------------------------------------------

static NSString *const kNppMacSessionDefaultsKey = @"NPPMacSessionV2";
static NSString *const kNppMacSessionDocsKey = @"documents";
static NSString *const kNppMacSessionSelectedIndexKey = @"selectedIndex";
static NSString *const kNppMacSessionProjectRootsKey = @"projectRoots";
static NSString *const kNppMacSessionWordWrapKey = @"wordWrap";
static NSString *const kNppMacSessionShowWhitespaceKey = @"showWhitespace";
static NSString *const kNppMacSessionShowEolKey = @"showEol";
static NSString *const kNppMacSessionShowLineNumbersKey = @"showLineNumbers";
static NSString *const kNppMacPrefRestoreSessionKey = @"NPPMacPrefRestoreSession";
static NSString *const kNppMacPrefShowToolbarKey = @"NPPMacPrefShowToolbar";
static NSString *const kNppMacPrefShowStatusBarKey = @"NPPMacPrefShowStatusBar";
static NSString *const kNppMacPrefShowSidebarKey = @"NPPMacPrefShowSidebar";
static NSString *const kNppMacPrefDefaultWordWrapKey = @"NPPMacPrefDefaultWordWrap";
static NSString *const kNppMacPrefDefaultLineNumbersKey = @"NPPMacPrefDefaultLineNumbers";
static NSString *const kNppMacMacroCompatibilityFolder = @"~/.nppmac";
static NSString *const kNppMacMacroCompatibilityFile = @"shortcuts.xml";

static NSString *const kToolbarNewID = @"npp.toolbar.new";
static NSString *const kToolbarOpenID = @"npp.toolbar.open";
static NSString *const kToolbarSaveID = @"npp.toolbar.save";
static NSString *const kToolbarSearchID = @"npp.toolbar.search";
static NSString *const kToolbarReplaceID = @"npp.toolbar.replace";
static NSString *const kToolbarSidebarID = @"npp.toolbar.sidebar";
static NSString *const kToolbarMacroRecordID = @"npp.toolbar.macrorecord";
static NSString *const kToolbarMacroPlayID = @"npp.toolbar.macroplay";

static NSInteger const kMenuTagWordWrap = 9101;
static NSInteger const kMenuTagShowWhitespace = 9102;
static NSInteger const kMenuTagShowEol = 9103;
static NSInteger const kMenuTagShowLineNumbers = 9104;
static NSInteger const kMenuTagLiveTail = 9105;
static NSInteger const kMenuTagSplitScreen = 9106;
static NSInteger const kMenuTagDocumentMap = 9107;
static NSInteger const kMenuTagEolWindows = 9201;
static NSInteger const kMenuTagEolUnix = 9202;
static NSInteger const kMenuTagEolMac = 9203;
static NSInteger const kMenuTagEncodingUtf8 = 9301;
static NSInteger const kMenuTagEncodingUtf16LE = 9302;
static NSInteger const kMenuTagEncodingUtf16BE = 9303;
static NSInteger const kMenuTagEncodingIso88591 = 9304;
static NSInteger const kMenuTagEncodingWindows1252 = 9305;
static NSInteger const kMenuTagEncodingWindows1251 = 9306;
static NSInteger const kMenuTagEncodingShiftJis = 9307;
static NSInteger const kMenuTagEncodingGb18030 = 9308;
static NSInteger const kMenuTagEncodingBig5 = 9309;
static NSInteger const kMenuTagEncodingEucKr = 9310;
static NSInteger const kMenuTagMacroRecord = 9401;
static NSInteger const kMenuTagMacroPlay = 9402;
static NSInteger const kMenuTagMacroSaveRecorded = 9403;
static NSInteger const kMenuTagMacroRepeat = 9404;
static NSInteger const kMenuTagMacroSeparator = 9405;
static NSInteger const kMenuTagMacroPlaceholder = 9406;
static NSInteger const kMenuTagMacroDynamicBase = 9500;
static NSInteger const kMenuTagAutosave = 9601;

static NSTimeInterval const kNppMacAutosaveIntervalSeconds = 5.0;

typedef void (*NppMacPluginInitFn)(void *context);
typedef void (*NppMacPluginDeinitFn)(void *context);
typedef const char *(*NppMacPluginNameFn)(void);
typedef void (*NppMacPluginRunFn)(void *context);
typedef int (*NppMacPluginApiVersionFn)(void);
typedef int (*NppMacPluginCommandCountFn)(void);
typedef const char *(*NppMacPluginCommandNameFn)(int index);
typedef const char *(*NppMacPluginCommandIdFn)(int index);
typedef void (*NppMacPluginRunCommandFn)(int index, void *context);

static NSStringEncoding nppEncodingWindows1252()
{
	return CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingWindowsLatin1);
}

static NSStringEncoding nppEncodingWindows1251()
{
	return CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingWindowsCyrillic);
}

static NSStringEncoding nppEncodingShiftJis()
{
	return CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingShiftJIS);
}

static NSStringEncoding nppEncodingGb18030()
{
	return CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000);
}

static NSStringEncoding nppEncodingBig5()
{
	return CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingBig5);
}

static NSStringEncoding nppEncodingEucKr()
{
	return CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingEUC_KR);
}

@interface AppController ()
- (void) configureTabHost;
- (void) wireMenuActions;
- (void) wireRuntimeFeatureMenus;
- (void) setupToolbar;
- (void) loadLexilla;
- (void) updateDocumentTabs;
- (void) updateWindowTitle;
- (void) updateStatusBar;
- (void) refreshEditorState: (NSTimer *) timer;
- (void) refreshUiToggles;
- (void) applyDisplayFlagsToEditor: (ScintillaView *) editor;
- (void) ensureExtraEditorForCurrentDocument;
- (void) removeExtraEditor;
- (void) layoutActiveEditorViews;
- (void) refreshExtraEditorState;
- (void) clearComparisonMarkers;
- (void) applyComparisonMarkersBetweenEditor: (ScintillaView *) left rightEditor: (ScintillaView *) right;
- (void) runAutosaveIfNeeded;

- (void) saveSessionState;
- (BOOL) restoreSessionState;

- (NPPDocument *) createUntitledDocument;
- (NPPDocument *) createDocumentWithText: (NSString *) text
								path: (NSString *) path
								encoding: (NSStringEncoding) encoding;
- (ScintillaView *) createEditorInView: (NSView *) host withText: (NSString *) text;

- (NPPDocument *) currentDocument;
- (NPPDocument *) documentForTabItem: (NSTabViewItem *) tabItem;
- (NPPDocument *) documentForPath: (NSString *) path;

- (void) selectDocument: (NPPDocument *) document;
- (BOOL) canCloseDocument: (NPPDocument *) document;
- (BOOL) saveDocument: (NPPDocument *) document forceSaveAs: (BOOL) forceSaveAs;
- (BOOL) openPath: (NSString *) path;

- (NSString *) titleForDocument: (NPPDocument *) document;
- (NSString *) lexerNameForDocument: (NPPDocument *) document;
- (void) applyLexerToDocument: (NPPDocument *) document;
- (NSInteger) currentEolModeForDocument: (NPPDocument *) document;
- (NSString *) encodingLabelForDocument: (NPPDocument *) document;
- (void) refreshFunctionList;
- (void) refreshProjectEntries;
- (NSArray *) projectFilesMatchingFilter: (NSString *) filter;
- (void) addProjectRootPath: (NSString *) rootPath;
- (void) projectPanelActivated: (id) sender;
- (void) functionPanelActivated: (id) sender;

- (void) findNextBackwards: (BOOL) backwards;
- (void) applyEncoding: (NSStringEncoding) encoding toCurrentDocumentWithName: (NSString *) encodingName;
- (void) convertEolToMode: (NSInteger) eolMode;
- (void) ensureSearchPanel;
- (void) updateSearchScopeUiState;
- (NSInteger) currentSearchFlagsFromPanel;
- (void) searchPanelFindNext: (id) sender;
- (void) searchPanelFindAll: (id) sender;
- (void) searchPanelReplace: (id) sender;
- (void) searchPanelReplaceAll: (id) sender;
- (void) searchPanelMarkAll: (id) sender;
- (NSArray *) rangesForQuery: (NSString *) query inText: (NSString *) text regex: (BOOL) regex matchCase: (BOOL) matchCase wholeWord: (BOOL) wholeWord;
- (BOOL) isWordBoundaryAtIndex: (NSUInteger) index inText: (NSString *) text;
- (void) selectRange: (NSRange) range inEditor: (ScintillaView *) editor;
- (NSArray *) searchFilterTokensFromString: (NSString *) filter;
- (BOOL) filePath: (NSString *) path matchesFilterTokens: (NSArray *) tokens;
- (NSArray *) filesInFolder: (NSString *) folderPath matchingFilter: (NSString *) filter;
- (NSArray *) filesForSearchScope: (NSInteger) scope;

- (void) ensurePreferencesWindow;
- (void) applyPreferences;
- (void) preferencesApplyAndClose: (id) sender;
- (void) preferencesCancel: (id) sender;

- (void) setupPluginsMenu;
- (void) loadPluginsFromDefaultLocations;
- (void) invokePluginCommand: (id) sender;
- (void) executeMacroSteps: (NSArray *) steps repeatCount: (NSUInteger) repeatCount;
- (NSString *) macroCompatibilityPath;
- (void) loadMacrosFromCompatibilityFile;
- (void) saveMacrosToCompatibilityFile;
- (void) updateMacroMenuState;

- (NSString *) promptForStringWithTitle: (NSString *) title
									message: (NSString *) message
								defaultValue: (NSString *) defaultValue;
- (BOOL) readTextFileAtPath: (NSString *) path
					content: (NSString **) outContent
				usedEncoding: (NSStringEncoding *) outEncoding
					   error: (NSError **) outError;
- (NSStringEncoding) detectEncodingForData: (NSData *) data fallbackEncoding: (NSStringEncoding) fallbackEncoding;
- (BOOL) isLikelyUtf8Data: (NSData *) data;
- (double) printableRatioForString: (NSString *) text;
- (void) toggleLiveTailEnabled: (BOOL) enabled;
- (void) resetLiveTailTrackingForCurrentDocument;
- (void) refreshLiveTail;
- (NSRange) currentSelectionRangeInEditor: (ScintillaView *) editor;
- (void) replaceSelectedOrWholeTextInCurrentDocumentUsingBlock: (NSString *(^)(NSString *input, NSRange range, BOOL *didChange)) transform;
- (NSString *) camelCaseFromString: (NSString *) source;
@end

@implementation AppController

- (void) dealloc
{
	for (NSDictionary *plugin in mPluginDescriptors) {
		NSValue *deinitValue = [plugin objectForKey: @"deinit"];
		NSValue *handleValue = [plugin objectForKey: @"handle"];
		NppMacPluginDeinitFn deinitFn = NULL;
		if ([deinitValue isKindOfClass: [NSValue class]])
			[deinitValue getValue: &deinitFn];
		void *handle = [handleValue pointerValue];
		if (deinitFn != NULL)
			deinitFn(self);
		if (handle != NULL)
			dlclose(handle);
	}

	[mStateTimer invalidate];
	[mStateTimer release];
	[mLastSearch release];
	[mDocuments release];
	[mFunctionEntries release];
	[mProjectEntries release];
	[mProjectRootPaths release];
	[mMacroSteps release];
	[mNamedMacros release];
	[mPluginDescriptors release];
	[mSearchPanel release];
	[mPreferencesWindow release];
	[mMainToolbar release];
	[mLiveTailPath release];
	[mLiveTailLastModificationDate release];
	[mComparedFilePath release];

	if (mLexillaDL != NULL)
		dlclose(mLexillaDL);

	[super dealloc];
}

- (void) awakeFromNib
{
	mDocuments = [[NSMutableArray alloc] init];
	mFunctionEntries = [[NSMutableArray alloc] init];
	mProjectEntries = [[NSMutableArray alloc] init];
	mProjectRootPaths = [[NSMutableArray alloc] init];
	mMacroSteps = [[NSMutableArray alloc] init];
	mNamedMacros = [[NSMutableArray alloc] init];
	mPluginDescriptors = [[NSMutableArray alloc] init];

	mUntitledCounter = 1;
	mLexillaDL = NULL;
	mCreateLexer = nullptr;
	mEditor = nil;
	sciExtra = nil;
	mMacroRecording = NO;

	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	BOOL prefDefaultWordWrap = [defaults objectForKey: kNppMacPrefDefaultWordWrapKey] ? [defaults boolForKey: kNppMacPrefDefaultWordWrapKey] : NO;
	BOOL prefDefaultLineNumbers = [defaults objectForKey: kNppMacPrefDefaultLineNumbersKey] ? [defaults boolForKey: kNppMacPrefDefaultLineNumbersKey] : YES;
	mWordWrap = prefDefaultWordWrap;
	mShowWhitespace = NO;
	mShowEol = NO;
	mShowLineNumbers = prefDefaultLineNumbers;
	mLiveTailEnabled = NO;
	mLiveTailPath = nil;
	mLiveTailKnownLength = 0;
	mLiveTailLastModificationDate = nil;
	mSplitViewEnabled = NO;
	mDocumentMapVisible = NO;
	mAutosaveEnabled = YES;
	mNextAutosaveTime = [NSDate timeIntervalSinceReferenceDate] + kNppMacAutosaveIntervalSeconds;
	mComparedFilePath = nil;
	mSidebarVisible = [defaults objectForKey: kNppMacPrefShowSidebarKey] ? [defaults boolForKey: kNppMacPrefShowSidebarKey] : YES;
	mStatusBarVisible = [defaults objectForKey: kNppMacPrefShowStatusBarKey] ? [defaults boolForKey: kNppMacPrefShowStatusBarKey] : YES;

	[NSApp setDelegate: self];

	[self configureTabHost];
	[self wireMenuActions];
	[self wireRuntimeFeatureMenus];
	[self setupToolbar];
	[self setupPluginsMenu];
	[self loadLexilla];
	[self loadMacrosFromCompatibilityFile];
	[self loadPluginsFromDefaultLocations];

	BOOL restoreSessionEnabled = [defaults objectForKey: kNppMacPrefRestoreSessionKey] ? [defaults boolForKey: kNppMacPrefRestoreSessionKey] : YES;
	if (!(restoreSessionEnabled && [self restoreSessionState]))
		[self createUntitledDocument];

	[self updateDocumentTabs];
	[self updateWindowTitle];
	[self updateStatusBar];
	[self refreshFunctionList];
	[self refreshProjectEntries];
	[self updateMacroMenuState];
	[self refreshUiToggles];

	mStateTimer = [[NSTimer scheduledTimerWithTimeInterval: 0.2
												   target: self
												 selector: @selector(refreshEditorState:)
												 userInfo: nil
											repeats: YES] retain];
}

- (void) configureTabHost
{
	NSView *contentView = [mEditHost contentView];
	NSArray *existingSubviews = [[contentView subviews] copy];
	for (NSView *subview in existingSubviews) {
		[subview removeFromSuperview];
	}
	[existingSubviews release];

	CGFloat statusHeight = mStatusBarVisible ? 22.0 : 0.0;
	NSRect bounds = [contentView bounds];
	NSRect splitFrame = bounds;
	splitFrame.size.height = MAX(0.0, splitFrame.size.height - statusHeight);

	mWorkspaceSplitView = [[[NSSplitView alloc] initWithFrame: splitFrame] autorelease];
	[mWorkspaceSplitView setVertical: YES];
	[mWorkspaceSplitView setDividerStyle: NSSplitViewDividerStyleThin];
	[mWorkspaceSplitView setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];
	[contentView addSubview: mWorkspaceSplitView];

	NSView *sidebarContainer = [[[NSView alloc] initWithFrame: NSMakeRect(0, 0, 260, splitFrame.size.height)] autorelease];
	[sidebarContainer setAutoresizingMask: NSViewHeightSizable];
	[mWorkspaceSplitView addSubview: sidebarContainer];

	mSidebarTabView = [[[NSTabView alloc] initWithFrame: [sidebarContainer bounds]] autorelease];
	[mSidebarTabView setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];
	[sidebarContainer addSubview: mSidebarTabView];

	NSScrollView *projectScroll = [[[NSScrollView alloc] initWithFrame: [sidebarContainer bounds]] autorelease];
	[projectScroll setHasVerticalScroller: YES];
	[projectScroll setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];
	mProjectTableView = [[[NSTableView alloc] initWithFrame: [projectScroll bounds]] autorelease];
	NSTableColumn *projectColumn = [[[NSTableColumn alloc] initWithIdentifier: @"project"] autorelease];
	[projectColumn setTitle: @"Project"];
	[projectColumn setWidth: 240];
	[mProjectTableView addTableColumn: projectColumn];
	[mProjectTableView setHeaderView: nil];
	[mProjectTableView setDataSource: self];
	[mProjectTableView setDelegate: self];
	[mProjectTableView setTarget: self];
	[mProjectTableView setDoubleAction: @selector(projectPanelActivated:)];
	[projectScroll setDocumentView: mProjectTableView];

	NSTabViewItem *projectTab = [[[NSTabViewItem alloc] initWithIdentifier: @"projectTab"] autorelease];
	[projectTab setLabel: @"Project"];
	[projectTab setView: projectScroll];
	[mSidebarTabView addTabViewItem: projectTab];

	NSScrollView *functionScroll = [[[NSScrollView alloc] initWithFrame: [sidebarContainer bounds]] autorelease];
	[functionScroll setHasVerticalScroller: YES];
	[functionScroll setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];
	mFunctionTableView = [[[NSTableView alloc] initWithFrame: [functionScroll bounds]] autorelease];
	NSTableColumn *functionColumn = [[[NSTableColumn alloc] initWithIdentifier: @"function"] autorelease];
	[functionColumn setTitle: @"Function"];
	[functionColumn setWidth: 240];
	[mFunctionTableView addTableColumn: functionColumn];
	[mFunctionTableView setHeaderView: nil];
	[mFunctionTableView setDataSource: self];
	[mFunctionTableView setDelegate: self];
	[mFunctionTableView setTarget: self];
	[mFunctionTableView setDoubleAction: @selector(functionPanelActivated:)];
	[functionScroll setDocumentView: mFunctionTableView];

	NSTabViewItem *functionTab = [[[NSTabViewItem alloc] initWithIdentifier: @"functionTab"] autorelease];
	[functionTab setLabel: @"Function List"];
	[functionTab setView: functionScroll];
	[mSidebarTabView addTabViewItem: functionTab];

	mEditorHost = [[[NSView alloc] initWithFrame: NSMakeRect(260, 0, splitFrame.size.width - 260, splitFrame.size.height)] autorelease];
	[mEditorHost setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];
	[mWorkspaceSplitView addSubview: mEditorHost];

	[mWorkspaceSplitView adjustSubviews];
	if (!mSidebarVisible) {
		[sidebarContainer setHidden: YES];
		[mWorkspaceSplitView setPosition: 0 ofDividerAtIndex: 0];
	} else {
		[mWorkspaceSplitView setPosition: 260 ofDividerAtIndex: 0];
	}

	mTabView = [[[NSTabView alloc] initWithFrame: [mEditorHost bounds]] autorelease];
	[mTabView setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];
	[mTabView setDelegate: self];
	[mTabView setTabViewType: NSTopTabsBezelBorder];
	[mEditorHost addSubview: mTabView];

	mStatusBar = [[[NSTextField alloc] initWithFrame: NSMakeRect(0, 0, bounds.size.width, 22)] autorelease];
	[mStatusBar setEditable: NO];
	[mStatusBar setBordered: NO];
	[mStatusBar setDrawsBackground: YES];
	[mStatusBar setBackgroundColor: [NSColor colorWithCalibratedWhite: 0.95 alpha: 1.0]];
	[mStatusBar setAutoresizingMask: NSViewWidthSizable | NSViewMaxYMargin];
	[mStatusBar setFont: [NSFont systemFontOfSize: 11]];
	[mStatusBar setHidden: !mStatusBarVisible];
	[mStatusBar setStringValue: @"Ready"];
	[contentView addSubview: mStatusBar];
}

- (void) setupToolbar
{
	NSWindow *window = [mEditHost window];
	if (window == nil)
		return;

	if (mMainToolbar == nil) {
		mMainToolbar = [[NSToolbar alloc] initWithIdentifier: @"NppMacToolbar"];
		[mMainToolbar setDelegate: self];
		[mMainToolbar setAllowsUserCustomization: YES];
		[mMainToolbar setAutosavesConfiguration: YES];
		[mMainToolbar setDisplayMode: NSToolbarDisplayModeIconOnly];
	}

	[window setToolbar: mMainToolbar];
	BOOL showToolbar = [[NSUserDefaults standardUserDefaults] objectForKey: kNppMacPrefShowToolbarKey]
		? [[NSUserDefaults standardUserDefaults] boolForKey: kNppMacPrefShowToolbarKey]
		: YES;
	[mMainToolbar setVisible: showToolbar];
}

- (NSArray *) toolbarAllowedItemIdentifiers: (NSToolbar *) toolbar
{
	#pragma unused(toolbar)
	return [NSArray arrayWithObjects:
		kToolbarNewID,
		kToolbarOpenID,
		kToolbarSaveID,
		NSToolbarFlexibleSpaceItemIdentifier,
		kToolbarSearchID,
		kToolbarReplaceID,
		kToolbarSidebarID,
		NSToolbarFlexibleSpaceItemIdentifier,
		kToolbarMacroRecordID,
		kToolbarMacroPlayID,
		NSToolbarSpaceItemIdentifier,
		NSToolbarCustomizeToolbarItemIdentifier,
		nil];
}

- (NSArray *) toolbarDefaultItemIdentifiers: (NSToolbar *) toolbar
{
	#pragma unused(toolbar)
	return [NSArray arrayWithObjects:
		kToolbarNewID,
		kToolbarOpenID,
		kToolbarSaveID,
		NSToolbarFlexibleSpaceItemIdentifier,
		kToolbarSearchID,
		kToolbarReplaceID,
		kToolbarSidebarID,
		NSToolbarFlexibleSpaceItemIdentifier,
		kToolbarMacroRecordID,
		kToolbarMacroPlayID,
		nil];
}

- (NSToolbarItem *) toolbar: (NSToolbar *) toolbar
	itemForItemIdentifier: (NSString *) itemIdentifier
willBeInsertedIntoToolbar: (BOOL) flag
{
	#pragma unused(toolbar)
	#pragma unused(flag)

	NSToolbarItem *item = [[[NSToolbarItem alloc] initWithItemIdentifier: itemIdentifier] autorelease];

	if ([itemIdentifier isEqualToString: kToolbarNewID]) {
		[item setLabel: @"New"];
		[item setPaletteLabel: @"New"];
		[item setImage: [NSImage imageNamed: NSImageNameAddTemplate]];
		[item setTarget: self];
		[item setAction: @selector(newDocument:)];
	} else if ([itemIdentifier isEqualToString: kToolbarOpenID]) {
		[item setLabel: @"Open"];
		[item setPaletteLabel: @"Open"];
		[item setImage: [NSImage imageNamed: NSImageNameFolder]];
		[item setTarget: self];
		[item setAction: @selector(openDocument:)];
	} else if ([itemIdentifier isEqualToString: kToolbarSaveID]) {
		[item setLabel: @"Save"];
		[item setPaletteLabel: @"Save"];
		[item setImage: [NSImage imageNamed: NSImageNameMenuOnStateTemplate]];
		[item setTarget: self];
		[item setAction: @selector(saveDocument:)];
	} else if ([itemIdentifier isEqualToString: kToolbarSearchID]) {
		[item setLabel: @"Search"];
		[item setPaletteLabel: @"Search"];
		[item setImage: [NSImage imageNamed: NSImageNameQuickLookTemplate]];
		[item setTarget: self];
		[item setAction: @selector(showSearchDialog:)];
	} else if ([itemIdentifier isEqualToString: kToolbarReplaceID]) {
		[item setLabel: @"Replace"];
		[item setPaletteLabel: @"Replace"];
		[item setImage: [NSImage imageNamed: NSImageNameRefreshTemplate]];
		[item setTarget: self];
		[item setAction: @selector(replaceText:)];
	} else if ([itemIdentifier isEqualToString: kToolbarSidebarID]) {
		[item setLabel: @"Sidebar"];
		[item setPaletteLabel: @"Sidebar"];
		[item setImage: [NSImage imageNamed: NSImageNameListViewTemplate]];
		[item setTarget: self];
		[item setAction: @selector(toggleSidebar:)];
	} else if ([itemIdentifier isEqualToString: kToolbarMacroRecordID]) {
		[item setLabel: @"Record"];
		[item setPaletteLabel: @"Record Macro"];
		[item setImage: [NSImage imageNamed: NSImageNameStatusUnavailable]];
		[item setTarget: self];
		[item setAction: @selector(startStopMacroRecording:)];
	} else if ([itemIdentifier isEqualToString: kToolbarMacroPlayID]) {
		[item setLabel: @"Play"];
		[item setPaletteLabel: @"Play Macro"];
		[item setImage: [NSImage imageNamed: NSImageNameRightFacingTriangleTemplate]];
		[item setTarget: self];
		[item setAction: @selector(playRecordedMacro:)];
	}

	return item;
}

- (void) wireMenuActions
{
	NSMenu *mainMenu = [NSApp mainMenu];
	if (mainMenu == nil)
		return;

	NSMenuItem *fileMenuItem = [mainMenu itemWithTitle: @"File"];
	if (fileMenuItem != nil) {
		NSMenu *fileMenu = [fileMenuItem submenu];
		if ([fileMenu itemWithTitle: @"Open Project Folder..."] == nil) {
			NSMenuItem *openProject = [[[NSMenuItem alloc] initWithTitle: @"Open Project Folder..."
																action: @selector(openProjectFolder:)
														 keyEquivalent: @"o"] autorelease];
			[openProject setKeyEquivalentModifierMask: NSCommandKeyMask | NSShiftKeyMask | NSAlternateKeyMask];
			[openProject setTarget: self];
			[fileMenu insertItem: openProject atIndex: 2];
		}

		for (NSMenuItem *item in [fileMenu itemArray]) {
			NSString *key = [item keyEquivalent];
			NSUInteger mask = ([item keyEquivalentModifierMask] & (NSCommandKeyMask | NSShiftKeyMask));

			if ([key isEqualToString: @"n"] && mask == NSCommandKeyMask) {
				[item setTarget: self];
				[item setAction: @selector(newDocument:)];
			} else if ([key isEqualToString: @"o"] && mask == NSCommandKeyMask) {
				[item setTarget: self];
				[item setAction: @selector(openDocument:)];
			} else if ([key isEqualToString: @"s"] && mask == NSCommandKeyMask) {
				[item setTarget: self];
				[item setAction: @selector(saveDocument:)];
			} else if ([key isEqualToString: @"s"] && mask == (NSCommandKeyMask | NSShiftKeyMask)) {
				[item setTarget: self];
				[item setAction: @selector(saveDocumentAs:)];
			} else if ([key isEqualToString: @"w"] && mask == NSCommandKeyMask) {
				[item setTarget: self];
				[item setAction: @selector(performClose:)];
			}

			if ([[item title] hasPrefix: @"Revert"]) {
				[item setTarget: self];
				[item setAction: @selector(revertDocumentToSaved:)];
			} else if ([[item title] isEqualToString: @"Open Project Folder..."]) {
				[item setTarget: self];
				[item setAction: @selector(openProjectFolder:)];
			}
		}
	}

	NSMenuItem *appMenuItem = [mainMenu itemAtIndex: 0];
	if (appMenuItem != nil) {
		NSMenu *appMenu = [appMenuItem submenu];
		NSMenuItem *prefItem = [appMenu itemWithTitle: @"Preferences…"];
		if (prefItem != nil) {
			[prefItem setTarget: self];
			[prefItem setAction: @selector(showPreferences:)];
		}
	}

	NSMenuItem *editMenuItem = [mainMenu itemWithTitle: @"Edit"];
	if (editMenuItem == nil)
		return;

	NSMenuItem *findMenuItem = [[editMenuItem submenu] itemWithTitle: @"Find"];
	if (findMenuItem == nil)
		return;

	NSMenu *findMenu = [findMenuItem submenu];
	for (NSMenuItem *item in [findMenu itemArray]) {
		if ([item tag] == 1) {
			[item setTarget: self];
			[item setAction: @selector(showSearchDialog:)];
		} else if ([item tag] == 2 || [item tag] == 3 || [item tag] == 7) {
			[item setTarget: self];
			[item setAction: @selector(performFindPanelAction:)];
		}
	}

	if ([findMenu itemWithTitle: @"Replace..."] == nil) {
		NSMenuItem *replaceItem = [[[NSMenuItem alloc] initWithTitle: @"Replace..."
												 action: @selector(replaceText:)
										  keyEquivalent: @"h"] autorelease];
		[replaceItem setKeyEquivalentModifierMask: NSCommandKeyMask | NSAlternateKeyMask];
		[replaceItem setTarget: self];
		[findMenu insertItem: replaceItem atIndex: 1];
	}
}

- (void) wireRuntimeFeatureMenus
{
	NSMenu *mainMenu = [NSApp mainMenu];
	if (mainMenu == nil)
		return;

	NSMenuItem *editMenuItem = [mainMenu itemWithTitle: @"Edit"];
	if (editMenuItem != nil) {
		NSMenu *editMenu = [editMenuItem submenu];
		NSMenuItem *findMenuItem = [editMenu itemWithTitle: @"Find"];
		if (findMenuItem != nil) {
			NSMenu *findMenu = [findMenuItem submenu];
			if ([findMenu itemWithTitle: @"Find in Files..."] == nil) {
				[findMenu addItem: [NSMenuItem separatorItem]];
				NSMenuItem *findInFiles = [[[NSMenuItem alloc] initWithTitle: @"Find in Files..."
																	 action: @selector(findInFiles:)
															  keyEquivalent: @"f"] autorelease];
				[findInFiles setKeyEquivalentModifierMask: NSCommandKeyMask | NSShiftKeyMask];
				[findInFiles setTarget: self];
				[findMenu addItem: findInFiles];
			}

			if ([findMenu itemWithTitle: @"Go to Line..."] == nil) {
				NSMenuItem *gotoLine = [[[NSMenuItem alloc] initWithTitle: @"Go to Line..."
																	action: @selector(goToLine:)
															 keyEquivalent: @"l"] autorelease];
				[gotoLine setKeyEquivalentModifierMask: NSCommandKeyMask];
				[gotoLine setTarget: self];
				[findMenu addItem: gotoLine];
			}
		}
	}

	NSMenuItem *viewMenuItem = [mainMenu itemWithTitle: @"View"];
	if (viewMenuItem != nil) {
		NSMenu *viewMenu = [viewMenuItem submenu];
		if ([viewMenu itemWithTag: kMenuTagWordWrap] == nil) {
			[viewMenu addItem: [NSMenuItem separatorItem]];

			NSMenuItem *wordWrap = [[[NSMenuItem alloc] initWithTitle: @"Word Wrap"
															   action: @selector(toggleWordWrap:)
														keyEquivalent: @"w"] autorelease];
			[wordWrap setKeyEquivalentModifierMask: NSCommandKeyMask | NSAlternateKeyMask];
			[wordWrap setTarget: self];
			[wordWrap setTag: kMenuTagWordWrap];
			[viewMenu addItem: wordWrap];

			NSMenuItem *showWhitespace = [[[NSMenuItem alloc] initWithTitle: @"Show White Space and TAB"
																	 action: @selector(toggleWhitespaceVisibility:)
															  keyEquivalent: @""] autorelease];
			[showWhitespace setTarget: self];
			[showWhitespace setTag: kMenuTagShowWhitespace];
			[viewMenu addItem: showWhitespace];

			NSMenuItem *showEol = [[[NSMenuItem alloc] initWithTitle: @"Show End of Line"
															 action: @selector(toggleEolVisibility:)
													  keyEquivalent: @""] autorelease];
			[showEol setTarget: self];
			[showEol setTag: kMenuTagShowEol];
			[viewMenu addItem: showEol];

			NSMenuItem *lineNumberMargin = [[[NSMenuItem alloc] initWithTitle: @"Show Line Number Margin"
																		action: @selector(toggleLineNumberMargin:)
																 keyEquivalent: @""] autorelease];
			[lineNumberMargin setTarget: self];
			[lineNumberMargin setTag: kMenuTagShowLineNumbers];
			[viewMenu addItem: lineNumberMargin];

			NSMenuItem *toggleSidebarItem = [[[NSMenuItem alloc] initWithTitle: @"Toggle Sidebar"
																		action: @selector(toggleSidebar:)
																 keyEquivalent: @"0"] autorelease];
			[toggleSidebarItem setKeyEquivalentModifierMask: NSCommandKeyMask];
			[toggleSidebarItem setTarget: self];
			[viewMenu addItem: toggleSidebarItem];

			NSMenuItem *liveTailItem = [[[NSMenuItem alloc] initWithTitle: @"Tail Current File (Live Reload)"
															 action: @selector(toggleLiveTailCurrentFile:)
													  keyEquivalent: @"t"] autorelease];
			[liveTailItem setKeyEquivalentModifierMask: NSCommandKeyMask | NSAlternateKeyMask];
			[liveTailItem setTarget: self];
			[liveTailItem setTag: kMenuTagLiveTail];
			[viewMenu addItem: liveTailItem];
		}

		if ([viewMenu itemWithTag: kMenuTagLiveTail] == nil) {
			NSMenuItem *liveTailItem = [[[NSMenuItem alloc] initWithTitle: @"Tail Current File (Live Reload)"
															 action: @selector(toggleLiveTailCurrentFile:)
													  keyEquivalent: @"t"] autorelease];
			[liveTailItem setKeyEquivalentModifierMask: NSCommandKeyMask | NSAlternateKeyMask];
			[liveTailItem setTarget: self];
			[liveTailItem setTag: kMenuTagLiveTail];
			[viewMenu addItem: liveTailItem];
		}

		if ([viewMenu itemWithTag: kMenuTagSplitScreen] == nil) {
			NSMenuItem *splitItem = [[[NSMenuItem alloc] initWithTitle: @"Split Screen Editing"
															 action: @selector(toggleSplitScreen:)
													  keyEquivalent: @"2"] autorelease];
			[splitItem setKeyEquivalentModifierMask: NSCommandKeyMask | NSAlternateKeyMask];
			[splitItem setTarget: self];
			[splitItem setTag: kMenuTagSplitScreen];
			[viewMenu addItem: splitItem];
		}

		if ([viewMenu itemWithTag: kMenuTagDocumentMap] == nil) {
			NSMenuItem *documentMapItem = [[[NSMenuItem alloc] initWithTitle: @"Document Map"
																	action: @selector(toggleDocumentMap:)
															 keyEquivalent: @"3"] autorelease];
			[documentMapItem setKeyEquivalentModifierMask: NSCommandKeyMask | NSAlternateKeyMask];
			[documentMapItem setTarget: self];
			[documentMapItem setTag: kMenuTagDocumentMap];
			[viewMenu addItem: documentMapItem];
		}
	}

	NSMenuItem *formatMenuItem = [mainMenu itemWithTitle: @"Format"];
	if (formatMenuItem != nil) {
		NSMenu *formatMenu = [formatMenuItem submenu];
		if ([formatMenu itemWithTag: kMenuTagEolWindows] == nil) {
			[formatMenu addItem: [NSMenuItem separatorItem]];

			NSMenuItem *eolWindows = [[[NSMenuItem alloc] initWithTitle: @"Convert EOL to Windows (CRLF)"
																 action: @selector(convertEolToWindows:)
														  keyEquivalent: @""] autorelease];
			[eolWindows setTarget: self];
			[eolWindows setTag: kMenuTagEolWindows];
			[formatMenu addItem: eolWindows];

			NSMenuItem *eolUnix = [[[NSMenuItem alloc] initWithTitle: @"Convert EOL to Unix (LF)"
															  action: @selector(convertEolToUnix:)
													   keyEquivalent: @""] autorelease];
			[eolUnix setTarget: self];
			[eolUnix setTag: kMenuTagEolUnix];
			[formatMenu addItem: eolUnix];

			NSMenuItem *eolMac = [[[NSMenuItem alloc] initWithTitle: @"Convert EOL to Macintosh (CR)"
															 action: @selector(convertEolToMacClassic:)
													  keyEquivalent: @""] autorelease];
			[eolMac setTarget: self];
			[eolMac setTag: kMenuTagEolMac];
			[formatMenu addItem: eolMac];
		}
	}

	NSMenuItem *encodingMenuItem = [mainMenu itemWithTitle: @"Encoding"];
	NSMenu *encodingMenu = nil;
	if (encodingMenuItem == nil) {
		encodingMenuItem = [[[NSMenuItem alloc] initWithTitle: @"Encoding" action: nil keyEquivalent: @""] autorelease];
		encodingMenu = [[[NSMenu alloc] initWithTitle: @"Encoding"] autorelease];
		[encodingMenuItem setSubmenu: encodingMenu];

		NSUInteger insertIndex = [mainMenu indexOfItemWithTitle: @"Format"];
		if (insertIndex == NSNotFound)
			insertIndex = [mainMenu numberOfItems];
		else
			insertIndex += 1;
		[mainMenu insertItem: encodingMenuItem atIndex: insertIndex];
	} else {
		encodingMenu = [encodingMenuItem submenu];
		if (encodingMenu == nil) {
			encodingMenu = [[[NSMenu alloc] initWithTitle: @"Encoding"] autorelease];
			[encodingMenuItem setSubmenu: encodingMenu];
		}
	}

	if ([encodingMenu itemWithTag: kMenuTagEncodingUtf8] == nil) {
		NSMenuItem *utf8 = [[[NSMenuItem alloc] initWithTitle: @"Convert to UTF-8"
													   action: @selector(setEncodingUtf8:)
												keyEquivalent: @""] autorelease];
		[utf8 setTarget: self];
		[utf8 setTag: kMenuTagEncodingUtf8];
		[encodingMenu addItem: utf8];

		NSMenuItem *utf16le = [[[NSMenuItem alloc] initWithTitle: @"Convert to UTF-16 LE"
														  action: @selector(setEncodingUtf16LE:)
												   keyEquivalent: @""] autorelease];
		[utf16le setTarget: self];
		[utf16le setTag: kMenuTagEncodingUtf16LE];
		[encodingMenu addItem: utf16le];

		NSMenuItem *utf16be = [[[NSMenuItem alloc] initWithTitle: @"Convert to UTF-16 BE"
														  action: @selector(setEncodingUtf16BE:)
												   keyEquivalent: @""] autorelease];
		[utf16be setTarget: self];
		[utf16be setTag: kMenuTagEncodingUtf16BE];
		[encodingMenu addItem: utf16be];

		[encodingMenu addItem: [NSMenuItem separatorItem]];

		NSMenuItem *iso88591 = [[[NSMenuItem alloc] initWithTitle: @"Convert to ISO-8859-1"
														 action: @selector(setEncodingIso88591:)
												  keyEquivalent: @""] autorelease];
		[iso88591 setTarget: self];
		[iso88591 setTag: kMenuTagEncodingIso88591];
		[encodingMenu addItem: iso88591];

		NSMenuItem *windows1252 = [[[NSMenuItem alloc] initWithTitle: @"Convert to Windows-1252"
															action: @selector(setEncodingWindows1252:)
													 keyEquivalent: @""] autorelease];
		[windows1252 setTarget: self];
		[windows1252 setTag: kMenuTagEncodingWindows1252];
		[encodingMenu addItem: windows1252];

		NSMenuItem *windows1251 = [[[NSMenuItem alloc] initWithTitle: @"Convert to Windows-1251"
															action: @selector(setEncodingWindows1251:)
													 keyEquivalent: @""] autorelease];
		[windows1251 setTarget: self];
		[windows1251 setTag: kMenuTagEncodingWindows1251];
		[encodingMenu addItem: windows1251];

		NSMenuItem *shiftJis = [[[NSMenuItem alloc] initWithTitle: @"Convert to Shift_JIS"
														 action: @selector(setEncodingShiftJis:)
												  keyEquivalent: @""] autorelease];
		[shiftJis setTarget: self];
		[shiftJis setTag: kMenuTagEncodingShiftJis];
		[encodingMenu addItem: shiftJis];

		NSMenuItem *gb18030 = [[[NSMenuItem alloc] initWithTitle: @"Convert to GB18030"
														action: @selector(setEncodingGb18030:)
												 keyEquivalent: @""] autorelease];
		[gb18030 setTarget: self];
		[gb18030 setTag: kMenuTagEncodingGb18030];
		[encodingMenu addItem: gb18030];

		NSMenuItem *big5 = [[[NSMenuItem alloc] initWithTitle: @"Convert to Big5"
													 action: @selector(setEncodingBig5:)
											  keyEquivalent: @""] autorelease];
		[big5 setTarget: self];
		[big5 setTag: kMenuTagEncodingBig5];
		[encodingMenu addItem: big5];

		NSMenuItem *eucKr = [[[NSMenuItem alloc] initWithTitle: @"Convert to EUC-KR"
													  action: @selector(setEncodingEucKr:)
											   keyEquivalent: @""] autorelease];
		[eucKr setTarget: self];
		[eucKr setTag: kMenuTagEncodingEucKr];
		[encodingMenu addItem: eucKr];
	}

	if ([encodingMenu itemWithTag: kMenuTagEncodingIso88591] == nil) {
		[encodingMenu addItem: [NSMenuItem separatorItem]];

		NSMenuItem *iso88591 = [[[NSMenuItem alloc] initWithTitle: @"Convert to ISO-8859-1"
														 action: @selector(setEncodingIso88591:)
												  keyEquivalent: @""] autorelease];
		[iso88591 setTarget: self];
		[iso88591 setTag: kMenuTagEncodingIso88591];
		[encodingMenu addItem: iso88591];

		NSMenuItem *windows1252 = [[[NSMenuItem alloc] initWithTitle: @"Convert to Windows-1252"
															action: @selector(setEncodingWindows1252:)
													 keyEquivalent: @""] autorelease];
		[windows1252 setTarget: self];
		[windows1252 setTag: kMenuTagEncodingWindows1252];
		[encodingMenu addItem: windows1252];

		NSMenuItem *windows1251 = [[[NSMenuItem alloc] initWithTitle: @"Convert to Windows-1251"
															action: @selector(setEncodingWindows1251:)
													 keyEquivalent: @""] autorelease];
		[windows1251 setTarget: self];
		[windows1251 setTag: kMenuTagEncodingWindows1251];
		[encodingMenu addItem: windows1251];

		NSMenuItem *shiftJis = [[[NSMenuItem alloc] initWithTitle: @"Convert to Shift_JIS"
														 action: @selector(setEncodingShiftJis:)
												  keyEquivalent: @""] autorelease];
		[shiftJis setTarget: self];
		[shiftJis setTag: kMenuTagEncodingShiftJis];
		[encodingMenu addItem: shiftJis];

		NSMenuItem *gb18030 = [[[NSMenuItem alloc] initWithTitle: @"Convert to GB18030"
														action: @selector(setEncodingGb18030:)
												 keyEquivalent: @""] autorelease];
		[gb18030 setTarget: self];
		[gb18030 setTag: kMenuTagEncodingGb18030];
		[encodingMenu addItem: gb18030];

		NSMenuItem *big5 = [[[NSMenuItem alloc] initWithTitle: @"Convert to Big5"
													 action: @selector(setEncodingBig5:)
											  keyEquivalent: @""] autorelease];
		[big5 setTarget: self];
		[big5 setTag: kMenuTagEncodingBig5];
		[encodingMenu addItem: big5];

		NSMenuItem *eucKr = [[[NSMenuItem alloc] initWithTitle: @"Convert to EUC-KR"
													  action: @selector(setEncodingEucKr:)
											   keyEquivalent: @""] autorelease];
		[eucKr setTarget: self];
		[eucKr setTag: kMenuTagEncodingEucKr];
		[encodingMenu addItem: eucKr];
	}

	NSMenuItem *toolsMenuItem = [mainMenu itemWithTitle: @"Tools"];
	NSMenu *toolsMenu = nil;
	if (toolsMenuItem == nil) {
		toolsMenuItem = [[[NSMenuItem alloc] initWithTitle: @"Tools" action: nil keyEquivalent: @""] autorelease];
		toolsMenu = [[[NSMenu alloc] initWithTitle: @"Tools"] autorelease];
		[toolsMenuItem setSubmenu: toolsMenu];
		NSUInteger insertIndex = [mainMenu indexOfItemWithTitle: @"Encoding"];
		if (insertIndex == NSNotFound)
			insertIndex = [mainMenu numberOfItems];
		else
			insertIndex += 1;
		[mainMenu insertItem: toolsMenuItem atIndex: insertIndex];
	} else {
		toolsMenu = [toolsMenuItem submenu];
	}

	if (toolsMenu != nil && [toolsMenu itemWithTag: kMenuTagAutosave] == nil) {
		NSMenuItem *compareItem = [[[NSMenuItem alloc] initWithTitle: @"Compare Current File With..."
															 action: @selector(compareCurrentWithFile:)
													  keyEquivalent: @""] autorelease];
		[compareItem setTarget: self];
		[toolsMenu addItem: compareItem];

		NSMenuItem *autosaveItem = [[[NSMenuItem alloc] initWithTitle: @"Autosave"
															 action: @selector(toggleAutosave:)
													  keyEquivalent: @""] autorelease];
		[autosaveItem setTarget: self];
		[autosaveItem setTag: kMenuTagAutosave];
		[toolsMenu addItem: autosaveItem];

		[toolsMenu addItem: [NSMenuItem separatorItem]];

		NSMenuItem *lineOps = [[[NSMenuItem alloc] initWithTitle: @"Line Operations" action: nil keyEquivalent: @""] autorelease];
		NSMenu *lineOpsMenu = [[[NSMenu alloc] initWithTitle: @"Line Operations"] autorelease];
		[lineOps setSubmenu: lineOpsMenu];
		[toolsMenu addItem: lineOps];

		NSMenuItem *sortAsc = [[[NSMenuItem alloc] initWithTitle: @"Sort Lines Ascending"
														  action: @selector(sortSelectedLinesAscending:)
												   keyEquivalent: @""] autorelease];
		[sortAsc setTarget: self];
		[lineOpsMenu addItem: sortAsc];

		NSMenuItem *sortDesc = [[[NSMenuItem alloc] initWithTitle: @"Sort Lines Descending"
														   action: @selector(sortSelectedLinesDescending:)
													keyEquivalent: @""] autorelease];
		[sortDesc setTarget: self];
		[lineOpsMenu addItem: sortDesc];

		NSMenuItem *trimSpaces = [[[NSMenuItem alloc] initWithTitle: @"Trim Trailing Whitespace"
															 action: @selector(trimTrailingWhitespaceLines:)
													  keyEquivalent: @""] autorelease];
		[trimSpaces setTarget: self];
		[lineOpsMenu addItem: trimSpaces];

		[lineOpsMenu addItem: [NSMenuItem separatorItem]];

		NSMenuItem *upperCase = [[[NSMenuItem alloc] initWithTitle: @"Selection to UPPERCASE"
															 action: @selector(convertSelectionToUpperCase:)
													  keyEquivalent: @""] autorelease];
		[upperCase setTarget: self];
		[lineOpsMenu addItem: upperCase];

		NSMenuItem *lowerCase = [[[NSMenuItem alloc] initWithTitle: @"Selection to lowercase"
															 action: @selector(convertSelectionToLowerCase:)
													  keyEquivalent: @""] autorelease];
		[lowerCase setTarget: self];
		[lineOpsMenu addItem: lowerCase];

		NSMenuItem *camelCase = [[[NSMenuItem alloc] initWithTitle: @"Selection to camelCase"
															 action: @selector(convertSelectionToCamelCase:)
													  keyEquivalent: @""] autorelease];
		[camelCase setTarget: self];
		[lineOpsMenu addItem: camelCase];
	}

	NSMenuItem *macroMenuItem = [mainMenu itemWithTitle: @"Macro"];
	if (macroMenuItem == nil) {
		macroMenuItem = [[[NSMenuItem alloc] initWithTitle: @"Macro" action: nil keyEquivalent: @""] autorelease];
		NSMenu *macroMenu = [[[NSMenu alloc] initWithTitle: @"Macro"] autorelease];
		[macroMenuItem setSubmenu: macroMenu];
		[mainMenu insertItem: macroMenuItem atIndex: [mainMenu numberOfItems] - 1];
	}

	mMacroMenu = [macroMenuItem submenu];
	if (mMacroMenu == nil) {
		mMacroMenu = [[[NSMenu alloc] initWithTitle: @"Macro"] autorelease];
		[macroMenuItem setSubmenu: mMacroMenu];
	}

	if ([mMacroMenu itemWithTag: kMenuTagMacroRecord] == nil) {
		mMacroRecordMenuItem = [[[NSMenuItem alloc] initWithTitle: @"Start Recording"
														 action: @selector(startStopMacroRecording:)
												  keyEquivalent: @"r"] autorelease];
		[mMacroRecordMenuItem setKeyEquivalentModifierMask: NSCommandKeyMask | NSShiftKeyMask];
		[mMacroRecordMenuItem setTarget: self];
		[mMacroRecordMenuItem setTag: kMenuTagMacroRecord];
		[mMacroMenu addItem: mMacroRecordMenuItem];

		NSMenuItem *playMacroItem = [[[NSMenuItem alloc] initWithTitle: @"Play Recorded Macro"
																action: @selector(playRecordedMacro:)
														 keyEquivalent: @"r"] autorelease];
		[playMacroItem setKeyEquivalentModifierMask: NSCommandKeyMask | NSShiftKeyMask | NSAlternateKeyMask];
		[playMacroItem setTarget: self];
		[playMacroItem setTag: kMenuTagMacroPlay];
		[mMacroMenu addItem: playMacroItem];

		NSMenuItem *saveRecorded = [[[NSMenuItem alloc] initWithTitle: @"Save Recorded Macro..."
															 action: @selector(saveRecordedMacroToLibrary:)
													  keyEquivalent: @""] autorelease];
		[saveRecorded setTarget: self];
		[saveRecorded setTag: kMenuTagMacroSaveRecorded];
		[mMacroMenu addItem: saveRecorded];

		NSMenuItem *runMulti = [[[NSMenuItem alloc] initWithTitle: @"Run Recorded Macro Multiple Times..."
														 action: @selector(runRecordedMacroMultipleTimes:)
												  keyEquivalent: @""] autorelease];
		[runMulti setTarget: self];
		[runMulti setTag: kMenuTagMacroRepeat];
		[mMacroMenu addItem: runMulti];
	}

	[self updateMacroMenuState];
}

- (void) loadLexilla
{
	if (mLexillaDL != NULL)
		return;

	mLexillaDL = dlopen(LEXILLA_LIB LEXILLA_EXTENSION, RTLD_LAZY | RTLD_LOCAL);

	if (mLexillaDL == NULL) {
		NSString *frameworksPath = [[NSBundle mainBundle] privateFrameworksPath];
		if (frameworksPath != nil) {
			NSString *libName = [NSString stringWithUTF8String: LEXILLA_LIB LEXILLA_EXTENSION];
			NSString *candidate = [frameworksPath stringByAppendingPathComponent: libName];
			mLexillaDL = dlopen([candidate fileSystemRepresentation], RTLD_LAZY | RTLD_LOCAL);
		}
	}

	if (mLexillaDL != NULL) {
		mCreateLexer = reinterpret_cast<Lexilla::CreateLexerFn>(dlsym(mLexillaDL, LEXILLA_CREATELEXER));
	}
}

- (ScintillaView *) createEditorInView: (NSView *) host withText: (NSString *) text
{
	ScintillaView *editor = [[[ScintillaView alloc] initWithFrame: [host bounds]] autorelease];
	[host addSubview: editor];
	[editor setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];
	[editor setDelegate: self];
	[editor setString: (text != nil) ? text : @""];

	[self setupEditor: editor];
	[self applyDisplayFlagsToEditor: editor];
	[editor setGeneralProperty: SCI_SETSAVEPOINT parameter: 0 value: 0];

	return editor;
}

- (NPPDocument *) createDocumentWithText: (NSString *) text
								path: (NSString *) path
							encoding: (NSStringEncoding) encoding
{
	NPPDocument *document = [[[NPPDocument alloc] init] autorelease];

	document.encoding = encoding;
	document.dirty = NO;
	document.metadataDirty = NO;

	if (path != nil) {
		document.untitled = NO;
		document.filePath = [path stringByStandardizingPath];
	} else {
		document.untitled = YES;
		document.untitledIndex = mUntitledCounter++;
	}

	NSView *container = [[[NSView alloc] initWithFrame: [mTabView bounds]] autorelease];
	[container setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];

	NSTabViewItem *tabItem = [[[NSTabViewItem alloc] initWithIdentifier: document] autorelease];
	[tabItem setView: container];
	document.tabItem = tabItem;

	document.editor = [self createEditorInView: container withText: text];
	[self applyLexerToDocument: document];

	[mDocuments addObject: document];
	[mTabView addTabViewItem: tabItem];
	[self selectDocument: document];

	return document;
}

- (NPPDocument *) createUntitledDocument
{
	return [self createDocumentWithText: @"" path: nil encoding: NSUTF8StringEncoding];
}

- (NPPDocument *) currentDocument
{
	NSTabViewItem *item = [mTabView selectedTabViewItem];
	return [self documentForTabItem: item];
}

- (NPPDocument *) documentForTabItem: (NSTabViewItem *) tabItem
{
	for (NPPDocument *document in mDocuments) {
		if (document.tabItem == tabItem)
			return document;
	}
	return nil;
}

- (NPPDocument *) documentForPath: (NSString *) path
{
	if (path == nil)
		return nil;

	NSString *normalized = [path stringByStandardizingPath];
	for (NPPDocument *document in mDocuments) {
		if (document.filePath != nil && [document.filePath isEqualToString: normalized])
			return document;
	}
	return nil;
}

- (void) selectDocument: (NPPDocument *) document
{
	if (document == nil)
		return;

	[mTabView selectTabViewItem: document.tabItem];
	mEditor = document.editor;
	[[mEditHost window] makeFirstResponder: mEditor];
	[self updateDocumentTabs];
	[self updateWindowTitle];
	[self refreshUiToggles];
	[self refreshFunctionList];
	[self refreshProjectEntries];
	if (mLiveTailEnabled)
		[self resetLiveTailTrackingForCurrentDocument];
	if (mSplitViewEnabled || mDocumentMapVisible)
		[self ensureExtraEditorForCurrentDocument];
	else
		[self removeExtraEditor];
}

- (NSString *) titleForDocument: (NPPDocument *) document
{
	NSString *baseName = nil;
	if (document.filePath != nil)
		baseName = [document.filePath lastPathComponent];
	else
		baseName = [NSString stringWithFormat: @"Untitled %lu", (unsigned long)document.untitledIndex];

	return document.dirty ? [@"*" stringByAppendingString: baseName] : baseName;
}

- (void) updateDocumentTabs
{
	for (NPPDocument *document in mDocuments)
		[document.tabItem setLabel: [self titleForDocument: document]];
}

- (void) updateWindowTitle
{
	NPPDocument *document = [self currentDocument];
	if (document == nil) {
		[[mEditHost window] setTitle: @"Notepad++ macOS Preview"];
		[self updateStatusBar];
		return;
	}

	long currentPos = [document.editor getGeneralProperty: SCI_GETCURRENTPOS parameter: 0];
	long line = [document.editor getGeneralProperty: SCI_LINEFROMPOSITION parameter: currentPos] + 1;
	long column = [document.editor getGeneralProperty: SCI_GETCOLUMN parameter: currentPos] + 1;
	NSInteger eolMode = [self currentEolModeForDocument: document];
	NSString *eolLabel = (eolMode == SC_EOL_CRLF) ? @"CRLF" : ((eolMode == SC_EOL_LF) ? @"LF" : @"CR");
	NSString *encodingLabel = [self encodingLabelForDocument: document];
	NSString *title = [NSString stringWithFormat: @"%@ - Ln %ld, Col %ld [%@ | %@]",
											 [self titleForDocument: document],
											 line,
											 column,
											 encodingLabel,
											 eolLabel];
	[[mEditHost window] setTitle: title];
	[self updateStatusBar];
}

- (void) updateStatusBar
{
	if (mStatusBar == nil)
		return;

	if (!mStatusBarVisible) {
		[mStatusBar setHidden: YES];
		return;
	}

	[mStatusBar setHidden: NO];

	NPPDocument *document = [self currentDocument];
	if (document == nil) {
		[mStatusBar setStringValue: @"Ready"];
		return;
	}

	long currentPos = [document.editor getGeneralProperty: SCI_GETCURRENTPOS parameter: 0];
	long line = [document.editor getGeneralProperty: SCI_LINEFROMPOSITION parameter: currentPos] + 1;
	long column = [document.editor getGeneralProperty: SCI_GETCOLUMN parameter: currentPos] + 1;
	long selectionStart = [document.editor getGeneralProperty: SCI_GETSELECTIONSTART parameter: 0];
	long selectionEnd = [document.editor getGeneralProperty: SCI_GETSELECTIONEND parameter: 0];
	long selectionLength = labs(selectionEnd - selectionStart);
	NSString *docTitle = [self titleForDocument: document];
	NSString *macroState = mMacroRecording ? @"REC" : @"";
	NSString *status = [NSString stringWithFormat: @"%@   Ln %ld, Col %ld   Sel %ld   %@   %@",
						   docTitle,
						   line,
						   column,
						   selectionLength,
						   [self encodingLabelForDocument: document],
						   macroState];
	[mStatusBar setStringValue: status];
}

- (void) refreshEditorState: (NSTimer *) timer
{
	#pragma unused(timer)

	for (NPPDocument *document in mDocuments) {
		BOOL isDirty = ([document.editor getGeneralProperty: SCI_GETMODIFY parameter: 0] != 0) || document.metadataDirty;
		if (document.dirty != isDirty)
			document.dirty = isDirty;
	}

	[self runAutosaveIfNeeded];
	[self refreshLiveTail];
	[self refreshExtraEditorState];
	[self updateDocumentTabs];
	[self updateWindowTitle];
	[self refreshUiToggles];
	[self refreshFunctionList];
}

- (void) refreshUiToggles
{
	NSMenu *mainMenu = [NSApp mainMenu];
	if (mainMenu == nil)
		return;

	NSMenuItem *wrapItem = [mainMenu itemWithTag: kMenuTagWordWrap];
	NSMenuItem *wsItem = [mainMenu itemWithTag: kMenuTagShowWhitespace];
	NSMenuItem *eolItem = [mainMenu itemWithTag: kMenuTagShowEol];
	NSMenuItem *marginItem = [mainMenu itemWithTag: kMenuTagShowLineNumbers];
	NSMenuItem *tailItem = [mainMenu itemWithTag: kMenuTagLiveTail];
	NSMenuItem *splitItem = [mainMenu itemWithTag: kMenuTagSplitScreen];
	NSMenuItem *documentMapItem = [mainMenu itemWithTag: kMenuTagDocumentMap];
	NSMenuItem *autosaveItem = [mainMenu itemWithTag: kMenuTagAutosave];
	NSMenuItem *viewMenuItem = [mainMenu itemWithTitle: @"View"];
	NSMenuItem *sidebarItem = [[viewMenuItem submenu] itemWithTitle: @"Toggle Sidebar"];

	[wrapItem setState: mWordWrap ? NSOnState : NSOffState];
	[wsItem setState: mShowWhitespace ? NSOnState : NSOffState];
	[eolItem setState: mShowEol ? NSOnState : NSOffState];
	[marginItem setState: mShowLineNumbers ? NSOnState : NSOffState];
	[sidebarItem setState: mSidebarVisible ? NSOnState : NSOffState];
	[tailItem setState: mLiveTailEnabled ? NSOnState : NSOffState];
	[splitItem setState: mSplitViewEnabled ? NSOnState : NSOffState];
	[documentMapItem setState: mDocumentMapVisible ? NSOnState : NSOffState];
	[autosaveItem setState: mAutosaveEnabled ? NSOnState : NSOffState];

	NPPDocument *document = [self currentDocument];
	if (document == nil)
		return;

	NSInteger eolMode = [self currentEolModeForDocument: document];
	[[mainMenu itemWithTag: kMenuTagEolWindows] setState: (eolMode == SC_EOL_CRLF) ? NSOnState : NSOffState];
	[[mainMenu itemWithTag: kMenuTagEolUnix] setState: (eolMode == SC_EOL_LF) ? NSOnState : NSOffState];
	[[mainMenu itemWithTag: kMenuTagEolMac] setState: (eolMode == SC_EOL_CR) ? NSOnState : NSOffState];

	NSStringEncoding encoding = document.encoding;
	[[mainMenu itemWithTag: kMenuTagEncodingUtf8] setState: (encoding == NSUTF8StringEncoding) ? NSOnState : NSOffState];
	[[mainMenu itemWithTag: kMenuTagEncodingUtf16LE] setState: (encoding == NSUTF16LittleEndianStringEncoding) ? NSOnState : NSOffState];
	[[mainMenu itemWithTag: kMenuTagEncodingUtf16BE] setState: (encoding == NSUTF16BigEndianStringEncoding) ? NSOnState : NSOffState];
	[[mainMenu itemWithTag: kMenuTagEncodingIso88591] setState: (encoding == NSISOLatin1StringEncoding) ? NSOnState : NSOffState];
	[[mainMenu itemWithTag: kMenuTagEncodingWindows1252] setState: (encoding == nppEncodingWindows1252()) ? NSOnState : NSOffState];
	[[mainMenu itemWithTag: kMenuTagEncodingWindows1251] setState: (encoding == nppEncodingWindows1251()) ? NSOnState : NSOffState];
	[[mainMenu itemWithTag: kMenuTagEncodingShiftJis] setState: (encoding == nppEncodingShiftJis()) ? NSOnState : NSOffState];
	[[mainMenu itemWithTag: kMenuTagEncodingGb18030] setState: (encoding == nppEncodingGb18030()) ? NSOnState : NSOffState];
	[[mainMenu itemWithTag: kMenuTagEncodingBig5] setState: (encoding == nppEncodingBig5()) ? NSOnState : NSOffState];
	[[mainMenu itemWithTag: kMenuTagEncodingEucKr] setState: (encoding == nppEncodingEucKr()) ? NSOnState : NSOffState];
}

- (void) applyDisplayFlagsToEditor: (ScintillaView *) editor
{
	if (editor == nil)
		return;

	[editor setGeneralProperty: SCI_SETWRAPMODE parameter: mWordWrap ? SC_WRAP_WORD : SC_WRAP_NONE value: 0];
	[editor setGeneralProperty: SCI_SETVIEWWS parameter: mShowWhitespace ? SCWS_VISIBLEALWAYS : SCWS_INVISIBLE value: 0];
	[editor setGeneralProperty: SCI_SETVIEWEOL parameter: mShowEol ? 1 : 0 value: 0];
	[editor setGeneralProperty: SCI_SETMARGINWIDTHN parameter: 0 value: mShowLineNumbers ? 48 : 0];
}

- (void) ensureExtraEditorForCurrentDocument
{
	if (!(mSplitViewEnabled || mDocumentMapVisible)) {
		[self removeExtraEditor];
		return;
	}

	NPPDocument *document = [self currentDocument];
	if (document == nil || document.editor == nil)
		return;

	NSView *container = [document.tabItem view];
	if (container == nil)
		return;

	if (sciExtra != nil && [sciExtra superview] != container) {
		[sciExtra removeFromSuperview];
		sciExtra = nil;
	}

	if (sciExtra == nil) {
		sciExtra = [[[ScintillaView alloc] initWithFrame: [container bounds]] autorelease];
		[sciExtra setDelegate: self];
		[self setupEditor: sciExtra];
		[self applyDisplayFlagsToEditor: sciExtra];
		[container addSubview: sciExtra];
	}

	[self layoutActiveEditorViews];
}

- (void) removeExtraEditor
{
	if (sciExtra != nil) {
		[sciExtra removeFromSuperview];
		sciExtra = nil;
	}

	[self clearComparisonMarkers];

	NPPDocument *document = [self currentDocument];
	if (document != nil && document.editor != nil) {
		NSView *container = [document.tabItem view];
		if (container != nil)
			[document.editor setFrame: [container bounds]];
	}
}

- (void) layoutActiveEditorViews
{
	NPPDocument *document = [self currentDocument];
	if (document == nil || document.editor == nil)
		return;

	NSView *container = [document.tabItem view];
	if (container == nil)
		return;

	NSRect bounds = [container bounds];
	if (sciExtra == nil || !(mSplitViewEnabled || mDocumentMapVisible)) {
		[document.editor setFrame: bounds];
		return;
	}

	if (mDocumentMapVisible) {
		CGFloat mapWidth = MIN(260.0, MAX(160.0, floor(bounds.size.width * 0.24)));
		CGFloat separator = 2.0;
		CGFloat mainWidth = MAX(120.0, bounds.size.width - mapWidth - separator);
		[document.editor setFrame: NSMakeRect(0, 0, mainWidth, bounds.size.height)];
		[sciExtra setFrame: NSMakeRect(mainWidth + separator, 0, bounds.size.width - (mainWidth + separator), bounds.size.height)];
		return;
	}

	CGFloat separator = 4.0;
	CGFloat leftWidth = floor((bounds.size.width - separator) * 0.5);
	CGFloat rightWidth = MAX(120.0, bounds.size.width - leftWidth - separator);
	[document.editor setFrame: NSMakeRect(0, 0, leftWidth, bounds.size.height)];
	[sciExtra setFrame: NSMakeRect(leftWidth + separator, 0, rightWidth, bounds.size.height)];
}

- (void) clearComparisonMarkers
{
	NSArray *editors = [NSArray arrayWithObjects: mEditor, sciExtra, nil];
	for (ScintillaView *editor in editors) {
		if (editor == nil)
			continue;
		long length = [editor getGeneralProperty: SCI_GETLENGTH parameter: 0];
		[editor setGeneralProperty: SCI_SETINDICATORCURRENT parameter: 12 value: 0];
		[editor setGeneralProperty: SCI_INDICATORCLEARRANGE parameter: 0 value: length];
	}
}

- (void) applyComparisonMarkersBetweenEditor: (ScintillaView *) left rightEditor: (ScintillaView *) right
{
	if (left == nil || right == nil)
		return;

	NSString *leftText = [left string];
	NSString *rightText = [right string];
	if (leftText == nil || rightText == nil)
		return;

	[self clearComparisonMarkers];

	NSArray *editors = [NSArray arrayWithObjects: left, right, nil];
	for (ScintillaView *editor in editors) {
		[editor setGeneralProperty: SCI_INDICSETSTYLE parameter: 12 value: INDIC_STRAIGHTBOX];
		[editor setColorProperty: SCI_INDICSETFORE parameter: 12 fromHTML: @"#FF5A3D"];
		[editor setGeneralProperty: SCI_SETINDICATORCURRENT parameter: 12 value: 0];
	}

	NSMutableArray *leftLines = [NSMutableArray array];
	NSMutableArray *leftRanges = [NSMutableArray array];
	[leftText enumerateSubstringsInRange: NSMakeRange(0, [leftText length])
								 options: NSStringEnumerationByLines | NSStringEnumerationSubstringNotRequired
							  usingBlock: ^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop) {
								  #pragma unused(substring)
								  #pragma unused(stop)
								  [leftLines addObject: [leftText substringWithRange: substringRange]];
								  [leftRanges addObject: [NSValue valueWithRange: enclosingRange]];
							  }];

	NSMutableArray *rightLines = [NSMutableArray array];
	NSMutableArray *rightRanges = [NSMutableArray array];
	[rightText enumerateSubstringsInRange: NSMakeRange(0, [rightText length])
								  options: NSStringEnumerationByLines | NSStringEnumerationSubstringNotRequired
							   usingBlock: ^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop) {
								   #pragma unused(substring)
								   #pragma unused(stop)
								   [rightLines addObject: [rightText substringWithRange: substringRange]];
								   [rightRanges addObject: [NSValue valueWithRange: enclosingRange]];
							   }];

	NSUInteger count = MAX([leftLines count], [rightLines count]);
	for (NSUInteger i = 0; i < count; ++i) {
		NSString *leftLine = (i < [leftLines count]) ? [leftLines objectAtIndex: i] : nil;
		NSString *rightLine = (i < [rightLines count]) ? [rightLines objectAtIndex: i] : nil;

		BOOL same = (leftLine != nil && rightLine != nil && [leftLine isEqualToString: rightLine]);
		if (same)
			continue;

		if (i < [leftRanges count]) {
			NSRange range = [[leftRanges objectAtIndex: i] rangeValue];
			[left setGeneralProperty: SCI_INDICATORFILLRANGE parameter: range.location value: range.length];
		}
		if (i < [rightRanges count]) {
			NSRange range = [[rightRanges objectAtIndex: i] rangeValue];
			[right setGeneralProperty: SCI_INDICATORFILLRANGE parameter: range.location value: range.length];
		}
	}
}

- (void) refreshExtraEditorState
{
	if (!(mSplitViewEnabled || mDocumentMapVisible))
		return;

	NPPDocument *document = [self currentDocument];
	if (document == nil || document.editor == nil)
		return;

	[self ensureExtraEditorForCurrentDocument];
	if (sciExtra == nil)
		return;

	[self layoutActiveEditorViews];

	BOOL compareMode = ([mComparedFilePath length] > 0);
	NSString *leftText = [document.editor string];
	if (!compareMode) {
		NSString *rightText = [sciExtra string];
		if (leftText != nil && ![leftText isEqualToString: rightText])
			[sciExtra setString: leftText];
		[self clearComparisonMarkers];
	} else {
		NSString *otherText = nil;
		NSStringEncoding ignoredEncoding = NSUTF8StringEncoding;
		if ([self readTextFileAtPath: mComparedFilePath content: &otherText usedEncoding: &ignoredEncoding error: nil] && otherText != nil) {
			if (![[sciExtra string] isEqualToString: otherText])
				[sciExtra setString: otherText];
			[self applyComparisonMarkersBetweenEditor: document.editor rightEditor: sciExtra];
		}
	}

	[sciExtra setGeneralProperty: SCI_SETREADONLY parameter: 1 value: 0];
	if (mDocumentMapVisible) {
		[sciExtra setGeneralProperty: SCI_SETZOOM parameter: -7 value: 0];
		[sciExtra setGeneralProperty: SCI_SETMARGINWIDTHN parameter: 0 value: 0];
		[sciExtra setGeneralProperty: SCI_SETMARGINWIDTHN parameter: 1 value: 0];
	} else {
		[sciExtra setGeneralProperty: SCI_SETZOOM parameter: 0 value: 0];
		[sciExtra setGeneralProperty: SCI_SETMARGINWIDTHN parameter: 0 value: mShowLineNumbers ? 48 : 0];
		[sciExtra setGeneralProperty: SCI_SETMARGINWIDTHN parameter: 1 value: 16];
	}

	long mainTop = [document.editor getGeneralProperty: SCI_GETFIRSTVISIBLELINE parameter: 0];
	long extraTop = [sciExtra getGeneralProperty: SCI_GETFIRSTVISIBLELINE parameter: 0];
	long delta = mainTop - extraTop;
	if (delta != 0)
		[sciExtra message: SCI_LINESCROLL wParam: 0 lParam: delta];
}

- (void) runAutosaveIfNeeded
{
	if (!mAutosaveEnabled)
		return;

	NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
	if (now < mNextAutosaveTime)
		return;
	mNextAutosaveTime = now + kNppMacAutosaveIntervalSeconds;

	NSUInteger saved = 0;
	for (NPPDocument *document in mDocuments) {
		if (document == nil || [document.filePath length] == 0)
			continue;
		if (!document.dirty)
			continue;
		if ([self saveDocument: document forceSaveAs: NO])
			saved++;
	}

	if (saved > 0 && mEditor != nil)
		[mEditor setStatusText: [NSString stringWithFormat: @"Autosaved %lu file(s)", (unsigned long)saved]];
}

- (void) saveSessionState
{
	NSMutableArray *documents = [NSMutableArray array];
	for (NPPDocument *document in mDocuments) {
		NSMutableDictionary *entry = [NSMutableDictionary dictionary];

		if (document.filePath != nil) {
			[entry setObject: document.filePath forKey: @"path"];
		} else {
			NSString *text = [document.editor string];
			if ([text length] == 0 && !document.dirty)
				continue;
			[entry setObject: text forKey: @"untitledText"];
		}

		[entry setObject: [NSNumber numberWithUnsignedInteger: document.encoding] forKey: @"encoding"];
		[documents addObject: entry];
	}

	NSInteger selectedIndex = [mTabView indexOfTabViewItem: [mTabView selectedTabViewItem]];
	NSDictionary *session = [NSDictionary dictionaryWithObjectsAndKeys:
		documents, kNppMacSessionDocsKey,
		[NSNumber numberWithInteger: selectedIndex], kNppMacSessionSelectedIndexKey,
		mProjectRootPaths, kNppMacSessionProjectRootsKey,
		[NSNumber numberWithBool: mWordWrap], kNppMacSessionWordWrapKey,
		[NSNumber numberWithBool: mShowWhitespace], kNppMacSessionShowWhitespaceKey,
		[NSNumber numberWithBool: mShowEol], kNppMacSessionShowEolKey,
		[NSNumber numberWithBool: mShowLineNumbers], kNppMacSessionShowLineNumbersKey,
		nil];

	[[NSUserDefaults standardUserDefaults] setObject: session forKey: kNppMacSessionDefaultsKey];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

- (BOOL) restoreSessionState
{
	NSDictionary *session = [[NSUserDefaults standardUserDefaults] objectForKey: kNppMacSessionDefaultsKey];
	if (![session isKindOfClass: [NSDictionary class]])
		return NO;

	mWordWrap = [[session objectForKey: kNppMacSessionWordWrapKey] boolValue];
	mShowWhitespace = [[session objectForKey: kNppMacSessionShowWhitespaceKey] boolValue];
	mShowEol = [[session objectForKey: kNppMacSessionShowEolKey] boolValue];
	NSNumber *showLineNumbersValue = [session objectForKey: kNppMacSessionShowLineNumbersKey];
	mShowLineNumbers = [showLineNumbersValue isKindOfClass: [NSNumber class]] ? [showLineNumbersValue boolValue] : YES;

	NSArray *docs = [session objectForKey: kNppMacSessionDocsKey];
	if (![docs isKindOfClass: [NSArray class]] || [docs count] == 0)
		return NO;

	NSArray *projectRoots = [session objectForKey: kNppMacSessionProjectRootsKey];
	if ([projectRoots isKindOfClass: [NSArray class]]) {
		for (NSString *root in projectRoots) {
			if ([root isKindOfClass: [NSString class]] && [root length] > 0)
				[self addProjectRootPath: root];
		}
	}

	for (NSDictionary *entry in docs) {
		if (![entry isKindOfClass: [NSDictionary class]])
			continue;

		NSString *path = [entry objectForKey: @"path"];
		if ([path length] > 0 && [[NSFileManager defaultManager] fileExistsAtPath: path]) {
			[self openPath: path];
			NPPDocument *loaded = [self currentDocument];
			NSNumber *encoding = [entry objectForKey: @"encoding"];
			if ([encoding respondsToSelector: @selector(unsignedIntegerValue)])
				loaded.encoding = [encoding unsignedIntegerValue];
			continue;
		}

		NSString *untitledText = [entry objectForKey: @"untitledText"];
		if (![untitledText isKindOfClass: [NSString class]])
			continue;

		NSStringEncoding encoding = NSUTF8StringEncoding;
		NSNumber *encodingValue = [entry objectForKey: @"encoding"];
		if ([encodingValue respondsToSelector: @selector(unsignedIntegerValue)])
			encoding = [encodingValue unsignedIntegerValue];

		NPPDocument *document = [self createDocumentWithText: untitledText path: nil encoding: encoding];
		document.metadataDirty = YES;
		document.dirty = YES;
	}

	NSInteger selectedIndex = [[session objectForKey: kNppMacSessionSelectedIndexKey] integerValue];
	if (selectedIndex >= 0 && selectedIndex < (NSInteger)[mDocuments count]) {
		NPPDocument *document = [mDocuments objectAtIndex: selectedIndex];
		[self selectDocument: document];
	}

	return [mDocuments count] > 0;
}

- (NSString *) lexerNameForDocument: (NPPDocument *) document
{
	NSString *fileName = (document.filePath != nil)
		? [[document.filePath lastPathComponent] lowercaseString]
		: [[self titleForDocument: document] lowercaseString];

	if ([fileName isEqualToString: @"makefile"] || [fileName isEqualToString: @"gnumakefile"])
		return @"makefile";

	NSString *ext = [[fileName pathExtension] lowercaseString];
	if ([ext length] == 0)
		return nil;

	static NSDictionary *lexerMap = nil;
	if (lexerMap == nil) {
		lexerMap = [[NSDictionary alloc] initWithObjectsAndKeys:
			@"cpp", @"c", @"cpp", @"cc", @"cpp", @"cpp", @"cpp", @"cxx", @"cpp", @"h", @"cpp", @"hpp", @"cpp", @"hh", @"cpp", @"hxx", @"cpp", @"m", @"cpp", @"mm",
			@"python", @"py", @"ruby", @"rb", @"rust", @"rs", @"go", @"go", @"lua", @"lua",
			@"cpp", @"java", @"cpp", @"kt", @"cpp", @"kts",
			@"cpp", @"js", @"cpp", @"mjs", @"cpp", @"cjs",
			@"cpp", @"ts", @"cpp", @"tsx",
			@"json", @"json", @"yaml", @"yml", @"yaml", @"yaml", @"toml", @"toml",
			@"cmake", @"cmake", @"sql", @"sql", @"bash", @"sh", @"bash", @"bash", @"bash", @"zsh",
			@"xml", @"xml", @"xml", @"xsd", @"xml", @"xslt", @"xml", @"plist",
			@"hypertext", @"html", @"hypertext", @"htm", @"hypertext", @"php",
			@"css", @"css", @"css", @"scss", @"css", @"less",
			@"markdown", @"md", @"markdown", @"markdown",
			@"props", @"ini", @"props", @"cfg", @"props", @"conf",
			@"diff", @"diff", @"diff", @"patch",
			nil];
	}

	return [lexerMap objectForKey: ext];
}

- (void) applyLexerToDocument: (NPPDocument *) document
{
	if (document == nil)
		return;

	if (mCreateLexer == nullptr)
		return;

	NSString *lexerName = [self lexerNameForDocument: document];
	if (lexerName == nil)
		return;

	Scintilla::ILexer5 *pLexer = mCreateLexer([lexerName UTF8String]);
	if (pLexer != nullptr) {
		[document.editor setReferenceProperty: SCI_SETILEXER parameter: 0 value: pLexer];
		[document.editor setLexerProperty: @"fold" value: @"1"];
		[document.editor setGeneralProperty: SCI_COLOURISE parameter: 0 value: -1];
	}
}

- (NSInteger) currentEolModeForDocument: (NPPDocument *) document
{
	if (document == nil || document.editor == nil)
		return SC_EOL_LF;
	return [document.editor getGeneralProperty: SCI_GETEOLMODE parameter: 0];
}

- (NSString *) encodingLabelForDocument: (NPPDocument *) document
{
	if (document == nil)
		return @"UTF-8";

	switch (document.encoding) {
		case NSUTF16LittleEndianStringEncoding:
			return @"UTF-16 LE";
		case NSUTF16BigEndianStringEncoding:
			return @"UTF-16 BE";
		case NSISOLatin1StringEncoding:
			return @"ISO-8859-1";
		case NSUTF8StringEncoding:
			return @"UTF-8";
		default: {
			NSStringEncoding win1252 = nppEncodingWindows1252();
			NSStringEncoding win1251 = nppEncodingWindows1251();
			NSStringEncoding shiftJis = nppEncodingShiftJis();
			NSStringEncoding gb18030 = nppEncodingGb18030();
			NSStringEncoding big5 = nppEncodingBig5();
			NSStringEncoding eucKr = nppEncodingEucKr();
			if (document.encoding == win1252)
				return @"Windows-1252";
			if (document.encoding == win1251)
				return @"Windows-1251";
			if (document.encoding == shiftJis)
				return @"Shift_JIS";
			if (document.encoding == gb18030)
				return @"GB18030";
			if (document.encoding == big5)
				return @"Big5";
			if (document.encoding == eucKr)
				return @"EUC-KR";

			NSString *localized = [NSString localizedNameOfStringEncoding: document.encoding];
			if ([localized length] > 0)
				return localized;
			return @"Unknown Encoding";
		}
	}
}

- (void) setupEditor: (ScintillaView *) editor
{
	[editor suspendDrawing: YES];

	[editor setGeneralProperty: SCI_SETCODEPAGE parameter: SC_CP_UTF8 value: 0];
	[editor setStringProperty: SCI_STYLESETFONT parameter: STYLE_DEFAULT value: @"Menlo"];
	[editor setGeneralProperty: SCI_STYLESETSIZE parameter: STYLE_DEFAULT value: 13];
	[editor setColorProperty: SCI_STYLESETFORE parameter: STYLE_DEFAULT value: [NSColor textColor]];
	[editor setColorProperty: SCI_STYLESETBACK parameter: STYLE_DEFAULT value: [NSColor textBackgroundColor]];
	[editor setGeneralProperty: SCI_STYLECLEARALL parameter: 0 value: 0];

	[editor setGeneralProperty: SCI_SETMARGINTYPEN parameter: 0 value: SC_MARGIN_NUMBER];
	[editor setGeneralProperty: SCI_SETMARGINWIDTHN parameter: 0 value: 48];
	[editor setColorProperty: SCI_STYLESETFORE parameter: STYLE_LINENUMBER fromHTML: @"#666666"];
	[editor setColorProperty: SCI_STYLESETBACK parameter: STYLE_LINENUMBER fromHTML: @"#F3F3F3"];

	[editor setGeneralProperty: SCI_SETMARGINTYPEN parameter: 1 value: SC_MARGIN_SYMBOL];
	[editor setGeneralProperty: SCI_SETMARGINMASKN parameter: 1 value: SC_MASK_FOLDERS];
	[editor setGeneralProperty: SCI_SETMARGINWIDTHN parameter: 1 value: 16];
	[editor setGeneralProperty: SCI_SETMARGINSENSITIVEN parameter: 1 value: 1];

	[editor setGeneralProperty: SCI_MARKERDEFINE parameter: SC_MARKNUM_FOLDEROPEN value: SC_MARK_BOXMINUS];
	[editor setGeneralProperty: SCI_MARKERDEFINE parameter: SC_MARKNUM_FOLDER value: SC_MARK_BOXPLUS];
	[editor setGeneralProperty: SCI_MARKERDEFINE parameter: SC_MARKNUM_FOLDERSUB value: SC_MARK_VLINE];
	[editor setGeneralProperty: SCI_MARKERDEFINE parameter: SC_MARKNUM_FOLDERTAIL value: SC_MARK_LCORNER];
	[editor setGeneralProperty: SCI_MARKERDEFINE parameter: SC_MARKNUM_FOLDEREND value: SC_MARK_BOXPLUSCONNECTED];
	[editor setGeneralProperty: SCI_MARKERDEFINE parameter: SC_MARKNUM_FOLDEROPENMID value: SC_MARK_BOXMINUSCONNECTED];
	[editor setGeneralProperty: SCI_MARKERDEFINE parameter: SC_MARKNUM_FOLDERMIDTAIL value: SC_MARK_TCORNER];

	for (int marker = 25; marker < 32; ++marker) {
		[editor setColorProperty: SCI_MARKERSETFORE parameter: marker fromHTML: @"#FFFFFF"];
		[editor setColorProperty: SCI_MARKERSETBACK parameter: marker fromHTML: @"#6F6F6F"];
	}

	[editor setGeneralProperty: SCI_SETUSETABS parameter: 0 value: 0];
	[editor setGeneralProperty: SCI_SETTABWIDTH parameter: 4 value: 0];
	[editor setGeneralProperty: SCI_SETINDENT parameter: 4 value: 0];
	[editor setGeneralProperty: SCI_SETINDENTATIONGUIDES parameter: SC_IV_LOOKBOTH value: 0];
	[editor setGeneralProperty: SCI_SETWRAPMODE parameter: SC_WRAP_NONE value: 0];
	[editor setGeneralProperty: SCI_SETSCROLLWIDTHTRACKING parameter: 1 value: 0];

	[editor setColorProperty: SCI_SETSELBACK parameter: 1 value: [NSColor selectedTextBackgroundColor]];
	[editor setGeneralProperty: SCI_SETMULTIPLESELECTION parameter: 1 value: 0];
	[editor setLexerProperty: @"fold" value: @"1"];
	[editor setLexerProperty: @"fold.compact" value: @"0"];

	[editor suspendDrawing: NO];
}

- (BOOL) openPath: (NSString *) path
{
	if ([path length] == 0)
		return NO;

	NSString *normalizedPath = [path stringByStandardizingPath];
	NPPDocument *existing = [self documentForPath: normalizedPath];
	if (existing != nil) {
		[self selectDocument: existing];
		return YES;
	}

	NSError *readError = nil;
	NSStringEncoding detectedEncoding = NSUTF8StringEncoding;
	NSString *content = nil;
	BOOL ok = [self readTextFileAtPath: normalizedPath
							content: &content
						usedEncoding: &detectedEncoding
							   error: &readError];
	if (!ok)
		content = nil;
	if (content == nil) {
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert setMessageText: @"Cannot open file"];
		[alert setInformativeText: [readError localizedDescription]];
		[alert runModal];
		return NO;
	}

	NPPDocument *document = [self createDocumentWithText: content
										 path: normalizedPath
									 encoding: detectedEncoding];
	[[NSDocumentController sharedDocumentController] noteNewRecentDocumentURL: [NSURL fileURLWithPath: normalizedPath]];
	[self selectDocument: document];
	return YES;
}

- (BOOL) saveDocument: (NPPDocument *) document forceSaveAs: (BOOL) forceSaveAs
{
	if (document == nil)
		return NO;

	NSString *path = document.filePath;
	if (forceSaveAs || path == nil) {
		NSSavePanel *panel = [NSSavePanel savePanel];
		if (document.filePath != nil) {
			[panel setDirectoryURL: [NSURL fileURLWithPath: [document.filePath stringByDeletingLastPathComponent]]];
			[panel setNameFieldStringValue: [document.filePath lastPathComponent]];
		}
		if ([panel runModal] != NSFileHandlingPanelOKButton)
			return NO;
		path = [[panel URL] path];
	}

	NSString *text = [document.editor string];
	NSError *writeError = nil;
	NSStringEncoding encoding = (document.encoding != 0) ? document.encoding : NSUTF8StringEncoding;
	BOOL ok = [text writeToFile: path atomically: YES encoding: encoding error: &writeError];
	if (!ok) {
		ok = [text writeToFile: path atomically: YES encoding: NSUTF8StringEncoding error: &writeError];
		encoding = NSUTF8StringEncoding;
	}

	if (!ok) {
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert setMessageText: @"Cannot save file"];
		[alert setInformativeText: [writeError localizedDescription]];
		[alert runModal];
		return NO;
	}

	document.filePath = [path stringByStandardizingPath];
	document.encoding = encoding;
	document.untitled = NO;
	document.dirty = NO;
	document.metadataDirty = NO;
	[document.editor setGeneralProperty: SCI_SETSAVEPOINT parameter: 0 value: 0];

	[self applyLexerToDocument: document];
	[self updateDocumentTabs];
	[self updateWindowTitle];
	[[NSDocumentController sharedDocumentController] noteNewRecentDocumentURL: [NSURL fileURLWithPath: document.filePath]];
	if (mLiveTailEnabled && document == [self currentDocument])
		[self resetLiveTailTrackingForCurrentDocument];
	return YES;
}

- (BOOL) canCloseDocument: (NPPDocument *) document
{
	if (document == nil || !document.dirty)
		return YES;

	NSAlert *alert = [[[NSAlert alloc] init] autorelease];
	[alert setMessageText: @"Unsaved changes"];
	[alert setInformativeText: [NSString stringWithFormat: @"Save changes to %@?", [self titleForDocument: document]]];
	[alert addButtonWithTitle: @"Save"];
	[alert addButtonWithTitle: @"Don't Save"];
	[alert addButtonWithTitle: @"Cancel"];

	NSInteger response = [alert runModal];
	if (response == NSAlertFirstButtonReturn)
		return [self saveDocument: document forceSaveAs: NO];
	if (response == NSAlertSecondButtonReturn)
		return YES;
	return NO;
}

//--------------------------------------------------------------------------------------------------

- (IBAction) newDocument: (id) sender
{
	#pragma unused(sender)
	[self createUntitledDocument];
	[self updateDocumentTabs];
	[self updateWindowTitle];
}

- (IBAction) openDocument: (id) sender
{
	#pragma unused(sender)

	NSOpenPanel *panel = [NSOpenPanel openPanel];
	[panel setCanChooseFiles: YES];
	[panel setCanChooseDirectories: NO];
	[panel setAllowsMultipleSelection: YES];

	if ([panel runModal] != NSFileHandlingPanelOKButton)
		return;

	for (NSURL *url in [panel URLs])
		[self openPath: [url path]];

	[self updateDocumentTabs];
	[self updateWindowTitle];
}

- (IBAction) saveDocument: (id) sender
{
	#pragma unused(sender)
	[self saveDocument: [self currentDocument] forceSaveAs: NO];
}

- (IBAction) saveDocumentAs: (id) sender
{
	#pragma unused(sender)
	[self saveDocument: [self currentDocument] forceSaveAs: YES];
}

- (IBAction) revertDocumentToSaved: (id) sender
{
	#pragma unused(sender)

	NPPDocument *document = [self currentDocument];
	if (document == nil)
		return;

	if (document.filePath == nil) {
		[document.editor setString: @""];
		document.dirty = NO;
		document.metadataDirty = NO;
		[document.editor setGeneralProperty: SCI_SETSAVEPOINT parameter: 0 value: 0];
		[self updateDocumentTabs];
		[self updateWindowTitle];
		return;
	}

	NSError *readError = nil;
	NSStringEncoding detectedEncoding = NSUTF8StringEncoding;
	NSString *content = nil;
	BOOL ok = [self readTextFileAtPath: document.filePath
							content: &content
						usedEncoding: &detectedEncoding
							   error: &readError];
	if (!ok)
		content = nil;
	if (content == nil) {
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert setMessageText: @"Cannot revert file"];
		[alert setInformativeText: [readError localizedDescription]];
		[alert runModal];
		return;
	}

	[document.editor setString: content];
	document.encoding = detectedEncoding;
	document.dirty = NO;
	document.metadataDirty = NO;
	[document.editor setGeneralProperty: SCI_SETSAVEPOINT parameter: 0 value: 0];
	[self applyLexerToDocument: document];
	[self updateDocumentTabs];
	[self updateWindowTitle];
}

- (IBAction) performClose: (id) sender
{
	#pragma unused(sender)

	NPPDocument *document = [self currentDocument];
	if (document == nil)
		return;

	if (![self canCloseDocument: document])
		return;

	[mTabView removeTabViewItem: document.tabItem];
	[mDocuments removeObject: document];

	if ([mDocuments count] == 0)
		[self createUntitledDocument];

	[self updateDocumentTabs];
	[self updateWindowTitle];
}

//--------------------------------------------------------------------------------------------------

- (IBAction) searchText: (id) sender
{
	if (mEditor == nil)
		return;

	NSString *query = [sender respondsToSelector: @selector(stringValue)] ? [sender stringValue] : mLastSearch;
	if ([query length] == 0)
		return;

	[mLastSearch release];
	mLastSearch = [query copy];

	BOOL found = [mEditor findAndHighlightText: mLastSearch
							   matchCase: NO
							   wholeWord: NO
							    scrollTo: YES
									wrap: YES];
	if (!found)
		NSBeep();

	[self updateWindowTitle];
}

- (IBAction) showSearchDialog: (id) sender
{
	#pragma unused(sender)
	[self ensureSearchPanel];
	[self updateSearchScopeUiState];
	if ([mSearchFindField stringValue].length == 0) {
		NSString *selected = [mEditor selectedString];
		if ([selected length] > 0)
			[mSearchFindField setStringValue: selected];
	}
	if ([mSearchScopePopup indexOfSelectedItem] == 3 && [mSearchFolderField stringValue].length == 0) {
		NPPDocument *document = [self currentDocument];
		if ([document.filePath length] > 0)
			[mSearchFolderField setStringValue: [document.filePath stringByDeletingLastPathComponent]];
	}
	[mSearchPanel makeKeyAndOrderFront: nil];
	[[mSearchPanel windowController] showWindow: nil];
}

- (void) ensureSearchPanel
{
	if (mSearchPanel != nil)
		return;

	mSearchPanel = [[NSPanel alloc] initWithContentRect: NSMakeRect(200, 200, 700, 340)
										 styleMask: NSTitledWindowMask | NSClosableWindowMask | NSUtilityWindowMask
										   backing: NSBackingStoreBuffered
											 defer: NO];
	[mSearchPanel setTitle: @"Search"];

	NSView *content = [mSearchPanel contentView];

	NSTextField *findLabel = [[[NSTextField alloc] initWithFrame: NSMakeRect(20, 294, 90, 22)] autorelease];
	[findLabel setEditable: NO];
	[findLabel setBordered: NO];
	[findLabel setDrawsBackground: NO];
	[findLabel setStringValue: @"Find what:"];
	[content addSubview: findLabel];

	mSearchFindField = [[[NSTextField alloc] initWithFrame: NSMakeRect(110, 290, 470, 28)] autorelease];
	[content addSubview: mSearchFindField];

	NSTextField *replaceLabel = [[[NSTextField alloc] initWithFrame: NSMakeRect(20, 256, 90, 22)] autorelease];
	[replaceLabel setEditable: NO];
	[replaceLabel setBordered: NO];
	[replaceLabel setDrawsBackground: NO];
	[replaceLabel setStringValue: @"Replace with:"];
	[content addSubview: replaceLabel];

	mSearchReplaceField = [[[NSTextField alloc] initWithFrame: NSMakeRect(110, 252, 470, 28)] autorelease];
	[content addSubview: mSearchReplaceField];

	mSearchMatchCase = [[[NSButton alloc] initWithFrame: NSMakeRect(20, 214, 140, 22)] autorelease];
	[mSearchMatchCase setButtonType: NSSwitchButton];
	[mSearchMatchCase setTitle: @"Match case"];
	[content addSubview: mSearchMatchCase];

	mSearchWholeWord = [[[NSButton alloc] initWithFrame: NSMakeRect(170, 214, 170, 22)] autorelease];
	[mSearchWholeWord setButtonType: NSSwitchButton];
	[mSearchWholeWord setTitle: @"Whole word"];
	[content addSubview: mSearchWholeWord];

	mSearchRegex = [[[NSButton alloc] initWithFrame: NSMakeRect(350, 214, 120, 22)] autorelease];
	[mSearchRegex setButtonType: NSSwitchButton];
	[mSearchRegex setTitle: @"Regular expr"];
	[content addSubview: mSearchRegex];

	mSearchMarkAll = [[[NSButton alloc] initWithFrame: NSMakeRect(480, 214, 120, 22)] autorelease];
	[mSearchMarkAll setButtonType: NSSwitchButton];
	[mSearchMarkAll setTitle: @"Mark all"];
	[content addSubview: mSearchMarkAll];

	NSTextField *scopeLabel = [[[NSTextField alloc] initWithFrame: NSMakeRect(20, 176, 90, 22)] autorelease];
	[scopeLabel setEditable: NO];
	[scopeLabel setBordered: NO];
	[scopeLabel setDrawsBackground: NO];
	[scopeLabel setStringValue: @"Scope:"];
	[content addSubview: scopeLabel];

	mSearchScopePopup = [[[NSPopUpButton alloc] initWithFrame: NSMakeRect(110, 172, 220, 28) pullsDown: NO] autorelease];
	[mSearchScopePopup addItemsWithTitles: [NSArray arrayWithObjects: @"Current Document", @"All Open Documents", @"Project Files", @"Folder", nil]];
	[mSearchScopePopup setTarget: self];
	[mSearchScopePopup setAction: @selector(updateSearchScopeUiState)];
	[content addSubview: mSearchScopePopup];

	NSTextField *filterLabel = [[[NSTextField alloc] initWithFrame: NSMakeRect(340, 176, 70, 22)] autorelease];
	[filterLabel setEditable: NO];
	[filterLabel setBordered: NO];
	[filterLabel setDrawsBackground: NO];
	[filterLabel setStringValue: @"Filter:"];
	[content addSubview: filterLabel];

	mSearchFilterField = [[[NSTextField alloc] initWithFrame: NSMakeRect(410, 172, 260, 28)] autorelease];
	[mSearchFilterField setPlaceholderString: @"*.mm;*.h"];
	[content addSubview: mSearchFilterField];

	NSTextField *folderLabel = [[[NSTextField alloc] initWithFrame: NSMakeRect(20, 138, 90, 22)] autorelease];
	[folderLabel setEditable: NO];
	[folderLabel setBordered: NO];
	[folderLabel setDrawsBackground: NO];
	[folderLabel setStringValue: @"Folder:"];
	[content addSubview: folderLabel];

	mSearchFolderField = [[[NSTextField alloc] initWithFrame: NSMakeRect(110, 134, 480, 28)] autorelease];
	[mSearchFolderField setPlaceholderString: @"/path/to/folder"];
	[content addSubview: mSearchFolderField];

	NSButton *browseFolderButton = [[[NSButton alloc] initWithFrame: NSMakeRect(598, 134, 72, 28)] autorelease];
	[browseFolderButton setTitle: @"Browse"];
	[browseFolderButton setTarget: self];
	[browseFolderButton setAction: @selector(browseSearchFolder:)];
	[content addSubview: browseFolderButton];

	NSButton *findNextButton = [[[NSButton alloc] initWithFrame: NSMakeRect(20, 78, 120, 34)] autorelease];
	[findNextButton setTitle: @"Find Next"];
	[findNextButton setTarget: self];
	[findNextButton setAction: @selector(searchPanelFindNext:)];
	[content addSubview: findNextButton];

	NSButton *findAllButton = [[[NSButton alloc] initWithFrame: NSMakeRect(152, 78, 120, 34)] autorelease];
	[findAllButton setTitle: @"Find All"];
	[findAllButton setTarget: self];
	[findAllButton setAction: @selector(searchPanelFindAll:)];
	[content addSubview: findAllButton];

	NSButton *replaceButton = [[[NSButton alloc] initWithFrame: NSMakeRect(284, 78, 120, 34)] autorelease];
	[replaceButton setTitle: @"Replace"];
	[replaceButton setTarget: self];
	[replaceButton setAction: @selector(searchPanelReplace:)];
	[content addSubview: replaceButton];

	NSButton *replaceAllButton = [[[NSButton alloc] initWithFrame: NSMakeRect(416, 78, 120, 34)] autorelease];
	[replaceAllButton setTitle: @"Replace All"];
	[replaceAllButton setTarget: self];
	[replaceAllButton setAction: @selector(searchPanelReplaceAll:)];
	[content addSubview: replaceAllButton];

	NSButton *markButton = [[[NSButton alloc] initWithFrame: NSMakeRect(548, 78, 120, 34)] autorelease];
	[markButton setTitle: @"Mark"];
	[markButton setTarget: self];
	[markButton setAction: @selector(searchPanelMarkAll:)];
	[content addSubview: markButton];

	[self updateSearchScopeUiState];
}

- (void) updateSearchScopeUiState
{
	if (mSearchScopePopup == nil)
		return;

	NSInteger scope = [mSearchScopePopup indexOfSelectedItem];
	BOOL needsFilter = (scope == 2 || scope == 3);
	BOOL needsFolder = (scope == 3);

	[mSearchFilterField setEnabled: needsFilter];
	[mSearchFolderField setEnabled: needsFolder];
	if (mSearchFolderField != nil)
		[mSearchFolderField setTextColor: needsFolder ? [NSColor controlTextColor] : [NSColor disabledControlTextColor]];
}

- (NSInteger) currentSearchFlagsFromPanel
{
	NSInteger flags = SCFIND_NONE;
	if ([mSearchMatchCase state] == NSOnState)
		flags |= SCFIND_MATCHCASE;
	if ([mSearchWholeWord state] == NSOnState)
		flags |= SCFIND_WHOLEWORD;
	if ([mSearchRegex state] == NSOnState)
		flags |= SCFIND_REGEXP;
	return flags;
}

- (NSArray *) rangesForQuery: (NSString *) query inText: (NSString *) text regex: (BOOL) regex matchCase: (BOOL) matchCase wholeWord: (BOOL) wholeWord
{
	if ([query length] == 0 || [text length] == 0)
		return [NSArray array];

	NSMutableArray *ranges = [NSMutableArray array];
	if (regex) {
		NSRegularExpressionOptions options = matchCase ? 0 : NSRegularExpressionCaseInsensitive;
		NSError *error = nil;
		NSRegularExpression *rx = [NSRegularExpression regularExpressionWithPattern: query options: options error: &error];
		if (rx == nil || error != nil)
			return [NSArray array];

		NSArray *matches = [rx matchesInString: text options: 0 range: NSMakeRange(0, [text length])];
		for (NSTextCheckingResult *match in matches) {
			NSRange range = [match range];
			if (range.location != NSNotFound && range.length > 0)
				[ranges addObject: [NSValue valueWithRange: range]];
		}
		return ranges;
	}

	NSStringCompareOptions options = matchCase ? 0 : NSCaseInsensitiveSearch;
	NSRange searchRange = NSMakeRange(0, [text length]);
	while (searchRange.location < [text length]) {
		NSRange found = [text rangeOfString: query options: options range: searchRange];
		if (found.location == NSNotFound)
			break;

		BOOL include = YES;
		if (wholeWord) {
			BOOL leftBoundary = [self isWordBoundaryAtIndex: found.location inText: text];
			BOOL rightBoundary = [self isWordBoundaryAtIndex: NSMaxRange(found) inText: text];
			include = leftBoundary && rightBoundary;
		}

		if (include)
			[ranges addObject: [NSValue valueWithRange: found]];

		NSUInteger nextStart = NSMaxRange(found);
		if (nextStart <= searchRange.location)
			nextStart = searchRange.location + 1;
		if (nextStart >= [text length])
			break;
		searchRange = NSMakeRange(nextStart, [text length] - nextStart);
	}

	return ranges;
}

- (BOOL) isWordBoundaryAtIndex: (NSUInteger) index inText: (NSString *) text
{
	if (index == 0 || index >= [text length])
		return YES;

	NSCharacterSet *wordSet = [NSCharacterSet characterSetWithCharactersInString: @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_"];
	unichar c = [text characterAtIndex: index];
	return ![wordSet characterIsMember: c];
}

- (void) selectRange: (NSRange) range inEditor: (ScintillaView *) editor
{
	if (editor == nil || range.location == NSNotFound)
		return;

	[editor setGeneralProperty: SCI_SETSEL parameter: range.location value: NSMaxRange(range)];
	[editor setGeneralProperty: SCI_SCROLLCARET parameter: 0 value: 0];
}

- (void) searchPanelFindNext: (id) sender
{
	#pragma unused(sender)
	NSString *query = [mSearchFindField stringValue];
	if ([query length] == 0)
		return;

	BOOL regex = ([mSearchRegex state] == NSOnState);
	BOOL matchCase = ([mSearchMatchCase state] == NSOnState);
	BOOL wholeWord = ([mSearchWholeWord state] == NSOnState);

	NSInteger scope = [mSearchScopePopup indexOfSelectedItem];
	NPPDocument *document = [self currentDocument];
	if (document == nil)
		return;

	if (scope == 0) {
		NSString *text = [document.editor string];
		NSArray *ranges = [self rangesForQuery: query inText: text regex: regex matchCase: matchCase wholeWord: wholeWord];
		if ([ranges count] == 0) {
			NSBeep();
			return;
		}

		long currentPos = [document.editor getGeneralProperty: SCI_GETSELECTIONEND parameter: 0];
		NSRange picked = [[ranges objectAtIndex: 0] rangeValue];
		for (NSValue *value in ranges) {
			NSRange r = [value rangeValue];
			if ((long)r.location >= currentPos) {
				picked = r;
				break;
			}
		}

		[self selectRange: picked inEditor: document.editor];
	} else if (scope == 1) {
		NSInteger startIndex = [mDocuments indexOfObject: document];
		if (startIndex == NSNotFound)
			startIndex = 0;
		NSInteger count = [mDocuments count];
		BOOL found = NO;
		for (NSInteger offset = 0; offset < count; ++offset) {
			NSInteger index = (startIndex + offset) % count;
			NPPDocument *doc = [mDocuments objectAtIndex: index];
			NSArray *ranges = [self rangesForQuery: query inText: [doc.editor string] regex: regex matchCase: matchCase wholeWord: wholeWord];
			if ([ranges count] == 0)
				continue;
			[self selectDocument: doc];
			[self selectRange: [[ranges objectAtIndex: 0] rangeValue] inEditor: doc.editor];
			found = YES;
			break;
		}
		if (!found)
			NSBeep();
	} else {
		NSArray *files = [self filesForSearchScope: scope];
		BOOL found = NO;
		for (NSString *path in files) {
			NSStringEncoding enc = NSUTF8StringEncoding;
			NSString *text = nil;
			if (![self readTextFileAtPath: path content: &text usedEncoding: &enc error: nil] || text == nil)
				continue;
			if (text == nil)
				continue;
			NSArray *ranges = [self rangesForQuery: query inText: text regex: regex matchCase: matchCase wholeWord: wholeWord];
			if ([ranges count] == 0)
				continue;
			[self openPath: path];
			NPPDocument *opened = [self currentDocument];
			if (opened != nil)
				[self selectRange: [[ranges objectAtIndex: 0] rangeValue] inEditor: opened.editor];
			found = YES;
			break;
		}
		if (!found)
			NSBeep();
	}

	[mLastSearch release];
	mLastSearch = [query copy];

	if ([mSearchMarkAll state] == NSOnState)
		[self searchPanelMarkAll: nil];
}

- (void) searchPanelFindAll: (id) sender
{
	#pragma unused(sender)
	NSString *query = [mSearchFindField stringValue];
	if ([query length] == 0)
		return;

	BOOL regex = ([mSearchRegex state] == NSOnState);
	BOOL matchCase = ([mSearchMatchCase state] == NSOnState);
	BOOL wholeWord = ([mSearchWholeWord state] == NSOnState);
	NSInteger scope = [mSearchScopePopup indexOfSelectedItem];

	NSMutableString *results = [NSMutableString stringWithFormat: @"Search Results\nQuery: %@\nMode: %@\n\n", query, regex ? @"Regex" : @"Normal"];

	if (scope == 0 || scope == 1) {
		NSArray *docs = (scope == 0 && [self currentDocument] != nil)
			? [NSArray arrayWithObject: [self currentDocument]]
			: [NSArray arrayWithArray: mDocuments];
		for (NPPDocument *doc in docs) {
			NSString *text = [doc.editor string];
			NSArray *ranges = [self rangesForQuery: query inText: text regex: regex matchCase: matchCase wholeWord: wholeWord];
			if ([ranges count] == 0)
				continue;

			NSString *name = (doc.filePath != nil) ? doc.filePath : [self titleForDocument: doc];
			[results appendFormat: @"\n%@\n", name];

			__block NSUInteger lineNo = 0;
			[text enumerateLinesUsingBlock: ^(NSString *line, BOOL *stop) {
				lineNo++;
				NSArray *lineMatches = [self rangesForQuery: query inText: line regex: regex matchCase: matchCase wholeWord: wholeWord];
				if ([lineMatches count] > 0)
					[results appendFormat: @"  %lu: %@\n", (unsigned long)lineNo, line];
				if ([results length] > 500000)
					*stop = YES;
			}];
		}
	} else {
		NSArray *files = [self filesForSearchScope: scope];
		for (NSString *path in files) {
			NSStringEncoding encoding = NSUTF8StringEncoding;
			NSString *text = nil;
			if (![self readTextFileAtPath: path content: &text usedEncoding: &encoding error: nil] || text == nil)
				continue;
			if (text == nil)
				continue;

			NSArray *ranges = [self rangesForQuery: query inText: text regex: regex matchCase: matchCase wholeWord: wholeWord];
			if ([ranges count] == 0)
				continue;

			[results appendFormat: @"\n%@\n", path];
			__block NSUInteger lineNo = 0;
			[text enumerateLinesUsingBlock: ^(NSString *line, BOOL *stop) {
				lineNo++;
				NSArray *lineMatches = [self rangesForQuery: query inText: line regex: regex matchCase: matchCase wholeWord: wholeWord];
				if ([lineMatches count] > 0)
					[results appendFormat: @"  %lu: %@\n", (unsigned long)lineNo, line];
				if ([results length] > 500000)
					*stop = YES;
			}];
		}
	}

	NPPDocument *resultDocument = [self createDocumentWithText: results path: nil encoding: NSUTF8StringEncoding];
	[resultDocument.editor setGeneralProperty: SCI_SETSAVEPOINT parameter: 0 value: 0];
	resultDocument.dirty = NO;
	resultDocument.metadataDirty = NO;
	[self updateDocumentTabs];
}

- (void) searchPanelReplace: (id) sender
{
	#pragma unused(sender)
	NPPDocument *document = [self currentDocument];
	if (document == nil)
		return;

	NSString *query = [mSearchFindField stringValue];
	NSString *replacement = [mSearchReplaceField stringValue];
	if ([query length] == 0)
		return;

	NSString *selected = [document.editor selectedString];
	BOOL regex = ([mSearchRegex state] == NSOnState);
	BOOL matchCase = ([mSearchMatchCase state] == NSOnState);
	BOOL wholeWord = ([mSearchWholeWord state] == NSOnState);

	if (regex) {
		NSRegularExpressionOptions options = matchCase ? 0 : NSRegularExpressionCaseInsensitive;
		NSRegularExpression *rx = [NSRegularExpression regularExpressionWithPattern: query options: options error: nil];
		if (rx != nil && [selected length] > 0 && [rx firstMatchInString: selected options: 0 range: NSMakeRange(0, [selected length])] != nil) {
			NSString *newSelection = [rx stringByReplacingMatchesInString: selected options: 0 range: NSMakeRange(0, [selected length]) withTemplate: replacement];
			[document.editor message: SCI_REPLACESEL wParam: 0 lParam: (sptr_t)[newSelection UTF8String]];
			[self searchPanelFindNext: nil];
			return;
		}
	} else {
		NSStringCompareOptions options = matchCase ? 0 : NSCaseInsensitiveSearch;
		NSRange range = [selected rangeOfString: query options: options];
		BOOL wholeOk = !wholeWord || (range.location == 0 && range.length == [selected length]);
		if (range.location != NSNotFound && wholeOk) {
			[document.editor message: SCI_REPLACESEL wParam: 0 lParam: (sptr_t)[replacement UTF8String]];
			[self searchPanelFindNext: nil];
			return;
		}
	}

	[self searchPanelFindNext: nil];
}

- (void) searchPanelReplaceAll: (id) sender
{
	#pragma unused(sender)
	NSString *query = [mSearchFindField stringValue];
	NSString *replacement = [mSearchReplaceField stringValue];
	if ([query length] == 0)
		return;

	BOOL regex = ([mSearchRegex state] == NSOnState);
	BOOL matchCase = ([mSearchMatchCase state] == NSOnState);
	BOOL wholeWord = ([mSearchWholeWord state] == NSOnState);
	NSInteger scope = [mSearchScopePopup indexOfSelectedItem];

	NSUInteger replacements = 0;
	if (scope == 2 || scope == 3) {
		NSArray *files = [self filesForSearchScope: scope];
		for (NSString *path in files) {
			NSStringEncoding fileEncoding = NSUTF8StringEncoding;
			NSString *text = nil;
			if (![self readTextFileAtPath: path content: &text usedEncoding: &fileEncoding error: nil] || text == nil)
				continue;
			if (text == nil)
				continue;
			NSString *updated = text;
			if (regex) {
				NSRegularExpressionOptions options = matchCase ? 0 : NSRegularExpressionCaseInsensitive;
				NSRegularExpression *rx = [NSRegularExpression regularExpressionWithPattern: query options: options error: nil];
				if (rx == nil)
					continue;
				NSArray *matches = [rx matchesInString: text options: 0 range: NSMakeRange(0, [text length])];
				replacements += [matches count];
				updated = [rx stringByReplacingMatchesInString: text options: 0 range: NSMakeRange(0, [text length]) withTemplate: replacement];
			} else {
				NSArray *ranges = [self rangesForQuery: query inText: text regex: NO matchCase: matchCase wholeWord: wholeWord];
					replacements += [ranges count];
					if ([ranges count] > 0) {
						NSStringCompareOptions options = matchCase ? 0 : NSCaseInsensitiveSearch;
						if (wholeWord) {
							NSMutableString *mutableText = [text mutableCopy];
							for (NSInteger i = [ranges count] - 1; i >= 0; --i) {
								NSRange r = [[ranges objectAtIndex: i] rangeValue];
								[mutableText replaceCharactersInRange: r withString: replacement];
							}
							updated = [mutableText autorelease];
						} else {
							updated = [text stringByReplacingOccurrencesOfString: query withString: replacement options: options range: NSMakeRange(0, [text length])];
						}
					}
			}

			if (![updated isEqualToString: text]) {
				NSError *writeError = nil;
				BOOL writeOk = [updated writeToFile: path atomically: YES encoding: fileEncoding error: &writeError];
				if (!writeOk) {
					writeOk = [updated writeToFile: path atomically: YES encoding: NSUTF8StringEncoding error: &writeError];
					if (writeOk)
						fileEncoding = NSUTF8StringEncoding;
				}
				if (!writeOk)
					continue;
				NPPDocument *openDoc = [self documentForPath: path];
				if (openDoc != nil) {
					[openDoc.editor setString: updated];
					openDoc.encoding = fileEncoding;
					openDoc.dirty = NO;
					openDoc.metadataDirty = NO;
					[openDoc.editor setGeneralProperty: SCI_SETSAVEPOINT parameter: 0 value: 0];
				}
			}
		}
	} else {
		NSArray *docs = nil;
		if (scope == 0 && [self currentDocument] != nil)
			docs = [NSArray arrayWithObject: [self currentDocument]];
		else
			docs = [NSArray arrayWithArray: mDocuments];

		for (NPPDocument *doc in docs) {
			NSString *text = [doc.editor string];
			NSString *updated = text;

			if (regex) {
				NSRegularExpressionOptions options = matchCase ? 0 : NSRegularExpressionCaseInsensitive;
				NSRegularExpression *rx = [NSRegularExpression regularExpressionWithPattern: query options: options error: nil];
				if (rx == nil)
					continue;
				NSArray *matches = [rx matchesInString: text options: 0 range: NSMakeRange(0, [text length])];
				replacements += [matches count];
				updated = [rx stringByReplacingMatchesInString: text options: 0 range: NSMakeRange(0, [text length]) withTemplate: replacement];
			} else {
				NSArray *ranges = [self rangesForQuery: query inText: text regex: NO matchCase: matchCase wholeWord: wholeWord];
					replacements += [ranges count];
					if ([ranges count] > 0) {
						NSStringCompareOptions options = matchCase ? 0 : NSCaseInsensitiveSearch;
						if (wholeWord) {
							NSMutableString *mutableText = [text mutableCopy];
							for (NSInteger i = [ranges count] - 1; i >= 0; --i) {
								NSRange r = [[ranges objectAtIndex: i] rangeValue];
								[mutableText replaceCharactersInRange: r withString: replacement];
							}
							updated = [mutableText autorelease];
						} else {
							updated = [text stringByReplacingOccurrencesOfString: query withString: replacement options: options range: NSMakeRange(0, [text length])];
						}
					}
			}

			if (![updated isEqualToString: text]) {
				[doc.editor setString: updated];
				doc.dirty = YES;
			}
		}
	}

	[self refreshEditorState: nil];
	[mStatusBar setStringValue: [NSString stringWithFormat: @"Replace All completed: %lu replacement(s)", (unsigned long)replacements]];
}

- (void) searchPanelMarkAll: (id) sender
{
	#pragma unused(sender)
	NPPDocument *document = [self currentDocument];
	if (document == nil)
		return;

	NSString *query = [mSearchFindField stringValue];
	if ([query length] == 0)
		return;

	BOOL regex = ([mSearchRegex state] == NSOnState);
	BOOL matchCase = ([mSearchMatchCase state] == NSOnState);
	BOOL wholeWord = ([mSearchWholeWord state] == NSOnState);

	NSString *text = [document.editor string];
	NSArray *ranges = [self rangesForQuery: query inText: text regex: regex matchCase: matchCase wholeWord: wholeWord];
	long textLength = [document.editor getGeneralProperty: SCI_GETLENGTH parameter: 0];

	[document.editor setGeneralProperty: SCI_INDICSETSTYLE parameter: 8 value: INDIC_ROUNDBOX];
	[document.editor setColorProperty: SCI_INDICSETFORE parameter: 8 fromHTML: @"#FF9A00"];
	[document.editor setGeneralProperty: SCI_SETINDICATORCURRENT parameter: 8 value: 0];
	[document.editor setGeneralProperty: SCI_INDICATORCLEARRANGE parameter: 0 value: textLength];
	for (NSValue *value in ranges) {
		NSRange range = [value rangeValue];
		[document.editor setGeneralProperty: SCI_INDICATORFILLRANGE parameter: range.location value: range.length];
	}

	[document.editor setStatusText: [NSString stringWithFormat: @"Marked %lu occurrence(s)", (unsigned long)[ranges count]]];
}

- (void) findNextBackwards: (BOOL) backwards
{
	if (mEditor == nil)
		return;

	if ([mLastSearch length] == 0) {
		NSString *selected = [mEditor selectedString];
		if ([selected length] > 0) {
			[mLastSearch release];
			mLastSearch = [selected copy];
		} else {
			NSString *prompt = [self promptForStringWithTitle: @"Find"
											   message: @"Find text:"
										  defaultValue: @""];
			if ([prompt length] == 0)
				return;
			[mLastSearch release];
			mLastSearch = [prompt copy];
		}
	}

	BOOL found = [mEditor findAndHighlightText: mLastSearch
							   matchCase: NO
							   wholeWord: NO
							    scrollTo: YES
									wrap: YES
							   backwards: backwards];
	if (!found)
		NSBeep();
}

- (IBAction) performFindPanelAction: (id) sender
{
	NSInteger tag = [sender respondsToSelector: @selector(tag)] ? [sender tag] : 0;

	if (tag == 1) {
		[self showSearchDialog: nil];
	} else if (tag == 2) {
		if (mSearchPanel != nil && [mSearchPanel isVisible] && [[mSearchFindField stringValue] length] > 0)
			[self searchPanelFindNext: nil];
		else
			[self findNextBackwards: NO];
	} else if (tag == 3) {
		if (mSearchPanel != nil && [mSearchPanel isVisible] && [[mSearchFindField stringValue] length] > 0) {
			NPPDocument *document = [self currentDocument];
			if (document != nil) {
				NSString *query = [mSearchFindField stringValue];
				BOOL regex = ([mSearchRegex state] == NSOnState);
				BOOL matchCase = ([mSearchMatchCase state] == NSOnState);
				BOOL wholeWord = ([mSearchWholeWord state] == NSOnState);
				NSArray *ranges = [self rangesForQuery: query inText: [document.editor string] regex: regex matchCase: matchCase wholeWord: wholeWord];
				if ([ranges count] == 0) {
					NSBeep();
					return;
				}
				long currentPos = [document.editor getGeneralProperty: SCI_GETSELECTIONSTART parameter: 0];
				NSRange picked = [[ranges lastObject] rangeValue];
				for (NSInteger i = [ranges count] - 1; i >= 0; --i) {
					NSRange r = [[ranges objectAtIndex: i] rangeValue];
					if ((long)r.location < currentPos) {
						picked = r;
						break;
					}
				}
				[self selectRange: picked inEditor: document.editor];
			}
		} else {
			[self findNextBackwards: YES];
		}
	} else if (tag == 7) {
		NSString *selection = [mEditor selectedString];
		if ([selection length] > 0) {
			[mLastSearch release];
			mLastSearch = [selection copy];
		}
	}
}

- (IBAction) replaceText: (id) sender
{
	#pragma unused(sender)
	[self showSearchDialog: nil];
	[mSearchPanel makeFirstResponder: mSearchReplaceField];
}

- (IBAction) findInFiles: (id) sender
{
	#pragma unused(sender)
	[self ensureSearchPanel];
	[mSearchScopePopup selectItemAtIndex: 3];
	[self updateSearchScopeUiState];

	if ([mSearchFindField stringValue].length == 0) {
		NSString *selected = [mEditor selectedString];
		if ([selected length] > 0)
			[mSearchFindField setStringValue: selected];
		else if ([mLastSearch length] > 0)
			[mSearchFindField setStringValue: mLastSearch];
	}

	if ([mSearchFolderField stringValue].length == 0) {
		NPPDocument *document = [self currentDocument];
		if ([document.filePath length] > 0) {
			[mSearchFolderField setStringValue: [document.filePath stringByDeletingLastPathComponent]];
		} else if ([mProjectRootPaths count] > 0) {
			[mSearchFolderField setStringValue: [mProjectRootPaths objectAtIndex: 0]];
		}
	}

	[mSearchPanel makeKeyAndOrderFront: nil];
	[[mSearchPanel windowController] showWindow: nil];
	[mSearchPanel makeFirstResponder: mSearchFindField];
}

- (IBAction) browseSearchFolder: (id) sender
{
	#pragma unused(sender)
	[self ensureSearchPanel];

	NSOpenPanel *panel = [NSOpenPanel openPanel];
	[panel setCanChooseFiles: NO];
	[panel setCanChooseDirectories: YES];
	[panel setAllowsMultipleSelection: NO];
	[panel setPrompt: @"Select"];

	NSString *existing = [[mSearchFolderField stringValue] stringByStandardizingPath];
	if ([existing length] > 0)
		[panel setDirectoryURL: [NSURL fileURLWithPath: existing]];

	if ([panel runModal] != NSFileHandlingPanelOKButton)
		return;

	NSArray *urls = [panel URLs];
	if ([urls count] == 0)
		return;

	NSString *folder = [[[urls objectAtIndex: 0] path] stringByStandardizingPath];
	[mSearchFolderField setStringValue: folder];
	[mSearchScopePopup selectItemAtIndex: 3];
	[self updateSearchScopeUiState];
}

- (IBAction) goToLine: (id) sender
{
	#pragma unused(sender)
	if (mEditor == nil)
		return;

	long currentPos = [mEditor getGeneralProperty: SCI_GETCURRENTPOS parameter: 0];
	long currentLine = [mEditor getGeneralProperty: SCI_LINEFROMPOSITION parameter: currentPos] + 1;

	NSString *lineText = [self promptForStringWithTitle: @"Go to Line"
										message: @"Enter line number:"
									defaultValue: [NSString stringWithFormat: @"%ld", currentLine]];
	if ([lineText length] == 0)
		return;

	NSInteger targetLine = [lineText integerValue];
	if (targetLine < 1)
		targetLine = 1;

	[mEditor setGeneralProperty: SCI_GOTOLINE parameter: targetLine - 1 value: 0];
	[self updateWindowTitle];
}

- (IBAction) toggleWordWrap: (id) sender
{
	#pragma unused(sender)
	mWordWrap = !mWordWrap;
	for (NPPDocument *document in mDocuments)
		[self applyDisplayFlagsToEditor: document.editor];
	[self refreshUiToggles];
}

- (IBAction) toggleWhitespaceVisibility: (id) sender
{
	#pragma unused(sender)
	mShowWhitespace = !mShowWhitespace;
	for (NPPDocument *document in mDocuments)
		[self applyDisplayFlagsToEditor: document.editor];
	[self refreshUiToggles];
}

- (IBAction) toggleEolVisibility: (id) sender
{
	#pragma unused(sender)
	mShowEol = !mShowEol;
	for (NPPDocument *document in mDocuments)
		[self applyDisplayFlagsToEditor: document.editor];
	[self refreshUiToggles];
}

- (IBAction) toggleLineNumberMargin: (id) sender
{
	#pragma unused(sender)
	mShowLineNumbers = !mShowLineNumbers;
	for (NPPDocument *document in mDocuments)
		[self applyDisplayFlagsToEditor: document.editor];
	if (sciExtra != nil)
		[self applyDisplayFlagsToEditor: sciExtra];
	[self refreshUiToggles];
}

- (IBAction) toggleLiveTailCurrentFile: (id) sender
{
	#pragma unused(sender)
	[self toggleLiveTailEnabled: !mLiveTailEnabled];
}

- (void) toggleLiveTailEnabled: (BOOL) enabled
{
	if (!enabled) {
		mLiveTailEnabled = NO;
		[mLiveTailPath release];
		mLiveTailPath = nil;
		mLiveTailKnownLength = 0;
		[mLiveTailLastModificationDate release];
		mLiveTailLastModificationDate = nil;
		[self refreshUiToggles];
		return;
	}

	NPPDocument *document = [self currentDocument];
	if (document == nil || [document.filePath length] == 0) {
		NSBeep();
		if (document != nil)
			[document.editor setStatusText: @"Live tail requires a saved file"];
		return;
	}

	mLiveTailEnabled = YES;
	[self resetLiveTailTrackingForCurrentDocument];
	[document.editor setStatusText: @"Live tail enabled"];
	[self refreshUiToggles];
}

- (IBAction) toggleSplitScreen: (id) sender
{
	#pragma unused(sender)
	mSplitViewEnabled = !mSplitViewEnabled;
	if (mSplitViewEnabled)
		mDocumentMapVisible = NO;

	if (!(mSplitViewEnabled || mDocumentMapVisible)) {
		[self removeExtraEditor];
		[mComparedFilePath release];
		mComparedFilePath = nil;
	} else {
		[self ensureExtraEditorForCurrentDocument];
	}

	[self refreshUiToggles];
}

- (IBAction) toggleDocumentMap: (id) sender
{
	#pragma unused(sender)
	mDocumentMapVisible = !mDocumentMapVisible;
	if (mDocumentMapVisible) {
		mSplitViewEnabled = NO;
		[mComparedFilePath release];
		mComparedFilePath = nil;
	}

	if (!(mSplitViewEnabled || mDocumentMapVisible))
		[self removeExtraEditor];
	else
		[self ensureExtraEditorForCurrentDocument];

	[self refreshUiToggles];
}

- (IBAction) toggleAutosave: (id) sender
{
	#pragma unused(sender)
	mAutosaveEnabled = !mAutosaveEnabled;
	mNextAutosaveTime = [NSDate timeIntervalSinceReferenceDate] + kNppMacAutosaveIntervalSeconds;
	if (mEditor != nil)
		[mEditor setStatusText: mAutosaveEnabled ? @"Autosave enabled" : @"Autosave disabled"];
	[self refreshUiToggles];
}

- (IBAction) compareCurrentWithFile: (id) sender
{
	#pragma unused(sender)
	NPPDocument *document = [self currentDocument];
	if (document == nil)
		return;

	NSOpenPanel *panel = [NSOpenPanel openPanel];
	[panel setCanChooseFiles: YES];
	[panel setCanChooseDirectories: NO];
	[panel setAllowsMultipleSelection: NO];
	[panel setPrompt: @"Compare"];

	if ([panel runModal] != NSFileHandlingPanelOKButton)
		return;

	NSArray *urls = [panel URLs];
	if ([urls count] == 0)
		return;

	NSString *otherPath = [[[urls objectAtIndex: 0] path] stringByStandardizingPath];
	if ([otherPath length] == 0)
		return;

	mSplitViewEnabled = YES;
	mDocumentMapVisible = NO;
	[mComparedFilePath release];
	mComparedFilePath = [otherPath copy];
	[self ensureExtraEditorForCurrentDocument];

	if (mEditor != nil)
		[mEditor setStatusText: [NSString stringWithFormat: @"Comparing with %@", [otherPath lastPathComponent]]];
	[self refreshUiToggles];
}

- (IBAction) sortSelectedLinesAscending: (id) sender
{
	#pragma unused(sender)
	NPPDocument *document = [self currentDocument];
	if (document == nil)
		return;

	NSString *text = [document.editor string];
	NSRange selection = [self currentSelectionRangeInEditor: document.editor];
	NSRange lineRange = (selection.length == 0) ? NSMakeRange(0, [text length]) : [text lineRangeForRange: selection];
	NSString *segment = [text substringWithRange: lineRange];

	NSMutableArray *lines = [NSMutableArray array];
	[segment enumerateLinesUsingBlock: ^(NSString *line, BOOL *stop) {
		#pragma unused(stop)
		[lines addObject: line];
	}];
	if ([lines count] == 0)
		return;

	[lines sortUsingComparator: ^NSComparisonResult(id lhs, id rhs) {
		return [(NSString *)lhs localizedCaseInsensitiveCompare: (NSString *)rhs];
	}];

	BOOL hadTrailingNewline = [segment hasSuffix: @"\n"] || [segment hasSuffix: @"\r"];
	NSString *replacement = [lines componentsJoinedByString: @"\n"];
	if (hadTrailingNewline)
		replacement = [replacement stringByAppendingString: @"\n"];

	NSMutableString *updated = [[text mutableCopy] autorelease];
	[updated replaceCharactersInRange: lineRange withString: replacement];
	[document.editor setString: updated];
	[document.editor setGeneralProperty: SCI_SETSEL parameter: lineRange.location value: lineRange.location + [replacement length]];
	document.dirty = YES;
}

- (IBAction) sortSelectedLinesDescending: (id) sender
{
	#pragma unused(sender)
	NPPDocument *document = [self currentDocument];
	if (document == nil)
		return;

	NSString *text = [document.editor string];
	NSRange selection = [self currentSelectionRangeInEditor: document.editor];
	NSRange lineRange = (selection.length == 0) ? NSMakeRange(0, [text length]) : [text lineRangeForRange: selection];
	NSString *segment = [text substringWithRange: lineRange];

	NSMutableArray *lines = [NSMutableArray array];
	[segment enumerateLinesUsingBlock: ^(NSString *line, BOOL *stop) {
		#pragma unused(stop)
		[lines addObject: line];
	}];
	if ([lines count] == 0)
		return;

	[lines sortUsingComparator: ^NSComparisonResult(id lhs, id rhs) {
		return [(NSString *)rhs localizedCaseInsensitiveCompare: (NSString *)lhs];
	}];

	BOOL hadTrailingNewline = [segment hasSuffix: @"\n"] || [segment hasSuffix: @"\r"];
	NSString *replacement = [lines componentsJoinedByString: @"\n"];
	if (hadTrailingNewline)
		replacement = [replacement stringByAppendingString: @"\n"];

	NSMutableString *updated = [[text mutableCopy] autorelease];
	[updated replaceCharactersInRange: lineRange withString: replacement];
	[document.editor setString: updated];
	[document.editor setGeneralProperty: SCI_SETSEL parameter: lineRange.location value: lineRange.location + [replacement length]];
	document.dirty = YES;
}

- (IBAction) trimTrailingWhitespaceLines: (id) sender
{
	#pragma unused(sender)
	[self replaceSelectedOrWholeTextInCurrentDocumentUsingBlock: ^NSString *(NSString *input, NSRange range, BOOL *didChange) {
		NSMutableString *output = [NSMutableString string];
		[input enumerateSubstringsInRange: range
								  options: NSStringEnumerationByLines | NSStringEnumerationSubstringNotRequired
							   usingBlock: ^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop) {
								   #pragma unused(substring)
								   #pragma unused(stop)
								   NSString *line = [input substringWithRange: substringRange];
								   NSString *trimmed = [line stringByReplacingOccurrencesOfString: @"[ \t]+$"
																				   withString: @""
																					  options: NSRegularExpressionSearch
																						range: NSMakeRange(0, [line length])];
								   NSRange endingRange = NSMakeRange(NSMaxRange(substringRange), NSMaxRange(enclosingRange) - NSMaxRange(substringRange));
								   NSString *lineEnding = (endingRange.length > 0) ? [input substringWithRange: endingRange] : @"";
								   [output appendString: trimmed];
								   [output appendString: lineEnding];
							   }];
		NSString *original = [input substringWithRange: range];
		*didChange = ![original isEqualToString: output];
		return output;
	}];
}

- (IBAction) convertSelectionToUpperCase: (id) sender
{
	#pragma unused(sender)
	[self replaceSelectedOrWholeTextInCurrentDocumentUsingBlock: ^NSString *(NSString *input, NSRange range, BOOL *didChange) {
		NSString *original = [input substringWithRange: range];
		NSString *result = [original uppercaseString];
		*didChange = ![original isEqualToString: result];
		return result;
	}];
}

- (IBAction) convertSelectionToLowerCase: (id) sender
{
	#pragma unused(sender)
	[self replaceSelectedOrWholeTextInCurrentDocumentUsingBlock: ^NSString *(NSString *input, NSRange range, BOOL *didChange) {
		NSString *original = [input substringWithRange: range];
		NSString *result = [original lowercaseString];
		*didChange = ![original isEqualToString: result];
		return result;
	}];
}

- (IBAction) convertSelectionToCamelCase: (id) sender
{
	#pragma unused(sender)
	[self replaceSelectedOrWholeTextInCurrentDocumentUsingBlock: ^NSString *(NSString *input, NSRange range, BOOL *didChange) {
		NSString *original = [input substringWithRange: range];
		NSString *result = [self camelCaseFromString: original];
		*didChange = ![original isEqualToString: result];
		return result;
	}];
}

- (void) resetLiveTailTrackingForCurrentDocument
{
	if (!mLiveTailEnabled)
		return;

	NPPDocument *document = [self currentDocument];
	if (document == nil || [document.filePath length] == 0)
		return;

	NSString *path = [document.filePath stringByStandardizingPath];
	if (mLiveTailPath == nil || ![mLiveTailPath isEqualToString: path]) {
		[mLiveTailPath release];
		mLiveTailPath = [path copy];
	}

	NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath: path error: nil];
	mLiveTailKnownLength = [[attributes objectForKey: NSFileSize] unsignedLongLongValue];
	[mLiveTailLastModificationDate release];
	mLiveTailLastModificationDate = [[attributes objectForKey: NSFileModificationDate] copy];
}

- (void) refreshLiveTail
{
	if (!mLiveTailEnabled)
		return;

	NPPDocument *document = [self currentDocument];
	if (document == nil || [document.filePath length] == 0)
		return;

	NSString *path = [document.filePath stringByStandardizingPath];
	if (mLiveTailPath == nil || ![mLiveTailPath isEqualToString: path]) {
		[self resetLiveTailTrackingForCurrentDocument];
		return;
	}

	NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath: path error: nil];
	if (attributes == nil)
		return;

	unsigned long long fileSize = [[attributes objectForKey: NSFileSize] unsignedLongLongValue];
	NSDate *modifiedDate = [attributes objectForKey: NSFileModificationDate];
	BOOL hasSizeChange = (fileSize != mLiveTailKnownLength);
	BOOL hasTimeChange = (mLiveTailLastModificationDate == nil && modifiedDate != nil) ||
		(mLiveTailLastModificationDate != nil && modifiedDate != nil && [modifiedDate compare: mLiveTailLastModificationDate] == NSOrderedDescending);
	if (!hasSizeChange && !hasTimeChange)
		return;

	BOOL reloadedAll = NO;
	if (fileSize < mLiveTailKnownLength) {
		NSStringEncoding detectedEncoding = document.encoding;
		NSString *content = nil;
		if ([self readTextFileAtPath: path content: &content usedEncoding: &detectedEncoding error: nil] && content != nil) {
			[document.editor setString: content];
			document.encoding = detectedEncoding;
			[self applyLexerToDocument: document];
			reloadedAll = YES;
		}
	} else if (fileSize > mLiveTailKnownLength) {
		NSFileHandle *handle = [NSFileHandle fileHandleForReadingAtPath: path];
		NSData *delta = nil;
		@try {
			[handle seekToFileOffset: mLiveTailKnownLength];
			delta = [handle readDataToEndOfFile];
		} @catch (NSException *exception) {
			#pragma unused(exception)
			delta = nil;
		}
		[handle closeFile];

		if ([delta length] > 0) {
			NSStringEncoding chunkEncoding = (document.encoding != 0) ? document.encoding : NSUTF8StringEncoding;
			NSString *deltaText = [[[NSString alloc] initWithData: delta encoding: chunkEncoding] autorelease];
			if (deltaText == nil) {
				NSStringEncoding fallback = [self detectEncodingForData: delta fallbackEncoding: chunkEncoding];
				deltaText = [[[NSString alloc] initWithData: delta encoding: fallback] autorelease];
			}

			if (deltaText != nil) {
				NSData *utf8 = [deltaText dataUsingEncoding: NSUTF8StringEncoding allowLossyConversion: YES];
				if ([utf8 length] > 0) {
					[document.editor message: SCI_APPENDTEXT wParam: [utf8 length] lParam: (sptr_t)[utf8 bytes]];
					long endPos = [document.editor getGeneralProperty: SCI_GETLENGTH parameter: 0];
					[document.editor setGeneralProperty: SCI_GOTOPOS parameter: endPos value: 0];
					[document.editor setGeneralProperty: SCI_SCROLLCARET parameter: 0 value: 0];
				}
			} else {
				NSStringEncoding detectedEncoding = document.encoding;
				NSString *content = nil;
				if ([self readTextFileAtPath: path content: &content usedEncoding: &detectedEncoding error: nil] && content != nil) {
					[document.editor setString: content];
					document.encoding = detectedEncoding;
					[self applyLexerToDocument: document];
					reloadedAll = YES;
				}
			}
		}
	}

	if (reloadedAll) {
		long endPos = [document.editor getGeneralProperty: SCI_GETLENGTH parameter: 0];
		[document.editor setGeneralProperty: SCI_GOTOPOS parameter: endPos value: 0];
		[document.editor setGeneralProperty: SCI_SCROLLCARET parameter: 0 value: 0];
	}

	[document.editor setGeneralProperty: SCI_SETSAVEPOINT parameter: 0 value: 0];
	document.dirty = NO;
	document.metadataDirty = NO;

	mLiveTailKnownLength = fileSize;
	[mLiveTailLastModificationDate release];
	mLiveTailLastModificationDate = [modifiedDate copy];
}

- (IBAction) toggleSidebar: (id) sender
{
	#pragma unused(sender)
	mSidebarVisible = !mSidebarVisible;
	NSArray *subviews = [mWorkspaceSplitView subviews];
	if ([subviews count] > 0) {
		NSView *sidebar = [subviews objectAtIndex: 0];
		[sidebar setHidden: !mSidebarVisible];
		if (mSidebarVisible)
			[mWorkspaceSplitView setPosition: 260 ofDividerAtIndex: 0];
		else
			[mWorkspaceSplitView setPosition: 0 ofDividerAtIndex: 0];
		[mWorkspaceSplitView adjustSubviews];
	}
	[self refreshUiToggles];
}

- (IBAction) openProjectFolder: (id) sender
{
	#pragma unused(sender)
	NSOpenPanel *panel = [NSOpenPanel openPanel];
	[panel setCanChooseFiles: NO];
	[panel setCanChooseDirectories: YES];
	[panel setAllowsMultipleSelection: YES];
	[panel setPrompt: @"Add"];
	if ([panel runModal] != NSFileHandlingPanelOKButton)
		return;

	for (NSURL *url in [panel URLs]) {
		NSString *path = [url path];
		if ([path length] > 0)
			[self addProjectRootPath: path];
	}

	if (!mSidebarVisible)
		[self toggleSidebar: nil];
}

- (void) ensurePreferencesWindow
{
	if (mPreferencesWindow != nil)
		return;

	mPreferencesWindow = [[NSWindow alloc] initWithContentRect: NSMakeRect(260, 260, 520, 320)
												  styleMask: NSTitledWindowMask | NSClosableWindowMask
													backing: NSBackingStoreBuffered
													  defer: NO];
	[mPreferencesWindow setTitle: @"Preferences"];

	NSView *content = [mPreferencesWindow contentView];

	mPrefRestoreSession = [[[NSButton alloc] initWithFrame: NSMakeRect(24, 260, 250, 24)] autorelease];
	[mPrefRestoreSession setButtonType: NSSwitchButton];
	[mPrefRestoreSession setTitle: @"Restore previous session on startup"];
	[content addSubview: mPrefRestoreSession];

	mPrefShowToolbar = [[[NSButton alloc] initWithFrame: NSMakeRect(24, 232, 250, 24)] autorelease];
	[mPrefShowToolbar setButtonType: NSSwitchButton];
	[mPrefShowToolbar setTitle: @"Show toolbar"];
	[content addSubview: mPrefShowToolbar];

	mPrefShowStatusBar = [[[NSButton alloc] initWithFrame: NSMakeRect(24, 204, 250, 24)] autorelease];
	[mPrefShowStatusBar setButtonType: NSSwitchButton];
	[mPrefShowStatusBar setTitle: @"Show status bar"];
	[content addSubview: mPrefShowStatusBar];

	mPrefShowSidebar = [[[NSButton alloc] initWithFrame: NSMakeRect(24, 176, 250, 24)] autorelease];
	[mPrefShowSidebar setButtonType: NSSwitchButton];
	[mPrefShowSidebar setTitle: @"Show sidebar (Project/Function List)"];
	[content addSubview: mPrefShowSidebar];

	mPrefDefaultWordWrap = [[[NSButton alloc] initWithFrame: NSMakeRect(24, 148, 250, 24)] autorelease];
	[mPrefDefaultWordWrap setButtonType: NSSwitchButton];
	[mPrefDefaultWordWrap setTitle: @"Default word wrap for new files"];
	[content addSubview: mPrefDefaultWordWrap];

	mPrefDefaultLineNumbers = [[[NSButton alloc] initWithFrame: NSMakeRect(24, 120, 250, 24)] autorelease];
	[mPrefDefaultLineNumbers setButtonType: NSSwitchButton];
	[mPrefDefaultLineNumbers setTitle: @"Default line numbers for new files"];
	[content addSubview: mPrefDefaultLineNumbers];

	NSButton *applyButton = [[[NSButton alloc] initWithFrame: NSMakeRect(330, 18, 80, 32)] autorelease];
	[applyButton setTitle: @"Apply"];
	[applyButton setTarget: self];
	[applyButton setAction: @selector(preferencesApplyAndClose:)];
	[content addSubview: applyButton];

	NSButton *cancelButton = [[[NSButton alloc] initWithFrame: NSMakeRect(420, 18, 80, 32)] autorelease];
	[cancelButton setTitle: @"Close"];
	[cancelButton setTarget: self];
	[cancelButton setAction: @selector(preferencesCancel:)];
	[content addSubview: cancelButton];
}

- (IBAction) showPreferences: (id) sender
{
	#pragma unused(sender)
	[self ensurePreferencesWindow];
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[mPrefRestoreSession setState: [defaults objectForKey: kNppMacPrefRestoreSessionKey] ? [defaults boolForKey: kNppMacPrefRestoreSessionKey] : YES];
	[mPrefShowToolbar setState: [defaults objectForKey: kNppMacPrefShowToolbarKey] ? [defaults boolForKey: kNppMacPrefShowToolbarKey] : YES];
	[mPrefShowStatusBar setState: [defaults objectForKey: kNppMacPrefShowStatusBarKey] ? [defaults boolForKey: kNppMacPrefShowStatusBarKey] : YES];
	[mPrefShowSidebar setState: [defaults objectForKey: kNppMacPrefShowSidebarKey] ? [defaults boolForKey: kNppMacPrefShowSidebarKey] : YES];
	[mPrefDefaultWordWrap setState: [defaults objectForKey: kNppMacPrefDefaultWordWrapKey] ? [defaults boolForKey: kNppMacPrefDefaultWordWrapKey] : NO];
	[mPrefDefaultLineNumbers setState: [defaults objectForKey: kNppMacPrefDefaultLineNumbersKey] ? [defaults boolForKey: kNppMacPrefDefaultLineNumbersKey] : YES];
	[mPreferencesWindow makeKeyAndOrderFront: nil];
}

- (void) applyPreferences
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults setBool: ([mPrefRestoreSession state] == NSOnState) forKey: kNppMacPrefRestoreSessionKey];
	[defaults setBool: ([mPrefShowToolbar state] == NSOnState) forKey: kNppMacPrefShowToolbarKey];
	[defaults setBool: ([mPrefShowStatusBar state] == NSOnState) forKey: kNppMacPrefShowStatusBarKey];
	[defaults setBool: ([mPrefShowSidebar state] == NSOnState) forKey: kNppMacPrefShowSidebarKey];
	[defaults setBool: ([mPrefDefaultWordWrap state] == NSOnState) forKey: kNppMacPrefDefaultWordWrapKey];
	[defaults setBool: ([mPrefDefaultLineNumbers state] == NSOnState) forKey: kNppMacPrefDefaultLineNumbersKey];
	[defaults synchronize];

	BOOL toolbarVisible = ([mPrefShowToolbar state] == NSOnState);
	[mMainToolbar setVisible: toolbarVisible];

	BOOL statusVisible = ([mPrefShowStatusBar state] == NSOnState);
	mStatusBarVisible = statusVisible;
	[mStatusBar setHidden: !mStatusBarVisible];
	NSView *content = [mEditHost contentView];
	NSRect bounds = [content bounds];
	CGFloat statusHeight = mStatusBarVisible ? 22.0 : 0.0;
	NSRect splitFrame = bounds;
	splitFrame.size.height = MAX(0.0, bounds.size.height - statusHeight);
	[mWorkspaceSplitView setFrame: splitFrame];
	[mStatusBar setFrame: NSMakeRect(0, 0, bounds.size.width, 22)];
	[self updateStatusBar];

	BOOL sidebarVisible = ([mPrefShowSidebar state] == NSOnState);
	if (mSidebarVisible != sidebarVisible)
		[self toggleSidebar: nil];
}

- (void) preferencesApplyAndClose: (id) sender
{
	#pragma unused(sender)
	[self applyPreferences];
	[mPreferencesWindow orderOut: nil];
}

- (void) preferencesCancel: (id) sender
{
	#pragma unused(sender)
	[mPreferencesWindow orderOut: nil];
}

- (void) setupPluginsMenu
{
	NSMenu *mainMenu = [NSApp mainMenu];
	if (mainMenu == nil)
		return;

	NSMenuItem *pluginsItem = [mainMenu itemWithTitle: @"Plugins"];
	if (pluginsItem == nil) {
		pluginsItem = [[[NSMenuItem alloc] initWithTitle: @"Plugins" action: nil keyEquivalent: @""] autorelease];
		mPluginsMenu = [[[NSMenu alloc] initWithTitle: @"Plugins"] autorelease];
		[pluginsItem setSubmenu: mPluginsMenu];
		[mainMenu insertItem: pluginsItem atIndex: [mainMenu numberOfItems] - 1];
	} else {
		mPluginsMenu = [pluginsItem submenu];
		if (mPluginsMenu == nil) {
			mPluginsMenu = [[[NSMenu alloc] initWithTitle: @"Plugins"] autorelease];
			[pluginsItem setSubmenu: mPluginsMenu];
		}
	}

	[mPluginsMenu removeAllItems];
	NSMenuItem *reloadItem = [[[NSMenuItem alloc] initWithTitle: @"Reload Plugins"
														 action: @selector(reloadPlugins:)
												  keyEquivalent: @""] autorelease];
	[reloadItem setTarget: self];
	[mPluginsMenu addItem: reloadItem];
	[mPluginsMenu addItem: [NSMenuItem separatorItem]];

	if ([mPluginDescriptors count] == 0) {
		NSMenuItem *emptyItem = [[[NSMenuItem alloc] initWithTitle: @"(No plugins loaded)" action: nil keyEquivalent: @""] autorelease];
		[emptyItem setEnabled: NO];
		[mPluginsMenu addItem: emptyItem];
		return;
	}

	for (NSDictionary *plugin in mPluginDescriptors) {
		NSString *title = [plugin objectForKey: @"name"];
		if ([title length] == 0)
			title = [plugin objectForKey: @"path"];

		NSArray *commands = [plugin objectForKey: @"commands"];
		if ([commands isKindOfClass: [NSArray class]] && [commands count] > 0) {
			NSMenuItem *pluginItem = [[[NSMenuItem alloc] initWithTitle: title action: nil keyEquivalent: @""] autorelease];
			NSMenu *subMenu = [[[NSMenu alloc] initWithTitle: title] autorelease];
			[pluginItem setSubmenu: subMenu];
			for (NSDictionary *command in commands) {
				NSString *commandTitle = [command objectForKey: @"title"];
				if ([commandTitle length] == 0)
					commandTitle = [command objectForKey: @"id"];
				if ([commandTitle length] == 0)
					commandTitle = @"Command";
				NSMenuItem *commandItem = [[[NSMenuItem alloc] initWithTitle: commandTitle
																	 action: @selector(invokePluginCommand:)
															  keyEquivalent: @""] autorelease];
				[commandItem setTarget: self];
				[commandItem setRepresentedObject: [NSDictionary dictionaryWithObjectsAndKeys:
					plugin, @"plugin",
					command, @"command",
					nil]];
				[subMenu addItem: commandItem];
			}
			[mPluginsMenu addItem: pluginItem];
			continue;
		}

		NSMenuItem *runItem = [[[NSMenuItem alloc] initWithTitle: [NSString stringWithFormat: @"Run %@", title]
														  action: @selector(invokePluginCommand:)
												   keyEquivalent: @""] autorelease];
		[runItem setTarget: self];
		[runItem setRepresentedObject: plugin];
		[mPluginsMenu addItem: runItem];
	}
}

- (void) loadPluginsFromDefaultLocations
{
	NSString *bundlePlugins = [[[NSBundle mainBundle] builtInPlugInsPath] stringByStandardizingPath];
	NSString *cwdPlugins = [[[[NSFileManager defaultManager] currentDirectoryPath] stringByAppendingPathComponent: @"macos/plugins"] stringByStandardizingPath];
	NSArray *pluginDirs = [NSArray arrayWithObjects:
		bundlePlugins,
		cwdPlugins,
		[[@"~/.nppmac/plugins" stringByExpandingTildeInPath] stringByStandardizingPath],
		nil];

	NSMutableSet *loadedFiles = [NSMutableSet set];
	NSFileManager *fm = [NSFileManager defaultManager];
	for (NSString *dir in pluginDirs) {
		BOOL isDir = NO;
		if (![fm fileExistsAtPath: dir isDirectory: &isDir] || !isDir)
			continue;

		NSArray *entries = [fm contentsOfDirectoryAtPath: dir error: nil];
		for (NSString *entry in entries) {
			if (![[entry pathExtension] isEqualToString: @"dylib"])
				continue;

			NSString *fullPath = [dir stringByAppendingPathComponent: entry];
			if ([loadedFiles containsObject: fullPath])
				continue;

			void *handle = dlopen([fullPath fileSystemRepresentation], RTLD_NOW | RTLD_LOCAL);
			if (handle == NULL)
				continue;

			[loadedFiles addObject: fullPath];

			NppMacPluginInitFn initFn = (NppMacPluginInitFn)dlsym(handle, "nppmac_plugin_init");
			NppMacPluginDeinitFn deinitFn = (NppMacPluginDeinitFn)dlsym(handle, "nppmac_plugin_deinit");
			NppMacPluginNameFn nameFn = (NppMacPluginNameFn)dlsym(handle, "nppmac_plugin_name");
			NppMacPluginRunFn runFn = (NppMacPluginRunFn)dlsym(handle, "nppmac_plugin_run");
			NppMacPluginApiVersionFn apiVersionFn = (NppMacPluginApiVersionFn)dlsym(handle, "nppmac_plugin_api_version");
			NppMacPluginCommandCountFn commandCountFn = (NppMacPluginCommandCountFn)dlsym(handle, "nppmac_plugin_command_count");
			NppMacPluginCommandNameFn commandNameFn = (NppMacPluginCommandNameFn)dlsym(handle, "nppmac_plugin_command_name");
			NppMacPluginCommandIdFn commandIdFn = (NppMacPluginCommandIdFn)dlsym(handle, "nppmac_plugin_command_id");
			NppMacPluginRunCommandFn runCommandFn = (NppMacPluginRunCommandFn)dlsym(handle, "nppmac_plugin_run_command");

			NSString *name = [entry stringByDeletingPathExtension];
			if (nameFn != NULL) {
				const char *cName = nameFn();
				if (cName != NULL && strlen(cName) > 0)
					name = [NSString stringWithUTF8String: cName];
			}

			int apiVersion = (apiVersionFn != NULL) ? apiVersionFn() : 0;
			NSMutableArray *commands = [NSMutableArray array];
			if (commandCountFn != NULL && runCommandFn != NULL) {
				int count = commandCountFn();
				if (count < 0)
					count = 0;
				if (count > 128)
					count = 128;
				for (int i = 0; i < count; ++i) {
					NSString *commandTitle = nil;
					if (commandNameFn != NULL) {
						const char *cTitle = commandNameFn(i);
						if (cTitle != NULL && strlen(cTitle) > 0)
							commandTitle = [NSString stringWithUTF8String: cTitle];
					}
					NSString *commandId = nil;
					if (commandIdFn != NULL) {
						const char *cId = commandIdFn(i);
						if (cId != NULL && strlen(cId) > 0)
							commandId = [NSString stringWithUTF8String: cId];
					}

					if ([commandTitle length] == 0)
						commandTitle = [NSString stringWithFormat: @"Command %d", i + 1];
					if ([commandId length] == 0)
						commandId = [NSString stringWithFormat: @"cmd.%d", i + 1];

					[commands addObject: [NSDictionary dictionaryWithObjectsAndKeys:
						commandTitle, @"title",
						commandId, @"id",
						[NSNumber numberWithInt: i], @"index",
						nil]];
				}
			}

			if (runFn == NULL && (runCommandFn == NULL || [commands count] == 0)) {
				dlclose(handle);
				continue;
			}

			if (initFn != NULL)
				initFn(self);

			NSMutableDictionary *descriptor = [NSMutableDictionary dictionary];
			[descriptor setObject: name forKey: @"name"];
			[descriptor setObject: fullPath forKey: @"path"];
			[descriptor setObject: [NSNumber numberWithInt: apiVersion] forKey: @"apiVersion"];
			[descriptor setObject: [NSValue valueWithPointer: handle] forKey: @"handle"];
			[descriptor setObject: [NSValue valueWithBytes: &deinitFn objCType: @encode(NppMacPluginDeinitFn)] forKey: @"deinit"];
			[descriptor setObject: [NSValue valueWithBytes: &runFn objCType: @encode(NppMacPluginRunFn)] forKey: @"run"];
			[descriptor setObject: [NSValue valueWithBytes: &runCommandFn objCType: @encode(NppMacPluginRunCommandFn)] forKey: @"runCommand"];
			[descriptor setObject: commands forKey: @"commands"];
			[mPluginDescriptors addObject: descriptor];
		}
	}

	[self setupPluginsMenu];
}

- (IBAction) reloadPlugins: (id) sender
{
	#pragma unused(sender)
	for (NSDictionary *plugin in mPluginDescriptors) {
		NppMacPluginDeinitFn deinitFn = NULL;
		NSValue *deinitValue = [plugin objectForKey: @"deinit"];
		if ([deinitValue isKindOfClass: [NSValue class]])
			[deinitValue getValue: &deinitFn];
		void *handle = [[plugin objectForKey: @"handle"] pointerValue];
		if (deinitFn != NULL)
			deinitFn(self);
		if (handle != NULL)
			dlclose(handle);
	}
	[mPluginDescriptors removeAllObjects];
	[self loadPluginsFromDefaultLocations];
}

- (void) invokePluginCommand: (id) sender
{
	id represented = [sender representedObject];
	NSDictionary *plugin = nil;
	NSDictionary *command = nil;

	if ([represented isKindOfClass: [NSDictionary class]] && [represented objectForKey: @"plugin"] != nil) {
		plugin = [represented objectForKey: @"plugin"];
		command = [represented objectForKey: @"command"];
	} else if ([represented isKindOfClass: [NSDictionary class]]) {
		plugin = represented;
	}

	if (![plugin isKindOfClass: [NSDictionary class]]) {
		NSBeep();
		return;
	}

	NppMacPluginRunCommandFn runCommandFn = NULL;
	NSValue *runCommandValue = [plugin objectForKey: @"runCommand"];
	if ([runCommandValue isKindOfClass: [NSValue class]])
		[runCommandValue getValue: &runCommandFn];
	if (runCommandFn != NULL && [command isKindOfClass: [NSDictionary class]]) {
		int index = [[command objectForKey: @"index"] intValue];
		runCommandFn(index, self);
		return;
	}

	NppMacPluginRunFn runFn = NULL;
	NSValue *runValue = [plugin objectForKey: @"run"];
	if ([runValue isKindOfClass: [NSValue class]])
		[runValue getValue: &runFn];
	if (runFn != NULL) {
		runFn(self);
		return;
	}

	NSBeep();
}

- (NSString *) macroCompatibilityPath
{
	NSString *dir = [kNppMacMacroCompatibilityFolder stringByExpandingTildeInPath];
	return [dir stringByAppendingPathComponent: kNppMacMacroCompatibilityFile];
}

- (void) loadMacrosFromCompatibilityFile
{
	[mNamedMacros removeAllObjects];

	NSString *path = [self macroCompatibilityPath];
	if (![[NSFileManager defaultManager] fileExistsAtPath: path])
		return;

	NSData *data = [NSData dataWithContentsOfFile: path];
	if (data == nil || [data length] == 0)
		return;

	NSError *error = nil;
	NSXMLDocument *document = [[[NSXMLDocument alloc] initWithData: data options: 0 error: &error] autorelease];
	if (document == nil || error != nil)
		return;

	NSArray *macroNodes = [document nodesForXPath: @"//Macro" error: nil];
	for (NSXMLElement *macroElement in macroNodes) {
		if (![macroElement isKindOfClass: [NSXMLElement class]])
			continue;

		NSString *macroName = [[macroElement attributeForName: @"name"] stringValue];
		if ([macroName length] == 0)
			continue;

		NSMutableArray *steps = [NSMutableArray array];
		NSArray *actions = [macroElement elementsForName: @"Action"];
		for (NSXMLElement *action in actions) {
			NSString *messageValue = [[action attributeForName: @"message"] stringValue];
			if ([messageValue length] == 0)
				continue;

			unsigned int message = (unsigned int)[messageValue integerValue];
			uptr_t wParam = (uptr_t)[[[action attributeForName: @"wParam"] stringValue] longLongValue];
			sptr_t lParam = (sptr_t)[[[action attributeForName: @"lParam"] stringValue] longLongValue];
			NSString *sParam = [[action attributeForName: @"sParam"] stringValue];

			NSMutableDictionary *step = [NSMutableDictionary dictionary];
			[step setObject: [NSNumber numberWithUnsignedInt: message] forKey: @"message"];
			[step setObject: [NSNumber numberWithUnsignedLongLong: (unsigned long long)wParam] forKey: @"wParam"];
			[step setObject: [NSNumber numberWithLongLong: (long long)lParam] forKey: @"lParam"];
			if ([sParam length] > 0)
				[step setObject: sParam forKey: @"text"];
			[steps addObject: step];
		}

		if ([steps count] == 0)
			continue;

		[mNamedMacros addObject: [NSDictionary dictionaryWithObjectsAndKeys:
			macroName, @"name",
			steps, @"steps",
			nil]];
	}
}

- (void) saveMacrosToCompatibilityFile
{
	NSString *path = [self macroCompatibilityPath];
	NSString *directory = [path stringByDeletingLastPathComponent];
	NSFileManager *fm = [NSFileManager defaultManager];
	if (![fm fileExistsAtPath: directory]) {
		[fm createDirectoryAtPath: directory withIntermediateDirectories: YES attributes: nil error: nil];
	}

	NSXMLDocument *document = nil;
	if ([fm fileExistsAtPath: path]) {
		NSData *existingData = [NSData dataWithContentsOfFile: path];
		if (existingData != nil && [existingData length] > 0)
			document = [[[NSXMLDocument alloc] initWithData: existingData options: 0 error: nil] autorelease];
	}

	if (document == nil) {
		NSXMLElement *root = [[[NSXMLElement alloc] initWithName: @"NotepadPlus"] autorelease];
		document = [[[NSXMLDocument alloc] initWithRootElement: root] autorelease];
	}

	NSXMLElement *root = [document rootElement];
	if (root == nil || ![[root name] isEqualToString: @"NotepadPlus"]) {
		root = [[[NSXMLElement alloc] initWithName: @"NotepadPlus"] autorelease];
		[document setRootElement: root];
	}

	NSArray *existingMacrosNodes = [root elementsForName: @"Macros"];
	NSXMLElement *macrosNode = ([existingMacrosNodes count] > 0) ? [existingMacrosNodes objectAtIndex: 0] : nil;
	if (macrosNode == nil) {
		macrosNode = [[[NSXMLElement alloc] initWithName: @"Macros"] autorelease];
		[root addChild: macrosNode];
	}

	while ([[macrosNode children] count] > 0)
		[[macrosNode childAtIndex: 0] detach];

	for (NSDictionary *macro in mNamedMacros) {
		NSString *name = [macro objectForKey: @"name"];
		NSArray *steps = [macro objectForKey: @"steps"];
		if ([name length] == 0 || ![steps isKindOfClass: [NSArray class]] || [steps count] == 0)
			continue;

		NSXMLElement *macroElement = [[[NSXMLElement alloc] initWithName: @"Macro"] autorelease];
		[macroElement addAttribute: [NSXMLNode attributeWithName: @"name" stringValue: name]];

		for (NSDictionary *step in steps) {
			NSXMLElement *action = [[[NSXMLElement alloc] initWithName: @"Action"] autorelease];
			[action addAttribute: [NSXMLNode attributeWithName: @"type" stringValue: @"2"]];
			[action addAttribute: [NSXMLNode attributeWithName: @"message" stringValue: [[step objectForKey: @"message"] stringValue]]];
			[action addAttribute: [NSXMLNode attributeWithName: @"wParam" stringValue: [[step objectForKey: @"wParam"] stringValue]]];
			[action addAttribute: [NSXMLNode attributeWithName: @"lParam" stringValue: [[step objectForKey: @"lParam"] stringValue]]];
			NSString *text = [step objectForKey: @"text"];
			if ([text length] > 0)
				[action addAttribute: [NSXMLNode attributeWithName: @"sParam" stringValue: text]];
			[macroElement addChild: action];
		}

		[macrosNode addChild: macroElement];
	}

	NSData *xmlData = [document XMLDataWithOptions: NSXMLNodePrettyPrint];
	[xmlData writeToFile: path atomically: YES];
}

- (void) executeMacroSteps: (NSArray *) steps repeatCount: (NSUInteger) repeatCount
{
	NPPDocument *document = [self currentDocument];
	if (document == nil || ![steps isKindOfClass: [NSArray class]] || [steps count] == 0 || repeatCount == 0)
		return;

	if (mMacroRecording)
		[self startStopMacroRecording: nil];

	for (NSUInteger iteration = 0; iteration < repeatCount; ++iteration) {
		for (NSDictionary *step in steps) {
			unsigned int message = [[step objectForKey: @"message"] unsignedIntValue];
			uptr_t wParam = [[step objectForKey: @"wParam"] unsignedLongLongValue];
			sptr_t lParam = [[step objectForKey: @"lParam"] longLongValue];
			NSString *text = [step objectForKey: @"text"];
			if ([text length] > 0)
				lParam = (sptr_t)[text UTF8String];
			[document.editor message: message wParam: wParam lParam: lParam];
		}
	}
}

- (void) updateMacroMenuState
{
	if (mMacroMenu == nil)
		return;

	if (mMacroRecordMenuItem == nil)
		mMacroRecordMenuItem = [mMacroMenu itemWithTag: kMenuTagMacroRecord];
	if (mMacroRecordMenuItem != nil)
		[mMacroRecordMenuItem setTitle: mMacroRecording ? @"Stop Recording" : @"Start Recording"];

	NSMenuItem *playItem = [mMacroMenu itemWithTag: kMenuTagMacroPlay];
	if (playItem != nil)
		[playItem setEnabled: [mMacroSteps count] > 0];

	NSMenuItem *saveItem = [mMacroMenu itemWithTag: kMenuTagMacroSaveRecorded];
	if (saveItem != nil)
		[saveItem setEnabled: [mMacroSteps count] > 0];

	NSMenuItem *repeatItem = [mMacroMenu itemWithTag: kMenuTagMacroRepeat];
	if (repeatItem != nil)
		[repeatItem setEnabled: [mMacroSteps count] > 0];

	for (NSInteger i = [mMacroMenu numberOfItems] - 1; i >= 0; --i) {
		NSMenuItem *item = [mMacroMenu itemAtIndex: i];
		if ([item tag] >= kMenuTagMacroDynamicBase ||
			[item tag] == kMenuTagMacroSeparator ||
			[item tag] == kMenuTagMacroPlaceholder) {
			[mMacroMenu removeItemAtIndex: i];
		}
	}

	NSMenuItem *separator = [NSMenuItem separatorItem];
	[separator setTag: kMenuTagMacroSeparator];
	[mMacroMenu addItem: separator];

	if ([mNamedMacros count] == 0) {
		NSMenuItem *emptyItem = [[[NSMenuItem alloc] initWithTitle: @"(No saved macros)"
														  action: nil
												   keyEquivalent: @""] autorelease];
		[emptyItem setTag: kMenuTagMacroPlaceholder];
		[emptyItem setEnabled: NO];
		[mMacroMenu addItem: emptyItem];
	} else {
		NSInteger index = 0;
		for (NSDictionary *macro in mNamedMacros) {
			NSString *name = [macro objectForKey: @"name"];
			if ([name length] == 0)
				continue;
			NSMenuItem *item = [[[NSMenuItem alloc] initWithTitle: [NSString stringWithFormat: @"Run %@", name]
															action: @selector(runNamedMacro:)
													 keyEquivalent: @""] autorelease];
			[item setTag: kMenuTagMacroDynamicBase + index];
			[item setTarget: self];
			[item setRepresentedObject: macro];
			[mMacroMenu addItem: item];
			index++;
		}
	}

	[self updateStatusBar];
}

- (IBAction) startStopMacroRecording: (id) sender
{
	#pragma unused(sender)
	NPPDocument *document = [self currentDocument];
	if (document == nil)
		return;

	if (!mMacroRecording) {
		[mMacroSteps removeAllObjects];
		mMacroRecording = YES;
		[document.editor setGeneralProperty: SCI_STARTRECORD parameter: 0 value: 0];
		[document.editor setStatusText: @"Macro recording started"];
	} else {
		[document.editor setGeneralProperty: SCI_STOPRECORD parameter: 0 value: 0];
		mMacroRecording = NO;
		[document.editor setStatusText: [NSString stringWithFormat: @"Macro recording stopped (%lu step(s))", (unsigned long)[mMacroSteps count]]];
	}

	[self updateMacroMenuState];
}

- (IBAction) playRecordedMacro: (id) sender
{
	#pragma unused(sender)
	if ([mMacroSteps count] == 0)
		return;

	[self executeMacroSteps: mMacroSteps repeatCount: 1];
	NPPDocument *document = [self currentDocument];
	if (document != nil)
		[document.editor setStatusText: [NSString stringWithFormat: @"Macro playback finished (%lu step(s))", (unsigned long)[mMacroSteps count]]];
}

- (IBAction) saveRecordedMacroToLibrary: (id) sender
{
	#pragma unused(sender)
	if ([mMacroSteps count] == 0)
		return;

	NSString *defaultName = [NSString stringWithFormat: @"Recorded Macro %lu", (unsigned long)([mNamedMacros count] + 1)];
	NSString *name = [self promptForStringWithTitle: @"Save Macro"
										message: @"Macro name:"
									defaultValue: defaultName];
	if ([name length] == 0)
		return;

	NSMutableArray *copiedSteps = [NSMutableArray arrayWithCapacity: [mMacroSteps count]];
	for (NSDictionary *step in mMacroSteps)
		[copiedSteps addObject: [NSDictionary dictionaryWithDictionary: step]];

	NSUInteger replaceIndex = NSNotFound;
	for (NSUInteger i = 0; i < [mNamedMacros count]; ++i) {
		NSDictionary *existing = [mNamedMacros objectAtIndex: i];
		if ([[[existing objectForKey: @"name"] lowercaseString] isEqualToString: [name lowercaseString]]) {
			replaceIndex = i;
			break;
		}
	}

	NSDictionary *macro = [NSDictionary dictionaryWithObjectsAndKeys:
		name, @"name",
		copiedSteps, @"steps",
		nil];
	if (replaceIndex == NSNotFound)
		[mNamedMacros addObject: macro];
	else
		[mNamedMacros replaceObjectAtIndex: replaceIndex withObject: macro];

	[self saveMacrosToCompatibilityFile];
	[self updateMacroMenuState];
	NPPDocument *document = [self currentDocument];
	if (document != nil)
		[document.editor setStatusText: [NSString stringWithFormat: @"Macro '%@' saved", name]];
}

- (IBAction) runRecordedMacroMultipleTimes: (id) sender
{
	#pragma unused(sender)
	if ([mMacroSteps count] == 0)
		return;

	NSString *repeatText = [self promptForStringWithTitle: @"Run Macro"
									   message: @"Number of times:"
								  defaultValue: @"1"];
	if ([repeatText length] == 0)
		return;

	NSInteger repeatCount = [repeatText integerValue];
	if (repeatCount < 1)
		repeatCount = 1;
	if (repeatCount > 1000)
		repeatCount = 1000;

	[self executeMacroSteps: mMacroSteps repeatCount: (NSUInteger)repeatCount];
	NPPDocument *document = [self currentDocument];
	if (document != nil)
		[document.editor setStatusText: [NSString stringWithFormat: @"Macro played %ld time(s)", (long)repeatCount]];
}

- (IBAction) runNamedMacro: (id) sender
{
	NSDictionary *macro = [sender representedObject];
	if (![macro isKindOfClass: [NSDictionary class]])
		return;

	NSArray *steps = [macro objectForKey: @"steps"];
	if (![steps isKindOfClass: [NSArray class]] || [steps count] == 0)
		return;

	[self executeMacroSteps: steps repeatCount: 1];
	NPPDocument *document = [self currentDocument];
	if (document != nil)
		[document.editor setStatusText: [NSString stringWithFormat: @"Macro '%@' finished", [macro objectForKey: @"name"]]];
}

- (void) convertEolToMode: (NSInteger) eolMode
{
	NPPDocument *document = [self currentDocument];
	if (document == nil)
		return;

	[document.editor setGeneralProperty: SCI_CONVERTEOLS parameter: eolMode value: 0];
	[document.editor setGeneralProperty: SCI_SETEOLMODE parameter: eolMode value: 0];
	document.metadataDirty = YES;
	document.dirty = YES;
	[self refreshEditorState: nil];
}

- (IBAction) convertEolToWindows: (id) sender
{
	#pragma unused(sender)
	[self convertEolToMode: SC_EOL_CRLF];
}

- (IBAction) convertEolToUnix: (id) sender
{
	#pragma unused(sender)
	[self convertEolToMode: SC_EOL_LF];
}

- (IBAction) convertEolToMacClassic: (id) sender
{
	#pragma unused(sender)
	[self convertEolToMode: SC_EOL_CR];
}

- (void) applyEncoding: (NSStringEncoding) encoding toCurrentDocumentWithName: (NSString *) encodingName
{
	NPPDocument *document = [self currentDocument];
	if (document == nil)
		return;

	document.encoding = encoding;
	document.metadataDirty = YES;
	document.dirty = YES;
	[document.editor setStatusText: [NSString stringWithFormat: @"Encoding set to %@", encodingName]];
	[self refreshEditorState: nil];
}

- (IBAction) setEncodingUtf8: (id) sender
{
	#pragma unused(sender)
	[self applyEncoding: NSUTF8StringEncoding toCurrentDocumentWithName: @"UTF-8"];
}

- (IBAction) setEncodingUtf16LE: (id) sender
{
	#pragma unused(sender)
	[self applyEncoding: NSUTF16LittleEndianStringEncoding toCurrentDocumentWithName: @"UTF-16 LE"];
}

- (IBAction) setEncodingUtf16BE: (id) sender
{
	#pragma unused(sender)
	[self applyEncoding: NSUTF16BigEndianStringEncoding toCurrentDocumentWithName: @"UTF-16 BE"];
}

- (IBAction) setEncodingIso88591: (id) sender
{
	#pragma unused(sender)
	[self applyEncoding: NSISOLatin1StringEncoding toCurrentDocumentWithName: @"ISO-8859-1"];
}

- (IBAction) setEncodingWindows1252: (id) sender
{
	#pragma unused(sender)
	[self applyEncoding: nppEncodingWindows1252() toCurrentDocumentWithName: @"Windows-1252"];
}

- (IBAction) setEncodingWindows1251: (id) sender
{
	#pragma unused(sender)
	[self applyEncoding: nppEncodingWindows1251() toCurrentDocumentWithName: @"Windows-1251"];
}

- (IBAction) setEncodingShiftJis: (id) sender
{
	#pragma unused(sender)
	[self applyEncoding: nppEncodingShiftJis() toCurrentDocumentWithName: @"Shift_JIS"];
}

- (IBAction) setEncodingGb18030: (id) sender
{
	#pragma unused(sender)
	[self applyEncoding: nppEncodingGb18030() toCurrentDocumentWithName: @"GB18030"];
}

- (IBAction) setEncodingBig5: (id) sender
{
	#pragma unused(sender)
	[self applyEncoding: nppEncodingBig5() toCurrentDocumentWithName: @"Big5"];
}

- (IBAction) setEncodingEucKr: (id) sender
{
	#pragma unused(sender)
	[self applyEncoding: nppEncodingEucKr() toCurrentDocumentWithName: @"EUC-KR"];
}

- (void) refreshFunctionList
{
	[mFunctionEntries removeAllObjects];

	NPPDocument *document = [self currentDocument];
	if (document == nil) {
		[mFunctionTableView reloadData];
		return;
	}

	NSString *text = [document.editor string];
	if ([text length] == 0) {
		[mFunctionTableView reloadData];
		return;
	}

	static NSRegularExpression *pythonRegex = nil;
	static NSRegularExpression *jsFunctionRegex = nil;
	static NSRegularExpression *jsArrowRegex = nil;
	static NSRegularExpression *cLikeRegex = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		pythonRegex = [[NSRegularExpression alloc] initWithPattern: @"^\\s*(?:def|class)\\s+([A-Za-z_][A-Za-z0-9_]*)\\b" options: 0 error: nil];
		jsFunctionRegex = [[NSRegularExpression alloc] initWithPattern: @"^\\s*function\\s+([A-Za-z_$][A-Za-z0-9_$]*)\\s*\\(" options: 0 error: nil];
		jsArrowRegex = [[NSRegularExpression alloc] initWithPattern: @"^\\s*([A-Za-z_$][A-Za-z0-9_$]*)\\s*=\\s*(?:\\([^\\)]*\\)|[A-Za-z_$][A-Za-z0-9_$]*)\\s*=>" options: 0 error: nil];
		cLikeRegex = [[NSRegularExpression alloc] initWithPattern: @"^\\s*(?:template\\s*<[^>]+>\\s*)?(?:[A-Za-z_][A-Za-z0-9_:<>,~\\*&\\s]+\\s+)?([A-Za-z_][A-Za-z0-9_:~]*)\\s*\\([^;]*\\)\\s*(?:const\\s*)?(?:\\{|$)" options: 0 error: nil];
	});

	NSSet *excludedNames = [NSSet setWithObjects:
		@"if", @"for", @"while", @"switch", @"catch", @"return", @"sizeof", @"foreach",
		@"else", @"do", @"case", @"default", @"try", nil];

	__block NSUInteger lineNumber = 0;
	[text enumerateLinesUsingBlock: ^(NSString *line, BOOL *stop) {
		lineNumber++;
		if ([line length] < 2 || [mFunctionEntries count] > 2000)
			return;

		NSArray *regexes = [NSArray arrayWithObjects: pythonRegex, jsFunctionRegex, jsArrowRegex, cLikeRegex, nil];
		for (NSRegularExpression *regex in regexes) {
			NSTextCheckingResult *match = [regex firstMatchInString: line options: 0 range: NSMakeRange(0, [line length])];
			if (match == nil || [match numberOfRanges] < 2)
				continue;

			NSRange nameRange = [match rangeAtIndex: 1];
			if (nameRange.location == NSNotFound || nameRange.length == 0)
				continue;

			NSString *name = [line substringWithRange: nameRange];
			if ([excludedNames containsObject: [name lowercaseString]])
				continue;

			NSDictionary *entry = [NSDictionary dictionaryWithObjectsAndKeys:
				name, @"name",
				[NSNumber numberWithUnsignedInteger: lineNumber], @"line",
				nil];
			[mFunctionEntries addObject: entry];
			break;
		}

		if ([mFunctionEntries count] > 2000)
			*stop = YES;
	}];

	[mFunctionTableView reloadData];
}

- (void) refreshProjectEntries
{
	[mProjectEntries removeAllObjects];

	for (NPPDocument *doc in mDocuments) {
		if ([doc.filePath length] == 0)
			continue;
		[mProjectEntries addObject: [NSDictionary dictionaryWithObjectsAndKeys:
			[NSString stringWithFormat: @"[Open] %@", [doc.filePath lastPathComponent]], @"display",
			doc.filePath, @"path",
			[NSNumber numberWithBool: NO], @"isRoot",
			nil]];
	}

	NSFileManager *fm = [NSFileManager defaultManager];
	for (NSString *root in mProjectRootPaths) {
		if (![fm fileExistsAtPath: root])
			continue;

		[mProjectEntries addObject: [NSDictionary dictionaryWithObjectsAndKeys:
			[NSString stringWithFormat: @"[%@]", [root lastPathComponent]], @"display",
			root, @"path",
			[NSNumber numberWithBool: YES], @"isRoot",
			nil]];

		NSDirectoryEnumerator *enumerator = [fm enumeratorAtURL: [NSURL fileURLWithPath: root]
										includingPropertiesForKeys: [NSArray arrayWithObjects: NSURLIsRegularFileKey, nil]
														   options: NSDirectoryEnumerationSkipsHiddenFiles
													  errorHandler: nil];
		NSUInteger count = 0;
		for (NSURL *url in enumerator) {
			NSNumber *isRegular = nil;
			if (![url getResourceValue: &isRegular forKey: NSURLIsRegularFileKey error: nil] || ![isRegular boolValue])
				continue;

			NSString *path = [url path];
			NSString *relative = [path stringByReplacingOccurrencesOfString: [root stringByAppendingString: @"/"] withString: @""];
			[mProjectEntries addObject: [NSDictionary dictionaryWithObjectsAndKeys:
				relative, @"display",
				path, @"path",
				[NSNumber numberWithBool: NO], @"isRoot",
				nil]];

			count++;
			if (count >= 5000)
				break;
		}
	}

	[mProjectTableView reloadData];
}

- (NSArray *) projectFilesMatchingFilter: (NSString *) filter
{
	NSMutableArray *results = [NSMutableArray array];
	NSArray *tokens = [self searchFilterTokensFromString: filter];

	for (NSDictionary *entry in mProjectEntries) {
		if ([[entry objectForKey: @"isRoot"] boolValue])
			continue;
		NSString *path = [entry objectForKey: @"path"];
		if ([path length] == 0)
			continue;

		if ([self filePath: path matchesFilterTokens: tokens] &&
			[[NSFileManager defaultManager] fileExistsAtPath: path]) {
			[results addObject: path];
		}
	}

	if ([results count] == 0) {
		for (NPPDocument *doc in mDocuments) {
			if ([doc.filePath length] > 0)
				[results addObject: doc.filePath];
		}
	}

	return results;
}

- (NSArray *) searchFilterTokensFromString: (NSString *) filter
{
	if ([filter length] == 0)
		return [NSArray array];

	NSMutableCharacterSet *separators = [[NSCharacterSet whitespaceAndNewlineCharacterSet] mutableCopy];
	[separators addCharactersInString: @";,"];
	NSArray *rawTokens = [filter componentsSeparatedByCharactersInSet: separators];
	[separators release];

	NSMutableArray *tokens = [NSMutableArray array];
	for (NSString *raw in rawTokens) {
		NSString *token = [[raw stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]] lowercaseString];
		if ([token length] == 0)
			continue;
		[tokens addObject: token];
	}
	return tokens;
}

- (BOOL) filePath: (NSString *) path matchesFilterTokens: (NSArray *) tokens
{
	if ([tokens count] == 0)
		return YES;

	NSString *filename = [[path lastPathComponent] lowercaseString];
	NSString *fullPath = [path lowercaseString];
	for (NSString *token in tokens) {
		if ([token isEqualToString: @"*"] || [token isEqualToString: @"*.*"])
			return YES;

		NSPredicate *predicate = [NSPredicate predicateWithFormat: @"SELF LIKE %@", token];
		if ([predicate evaluateWithObject: filename] || [predicate evaluateWithObject: fullPath])
			return YES;
	}

	return NO;
}

- (NSArray *) filesInFolder: (NSString *) folderPath matchingFilter: (NSString *) filter
{
	NSString *normalizedFolder = [folderPath stringByStandardizingPath];
	if ([normalizedFolder length] == 0)
		return [NSArray array];

	BOOL isDirectory = NO;
	if (![[NSFileManager defaultManager] fileExistsAtPath: normalizedFolder isDirectory: &isDirectory] || !isDirectory)
		return [NSArray array];

	NSArray *tokens = [self searchFilterTokensFromString: filter];
	NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtURL: [NSURL fileURLWithPath: normalizedFolder]
															 includingPropertiesForKeys: [NSArray arrayWithObjects: NSURLIsRegularFileKey, nil]
																				options: NSDirectoryEnumerationSkipsHiddenFiles
																		   errorHandler: nil];

	NSMutableArray *results = [NSMutableArray array];
	NSUInteger count = 0;
	for (NSURL *url in enumerator) {
		NSNumber *isRegular = nil;
		if (![url getResourceValue: &isRegular forKey: NSURLIsRegularFileKey error: nil] || ![isRegular boolValue])
			continue;

		NSString *path = [url path];
		if (![self filePath: path matchesFilterTokens: tokens])
			continue;

		[results addObject: path];
		count++;
		if (count >= 30000)
			break;
	}

	return results;
}

- (NSArray *) filesForSearchScope: (NSInteger) scope
{
	if (scope == 2)
		return [self projectFilesMatchingFilter: [mSearchFilterField stringValue]];
	if (scope == 3) {
		NSString *folder = [[mSearchFolderField stringValue] stringByStandardizingPath];
		if ([folder length] == 0) {
			NPPDocument *document = [self currentDocument];
			if ([document.filePath length] > 0)
				folder = [document.filePath stringByDeletingLastPathComponent];
		}
		return [self filesInFolder: folder matchingFilter: [mSearchFilterField stringValue]];
	}
	return [NSArray array];
}

- (void) addProjectRootPath: (NSString *) rootPath
{
	if ([rootPath length] == 0)
		return;

	NSString *normalized = [rootPath stringByStandardizingPath];
	if ([mProjectRootPaths containsObject: normalized])
		return;

	[mProjectRootPaths addObject: normalized];
	[self refreshProjectEntries];
}

- (void) projectPanelActivated: (id) sender
{
	#pragma unused(sender)
	NSInteger row = [mProjectTableView clickedRow];
	if (row < 0)
		row = [mProjectTableView selectedRow];
	if (row < 0 || row >= (NSInteger)[mProjectEntries count])
		return;

	NSDictionary *entry = [mProjectEntries objectAtIndex: row];
	if ([[entry objectForKey: @"isRoot"] boolValue])
		return;

	NSString *path = [entry objectForKey: @"path"];
	if ([path length] > 0)
		[self openPath: path];
}

- (void) functionPanelActivated: (id) sender
{
	#pragma unused(sender)
	NSInteger row = [mFunctionTableView clickedRow];
	if (row < 0)
		row = [mFunctionTableView selectedRow];
	if (row < 0 || row >= (NSInteger)[mFunctionEntries count] || mEditor == nil)
		return;

	NSDictionary *entry = [mFunctionEntries objectAtIndex: row];
	NSInteger line = [[entry objectForKey: @"line"] integerValue];
	if (line < 1)
		line = 1;
	[mEditor setGeneralProperty: SCI_GOTOLINE parameter: line - 1 value: 0];
	[self updateWindowTitle];
}

- (NSString *) promptForStringWithTitle: (NSString *) title
									message: (NSString *) message
								defaultValue: (NSString *) defaultValue
{
	NSAlert *alert = [[[NSAlert alloc] init] autorelease];
	[alert setMessageText: title];
	[alert setInformativeText: message];
	[alert addButtonWithTitle: @"OK"];
	[alert addButtonWithTitle: @"Cancel"];

	NSTextField *inputField = [[[NSTextField alloc] initWithFrame: NSMakeRect(0, 0, 320, 24)] autorelease];
	[inputField setStringValue: (defaultValue != nil) ? defaultValue : @""];
	[alert setAccessoryView: inputField];

	if ([alert runModal] != NSAlertFirstButtonReturn)
		return nil;

	return [[[inputField stringValue] copy] autorelease];
}

- (NSRange) currentSelectionRangeInEditor: (ScintillaView *) editor
{
	if (editor == nil)
		return NSMakeRange(NSNotFound, 0);

	long start = [editor getGeneralProperty: SCI_GETSELECTIONSTART parameter: 0];
	long end = [editor getGeneralProperty: SCI_GETSELECTIONEND parameter: 0];
	if (start > end) {
		long tmp = start;
		start = end;
		end = tmp;
	}
	return NSMakeRange((NSUInteger)MAX(0, start), (NSUInteger)MAX(0, end - start));
}

- (void) replaceSelectedOrWholeTextInCurrentDocumentUsingBlock: (NSString *(^)(NSString *input, NSRange range, BOOL *didChange)) transform
{
	if (transform == nil)
		return;

	NPPDocument *document = [self currentDocument];
	if (document == nil)
		return;

	NSString *text = [document.editor string];
	if (text == nil)
		return;

	NSRange selection = [self currentSelectionRangeInEditor: document.editor];
	if (selection.location == NSNotFound)
		return;
	NSRange range = (selection.length == 0) ? NSMakeRange(0, [text length]) : selection;
	if (range.location > [text length] || NSMaxRange(range) > [text length])
		return;

	BOOL didChange = NO;
	NSString *replacement = transform(text, range, &didChange);
	if (!didChange || replacement == nil)
		return;

	NSMutableString *updated = [[text mutableCopy] autorelease];
	[updated replaceCharactersInRange: range withString: replacement];
	[document.editor setString: updated];
	[document.editor setGeneralProperty: SCI_SETSEL parameter: range.location value: range.location + [replacement length]];
	document.dirty = YES;
}

- (NSString *) camelCaseFromString: (NSString *) source
{
	if (source == nil || [source length] == 0)
		return source;

	NSArray *rawParts = [source componentsSeparatedByCharactersInSet: [[NSCharacterSet alphanumericCharacterSet] invertedSet]];
	NSMutableArray *parts = [NSMutableArray array];
	for (NSString *part in rawParts) {
		if ([part length] == 0)
			continue;
		[parts addObject: [part lowercaseString]];
	}
	if ([parts count] == 0)
		return source;

	NSMutableString *result = [NSMutableString stringWithString: [parts objectAtIndex: 0]];
	for (NSUInteger i = 1; i < [parts count]; ++i) {
		NSString *part = [parts objectAtIndex: i];
		NSString *head = [[part substringToIndex: 1] uppercaseString];
		NSString *tail = ([part length] > 1) ? [part substringFromIndex: 1] : @"";
		[result appendString: head];
		[result appendString: tail];
	}
	return result;
}

- (BOOL) readTextFileAtPath: (NSString *) path
					content: (NSString **) outContent
				usedEncoding: (NSStringEncoding *) outEncoding
					   error: (NSError **) outError
{
	if ([path length] == 0) {
		if (outError != nil) {
			*outError = [NSError errorWithDomain: NSCocoaErrorDomain
										code: NSFileReadInvalidFileNameError
									userInfo: [NSDictionary dictionaryWithObject: @"Empty file path" forKey: NSLocalizedDescriptionKey]];
		}
		return NO;
	}

	NSData *data = [NSData dataWithContentsOfFile: path options: NSDataReadingMappedIfSafe error: outError];
	if (data == nil)
		return NO;

	if ([data length] == 0) {
		if (outContent != nil)
			*outContent = @"";
		if (outEncoding != nil)
			*outEncoding = NSUTF8StringEncoding;
		return YES;
	}

	NSStringEncoding detectedEncoding = [self detectEncodingForData: data fallbackEncoding: NSUTF8StringEncoding];
	NSString *text = [[[NSString alloc] initWithData: data encoding: detectedEncoding] autorelease];

	if (text == nil) {
		NSArray *candidates = [NSArray arrayWithObjects:
			[NSNumber numberWithUnsignedInteger: NSUTF8StringEncoding],
			[NSNumber numberWithUnsignedInteger: NSUTF16LittleEndianStringEncoding],
			[NSNumber numberWithUnsignedInteger: NSUTF16BigEndianStringEncoding],
			[NSNumber numberWithUnsignedInteger: NSISOLatin1StringEncoding],
			[NSNumber numberWithUnsignedInteger: nppEncodingWindows1252()],
			[NSNumber numberWithUnsignedInteger: nppEncodingWindows1251()],
			[NSNumber numberWithUnsignedInteger: nppEncodingShiftJis()],
			[NSNumber numberWithUnsignedInteger: nppEncodingGb18030()],
			[NSNumber numberWithUnsignedInteger: nppEncodingBig5()],
			[NSNumber numberWithUnsignedInteger: nppEncodingEucKr()],
			nil];
		for (NSNumber *candidate in candidates) {
			NSStringEncoding candidateEncoding = [candidate unsignedIntegerValue];
			if (candidateEncoding == detectedEncoding)
				continue;
			text = [[[NSString alloc] initWithData: data encoding: candidateEncoding] autorelease];
			if (text != nil) {
				detectedEncoding = candidateEncoding;
				break;
			}
		}
	}

	if (text == nil) {
		NSError *fallbackError = nil;
		NSStringEncoding fallbackEncoding = NSUTF8StringEncoding;
		text = [NSString stringWithContentsOfFile: path usedEncoding: &fallbackEncoding error: &fallbackError];
		if (text == nil) {
			if (outError != nil)
				*outError = fallbackError;
			return NO;
		}
		detectedEncoding = fallbackEncoding;
	}

	if (outContent != nil)
		*outContent = text;
	if (outEncoding != nil)
		*outEncoding = detectedEncoding;
	return YES;
}

- (NSStringEncoding) detectEncodingForData: (NSData *) data fallbackEncoding: (NSStringEncoding) fallbackEncoding
{
	if (data == nil || [data length] == 0)
		return fallbackEncoding;

	const unsigned char *bytes = (const unsigned char *)[data bytes];
	NSUInteger length = [data length];

	if (length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF)
		return NSUTF8StringEncoding;
	if (length >= 4 && bytes[0] == 0xFF && bytes[1] == 0xFE && bytes[2] == 0x00 && bytes[3] == 0x00)
		return NSUTF32LittleEndianStringEncoding;
	if (length >= 4 && bytes[0] == 0x00 && bytes[1] == 0x00 && bytes[2] == 0xFE && bytes[3] == 0xFF)
		return NSUTF32BigEndianStringEncoding;
	if (length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE)
		return NSUTF16LittleEndianStringEncoding;
	if (length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF)
		return NSUTF16BigEndianStringEncoding;

	NSUInteger sampleLength = MIN(length, (NSUInteger)8192);
	NSUInteger evenNulls = 0;
	NSUInteger oddNulls = 0;
	for (NSUInteger i = 0; i < sampleLength; ++i) {
		if (bytes[i] == 0x00) {
			if ((i % 2) == 0)
				evenNulls++;
			else
				oddNulls++;
		}
	}

	if (sampleLength > 32) {
		double evenRatio = (double)evenNulls / (double)sampleLength;
		double oddRatio = (double)oddNulls / (double)sampleLength;
		if (evenRatio > 0.20 && oddRatio < 0.05)
			return NSUTF16BigEndianStringEncoding;
		if (oddRatio > 0.20 && evenRatio < 0.05)
			return NSUTF16LittleEndianStringEncoding;
	}

	if ([self isLikelyUtf8Data: data])
		return NSUTF8StringEncoding;

	NSArray *candidates = [NSArray arrayWithObjects:
		[NSNumber numberWithUnsignedInteger: NSUTF8StringEncoding],
		[NSNumber numberWithUnsignedInteger: nppEncodingWindows1252()],
		[NSNumber numberWithUnsignedInteger: NSISOLatin1StringEncoding],
		[NSNumber numberWithUnsignedInteger: nppEncodingWindows1251()],
		[NSNumber numberWithUnsignedInteger: nppEncodingShiftJis()],
		[NSNumber numberWithUnsignedInteger: nppEncodingGb18030()],
		[NSNumber numberWithUnsignedInteger: nppEncodingBig5()],
		[NSNumber numberWithUnsignedInteger: nppEncodingEucKr()],
		nil];

	NSStringEncoding bestEncoding = fallbackEncoding;
	double bestScore = -1.0;
	for (NSNumber *candidate in candidates) {
		NSStringEncoding encoding = [candidate unsignedIntegerValue];
		NSString *decoded = [[[NSString alloc] initWithData: data encoding: encoding] autorelease];
		if (decoded == nil)
			continue;

		double score = [self printableRatioForString: decoded];
		if ([decoded rangeOfString: @"\uFFFD"].location != NSNotFound)
			score -= 0.15;
		if (encoding == NSUTF8StringEncoding)
			score += 0.02;

		if (score > bestScore) {
			bestScore = score;
			bestEncoding = encoding;
		}
	}

	if (bestScore < 0.60)
		return fallbackEncoding;
	return bestEncoding;
}

- (BOOL) isLikelyUtf8Data: (NSData *) data
{
	if (data == nil)
		return NO;

	const unsigned char *bytes = (const unsigned char *)[data bytes];
	NSUInteger length = [data length];
	NSUInteger i = 0;
	while (i < length) {
		unsigned char byte = bytes[i];
		if (byte <= 0x7F) {
			i++;
			continue;
		}

		NSUInteger continuationLength = 0;
		if ((byte & 0xE0) == 0xC0) {
			if (byte < 0xC2)
				return NO;
			continuationLength = 1;
		} else if ((byte & 0xF0) == 0xE0) {
			continuationLength = 2;
		} else if ((byte & 0xF8) == 0xF0) {
			if (byte > 0xF4)
				return NO;
			continuationLength = 3;
		} else {
			return NO;
		}

		if (i + continuationLength >= length)
			return NO;
		for (NSUInteger j = 1; j <= continuationLength; ++j) {
			if ((bytes[i + j] & 0xC0) != 0x80)
				return NO;
		}

		i += continuationLength + 1;
	}

	return YES;
}

- (double) printableRatioForString: (NSString *) text
{
	if (text == nil || [text length] == 0)
		return 1.0;

	NSUInteger maxLength = MIN([text length], (NSUInteger)4096);
	NSUInteger printable = 0;
	for (NSUInteger i = 0; i < maxLength; ++i) {
		unichar c = [text characterAtIndex: i];
		BOOL isControl = [[NSCharacterSet controlCharacterSet] characterIsMember: c];
		if (!isControl || c == '\n' || c == '\r' || c == '\t')
			printable++;
	}

	return (double)printable / (double)maxLength;
}

//--------------------------------------------------------------------------------------------------

- (IBAction) addRemoveExtra: (id) sender
{
	[self toggleSplitScreen: sender];
}

- (IBAction) setFontQuality: (id) sender
{
	if (mEditor != nil)
		[ScintillaView directCall: mEditor message: SCI_SETFONTQUALITY wParam: [sender tag] lParam: 0];
}

- (NSInteger) numberOfRowsInTableView: (NSTableView *) tableView
{
	if (tableView == mFunctionTableView)
		return [mFunctionEntries count];
	if (tableView == mProjectTableView)
		return [mProjectEntries count];
	return 0;
}

- (id) tableView: (NSTableView *) tableView objectValueForTableColumn: (NSTableColumn *) tableColumn row: (NSInteger) row
{
	#pragma unused(tableColumn)
	if (tableView == mFunctionTableView) {
		if (row < 0 || row >= (NSInteger)[mFunctionEntries count])
			return @"";
		NSDictionary *entry = [mFunctionEntries objectAtIndex: row];
		NSString *name = [entry objectForKey: @"name"];
		NSNumber *line = [entry objectForKey: @"line"];
		return [NSString stringWithFormat: @"%@  (L%@)", name, line];
	}

	if (tableView == mProjectTableView) {
		if (row < 0 || row >= (NSInteger)[mProjectEntries count])
			return @"";
		return [[mProjectEntries objectAtIndex: row] objectForKey: @"display"];
	}

	return @"";
}

//--------------------------------------------------------------------------------------------------

- (BOOL) validateMenuItem: (NSMenuItem *) menuItem
{
	SEL action = [menuItem action];
	NPPDocument *document = [self currentDocument];

	if (action == @selector(saveDocument:) ||
		action == @selector(saveDocumentAs:) ||
		action == @selector(openDocument:) ||
		action == @selector(newDocument:) ||
		action == @selector(showSearchDialog:) ||
		action == @selector(openProjectFolder:) ||
		action == @selector(showPreferences:) ||
		action == @selector(reloadPlugins:)) {
		return YES;
	}

	if (action == @selector(findInFiles:) ||
		action == @selector(toggleWordWrap:) ||
		action == @selector(toggleWhitespaceVisibility:) ||
		action == @selector(toggleEolVisibility:) ||
		action == @selector(toggleLineNumberMargin:) ||
		action == @selector(toggleLiveTailCurrentFile:) ||
		action == @selector(toggleSplitScreen:) ||
		action == @selector(toggleDocumentMap:) ||
		action == @selector(toggleAutosave:) ||
		action == @selector(toggleSidebar:)) {
		if (action == @selector(toggleSidebar:))
			[menuItem setState: mSidebarVisible ? NSOnState : NSOffState];
		if (action == @selector(toggleLiveTailCurrentFile:))
			[menuItem setState: mLiveTailEnabled ? NSOnState : NSOffState];
		if (action == @selector(toggleSplitScreen:))
			[menuItem setState: mSplitViewEnabled ? NSOnState : NSOffState];
		if (action == @selector(toggleDocumentMap:))
			[menuItem setState: mDocumentMapVisible ? NSOnState : NSOffState];
		if (action == @selector(toggleAutosave:))
			[menuItem setState: mAutosaveEnabled ? NSOnState : NSOffState];
		if (action == @selector(toggleLiveTailCurrentFile:))
			return (document != nil);
		return YES;
	}

	if (action == @selector(startStopMacroRecording:)) {
		[menuItem setTitle: mMacroRecording ? @"Stop Recording" : @"Start Recording"];
		return YES;
	}

	if (action == @selector(playRecordedMacro:))
		return (document != nil && [mMacroSteps count] > 0);

	if (action == @selector(saveRecordedMacroToLibrary:) ||
		action == @selector(runRecordedMacroMultipleTimes:))
		return (document != nil && [mMacroSteps count] > 0);

	if (action == @selector(runNamedMacro:)) {
		NSDictionary *macro = [menuItem representedObject];
		NSArray *steps = [macro objectForKey: @"steps"];
		return (document != nil && [steps isKindOfClass: [NSArray class]] && [steps count] > 0);
	}

	if (action == @selector(revertDocumentToSaved:))
		return (document != nil && document.filePath != nil);

	if (action == @selector(performClose:))
		return (document != nil);

	if (action == @selector(goToLine:) ||
		action == @selector(compareCurrentWithFile:) ||
		action == @selector(sortSelectedLinesAscending:) ||
		action == @selector(sortSelectedLinesDescending:) ||
		action == @selector(trimTrailingWhitespaceLines:) ||
		action == @selector(convertSelectionToUpperCase:) ||
		action == @selector(convertSelectionToLowerCase:) ||
		action == @selector(convertSelectionToCamelCase:) ||
		action == @selector(convertEolToWindows:) ||
		action == @selector(convertEolToUnix:) ||
		action == @selector(convertEolToMacClassic:) ||
		action == @selector(setEncodingUtf8:) ||
		action == @selector(setEncodingUtf16LE:) ||
		action == @selector(setEncodingUtf16BE:) ||
		action == @selector(setEncodingIso88591:) ||
		action == @selector(setEncodingWindows1252:) ||
		action == @selector(setEncodingWindows1251:) ||
		action == @selector(setEncodingShiftJis:) ||
		action == @selector(setEncodingGb18030:) ||
		action == @selector(setEncodingBig5:) ||
		action == @selector(setEncodingEucKr:)) {
		return (document != nil);
	}

	if (action == @selector(performFindPanelAction:)) {
		NSInteger tag = [menuItem tag];
		if (tag == 2 || tag == 3)
			return ([mLastSearch length] > 0 || [[mEditor selectedString] length] > 0);
		return YES;
	}

	if (action == @selector(replaceText:))
		return (document != nil);

	return YES;
}

- (void) tabView: (NSTabView *) tabView didSelectTabViewItem: (NSTabViewItem *) tabViewItem
{
	#pragma unused(tabView)
	NPPDocument *document = [self documentForTabItem: tabViewItem];
	mEditor = document.editor;
	[[mEditHost window] makeFirstResponder: mEditor];
	if (mSplitViewEnabled || mDocumentMapVisible)
		[self ensureExtraEditorForCurrentDocument];
	else
		[self removeExtraEditor];
	[self updateWindowTitle];
	[self refreshUiToggles];
}

- (void) notification: (SCNotification *) notification
{
	if (notification != NULL &&
		notification->nmhdr.code == SCN_MACRORECORD &&
		mMacroRecording) {
		NSMutableDictionary *step = [NSMutableDictionary dictionary];
		[step setObject: [NSNumber numberWithUnsignedInt: (unsigned int)notification->message] forKey: @"message"];
		[step setObject: [NSNumber numberWithUnsignedLongLong: (unsigned long long)notification->wParam] forKey: @"wParam"];
		[step setObject: [NSNumber numberWithLongLong: (long long)notification->lParam] forKey: @"lParam"];

		switch (notification->message) {
			case SCI_ADDTEXT:
			case SCI_INSERTTEXT:
			case SCI_REPLACESEL:
			case SCI_SEARCHINTARGET:
			case SCI_SETTEXT: {
				const char *text = reinterpret_cast<const char *>(notification->lParam);
				if (text != NULL) {
					NSString *copied = [NSString stringWithUTF8String: text];
					if (copied != nil)
						[step setObject: copied forKey: @"text"];
				}
				break;
			}
			default:
				break;
		}

		[mMacroSteps addObject: step];
	}

	[self refreshEditorState: nil];
}

- (BOOL) applicationShouldTerminateAfterLastWindowClosed: (NSApplication *) sender
{
	#pragma unused(sender)
	return YES;
}

- (NSApplicationTerminateReply) applicationShouldTerminate: (NSApplication *) sender
{
	#pragma unused(sender)

	NSArray *snapshot = [[mDocuments copy] autorelease];
	for (NPPDocument *document in snapshot) {
		if (![self canCloseDocument: document])
			return NSTerminateCancel;
	}

	[self saveMacrosToCompatibilityFile];
	[self saveSessionState];
	return NSTerminateNow;
}

@end

//--------------------------------------------------------------------------------------------------

/**
 * AppController.h
 * ScintillaTest
 *
 * Created by Mike Lischke on 01.04.09.
 * Copyright 2009 Sun Microsystems, Inc. All rights reserved.
 * This file is dual licensed under LGPL v2.1 and the Scintilla license (http://www.scintilla.org/License.txt).
 */

#import <Cocoa/Cocoa.h>

#include <dlfcn.h>

#import "Scintilla/ILexer.h"
#import "Scintilla/ScintillaView.h"
#import "Scintilla/InfoBar.h"
#include <SciLexer.h>
#include <Lexilla.h>

@interface AppController : NSObject <
  NSApplicationDelegate,
  NSTabViewDelegate,
  NSMenuItemValidation,
  ScintillaNotificationProtocol,
  NSTableViewDataSource,
  NSTableViewDelegate,
  NSToolbarDelegate
> {
  IBOutlet NSBox *mEditHost;
  ScintillaView *mEditor;
  ScintillaView *sciExtra;

  NSView *mEditorHost;
  NSSplitView *mEditorSplitView;
  NSView *mEditorTabContainer;
  NSView *mSearchResultContainer;
  NSTableView *mSearchResultsTableView;
  NSTextField *mSearchResultsSummaryLabel;
  NSMutableArray *mSearchResultEntries;
  BOOL mSearchResultsVisible;
  NSSplitView *mWorkspaceSplitView;
  NSTabView *mSidebarTabView;
  NSTableView *mFunctionTableView;
  NSTableView *mProjectTableView;
  NSMutableArray *mFunctionEntries;
  NSMutableArray *mProjectEntries;
  NSMutableArray *mProjectRootPaths;

  NSTextField *mStatusBar;
  NSToolbar *mMainToolbar;
  BOOL mSidebarVisible;
  BOOL mStatusBarVisible;

  NSPanel *mSearchPanel;
  NSTextField *mSearchFindField;
  NSTextField *mSearchReplaceField;
  NSTextField *mSearchFilterField;
  NSTextField *mSearchFolderField;
  NSButton *mSearchMatchCase;
  NSButton *mSearchWholeWord;
  NSButton *mSearchRegex;
  NSButton *mSearchMarkAll;
  NSPopUpButton *mSearchScopePopup;

  NSWindow *mPreferencesWindow;
  NSButton *mPrefRestoreSession;
  NSButton *mPrefShowToolbar;
  NSButton *mPrefShowStatusBar;
  NSButton *mPrefShowSidebar;
  NSButton *mPrefDefaultWordWrap;
  NSButton *mPrefDefaultLineNumbers;

  NSTabView *mTabView;
  NSMutableArray *mDocuments;
  NSString *mLastSearch;
  void *mLexillaDL;
  Lexilla::CreateLexerFn mCreateLexer;
  NSUInteger mUntitledCounter;
  NSTimer *mStateTimer;
  BOOL mWordWrap;
  BOOL mShowWhitespace;
  BOOL mShowEol;
  BOOL mShowLineNumbers;
  BOOL mLiveTailEnabled;
  NSString *mLiveTailPath;
  unsigned long long mLiveTailKnownLength;
  NSDate *mLiveTailLastModificationDate;
  BOOL mSplitViewEnabled;
  BOOL mDocumentMapVisible;
  BOOL mAutosaveEnabled;
  NSTimeInterval mNextAutosaveTime;
  NSString *mComparedFilePath;

  BOOL mMacroRecording;
  NSMutableArray *mMacroSteps;
  NSMutableArray *mNamedMacros;
  NSMenu *mMacroMenu;
  NSMenuItem *mMacroRecordMenuItem;

  NSMutableArray *mPluginDescriptors;
  NSMenu *mPluginsMenu;
}

- (void) awakeFromNib;
- (void) setupEditor: (ScintillaView *) editor;

- (IBAction) newDocument: (id) sender;
- (IBAction) openDocument: (id) sender;
- (IBAction) saveDocument: (id) sender;
- (IBAction) saveDocumentAs: (id) sender;
- (IBAction) revertDocumentToSaved: (id) sender;
- (IBAction) performClose: (id) sender;

- (IBAction) searchText: (id) sender;
- (IBAction) showSearchDialog: (id) sender;
- (IBAction) performFindPanelAction: (id) sender;
- (IBAction) replaceText: (id) sender;
- (IBAction) findInFiles: (id) sender;
- (IBAction) goToLine: (id) sender;
- (IBAction) browseSearchFolder: (id) sender;

- (IBAction) toggleWordWrap: (id) sender;
- (IBAction) toggleWhitespaceVisibility: (id) sender;
- (IBAction) toggleEolVisibility: (id) sender;
- (IBAction) toggleLineNumberMargin: (id) sender;
- (IBAction) toggleLiveTailCurrentFile: (id) sender;
- (IBAction) toggleSplitScreen: (id) sender;
- (IBAction) toggleDocumentMap: (id) sender;
- (IBAction) toggleAutosave: (id) sender;
- (IBAction) compareCurrentWithFile: (id) sender;

- (IBAction) sortSelectedLinesAscending: (id) sender;
- (IBAction) sortSelectedLinesDescending: (id) sender;
- (IBAction) trimTrailingWhitespaceLines: (id) sender;
- (IBAction) convertSelectionToUpperCase: (id) sender;
- (IBAction) convertSelectionToLowerCase: (id) sender;
- (IBAction) convertSelectionToCamelCase: (id) sender;

- (IBAction) convertEolToWindows: (id) sender;
- (IBAction) convertEolToUnix: (id) sender;
- (IBAction) convertEolToMacClassic: (id) sender;

- (IBAction) setEncodingUtf8: (id) sender;
- (IBAction) setEncodingUtf16LE: (id) sender;
- (IBAction) setEncodingUtf16BE: (id) sender;
- (IBAction) setEncodingIso88591: (id) sender;
- (IBAction) setEncodingWindows1252: (id) sender;
- (IBAction) setEncodingWindows1251: (id) sender;
- (IBAction) setEncodingShiftJis: (id) sender;
- (IBAction) setEncodingGb18030: (id) sender;
- (IBAction) setEncodingBig5: (id) sender;
- (IBAction) setEncodingEucKr: (id) sender;

- (IBAction) toggleSidebar: (id) sender;
- (IBAction) openProjectFolder: (id) sender;
- (IBAction) showPreferences: (id) sender;

- (IBAction) startStopMacroRecording: (id) sender;
- (IBAction) playRecordedMacro: (id) sender;
- (IBAction) saveRecordedMacroToLibrary: (id) sender;
- (IBAction) runRecordedMacroMultipleTimes: (id) sender;
- (IBAction) runNamedMacro: (id) sender;

- (IBAction) reloadPlugins: (id) sender;

- (IBAction) addRemoveExtra: (id) sender;
- (IBAction) setFontQuality: (id) sender;

@end

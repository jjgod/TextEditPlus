#import <Cocoa/Cocoa.h>
#import "ScalingScrollView.h"

@interface DocumentWindowController : NSWindowController <NSLayoutManagerDelegate, NSTextViewDelegate> {
    IBOutlet ScalingScrollView *scrollView;
    NSLayoutManager *layoutMgr;
    BOOL hasMultiplePages;
    BOOL rulerIsBeingDisplayed;
    BOOL isSettingSize;
}

// Convenience initializer. Loads the correct nib automatically.
- (id)init;

- (NSUInteger)numberOfPages;

- (NSView *)documentView;

- (void)breakUndoCoalescing;

/* Layout orientation sections */
- (NSArray *)layoutOrientationSections;

- (IBAction)chooseAndAttachFiles:(id)sender;

@end

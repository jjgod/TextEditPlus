#import <Cocoa/Cocoa.h>

@class NSPopUpButton;

@interface ScalingScrollView : NSScrollView {
    NSPopUpButton *_scalePopUpButton;
    CGFloat scaleFactor;
}

- (IBAction)scalePopUpAction:(id)sender;
- (void)setScaleFactor:(CGFloat)factor adjustPopup:(BOOL)flag;
- (CGFloat)scaleFactor;

@end

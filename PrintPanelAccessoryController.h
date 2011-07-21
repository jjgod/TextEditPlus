#import <Cocoa/Cocoa.h>


@interface PrintPanelAccessoryController : NSViewController <NSPrintPanelAccessorizing> {
    BOOL showsWrappingToFit;
    BOOL wrappingToFit;
}

- (IBAction)changePageNumbering:(id)sender;
- (IBAction)changeWrappingToFit:(id)sender;

@property BOOL pageNumbering;
@property BOOL wrappingToFit;
@property BOOL showsWrappingToFit;

@end

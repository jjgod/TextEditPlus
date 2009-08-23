#import <Cocoa/Cocoa.h>


@interface DocumentPropertiesPanelController : NSWindowController {
    IBOutlet id documentObjectController;
    id inspectedDocument;
}

- (IBAction)toggleWindow:(id)sender;

@end

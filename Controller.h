#import <Cocoa/Cocoa.h>

@class Preferences, DocumentPropertiesPanelController, LinePanelController;

@interface Controller : NSObject {
    IBOutlet Preferences *preferencesController;
    IBOutlet DocumentPropertiesPanelController *propertiesController;
    IBOutlet LinePanelController *lineController;
}

@property (assign) Preferences *preferencesController;
@property (assign) DocumentPropertiesPanelController *propertiesController;
@property (assign) LinePanelController *lineController;

@end

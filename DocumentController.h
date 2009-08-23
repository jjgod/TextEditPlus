#import <Cocoa/Cocoa.h>
#import "Document.h"

/* An instance of this subclass is created in the main nib file. */

// NSDocumentController is subclassed to provide for modification of the open panel. Normally, there is no need to subclass the document controller.
@interface DocumentController : NSDocumentController {
    NSMutableDictionary *customOpenSettings;	    // Mapping of document URLs to encoding, ignore HTML, and ignore rich text settings that override the defaults from Preferences
    NSMutableArray *deferredDocuments;
    NSLock *transientDocumentLock;
    NSLock *displayDocumentLock;
}

+ (NSView *)encodingAccessory:(NSUInteger)encoding includeDefaultEntry:(BOOL)includeDefaultItem encodingPopUp:(NSPopUpButton **)popup checkBox:(NSButton **)button;

- (Document *)openDocumentWithContentsOfPasteboard:(NSPasteboard *)pb display:(BOOL)display error:(NSError **)error;

- (NSStringEncoding)lastSelectedEncodingForURL:(NSURL *)url;
- (BOOL)lastSelectedIgnoreHTMLForURL:(NSURL *)url;
- (BOOL)lastSelectedIgnoreRichForURL:(NSURL *)url;

- (NSInteger)runModalOpenPanel:(NSOpenPanel *)openPanel forTypes:(NSArray *)types;

- (Document *)transientDocumentToReplace;
- (void)displayDocument:(NSDocument *)doc;
- (void)replaceTransientDocument:(NSArray *)documents;

@end

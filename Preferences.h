#import <Cocoa/Cocoa.h>

enum {
    HTMLDocumentTypeOptionUseTransitional = (1 << 0),
    HTMLDocumentTypeOptionUseXHTML = (1 << 1)
};
typedef NSUInteger HTMLDocumentTypeOptions;

enum {
    HTMLStylingUseEmbeddedCSS = 0,
    HTMLStylingUseInlineCSS = 1,
    HTMLStylingUseNoCSS = 2
};
typedef NSInteger HTMLStylingMode;

@interface Preferences : NSWindowController {
    BOOL changingRTFFont;
    NSInteger originalDimensionFieldValue;
}
- (IBAction)revertToDefault:(id)sender;    

- (IBAction)changeRichTextFont:(id)sender;	/* Request to change the rich text font */
- (IBAction)changePlainTextFont:(id)sender;	/* Request to change the plain text font */
- (void)changeFont:(id)fontManager;	/* Sent by the font manager */

- (NSFont *)richTextFont;
- (void)setRichTextFont:(NSFont *)newFont;
- (NSFont *)plainTextFont;
- (void)setPlainTextFont:(NSFont *)newFont;

@end

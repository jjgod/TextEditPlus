#import <Cocoa/Cocoa.h>

@interface Document : NSDocument {
    // Book-keeping
    BOOL setUpPrintInfoDefaults;	/* YES the first time -printInfo is called */
    BOOL inDuplicate;
    // Document data
    NSTextStorage *textStorage;		/* The (styled) text content of the document */
    CGFloat scaleFactor;		/* The scale factor retreived from file */
    BOOL isReadOnly;			/* The document is locked and should not be modified */
    NSColor *backgroundColor;		/* The color of the document's background */
    CGFloat hyphenationFactor;		/* Hyphenation factor in range 0.0-1.0 */
    NSSize viewSize;			/* The view size, as stored in an RTF document. Can be NSZeroSize */
    BOOL hasMultiplePages;		/* Whether the document prefers a paged display */
    
    // The next seven are document properties (applicable only to rich text documents)
    NSString *author;			/* Corresponds to NSAuthorDocumentAttribute */
    NSString *copyright;		/* Corresponds to NSCopyrightDocumentAttribute */
    NSString *company;			/* Corresponds to NSCompanyDocumentAttribute */
    NSString *title;			/* Corresponds to NSTitleDocumentAttribute */
    NSString *subject;			/* Corresponds to NSSubjectDocumentAttribute */
    NSString *comment;			/* Corresponds to NSCommentDocumentAttribute */
    NSArray *keywords;			/* Corresponds to NSKeywordsDocumentAttribute */
    
    // Information about how the document was created
    BOOL openedIgnoringRichText;	/* Setting at the the time the doc was open (so revert does the same thing) */
    NSStringEncoding documentEncoding;	/* NSStringEncoding used to interpret / save the document */
    BOOL convertedDocument;		/* Converted (or filtered) from some other format (and hence not writable) */
    BOOL lossyDocument;			/* Loaded lossily, so might not be a good idea to overwrite */
    BOOL transient;			/* Untitled document automatically opened and never modified */
    NSArray *originalOrientationSections; /* An array of dictionaries. Each describing the text layout orientation for a page */
    
    // Temporary information about how to save the document
    NSStringEncoding documentEncodingForSaving;	    /* NSStringEncoding for saving the document */
    NSSaveOperationType currentSaveOperation;          /* So we can know whether to use documentEncodingForSaving or documentEncoding
                                                        in -fileWrapperOfType:error: */
    NSLock *saveOperationTypeLock;                  /* so we can atomically set the save operation type and do the save */
    
    
    // Temporary information about document's desired file type
    NSString *fileTypeToSet;		/* Actual file type determined during a read, and set after the read (which includes revert) is complete. */ 

}

- (BOOL)readFromURL:(NSURL *)absoluteURL ofType:(NSString *)typeName encoding:(NSStringEncoding)encoding ignoreRTF:(BOOL)ignoreRTF ignoreHTML:(BOOL)ignoreHTML error:(NSError **)outError;

/* Is the document rich? */
- (BOOL)isRichText;
- (void)setRichText:(BOOL)flag;

/* Is the document read-only? */
- (BOOL)isReadOnly;
- (void)setReadOnly:(BOOL)flag;

/* Document background color */
- (NSColor *)backgroundColor;
- (void)setBackgroundColor:(NSColor *)color;

/* The encoding of the document... */
- (NSUInteger)encoding;
- (void)setEncoding:(NSUInteger)encoding;

/* Encoding of the document chosen when saving */
- (NSUInteger)encodingForSaving;
- (void)setEncodingForSaving:(NSUInteger)encoding;

/* Whether document was converted from some other format (filter services) */
- (BOOL)isConverted;
- (void)setConverted:(BOOL)flag;

/* Whether document was opened ignoring rich text */
- (BOOL)isOpenedIgnoringRichText;
- (void)setOpenedIgnoringRichText:(BOOL)flag;

/* Whether document was loaded lossily */
- (BOOL)isLossy;
- (void)setLossy:(BOOL)flag;

/* Hyphenation factor (0.0-1.0, 0.0 == disabled) */
- (float)hyphenationFactor;
- (void)setHyphenationFactor:(float)factor;

/* View size (as it should be saved in a RTF file) */
- (NSSize)viewSize;
- (void)setViewSize:(NSSize)newSize;

/* Scale factor; 1.0 is 100% */
- (CGFloat)scaleFactor;
- (void)setScaleFactor:(CGFloat)scaleFactor;

/* Attributes */
- (NSTextStorage *)textStorage;
- (void)setTextStorage:(id)ts; // This will _copy_ the contents of the NS[Attributed]String ts into the document's textStorage.

/* Page-oriented methods */
- (void)setHasMultiplePages:(BOOL)flag;
- (BOOL)hasMultiplePages;
- (NSSize)paperSize;
- (void)setPaperSize:(NSSize)size;

/* Action methods */
- (IBAction)toggleReadOnly:(id)sender;
- (IBAction)togglePageBreaks:(id)sender;
- (IBAction)saveDocumentAsPDFTo:(id)sender;

/* Whether conversion to rich/plain be done without loss of information */
- (BOOL)toggleRichWillLoseInformation;

/* Default text attributes for plain or rich text formats */
- (NSDictionary *)defaultTextAttributes:(BOOL)forRichText;
- (void)applyDefaultTextAttributes:(BOOL)forRichText;

/* Document properties */
- (NSDictionary *)documentPropertyToAttributeNameMappings;
- (NSArray *)knownDocumentProperties;
- (void)clearDocumentProperties;
- (void)setDocumentPropertiesToDefaults;
- (BOOL)hasDocumentProperties;

/* Transient documents */
- (BOOL)isTransient;
- (void)setTransient:(BOOL)flag;
- (BOOL)isTransientAndCanBeReplaced;

/* Layout orientation sections */
- (NSArray *)originalOrientationSections;
- (void)setOriginalOrientationSections:(NSArray *)array;
@end

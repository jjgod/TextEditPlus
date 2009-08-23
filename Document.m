/*
        Document.m
        Copyright (c) 1995-2009 by Apple Computer, Inc., all rights reserved.
        Author: Ali Ozer

        Document object for TextEdit. 
	As of TextEdit 1.5, a subclass of NSDocument.
*/
/*
 IMPORTANT:  This Apple software is supplied to you by Apple Computer, Inc. ("Apple") in
 consideration of your agreement to the following terms, and your use, installation, 
 modification or redistribution of this Apple software constitutes acceptance of these 
 terms.  If you do not agree with these terms, please do not use, install, modify or 
 redistribute this Apple software.
 
 In consideration of your agreement to abide by the following terms, and subject to these 
 terms, Apple grants you a personal, non-exclusive license, under Apple's copyrights in 
 this original Apple software (the "Apple Software"), to use, reproduce, modify and 
 redistribute the Apple Software, with or without modifications, in source and/or binary 
 forms; provided that if you redistribute the Apple Software in its entirety and without 
 modifications, you must retain this notice and the following text and disclaimers in all 
 such redistributions of the Apple Software.  Neither the name, trademarks, service marks 
 or logos of Apple Computer, Inc. may be used to endorse or promote products derived from 
 the Apple Software without specific prior written permission from Apple. Except as expressly
 stated in this notice, no other rights or licenses, express or implied, are granted by Apple
 herein, including but not limited to any patent rights that may be infringed by your 
 derivative works or by other works in which the Apple Software may be incorporated.
 
 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE MAKES NO WARRANTIES, 
 EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, 
 MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS 
 USE AND OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.
 
 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL OR CONSEQUENTIAL 
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS 
 OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, 
 REPRODUCTION, MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED AND 
 WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE), STRICT LIABILITY OR 
 OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

#import <Cocoa/Cocoa.h>
#import "EncodingManager.h"
#import "Document.h"
#import "DocumentController.h"
#import "DocumentWindowController.h"
#import "PrintPanelAccessoryController.h"
#import "TextEditDefaultsKeys.h"
#import "TextEditErrors.h"
#import "TextEditMisc.h"

#define oldEditPaddingCompensation 12.0

NSString *SimpleTextType = @"com.apple.traditional-mac-plain-text";
NSString *Word97Type = @"com.microsoft.word.doc";
NSString *Word2007Type = @"org.openxmlformats.wordprocessingml.document";
NSString *Word2003XMLType = @"com.microsoft.word.wordml";
NSString *OpenDocumentTextType = @"org.oasis-open.opendocument.text";


@implementation Document

- (id)init {
    if (self = [super init]) {
        [[self undoManager] disableUndoRegistration];
        
	textStorage = [[NSTextStorage allocWithZone:[self zone]] init];
	
	[self setBackgroundColor:[NSColor whiteColor]];
	[self setEncoding:NoStringEncoding];
	[self setEncodingForSaving:NoStringEncoding];
	[self setScaleFactor:1.0];
	[self setDocumentPropertiesToDefaults];
	
	 // Assume the default file type for now, since -initWithType:error: does not currently get called when creating documents using AppleScript. (4165700)
	[self setFileType:[[NSDocumentController sharedDocumentController] defaultType]];
	
        [self setPrintInfo:[self printInfo]];
        
	hasMultiplePages = [[NSUserDefaults standardUserDefaults] boolForKey:ShowPageBreaks];
        
        [[self undoManager] enableUndoRegistration];
    }
    return self;
}

/* Return an NSDictionary which maps Cocoa text system document identifiers (as declared in AppKit/NSAttributedString.h) to document types declared in TextEdit's Info.plist.
*/
- (NSDictionary *)textDocumentTypeToTextEditDocumentTypeMappingTable {
    static NSDictionary *documentMappings = nil;
    if (documentMappings == nil) {
	documentMappings = [[NSDictionary alloc] initWithObjectsAndKeys:
            (NSString *)kUTTypePlainText, NSPlainTextDocumentType,
            (NSString *)kUTTypeRTF, NSRTFTextDocumentType,
            (NSString *)kUTTypeRTFD, NSRTFDTextDocumentType,
            SimpleTextType, NSMacSimpleTextDocumentType,
            (NSString *)kUTTypeHTML, NSHTMLTextDocumentType,
	    Word97Type, NSDocFormatTextDocumentType,
	    Word2007Type, NSOfficeOpenXMLTextDocumentType,
	    Word2003XMLType, NSWordMLTextDocumentType,
	    OpenDocumentTextType, NSOpenDocumentTextDocumentType,
            (NSString *)kUTTypeWebArchive, NSWebArchiveTextDocumentType,
	    nil];
    }
    return documentMappings;
}

/* This method is called by the document controller. The message is passed on after information about the selected encoding (from our controller subclass) and preference regarding HTML and RTF formatting has been added. -lastSelectedEncodingForURL: returns the encoding specified in the Open panel, or the default encoding if the document was opened without an open panel.
*/
- (BOOL)readFromURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError {
    DocumentController *docController = [DocumentController sharedDocumentController];
    return [self readFromURL:absoluteURL ofType:typeName encoding:[docController lastSelectedEncodingForURL:absoluteURL] ignoreRTF:[docController lastSelectedIgnoreRichForURL:absoluteURL] ignoreHTML:[docController lastSelectedIgnoreHTMLForURL:absoluteURL] error:outError];
}

- (BOOL)readFromURL:(NSURL *)absoluteURL ofType:(NSString *)typeName encoding:(NSStringEncoding)encoding ignoreRTF:(BOOL)ignoreRTF ignoreHTML:(BOOL)ignoreHTML error:(NSError **)outError {
    NSMutableDictionary *options = [NSMutableDictionary dictionaryWithCapacity:5];
    NSDictionary *docAttrs;
    id val, paperSizeVal, viewSizeVal;
    NSTextStorage *text = [self textStorage];
    
    [[self undoManager] disableUndoRegistration];
    
    [options setObject:absoluteURL forKey:NSBaseURLDocumentOption];
    if (encoding != NoStringEncoding) {
        [options setObject:[NSNumber numberWithUnsignedInteger:encoding] forKey:NSCharacterEncodingDocumentOption];
    }
    [self setEncoding:encoding];
    
    // Check type to see if we should load the document as plain. Note that this check isn't always conclusive, which is why we do another check below, after the document has been loaded (and correctly categorized).
    NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
    if ((ignoreRTF && ([workspace type:typeName conformsToType:(NSString *)kUTTypeRTF] || [workspace type:typeName conformsToType:Word2003XMLType])) || (ignoreHTML && [workspace type:typeName conformsToType:(NSString *)kUTTypeHTML]) || [self isOpenedIgnoringRichText]) {
        [options setObject:NSPlainTextDocumentType forKey:NSDocumentTypeDocumentOption]; // Force plain
	[self setFileType:(NSString *)kUTTypePlainText];
	[self setOpenedIgnoringRichText:YES];
    }
    
    [[text mutableString] setString:@""];
    // Remove the layout managers while loading the text; mutableCopy retains the array so the layout managers aren't released
    NSMutableArray *layoutMgrs = [[text layoutManagers] mutableCopy];
    NSEnumerator *layoutMgrEnum = [layoutMgrs objectEnumerator];
    NSLayoutManager *layoutMgr = nil;
    while (layoutMgr = [layoutMgrEnum nextObject]) [text removeLayoutManager:layoutMgr];
    
    // We can do this loop twice, if the document is loaded as rich text although the user requested plain
    BOOL retry;
    do {
	BOOL success;
	NSString *docType;
	
	retry = NO;

	[text beginEditing];
	success = [text readFromURL:absoluteURL options:options documentAttributes:&docAttrs error:outError];

        if (!success) {
	    [text endEditing];
	    layoutMgrEnum = [layoutMgrs objectEnumerator]; // rewind
	    while (layoutMgr = [layoutMgrEnum nextObject]) [text addLayoutManager:layoutMgr];   // Add the layout managers back
	    [layoutMgrs release];
	    return NO;	// return NO on error; outError has already been set
	}
	
	docType = [docAttrs objectForKey:NSDocumentTypeDocumentAttribute];

	// First check to see if the document was rich and should have been loaded as plain
	if (![[options objectForKey:NSDocumentTypeDocumentOption] isEqualToString:NSPlainTextDocumentType] && ((ignoreHTML && [docType isEqual:NSHTMLTextDocumentType]) || (ignoreRTF && ([docType isEqual:NSRTFTextDocumentType] || [docType isEqual:NSWordMLTextDocumentType])))) {
	    [text endEditing];
	    [[text mutableString] setString:@""];
	    [options setObject:NSPlainTextDocumentType forKey:NSDocumentTypeDocumentOption];
	    [self setFileType:(NSString *)kUTTypePlainText];
	    [self setOpenedIgnoringRichText:YES];
	    retry = YES;
	} else {
	    NSString *newFileType = [[self textDocumentTypeToTextEditDocumentTypeMappingTable] objectForKey:docType];
	    if (newFileType) {
		[self setFileType:newFileType];
	    } else {
		[self setFileType:(NSString *)kUTTypeRTF];	// Hmm, a new type in the Cocoa text system. Treat it as rich. ??? Should set the converted flag too?
	    }
	    if ([workspace type:[self fileType] conformsToType:(NSString *)kUTTypePlainText]) [self applyDefaultTextAttributes:NO];
	    [text endEditing];
	}
    } while(retry);

    layoutMgrEnum = [layoutMgrs objectEnumerator]; // rewind
    while (layoutMgr = [layoutMgrEnum nextObject]) [text addLayoutManager:layoutMgr];   // Add the layout managers back
    [layoutMgrs release];
    
    val = [docAttrs objectForKey:NSCharacterEncodingDocumentAttribute];
    [self setEncoding:(val ? [val unsignedIntegerValue] : NoStringEncoding)];
    
    if (val = [docAttrs objectForKey:NSConvertedDocumentAttribute]) {
        [self setConverted:([val integerValue] > 0)];	// Indicates filtered
        [self setLossy:([val integerValue] < 0)];	// Indicates lossily loaded
    }
    
    /* If the document has a stored value for view mode, use it. Otherwise wrap to window. */
    if ((val = [docAttrs objectForKey:NSViewModeDocumentAttribute])) {
        [self setHasMultiplePages:([val integerValue] == 1)];
        if ((val = [docAttrs objectForKey:NSViewZoomDocumentAttribute])) {
            [self setScaleFactor:([val doubleValue] / 100.0)];
        }
    } else [self setHasMultiplePages:NO];
    
    [self willChangeValueForKey:@"printInfo"];
    if ((val = [docAttrs objectForKey:NSLeftMarginDocumentAttribute])) [[self printInfo] setLeftMargin:[val doubleValue]];
    if ((val = [docAttrs objectForKey:NSRightMarginDocumentAttribute])) [[self printInfo] setRightMargin:[val doubleValue]];
    if ((val = [docAttrs objectForKey:NSBottomMarginDocumentAttribute])) [[self printInfo] setBottomMargin:[val doubleValue]];
    if ((val = [docAttrs objectForKey:NSTopMarginDocumentAttribute])) [[self printInfo] setTopMargin:[val doubleValue]];
    [self didChangeValueForKey:@"printInfo"];
    
    /* Pre MacOSX versions of TextEdit wrote out the view (window) size in PaperSize.
	If we encounter a non-MacOSX RTF file, and it's written by TextEdit, use PaperSize as ViewSize */
    viewSizeVal = [docAttrs objectForKey:NSViewSizeDocumentAttribute];
    paperSizeVal = [docAttrs objectForKey:NSPaperSizeDocumentAttribute];
    if (paperSizeVal && NSEqualSizes([paperSizeVal sizeValue], NSZeroSize)) paperSizeVal = nil;	// Protect against some old documents with 0 paper size
    
    if (viewSizeVal) {
        [self setViewSize:[viewSizeVal sizeValue]];
        if (paperSizeVal) [self setPaperSize:[paperSizeVal sizeValue]];
    } else {	// No ViewSize...
        if (paperSizeVal) {	// See if PaperSize should be used as ViewSize; if so, we also have some tweaking to do on it
            val = [docAttrs objectForKey:NSCocoaVersionDocumentAttribute];
            if (val && ([val integerValue] < 100)) {	// Indicates old RTF file; value described in AppKit/NSAttributedString.h
                NSSize size = [paperSizeVal sizeValue];
                if (size.width > 0 && size.height > 0 && ![self hasMultiplePages]) {
                    size.width = size.width - oldEditPaddingCompensation;
                    [self setViewSize:size];
                }
            } else {
		[self setPaperSize:[paperSizeVal sizeValue]];
            }
        }
    }
    
    [self setHyphenationFactor:(val = [docAttrs objectForKey:NSHyphenationFactorDocumentAttribute]) ? [val floatValue] : 0];
    [self setBackgroundColor:(val = [docAttrs objectForKey:NSBackgroundColorDocumentAttribute]) ? val : [NSColor whiteColor]];
    
    // Set the document properties, generically, going through key value coding
    NSDictionary *map = [self documentPropertyToAttributeNameMappings];
    for (NSString *property in [self knownDocumentProperties]) [self setValue:[docAttrs objectForKey:[map objectForKey:property]] forKey:property];	// OK to set nil to clear
    
    [self setReadOnly:((val = [docAttrs objectForKey:NSReadOnlyDocumentAttribute]) && ([val integerValue] > 0))];
    
    [[self undoManager] enableUndoRegistration];
    
    return YES;
}

- (NSDictionary *)defaultTextAttributes:(BOOL)forRichText {
    static NSParagraphStyle *defaultRichParaStyle = nil;
    NSMutableDictionary *textAttributes = [[[NSMutableDictionary alloc] initWithCapacity:2] autorelease];
    if (forRichText) {
	[textAttributes setObject:[NSFont userFontOfSize:0.0] forKey:NSFontAttributeName];
	if (defaultRichParaStyle == nil) {	// We do this once...
	    NSInteger cnt;
            NSString *measurementUnits = [[NSUserDefaults standardUserDefaults] objectForKey:@"AppleMeasurementUnits"];
            CGFloat tabInterval = ([@"Centimeters" isEqual:measurementUnits]) ? (72.0 / 2.54) : (72.0 / 2.0);  // Every cm or half inch
	    NSMutableParagraphStyle *paraStyle = [[[NSMutableParagraphStyle alloc] init] autorelease];
	    [paraStyle setTabStops:[NSArray array]];	// This first clears all tab stops
	    for (cnt = 0; cnt < 12; cnt++) {	// Add 12 tab stops, at desired intervals...
                NSTextTab *tabStop = [[NSTextTab alloc] initWithType:NSLeftTabStopType location:tabInterval * (cnt + 1)];
		[paraStyle addTabStop:tabStop];
	 	[tabStop release];
	    }
	    defaultRichParaStyle = [paraStyle copy];
	}
	[textAttributes setObject:defaultRichParaStyle forKey:NSParagraphStyleAttributeName];
    } else {
	NSFont *plainFont = [NSFont userFixedPitchFontOfSize:0.0];
	NSInteger tabWidth = [[NSUserDefaults standardUserDefaults] integerForKey:TabWidth];
	CGFloat charWidth = [@" " sizeWithAttributes:[NSDictionary dictionaryWithObject:plainFont forKey:NSFontAttributeName]].width;
        if (charWidth == 0) charWidth = [[plainFont screenFontWithRenderingMode:NSFontDefaultRenderingMode] maximumAdvancement].width;
	
	// Now use a default paragraph style, but with the tab width adjusted
	NSMutableParagraphStyle *mStyle = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
	[mStyle setTabStops:[NSArray array]];
	[mStyle setDefaultTabInterval:(charWidth * tabWidth)];
        [textAttributes setObject:[[mStyle copy] autorelease] forKey:NSParagraphStyleAttributeName];
	
	// Also set the font
	[textAttributes setObject:plainFont forKey:NSFontAttributeName];
    }
    return textAttributes;
}

- (void)applyDefaultTextAttributes:(BOOL)forRichText {
    NSDictionary *textAttributes = [self defaultTextAttributes:forRichText];
    NSTextStorage *text = [self textStorage];
    // We now preserve base writing direction even for plain text, using the 10.6-introduced attribute enumeration API
    [text enumerateAttribute:NSParagraphStyleAttributeName inRange:NSMakeRange(0, [text length]) options:0 usingBlock:^(id paragraphStyle, NSRange paragraphStyleRange, BOOL *stop){
        NSWritingDirection writingDirection = paragraphStyle ? [(NSParagraphStyle *)paragraphStyle baseWritingDirection] : NSWritingDirectionNatural;
        // We also preserve NSWritingDirectionAttributeName (new in 10.6)
        [text enumerateAttribute:NSWritingDirectionAttributeName inRange:paragraphStyleRange options:0 usingBlock:^(id value, NSRange attributeRange, BOOL *stop){
            [value retain];
            [text setAttributes:textAttributes range:attributeRange];
            if (value) [text addAttribute:NSWritingDirectionAttributeName value:value range:attributeRange];
            [value release];
        }];
        if (writingDirection != NSWritingDirectionNatural) [text setBaseWritingDirection:writingDirection range:paragraphStyleRange];
    }];
}


/* This method will return a suggested encoding for the document. In Leopard, unless the user has specified a favorite encoding for saving that applies to the document, we use UTF-8.
*/
- (NSStringEncoding)suggestedDocumentEncoding {
    NSUInteger enc = NoStringEncoding;
    NSNumber *val = [[NSUserDefaults standardUserDefaults] objectForKey:PlainTextEncodingForWrite];
    if (val) {
	NSStringEncoding chosenEncoding = [val unsignedIntegerValue];
	if ((chosenEncoding != NoStringEncoding)  && (chosenEncoding != NSUnicodeStringEncoding) && (chosenEncoding != NSUTF8StringEncoding)) {
	    if ([[[self textStorage] string] canBeConvertedToEncoding:chosenEncoding]) enc = chosenEncoding;
	}
    }
    if (enc == NoStringEncoding) enc = NSUTF8StringEncoding;	// Default to UTF-8
    return enc;
}

/* Returns an object that represents the document to be written to file. 
*/
- (id)fileWrapperOfType:(NSString *)typeName error:(NSError **)outError {
    NSTextStorage *text = [self textStorage];
    NSRange range = NSMakeRange(0, [text length]);

    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithObjectsAndKeys:
	[NSValue valueWithSize:[self paperSize]], NSPaperSizeDocumentAttribute, 
	[NSNumber numberWithInteger:[self isReadOnly] ? 1 : 0], NSReadOnlyDocumentAttribute, 
	[NSNumber numberWithFloat:[self hyphenationFactor]], NSHyphenationFactorDocumentAttribute, 
	[NSNumber numberWithDouble:[[self printInfo] leftMargin]], NSLeftMarginDocumentAttribute, 
	[NSNumber numberWithDouble:[[self printInfo] rightMargin]], NSRightMarginDocumentAttribute, 
	[NSNumber numberWithDouble:[[self printInfo] bottomMargin]], NSBottomMarginDocumentAttribute, 
	[NSNumber numberWithDouble:[[self printInfo] topMargin]], NSTopMarginDocumentAttribute, 
	[NSNumber numberWithInteger:[self hasMultiplePages] ? 1 : 0], NSViewModeDocumentAttribute,
	nil];
    NSString *docType = nil;
    id val = nil; // temporary values
    
    NSSize size = [self viewSize];
    if (!NSEqualSizes(size, NSZeroSize)) {
	[dict setObject:[NSValue valueWithSize:size] forKey:NSViewSizeDocumentAttribute];
    }
    
    // TextEdit knows how to save all these types, including their super-types. It does not know how to save any of their potential subtypes. Hence, the conformance check is the reverse of the usual pattern.
    NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
    if ([workspace type:(NSString *)kUTTypeRTF conformsToType:typeName]) docType = NSRTFTextDocumentType;
    else if ([workspace type:(NSString *)kUTTypeRTFD conformsToType:typeName]) docType = NSRTFDTextDocumentType;
    else if ([workspace type:(NSString *)kUTTypePlainText conformsToType:typeName]) docType = NSPlainTextDocumentType;
    else if ([workspace type:SimpleTextType conformsToType:typeName]) docType = NSMacSimpleTextDocumentType;
    else if ([workspace type:Word97Type conformsToType:typeName]) docType = NSDocFormatTextDocumentType;
    else if ([workspace type:Word2007Type conformsToType:typeName]) docType = NSOfficeOpenXMLTextDocumentType;
    else if ([workspace type:Word2003XMLType conformsToType:typeName]) docType = NSWordMLTextDocumentType;
    else if ([workspace type:OpenDocumentTextType conformsToType:typeName]) docType = NSOpenDocumentTextDocumentType;
    else if ([workspace type:(NSString *)kUTTypeHTML conformsToType:typeName]) docType = NSHTMLTextDocumentType;
    else if ([workspace type:(NSString *)kUTTypeWebArchive conformsToType:typeName]) docType = NSWebArchiveTextDocumentType;
    else [NSException raise:NSInvalidArgumentException format:@"%@ is not a recognized document type.", typeName];
    
    if (docType) [dict setObject:docType forKey:NSDocumentTypeDocumentAttribute];
    if ([self hasMultiplePages] && ([self scaleFactor] != 1.0)) [dict setObject:[NSNumber numberWithDouble:[self scaleFactor] * 100.0] forKey:NSViewZoomDocumentAttribute];
    if (val = [self backgroundColor]) [dict setObject:val forKey:NSBackgroundColorDocumentAttribute];
    
    if (docType == NSPlainTextDocumentType) {
        NSStringEncoding enc = [self encodingForSaving];

	// check here in case this didn't go through save panel (i.e. scripting)
        if (enc == NoStringEncoding) {
	    enc = [self encoding];
	    if (enc == NoStringEncoding) enc = [self suggestedDocumentEncoding];
	}
	[dict setObject:[NSNumber numberWithUnsignedInteger:enc] forKey:NSCharacterEncodingDocumentAttribute];
    } else if (docType == NSHTMLTextDocumentType || docType == NSWebArchiveTextDocumentType) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        
	NSMutableArray *excludedElements = [NSMutableArray array];
	if (![defaults boolForKey:UseXHTMLDocType]) [excludedElements addObject:@"XML"];
	if (![defaults boolForKey:UseTransitionalDocType]) [excludedElements addObjectsFromArray:[NSArray arrayWithObjects:@"APPLET", @"BASEFONT", @"CENTER", @"DIR", @"FONT", @"ISINDEX", @"MENU", @"S", @"STRIKE", @"U", nil]];
	if (![defaults boolForKey:UseEmbeddedCSS]) {
	    [excludedElements addObject:@"STYLE"];
	    if (![defaults boolForKey:UseInlineCSS]) [excludedElements addObject:@"SPAN"];
	}
	if (![defaults boolForKey:PreserveWhitespace]) {
	    [excludedElements addObject:@"Apple-converted-space"];
	    [excludedElements addObject:@"Apple-converted-tab"];
	    [excludedElements addObject:@"Apple-interchange-newline"];
	}
	[dict setObject:excludedElements forKey:NSExcludedElementsDocumentAttribute];
	[dict setObject:[defaults objectForKey:HTMLEncoding] forKey:NSCharacterEncodingDocumentAttribute];
	[dict setObject:[NSNumber numberWithInteger:2] forKey:NSPrefixSpacesDocumentAttribute];
    }
    
    // Set the document properties, generically, going through key value coding
    for (NSString *property in [self knownDocumentProperties]) {
	id value = [self valueForKey:property];
	if (value && ![value isEqual:@""] && ![value isEqual:[NSArray array]]) [dict setObject:value forKey:[[self documentPropertyToAttributeNameMappings] objectForKey:property]];
    }
    
    NSFileWrapper *result = nil;
    if (docType == NSRTFDTextDocumentType || (docType == NSPlainTextDocumentType && ![self isOpenedIgnoringRichText])) {	// We obtain a file wrapper from the text storage for RTFD (to produce a directory), or for true plain-text documents (to write out encoding in extended attributes)
        result = [text fileWrapperFromRange:range documentAttributes:dict error:outError]; // returns NSFileWrapper
    } else {
    	NSData *data = [text dataFromRange:range documentAttributes:dict error:outError]; // returns NSData
	if (data) {
	    result = [[[NSFileWrapper alloc] initRegularFileWithContents:data] autorelease];
	    if (!result && outError) *outError = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileWriteUnknownError userInfo:nil];    // Unlikely, but just in case we should generate an NSError for this case
        }
    }
    
    return result;
}

/* Clear the delegates of the text views and window, then release all resources and go away...
*/
- (void)dealloc {
    [textStorage release];
    [backgroundColor release];
    
    [author release];
    [comment release];
    [subject release];
    [title release];
    [keywords release];
    [copyright release];
    
    [defaultDestination release];

    if (uniqueZone) NSRecycleZone([self zone]);

    [super dealloc];
}

- (CGFloat)scaleFactor {
    return scaleFactor;
}

- (void)setScaleFactor:(CGFloat)newScaleFactor {
    scaleFactor = newScaleFactor;
}

- (NSSize)viewSize {
    return viewSize;
}

- (void)setViewSize:(NSSize)size {
    viewSize = size;
}

- (void)setReadOnly:(BOOL)flag {
    isReadOnly = flag;
}

- (BOOL)isReadOnly {
    return isReadOnly;
}

- (void)setBackgroundColor:(NSColor *)color {
    id oldCol = backgroundColor;
    backgroundColor = [color copy];
    [oldCol release];
}

- (NSColor *)backgroundColor {
    return backgroundColor;
}

- (NSTextStorage *)textStorage {
    return textStorage;
}

- (NSSize)paperSize {
    return [[self printInfo] paperSize];
}

- (void)setPaperSize:(NSSize)size {
    NSPrintInfo *oldPrintInfo = [self printInfo];
    if (!NSEqualSizes(size, [oldPrintInfo paperSize])) {
	NSPrintInfo *newPrintInfo = [oldPrintInfo copy];
	[newPrintInfo setPaperSize:size];
	[self setPrintInfo:newPrintInfo];
	[newPrintInfo release];
    }
}

/* Hyphenation related methods.
*/
- (void)setHyphenationFactor:(float)factor {
    hyphenationFactor = factor;
}

- (float)hyphenationFactor {
    return hyphenationFactor;
}

/* Encoding...
*/
- (NSUInteger)encoding {
    return documentEncoding;
}

- (void)setEncoding:(NSUInteger)encoding {
    documentEncoding = encoding;
}

/* This is the encoding used for saving; valid only during a save operation
*/
- (NSUInteger)encodingForSaving {
    return documentEncodingForSaving;
}

- (void)setEncodingForSaving:(NSUInteger)encoding {
    documentEncodingForSaving = encoding;
}


- (BOOL)isConverted {
    return convertedDocument;
}

- (void)setConverted:(BOOL)flag {
    convertedDocument = flag;
}

- (BOOL)isLossy {
    return lossyDocument;
}

- (void)setLossy:(BOOL)flag {
    lossyDocument = flag;
}

- (BOOL)isOpenedIgnoringRichText {
    return openedIgnoringRichText;
}

- (void)setOpenedIgnoringRichText:(BOOL)flag {
    openedIgnoringRichText = flag;
}

/* A transient document is an untitled document that was opened automatically. If a real document is opened before the transient document is edited, the real document should replace the transient. If a transient document is edited, it ceases to be transient. 
*/
- (BOOL)isTransient {
    return transient;
}

- (void)setTransient:(BOOL)flag {
    transient = flag;
}

/* We can't replace transient document that have sheets on them.
*/
- (BOOL)isTransientAndCanBeReplaced {
    if (![self isTransient]) return NO;
    for (NSWindowController *controller in [self windowControllers]) if ([[controller window] attachedSheet]) return NO;
    return YES;
}


/* The rich text status is dependent on the document type, and vice versa. Making a plain document rich, will -setFileType: to RTF. 
*/
- (void)setRichText:(BOOL)flag {
    if (flag != [self isRichText]) {
	[self setFileType:(NSString *)(flag ? kUTTypeRTF : kUTTypePlainText)];
	if (flag) {
	    [self setDocumentPropertiesToDefaults];
	} else {
	    [self clearDocumentProperties];
	}
    }
}

- (BOOL)isRichText {
    return ![[NSWorkspace sharedWorkspace] type:[self fileType] conformsToType:(NSString *)kUTTypePlainText];
}


/* Document properties management */

/* Table mapping document property keys "company", etc, to text system document attribute keys (NSCompanyDocumentAttribute, etc)
*/
- (NSDictionary *)documentPropertyToAttributeNameMappings {
    static NSDictionary *dict = nil;
    if (!dict) dict = [[NSDictionary alloc] initWithObjectsAndKeys:
	NSCompanyDocumentAttribute, @"company", 
	NSAuthorDocumentAttribute, @"author", 
	NSKeywordsDocumentAttribute, @"keywords", 
  	NSCopyrightDocumentAttribute, @"copyright", 
	NSTitleDocumentAttribute, @"title", 
	NSSubjectDocumentAttribute, @"subject", 
	NSCommentDocumentAttribute, @"comment", nil];
    return dict;
}

- (NSArray *)knownDocumentProperties {
    return [[self documentPropertyToAttributeNameMappings] allKeys];
}

/* If there are document properties and they are not the same as the defaults established in preferences, return YES
*/
- (BOOL)hasDocumentProperties {
    for (NSString *key in [self knownDocumentProperties]) {
	id value = [self valueForKey:key];
	if (value && ![value isEqual:[[NSUserDefaults standardUserDefaults] objectForKey:key]]) return YES;
    }
    return NO;
}

/* This actually clears all properties (rather than setting them to default values established in preferences)
*/
- (void)clearDocumentProperties {
    for (NSString *key in [self knownDocumentProperties]) [self setValue:nil forKey:key];
}

/* This sets document properties to values established in defaults
*/
- (void)setDocumentPropertiesToDefaults {
    for (NSString *key in [self knownDocumentProperties]) [self setValue:[[NSUserDefaults standardUserDefaults] objectForKey:key] forKey:key];
}

/* We implement a setValue:forDocumentProperty: to work around NSUndoManager bug where prepareWithInvocationTarget: fails to freeze-dry invocations with "known" methods such as setValue:forKey:.  
*/
- (void)setValue:(id)value forDocumentProperty:(NSString *)property {
    id oldValue = [self valueForKey:property];
    [[[self undoManager] prepareWithInvocationTarget:self] setValue:oldValue forDocumentProperty:property];
    [[self undoManager] setActionName:NSLocalizedString(property, "")];	// Potential strings for action names are listed below (for genstrings to pick up)

    // Call the regular KVC mechanism to get the value to be properly set
    [super setValue:value forKey:property];
}

- (void)setValue:(id)value forKey:(NSString *)key {
    if ([[self knownDocumentProperties] containsObject:key]) { 
	[self setValue:value forDocumentProperty:key];	// We take a side-trip to this method to register for undo
    } else {
	[super setValue:value forKey:key];  // In case some other KVC call is sent to Document, we treat it normally
    }
}

/* For genstrings:
    NSLocalizedStringWithDefaultValue(@"author", @"", @"", @"Change Author", @"Undo menu change string, without the 'Undo'");
    NSLocalizedStringWithDefaultValue(@"copyright", @"", @"", @"Change Copyright", @"Undo menu change string, without the 'Undo'");
    NSLocalizedStringWithDefaultValue(@"subject", @"", @"", @"Change Subject", @"Undo menu change string, without the 'Undo'");
    NSLocalizedStringWithDefaultValue(@"title", @"", @"", @"Change Title", @"Undo menu change string, without the 'Undo'");
    NSLocalizedStringWithDefaultValue(@"company", @"", @"", @"Change Company", @"Undo menu change string, without the 'Undo'");
    NSLocalizedStringWithDefaultValue(@"comment", @"", @"", @"Change Comment", @"Undo menu change string, without the 'Undo'");
    NSLocalizedStringWithDefaultValue(@"keywords", @"", @"", @"Change Keywords", @"Undo menu change string, without the 'Undo'");
*/



- (NSPrintOperation *)printOperationWithSettings:(NSDictionary *)printSettings error:(NSError **)outError {
    NSPrintInfo *tempPrintInfo = [self printInfo];
    BOOL numberPages = [[NSUserDefaults standardUserDefaults] boolForKey:NumberPagesWhenPrinting];
    if ([printSettings count] || numberPages) {
	tempPrintInfo = [[tempPrintInfo copy] autorelease];
	[[tempPrintInfo dictionary] addEntriesFromDictionary:printSettings];
	if (numberPages) {
	    [[tempPrintInfo dictionary] setValue:[NSNumber numberWithBool:YES] forKey:NSPrintHeaderAndFooter];
	}
    }
    if ([[self windowControllers] count] == 0) {
	[self makeWindowControllers];
    }
    
    NSPrintOperation *op = [NSPrintOperation printOperationWithView:[[[self windowControllers] objectAtIndex:0] documentView] printInfo:tempPrintInfo];
    [op setShowsPrintPanel:YES];
    [op setShowsProgressPanel:YES];
    
    [[[self windowControllers] objectAtIndex:0] doForegroundLayoutToCharacterIndex:NSIntegerMax];	// Make sure the whole document is laid out before printing
    
    NSPrintPanel *printPanel = [op printPanel];
    [printPanel addAccessoryController:[[[PrintPanelAccessoryController alloc] init] autorelease]];
    // We allow changing print parameters if not in "Wrap to Page" mode, where the page setup settings are used
    if (![self hasMultiplePages]) [printPanel setOptions:[printPanel options] | NSPrintPanelShowsPaperSize | NSPrintPanelShowsOrientation];
        
    return op;
}

- (NSPrintInfo *)printInfo {
    NSPrintInfo *printInfo = [super printInfo];
    if (!setUpPrintInfoDefaults) {
	setUpPrintInfoDefaults = YES;
	[printInfo setHorizontalPagination:NSFitPagination];
	[printInfo setHorizontallyCentered:NO];
	[printInfo setVerticallyCentered:NO];
	[printInfo setLeftMargin:72.0];
	[printInfo setRightMargin:72.0];
	[printInfo setTopMargin:72.0];
	[printInfo setBottomMargin:72.0];
    }
    return printInfo;
}

/* Toggles read-only state of the document
*/
- (IBAction)toggleReadOnly:(id)sender {
    [[self undoManager] registerUndoWithTarget:self selector:@selector(toggleReadOnly:) object:nil];
    [[self undoManager] setActionName:[self isReadOnly] ?
        NSLocalizedString(@"Allow Editing", @"Menu item to make the current document editable (not read-only)") :
        NSLocalizedString(@"Prevent Editing", @"Menu item to make the current document read-only")];
    [self setReadOnly:![self isReadOnly]];
}

- (BOOL)toggleRichWillLoseInformation {
    NSInteger length = [textStorage length];
    NSRange range;
    NSDictionary *attrs;
    return ( [self isRichText] // Only rich -> plain can lose information.
	     && ((length > 0) // If the document contains characters and...
		 && (attrs = [textStorage attributesAtIndex:0 effectiveRange:&range])  // ...they have attributes...
		 && ((range.length < length) // ...which either are not the same for the whole document...
		     || ![[self defaultTextAttributes:YES] isEqual:attrs]) // ...or differ from the default, then...
		 ) // ...we will lose styling information.
	     || [self hasDocumentProperties]); // We will also lose information if the document has properties.
}

- (BOOL)hasMultiplePages {
    return hasMultiplePages;
}

- (void)setHasMultiplePages:(BOOL)flag {
    hasMultiplePages = flag;
}

- (IBAction)togglePageBreaks:(id)sender {
    [self setHasMultiplePages:![self hasMultiplePages]];
}

- (void)toggleHyphenation:(id)sender {
    float currentHyphenation = [self hyphenationFactor];
    [[[self undoManager] prepareWithInvocationTarget:self] setHyphenationFactor:currentHyphenation];
    [self setHyphenationFactor:(currentHyphenation > 0.0) ? 0.0 : 0.9];	/* Toggle between 0.0 and 0.9 */
}

/* Action method for the "Append '.txt' extension" button
*/
- (void)appendPlainTextExtensionChanged:(id)sender {
    NSSavePanel *panel = (NSSavePanel *)[sender window];
    [panel setAllowsOtherFileTypes:[sender state]];
    [panel setAllowedFileTypes:[sender state] ? [NSArray arrayWithObject:(NSString *)kUTTypePlainText] : nil];
}

- (void)encodingPopupChanged:(NSPopUpButton *)popup {
    [self setEncodingForSaving:[[[popup selectedItem] representedObject] unsignedIntegerValue]];
}

/* Menu validation: Arbitrary numbers to determine the state of the menu items whose titles change. Speeds up the validation... Not zero. */   
#define TagForFirst 42
#define TagForSecond 43

void validateToggleItem(NSMenuItem *aCell, BOOL useFirst, NSString *first, NSString *second) {
    if (useFirst) {
        if ([aCell tag] != TagForFirst) {
            [aCell setTitleWithMnemonic:first];
            [aCell setTag:TagForFirst];
        }
    } else {
        if ([aCell tag] != TagForSecond) {
            [aCell setTitleWithMnemonic:second];
            [aCell setTag:TagForSecond];
        }
    }
}

/* Menu validation
*/
- (BOOL)validateMenuItem:(NSMenuItem *)aCell {
    SEL action = [aCell action];
    
    if (action == @selector(toggleReadOnly:)) {
	validateToggleItem(aCell, [self isReadOnly], NSLocalizedString(@"Allow Editing", @"Menu item to make the current document editable (not read-only)"), NSLocalizedString(@"Prevent Editing", @"Menu item to make the current document read-only"));
    } else if (action == @selector(togglePageBreaks:)) {
        validateToggleItem(aCell, [self hasMultiplePages], NSLocalizedString(@"&Wrap to Window", @"Menu item to cause text to be laid out to size of the window"), NSLocalizedString(@"&Wrap to Page", @"Menu item to cause text to be laid out to the size of the currently selected page type"));
    } else if (action == @selector(toggleHyphenation:)) {
        validateToggleItem(aCell, ([self hyphenationFactor] > 0.0), NSLocalizedString(@"Do not Allow Hyphenation", @"Menu item to disallow hyphenation in the document"), NSLocalizedString(@"Allow Hyphenation", @"Menu item to allow hyphenation in the document"));
        if ([self isReadOnly]) return NO;
    }
    
    return YES;
}

// For scripting. We already have a -textStorage method implemented above.
- (void)setTextStorage:(id)ts {
    // Warning, undo support can eat a lot of memory if a long text is changed frequently
    NSAttributedString *textStorageCopy = [[self textStorage] copy];
    [[self undoManager] registerUndoWithTarget:self selector:@selector(setTextStorage:) object:textStorageCopy];
    [textStorageCopy release];

    // ts can actually be a string or an attributed string.
    if ([ts isKindOfClass:[NSAttributedString class]]) {
        [[self textStorage] replaceCharactersInRange:NSMakeRange(0, [[self textStorage] length]) withAttributedString:ts];
    } else {
        [[self textStorage] replaceCharactersInRange:NSMakeRange(0, [[self textStorage] length]) withString:ts];
    }
}

- (IBAction)revertDocumentToSaved:(id)sender {
    // This is necessary, because document reverting doesn't happen within NSDocument if the fileURL is nil.
    // However, this is only a temporary workaround because it would be better if fileURL was never set to nil.
    if( [self fileURL] == nil && defaultDestination != nil ) {
        [self setFileURL: defaultDestination];
    }
    [super revertDocumentToSaved:sender];
}

- (BOOL)revertToContentsOfURL:(NSURL *)url ofType:(NSString *)type error:(NSError **)outError {
    // See the comment in the above override of -revertDocumentToSaved:.
    BOOL success = [super revertToContentsOfURL:url ofType:type error:outError];
    if (success) {
        [defaultDestination release];
        defaultDestination = nil;
        [self setHasMultiplePages:hasMultiplePages];
        [[self windowControllers] makeObjectsPerformSelector:@selector(setupTextViewForDocument)];
        [[self undoManager] removeAllActions];
    } else {
        // The document failed to revert correctly, or the user decided to cancel the revert.
        // This just restores the file URL to how it was before the sheet was displayed.
        [self setFileURL:nil];
    }
    return success;
}

/* Target/action method for saving as (actually "saving to") PDF. Note that this approach of omitting the path will not work on Leopard; see TextEdit's README.rtf
*/
- (IBAction)saveDocumentAsPDFTo:(id)sender {
    [self printDocumentWithSettings:[NSDictionary dictionaryWithObjectsAndKeys:NSPrintSaveJob, NSPrintJobDisposition, nil] showPrintPanel:NO delegate:nil didPrintSelector:NULL contextInfo:NULL];
}

@end


/* Returns the default padding on the left/right edges of text views
*/
CGFloat defaultTextPadding(void) {
    static CGFloat padding = -1;
    if (padding < 0.0) {
        NSTextContainer *container = [[NSTextContainer alloc] init];
        padding = [container lineFragmentPadding];
        [container release];
    }
    return padding;
}

@implementation Document (TextEditNSDocumentOverrides)

+ (BOOL)canConcurrentlyReadDocumentsOfType:(NSString *)typeName {
    NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
    return !([workspace type:typeName conformsToType:(NSString *)kUTTypeHTML] || [workspace type:typeName conformsToType:(NSString *)kUTTypeWebArchive]);
}

- (id)initForURL:(NSURL *)absoluteDocumentURL withContentsOfURL:(NSURL *)absoluteDocumentContentsURL ofType:(NSString *)typeName error:(NSError **)outError {
    // This is the method that NSDocumentController invokes during reopening of an autosaved document after a crash. The passed-in type name might be NSRTFDPboardType, but absoluteDocumentURL might point to an RTF document, and if we did nothing this document's fileURL and fileType might not agree, which would cause trouble the next time the user saved this document. absoluteDocumentURL might also be nil, if the document being reopened has never been saved before. It's an oddity of NSDocument that if you override -autosavingFileType you probably have to override this method too.
    if (absoluteDocumentURL) {
	NSString *realTypeName = [[NSDocumentController sharedDocumentController] typeForContentsOfURL:absoluteDocumentURL error:outError];
	if (realTypeName) {
	    self = [super initForURL:absoluteDocumentURL withContentsOfURL:absoluteDocumentContentsURL ofType:typeName error:outError];
	    [self setFileType:realTypeName];
	} else {
	    [self release];
	    self = nil;
	}
    } else {
	self = [super initForURL:absoluteDocumentURL withContentsOfURL:absoluteDocumentContentsURL ofType:typeName error:outError];
    }
    return self;
}

- (void)makeWindowControllers {
    NSArray *myControllers = [self windowControllers];
    
    /* If this document displaced a transient document, it will already have been assigned a window controller. If that is not the case, create one. */
    if ([myControllers count] == 0) {
        [self addWindowController:[[[DocumentWindowController allocWithZone:[self zone]] init] autorelease]];
    }
}

- (NSArray *)writableTypesForSaveOperation:(NSSaveOperationType)saveOperation {
    NSMutableArray *outArray = [[[[self class] writableTypes] mutableCopy] autorelease];
    if (saveOperation == NSSaveAsOperation) {
	/* Rich-text documents cannot be saved as plain text. */
	if ([self isRichText]) {
	    [outArray removeObject:(NSString *)kUTTypePlainText];
	}
	
	/* Documents that contain attacments can only be saved in formats that support embedded graphics. */
	if ([textStorage containsAttachments]) {
	    [outArray setArray:[NSArray arrayWithObjects:(NSString *)kUTTypeRTFD, (NSString *)kUTTypeWebArchive, nil]];
	}
    }
    return outArray;
}

/* Whether to keep the backup file
*/
- (BOOL)keepBackupFile {
    return ![[NSUserDefaults standardUserDefaults] boolForKey:DeleteBackup];
}

/* When a document is changed, it ceases to be transient. 
*/
- (void)updateChangeCount:(NSDocumentChangeType)change {
    [self setTransient:NO];
    [super updateChangeCount:change];
}

/* When we save, we send a notification so that views that are currently coalescing undo actions can break that. This is done for two reasons, one technical and the other HI oriented. 

Firstly, since the dirty state tracking is based on undo, for a coalesced set of changes that span over a save operation, the changes that occur between the save and the next time the undo coalescing stops will not mark the document as dirty. Secondly, allowing the user to undo back to the precise point of a save is good UI. 

In addition we overwrite this method as a way to tell that the document has been saved successfully. If so, we set the save time parameters in the document.
*/
- (BOOL)saveToURL:(NSURL *)absoluteURL ofType:(NSString *)typeName forSaveOperation:(NSSaveOperationType)saveOperation error:(NSError **)outError {
    // Note that we do the breakUndoCoalescing call even during autosave, which means the user's undo of long typing will take them back to the last spot an autosave occured. This might seem confusing, and a more elaborate solution may be possible (cause an autosave without having to breakUndoCoalescing), but since this change is coming late in Leopard, we decided to go with the lower risk fix.
    [[self windowControllers] makeObjectsPerformSelector:@selector(breakUndoCoalescing)];

    BOOL success = [super saveToURL:absoluteURL ofType:typeName forSaveOperation:saveOperation error:outError];
    if (success && (saveOperation == NSSaveOperation || (saveOperation == NSSaveAsOperation))) {    // If successful, set document parameters changed during the save operation
	if ([self encodingForSaving] != NoStringEncoding) [self setEncoding:[self encodingForSaving]];
    }
    [self setEncodingForSaving:NoStringEncoding];   // This is set during prepareSavePanel:, but should be cleared for future save operation without save panel
    return success;    
}

/* Since a document into which the user has dragged graphics should autosave as RTFD, we override this method to return RTFD, unless the document was already RTFD, WebArchive, or plain (the last one done for optimization, to avoid calling containsAttachments).
*/
- (NSString *)autosavingFileType {
    NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
    NSString *type = [super autosavingFileType];
    if ([workspace type:type conformsToType:(NSString *)kUTTypeRTFD] || [workspace type:type conformsToType:(NSString *)kUTTypeWebArchive] || [workspace type:type conformsToType:(NSString *)kUTTypePlainText]) return type;
    if ([textStorage containsAttachments]) return (NSString *)kUTTypeRTFD;
    return type;
}


/* When the file URL is set to nil, we store away the old URL. This happens when a document is converted to and from rich text. If the document exists on disk, we default to use the same base file when subsequently saving the document. 
*/
- (void)setFileURL:(NSURL *)url {
    NSURL *previousURL = [self fileURL];
    if (!url && previousURL) {
	[defaultDestination release];
	defaultDestination = [previousURL copy];
    }
    [super setFileURL:url];
}

- (void)didPresentErrorWithRecovery:(BOOL)didRecover contextInfo:(void *)contextInfo {
    if (didRecover) {
	[self performSelector:@selector(saveDocument:) withObject:self afterDelay:0.0];
    }
}

- (void)attemptRecoveryFromError:(NSError *)error optionIndex:(NSUInteger)recoveryOptionIndex delegate:(id)delegate didRecoverSelector:(SEL)didRecoverSelector contextInfo:(void *)contextInfo {
    BOOL saveAgain = NO;
    if ([[error domain] isEqualToString:TextEditErrorDomain]) {
	switch ([error code]) {
	    case TextEditSaveErrorConvertedDocument:
		if (recoveryOptionIndex == 0) { // Save with new name
		    [self setFileType:(NSString *)([textStorage containsAttachments] ? kUTTypeRTFD : kUTTypeRTF)];
		    [self setFileURL:nil];
		    [self setConverted:NO];
		    saveAgain = YES;
		} 
		break;
	    case TextEditSaveErrorLossyDocument:
		if (recoveryOptionIndex == 0) { // Save with new name
		    [self setFileURL:nil];
		    [self setLossy:NO];
		    saveAgain = YES;
		} else if (recoveryOptionIndex == 1) { // Overwrite
		    [self setLossy:NO];
		    saveAgain = YES;
		} 
		break;
	    case TextEditSaveErrorRTFDRequired:
		if (recoveryOptionIndex == 0) { // Save with new name; enable the user to choose a new name to save with
		    [self setFileType:(NSString *)kUTTypeRTFD];
		    [self setFileURL:nil];
		    saveAgain = YES;
		} else if (recoveryOptionIndex == 1) { // Save as RTFD with the same name
		    NSString *oldFilename = [[self fileURL] path];
		    NSError *newError;
		    if (![self saveToURL:[NSURL fileURLWithPath:[[oldFilename stringByDeletingPathExtension] stringByAppendingPathExtension:@"rtfd"]] ofType:(NSString *)kUTTypeRTFD forSaveOperation:NSSaveAsOperation error:&newError]) {
			// If attempt to save as RTFD fails, let the user know
			[self presentError:newError modalForWindow:[self windowForSheet] delegate:nil didPresentSelector:NULL contextInfo:contextInfo];
		    } else {
			// The RTFD is saved; we ignore error from trying to delete the RTF file
			(void)[[NSFileManager defaultManager] removeItemAtPath:oldFilename error:NULL];
		    }
		    saveAgain = NO;
		} 
		break;
	    case TextEditSaveErrorEncodingInapplicable:
		[self setEncodingForSaving:NoStringEncoding];
		[self setFileURL:nil];
		saveAgain = YES;
		break;
	}
    }

    [delegate didPresentErrorWithRecovery:saveAgain contextInfo:contextInfo];
}

- (void)saveDocumentWithDelegate:(id)delegate didSaveSelector:(SEL)didSaveSelector contextInfo:(void *)contextInfo {
    NSString *currType = [self fileType];
    NSError *error = nil;
    BOOL containsAttachments = [textStorage containsAttachments];
    
    if ([self fileURL]) {
	if ([self isConverted]) {
	    NSString *newFormatName = containsAttachments ? NSLocalizedString(@"rich text with graphics (RTFD)", @"Rich text with graphics file format name, displayed in alert") 
							  : NSLocalizedString(@"rich text", @"Rich text file format name, displayed in alert");
	    error = [NSError errorWithDomain:TextEditErrorDomain code:TextEditSaveErrorConvertedDocument userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
		NSLocalizedString(@"Please supply a new name.", @"Title of alert panel which brings up a warning while saving, asking for new name"), NSLocalizedDescriptionKey,
		[NSString stringWithFormat:NSLocalizedString(@"This document was converted from a format that TextEdit cannot save. It will be saved in %@ format with a new name.", @"Contents of alert panel informing user that they need to supply a new file name because the file needs to be saved using a different format than originally read in"), newFormatName], NSLocalizedRecoverySuggestionErrorKey, 
		[NSArray arrayWithObjects:NSLocalizedString(@"Save with new name", @"Button choice allowing user to choose a new name"), NSLocalizedString(@"Cancel", @"Button choice allowing user to cancel."), nil], NSLocalizedRecoveryOptionsErrorKey,
		self, NSRecoveryAttempterErrorKey,
		nil]];
	} else if ([self isLossy]) {
	    error = [NSError errorWithDomain:TextEditErrorDomain code:TextEditSaveErrorLossyDocument userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
		NSLocalizedString(@"Are you sure you want to overwrite the document?", @"Title of alert panel which brings up a warning about saving over the same document"), NSLocalizedDescriptionKey,
		NSLocalizedString(@"Overwriting this document might cause you to lose some of the original formatting.  Would you like to save the document using a new name?", @"Contents of alert panel informing user that they need to supply a new file name because the save might be lossy"), NSLocalizedRecoverySuggestionErrorKey,
		[NSArray arrayWithObjects:NSLocalizedString(@"Save with new name", @"Button choice allowing user to choose a new name"), NSLocalizedString(@"Overwrite", @"Button choice allowing user to overwrite the document."), NSLocalizedString(@"Cancel", @"Button choice allowing user to cancel."), nil], NSLocalizedRecoveryOptionsErrorKey,
		self, NSRecoveryAttempterErrorKey,
		nil]];
	} else if (containsAttachments && ![[self writableTypesForSaveOperation:NSSaveAsOperation] containsObject:currType]) {
	    error = [NSError errorWithDomain:TextEditErrorDomain code:TextEditSaveErrorRTFDRequired userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
		NSLocalizedString(@"Are you sure you want to save using RTFD format?", @"Title of alert panel which brings up a warning while saving"), NSLocalizedDescriptionKey,
		NSLocalizedString(@"This document contains graphics and will be saved using RTFD (RTF with graphics) format. RTFD documents are not compatible with some applications. Save anyway?", @"Contents of alert panel informing user that the document is being converted from RTF to RTFD, and allowing them to cancel, save anyway, or save with new name"), NSLocalizedRecoverySuggestionErrorKey,
		[NSArray arrayWithObjects:NSLocalizedString(@"Save with new name", @"Button choice allowing user to choose a new name"), NSLocalizedString(@"Save", @"Button choice which allows the user to save the document."), NSLocalizedString(@"Cancel", @"Button choice allowing user to cancel."), nil], NSLocalizedRecoveryOptionsErrorKey,
		self, NSRecoveryAttempterErrorKey,
		nil]];
	} else if (![self isRichText]) {
	    NSUInteger enc = [self encodingForSaving];
	    if (enc == NoStringEncoding) enc = [self encoding];
	    if (![[textStorage string] canBeConvertedToEncoding:enc]) {
		error = [NSError errorWithDomain:TextEditErrorDomain code:TextEditSaveErrorEncodingInapplicable userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
		    [NSString stringWithFormat:NSLocalizedString(@"This document can no longer be saved using its original %@ encoding.", @"Title of alert panel informing user that the file's string encoding needs to be changed."), [NSString localizedNameOfStringEncoding:enc]], NSLocalizedDescriptionKey,
		    NSLocalizedString(@"Please choose another encoding (such as UTF-8).", @"Subtitle of alert panel informing user that the file's string encoding needs to be changed"), NSLocalizedRecoverySuggestionErrorKey,
		    self, NSRecoveryAttempterErrorKey,
		    nil]];
	    }
	}
    }
    
    if (error) {
	[self presentError:error modalForWindow:[self windowForSheet] delegate:self didPresentSelector:@selector(didPresentErrorWithRecovery:contextInfo:) contextInfo:NULL];
    } else {
	[super saveDocumentWithDelegate:delegate didSaveSelector:didSaveSelector contextInfo:contextInfo];
    }
}

/* For plain-text documents, we add our own accessory view for selecting encodings. The plain text case does not require a format popup. 
*/
- (BOOL)shouldRunSavePanelWithAccessoryView {
    return [self isRichText];
}

/* If the document is a converted version of a document that existed on disk, set the default directory to the directory in which the source file (converted file) resided at the time the document was converted. If the document is plain text, we additionally add an encoding popup. 
*/
- (BOOL)prepareSavePanel:(NSSavePanel *)savePanel {
    NSPopUpButton *encodingPopup;
    NSButton *extCheckbox;
    NSUInteger cnt;
    NSString *string;
    
    if (defaultDestination) {
	NSString *dirPath = [[defaultDestination path] stringByDeletingPathExtension];
	BOOL isDir;
	if ([[NSFileManager defaultManager] fileExistsAtPath:dirPath isDirectory:&isDir] && isDir) {
	    [savePanel setDirectory:dirPath];
	}
    }
    
    if (![self isRichText]) {
	BOOL addExt = [[NSUserDefaults standardUserDefaults] boolForKey:AddExtensionToNewPlainTextFiles];
	// If no encoding, figure out which encoding should be default in encoding popup, set as document encoding.
	NSStringEncoding enc = [self encoding];
	[self setEncodingForSaving:(enc == NoStringEncoding) ? [self suggestedDocumentEncoding] : enc];
	[savePanel setAccessoryView:[[[NSDocumentController sharedDocumentController] class] encodingAccessory:[self encodingForSaving] includeDefaultEntry:NO encodingPopUp:&encodingPopup checkBox:&extCheckbox]];
	
	// Set up the checkbox
	[extCheckbox setTitle:NSLocalizedString(@"If no extension is provided, use \\U201c.txt\\U201d.", @"Checkbox indicating that if the user does not specify an extension when saving a plain text file, .txt will be used")];
	[extCheckbox setToolTip:NSLocalizedString(@"Automatically append \\U201c.txt\\U201d to the file name if no known file name extension is provided.", @"Tooltip for checkbox indicating that if the user does not specify an extension when saving a plain text file, .txt will be used")];
	[extCheckbox setState:addExt];
	[extCheckbox setAction:@selector(appendPlainTextExtensionChanged:)];
	[extCheckbox setTarget:self];
	if (addExt) {
	    [savePanel setAllowedFileTypes:[NSArray arrayWithObject:(NSString *)kUTTypePlainText]];
	    [savePanel setAllowsOtherFileTypes:YES];
	} else {
            // NSDocument defaults to setting the allowedFileType to kUTTypePlainText, which gives the fileName a ".txt" extension. We want don't want to append the extension for Untitled documents.
            // First we clear out the allowedFileType that NSDocument set. We want to allow anything, so we pass 'nil'. This will prevent NSSavePanel from appending an extension.
            [savePanel setAllowedFileTypes:nil];
            // If this document was previously saved, use the URL's name.
            NSString *fileName;
            BOOL gotFileName = [[self fileURL] getResourceValue:&fileName forKey:NSURLNameKey error:nil];
            // If the document has not yet been seaved, or we couldn't find the fileName, then use the displayName. 
            if (!gotFileName || fileName == nil) {
                fileName = [self displayName];
            }
            [savePanel setNameFieldStringValue:fileName];
        }
	
	// Further set up the encoding popup
	cnt = [encodingPopup numberOfItems];
	string = [textStorage string];
	if (cnt * [string length] < 5000000) {	// Otherwise it's just too slow; would be nice to make this more dynamic. With large docs and many encodings, the items just won't be validated.
	    while (cnt--) {	// No reason go backwards except to use one variable instead of two
                NSStringEncoding encoding = (NSStringEncoding)[[[encodingPopup itemAtIndex:cnt] representedObject] unsignedIntegerValue];
		// Hardwire some encodings known to allow any content
		if ((encoding != NoStringEncoding) && (encoding != NSUnicodeStringEncoding) && (encoding != NSUTF8StringEncoding) && (encoding != NSNonLossyASCIIStringEncoding) && ![string canBeConvertedToEncoding:encoding]) {
		    [[encodingPopup itemAtIndex:cnt] setEnabled:NO];
		}
	    }
	}
	[encodingPopup setAction:@selector(encodingPopupChanged:)];
	[encodingPopup setTarget:self];
    }
    
    return YES;
}

/* If the document does not exist on disk, but it has been converted from a document that existed on disk, return the base file name without the path extension. Otherwise return the default ("Untitled"). This is used for the window title and for the default name when saving. 
*/
- (NSString *)displayName {
    if (![self fileURL] && defaultDestination) {
	return [[[NSFileManager defaultManager] displayNameAtPath:[defaultDestination path]] stringByDeletingPathExtension];
    } else {
	return [super displayName];
    }
}

@end


/* Truncate string to no longer than truncationLength; should be > 10
*/
NSString *truncatedString(NSString *str, NSUInteger truncationLength) {
    NSUInteger len = [str length];
    if (len < truncationLength) return str;
    return [[str substringToIndex:truncationLength - 10] stringByAppendingString:@"\u2026"];	// Unicode character 2026 is ellipsis
}


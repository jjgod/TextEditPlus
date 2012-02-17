/*
     File: MultiplePageView.m
 Abstract: View which holds all the pages together in the multiple-page case.
  Version: 1.7.1
 
 Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple
 Inc. ("Apple") in consideration of your agreement to the following
 terms, and your use, installation, modification or redistribution of
 this Apple software constitutes acceptance of these terms.  If you do
 not agree with these terms, please do not use, install, modify or
 redistribute this Apple software.
 
 In consideration of your agreement to abide by the following terms, and
 subject to these terms, Apple grants you a personal, non-exclusive
 license, under Apple's copyrights in this original Apple software (the
 "Apple Software"), to use, reproduce, modify and redistribute the Apple
 Software, with or without modifications, in source and/or binary forms;
 provided that if you redistribute the Apple Software in its entirety and
 without modifications, you must retain this notice and the following
 text and disclaimers in all such redistributions of the Apple Software.
 Neither the name, trademarks, service marks or logos of Apple Inc. may
 be used to endorse or promote products derived from the Apple Software
 without specific prior written permission from Apple.  Except as
 expressly stated in this notice, no other rights or licenses, express or
 implied, are granted by Apple herein, including but not limited to any
 patent rights that may be infringed by your derivative works or by other
 works in which the Apple Software may be incorporated.
 
 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
 MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
 THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
 FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
 OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.
 
 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
 OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
 MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
 AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
 STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.
 
 Copyright (C) 2012 Apple Inc. All Rights Reserved.
 
 */

#import <Cocoa/Cocoa.h>
#import "MultiplePageView.h"
#import "TextEditMisc.h"

@implementation MultiplePageView

- (id)initWithFrame:(NSRect)rect {
    if ((self = [super initWithFrame:rect])) {
        numPages = 0;
        [self setLineColor:[NSColor lightGrayColor]];
        [self setMarginColor:[NSColor whiteColor]];
	/* This will set the frame to be whatever's appropriate... */
        [self setPrintInfo:[NSPrintInfo sharedPrintInfo]];
    }
    return self;
}

- (BOOL)isFlipped {
    return YES;
}

- (BOOL)isOpaque {
    return YES;
}

- (void)updateFrame {
    if ([self superview]) {
        NSRect rect = NSZeroRect;
        rect.size = [printInfo paperSize];
        if (NSTextLayoutOrientationHorizontal == layoutOrientation) {
            rect.size.height = rect.size.height * numPages;
            if (numPages > 1) rect.size.height += [self pageSeparatorHeight] * (numPages - 1);
        } else {
            rect.size.width = rect.size.width * numPages;
            if (numPages > 1) rect.size.width += [self pageSeparatorHeight] * (numPages - 1);
        }
        rect.size = [self convertSize:rect.size toView:[self superview]];
        [self setFrame:rect];
    }
}

- (void)setPrintInfo:(NSPrintInfo *)anObject {
    if (printInfo != anObject) {
        [printInfo autorelease];
        printInfo = [anObject copyWithZone:[self zone]];
        [self updateFrame];
        [self setNeedsDisplay:YES];	/* Because the page size or margins might change (could optimize this) */
    }
}

- (NSPrintInfo *)printInfo {
    return printInfo;
}

- (void)setNumberOfPages:(NSUInteger)num {
    if (numPages != num) {
	NSRect oldFrame = [self frame];
        NSRect newFrame;
        numPages = num;
        [self updateFrame];
	newFrame = [self frame];
        if (newFrame.size.height > oldFrame.size.height) {
	    [self setNeedsDisplayInRect:NSMakeRect(oldFrame.origin.x, NSMaxY(oldFrame), oldFrame.size.width, NSMaxY(newFrame) - NSMaxY(oldFrame))];
        }
    }
}

- (NSUInteger)numberOfPages {
    return numPages;
}
    
- (CGFloat)pageSeparatorHeight {
    return 5.0;
}

- (void)dealloc {
    [printInfo release];
    [super dealloc];
}

- (NSSize)documentSizeInPage {
    return documentSizeForPrintInfo(printInfo);
}

- (NSRect)documentRectForPageNumber:(NSUInteger)pageNumber {	/* First page is page 0, of course! */
    NSRect rect = [self pageRectForPageNumber:pageNumber];
    rect.origin.x += [printInfo leftMargin] - defaultTextPadding();
    rect.origin.y += [printInfo topMargin];
    rect.size = [self documentSizeInPage];
    return rect;
}

- (NSRect)pageRectForPageNumber:(NSUInteger)pageNumber {
    NSRect rect;
    rect.size = [printInfo paperSize];
    rect.origin = [self frame].origin;

    if (NSTextLayoutOrientationHorizontal == layoutOrientation) {
        rect.origin.y += ((rect.size.height + [self pageSeparatorHeight]) * pageNumber);
    } else {
        rect.origin.x += (NSWidth([self bounds]) - ((rect.size.width + [self pageSeparatorHeight]) * (pageNumber + 1)));
    }
    return rect;
}

- (void)setLineColor:(NSColor *)color {
    if (color != lineColor) {
        [lineColor autorelease];
        lineColor = [color copyWithZone:[self zone]];
        [self setNeedsDisplay:YES];
    }
}

- (NSColor *)lineColor {
    return lineColor;
}

- (void)setMarginColor:(NSColor *)color {
    if (color != marginColor) {
        [marginColor autorelease];
        marginColor = [color copyWithZone:[self zone]];
        [self setNeedsDisplay:YES];
    }
}

- (NSColor *)marginColor {
    return marginColor;
}

- (void)setLayoutOrientation:(NSTextLayoutOrientation)orientation {
    if (orientation != layoutOrientation) {
        layoutOrientation = orientation;

        [self updateFrame];
    }
}

- (NSTextLayoutOrientation)layoutOrientation {
    return layoutOrientation;
}

- (void)drawRect:(NSRect)rect {
    if ([[NSGraphicsContext currentContext] isDrawingToScreen]) {
        NSSize paperSize = [printInfo paperSize];
        NSUInteger firstPage;
        NSUInteger lastPage;
        NSUInteger cnt;

        if (NSTextLayoutOrientationHorizontal == layoutOrientation) {
            firstPage = NSMinY(rect) / (paperSize.height + [self pageSeparatorHeight]);
            lastPage = NSMaxY(rect) / (paperSize.height + [self pageSeparatorHeight]);
        } else {
            firstPage = numPages - (NSMaxX(rect) / (paperSize.width + [self pageSeparatorHeight]));
            lastPage = numPages - (NSMinX(rect) / (paperSize.width + [self pageSeparatorHeight]));
        }

        [marginColor set];
        NSRectFill(rect);

        [lineColor set];
        for (cnt = firstPage; cnt <= lastPage; cnt++) {
	    // Draw boundary around the page, making sure it doesn't overlap the document area in terms of pixels
	    NSRect docRect = NSInsetRect([self centerScanRect:[self documentRectForPageNumber:cnt]], -1.0, -1.0);
	    NSFrameRectWithWidth(docRect, 1.0);
        }

        if ([[self superview] isKindOfClass:[NSClipView class]]) {
	    NSColor *backgroundColor = [(NSClipView *)[self superview] backgroundColor];
            [backgroundColor set];
            for (cnt = firstPage; cnt <= lastPage; cnt++) {
		NSRect pageRect = [self pageRectForPageNumber:cnt];
                NSRect separatorRect;
                if (NSTextLayoutOrientationHorizontal == layoutOrientation) {
                    separatorRect = NSMakeRect(NSMinX(pageRect), NSMaxY(pageRect), NSWidth(pageRect), [self pageSeparatorHeight]);
                } else {
                    separatorRect = NSMakeRect(NSMaxX(pageRect), NSMinY(pageRect), [self pageSeparatorHeight], NSHeight(pageRect));
                }
		NSRectFill (separatorRect);
            }
        }
    }
}

/**** Printing support... ****/

- (BOOL)knowsPageRange:(NSRangePointer)aRange {
    aRange->length = [self numberOfPages];
    return YES;
}

- (NSRect)rectForPage:(NSInteger)page {
    return [self documentRectForPageNumber:page-1];  /* Our page numbers start from 0; the kit's from 1 */
}

/* This method makes sure that we center the view on the page. By default, the text view "bleeds" into the margins by defaultTextPadding() as a way to provide padding around the editing area. If we don't do anything special, the text view appears at the margin, which causes the text to be offset on the page by defaultTextPadding(). This method makes sure the text is centered.
*/
- (NSPoint)locationOfPrintRect:(NSRect)rect {
    NSSize paperSize = [printInfo paperSize];
    return NSMakePoint((paperSize.width - rect.size.width) / 2.0, (paperSize.height - rect.size.height) / 2.0);
}

- (BOOL)showsScalePopUpButton { return YES; }

@end


NSSize documentSizeForPrintInfo(NSPrintInfo *printInfo) {
    NSSize paperSize = [printInfo paperSize];
    paperSize.width -= ([printInfo leftMargin] + [printInfo rightMargin]) - defaultTextPadding() * 2.0;
    paperSize.height -= ([printInfo topMargin] + [printInfo bottomMargin]);
    return paperSize;
}


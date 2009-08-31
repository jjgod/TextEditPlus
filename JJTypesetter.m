//
//  JJTypesetter.m
//  TextEdit
//
//  Created by Jjgod Jiang on 8/31/09.
//

#import "JJTypesetter.h"

@implementation JJTypesetter

@synthesize enabled=_isEnabled;

- (void) fontDidChange: (NSFont *) font
{
	if (! _isEnabled)
		return;

	NSLayoutManager *lm = [self layoutManager];
	
	_lineHeight = [lm defaultLineHeightForFont: font];
	_baselineOffset = [lm defaultBaselineOffsetForFont: font];
}

- (void) willSetLineFragmentRect:(NSRectPointer)lineRect
                   forGlyphRange:(NSRange)glyphRange
                        usedRect:(NSRectPointer)usedRect
                  baselineOffset:(CGFloat *)baselineOffset
{
	if (! _isEnabled)
		return;

	if (! _lineHeight)
	{
		NSFont *font = [NSFont userFixedPitchFontOfSize:0.0];
		[self fontDidChange: font];
	}

	lineRect->size.height = _lineHeight;
	usedRect->size.height = _lineHeight;
	*baselineOffset = _baselineOffset;
}

@end

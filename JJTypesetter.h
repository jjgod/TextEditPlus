//
//  JJTypesetter.h
//  TextEdit
//
//  Created by Jjgod Jiang on 8/31/09.
//

#import <Cocoa/Cocoa.h>


@interface JJTypesetter : NSATSTypesetter {
	CGFloat _lineHeight;
	CGFloat _baselineOffset;
	BOOL _isEnabled;
}

@property BOOL enabled;

@end

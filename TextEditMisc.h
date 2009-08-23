/* Returns the default padding on the left/right edges of text views */
CGFloat defaultTextPadding(void);

/* Helper used in toggling menu items in validate methods, based on a condition (useFirst) */
void validateToggleItem(NSMenuItem *menuItem, BOOL useFirst, NSString *first, NSString *second);

/* Truncate string to no longer than truncationLength; should be > 10 */
NSString *truncatedString(NSString *str, NSUInteger truncationLength);



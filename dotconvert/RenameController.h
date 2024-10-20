#import <Foundation/Foundation.h>

@interface RenameController : NSObject

- (void)processEventWithPath:(NSString *)path eventId:(uint64_t)eventId fileId:(uint64_t)fileId;
- (void)performRenameActionWithFileId:(uint64_t)fileId oldPath:(NSString *)oldPath currentPath:(NSString *)currentPath;

@end

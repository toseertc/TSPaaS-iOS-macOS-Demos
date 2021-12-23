//
//  TSMView.h
//  macOSDemo
//
//  Created by yxibng on 2020/11/22.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN
IB_DESIGNABLE

@interface TSMView : NSView
@property (nonatomic, strong) IBInspectable NSColor *backgroundColor;
@property (nonatomic, assign) BOOL disableEvents;

/*
 是否是遮罩view
 遮罩拦截事件向下传递
 */
@property (nonatomic, assign) BOOL isMaskView;

@end

NS_ASSUME_NONNULL_END

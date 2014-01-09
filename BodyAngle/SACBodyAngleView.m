//
//  SACBodyAngleView.m
//  BodyAngle
//
//  Created by Michael Harper on 1/8/14.
//  Copyright (c) 2014 Standalone Code LLC. All rights reserved.
//

#import "SACBodyAngleView.h"

@interface SACBodyAngleView ()

@property (nonatomic) float bodyAngle;

@end

@implementation SACBodyAngleView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
    }
    return self;
}

- (void)drawRect:(CGRect)rect
{
  // For now, just draw a thick line displaying the current angle.
  CGFloat midY = CGRectGetMidY(self.bounds);
  self.transform = CGAffineTransformMakeRotation(self.bodyAngle);
  CGContextRef context = UIGraphicsGetCurrentContext();
  CGContextSaveGState(context);
  CGContextSetLineCap(context, kCGLineCapSquare);
  CGContextSetStrokeColorWithColor(context, [UIColor blackColor].CGColor);
  CGFloat lineWidth = 8.0;
  CGContextSetLineWidth(context, lineWidth);
  CGPoint startPoint = {.x = 0, .y = midY};
  CGPoint endPoint = {.x = CGRectGetMaxX(rect), .y = startPoint.y};
  CGContextMoveToPoint(context, startPoint.x + lineWidth/2, startPoint.y + lineWidth/2);
  CGContextAddLineToPoint(context, endPoint.x + lineWidth/2, endPoint.y + lineWidth/2);
  CGContextStrokePath(context);
  CGContextRestoreGState(context);
}

-(void) addBodyAngle:(float) angleInRadians
{
  self.bodyAngle = angleInRadians;
  [self setNeedsDisplay];
}

@end

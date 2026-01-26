#ifndef __FVG_TYPES_MQH__
#define __FVG_TYPES_MQH__

enum FVG_DIRECTION
{
   FVG_NONE    = 0,
   FVG_BULLISH = 1,
   FVG_BEARISH = -1
};

struct FvgBarData
{
   double rightBarHigh;
   double rightBarLow;
   double rightBarOpen;
   double rightBarClose;
   double midBarHigh;
   double midBarLow;
   double midBarOpen;
   double midBarClose;
   double leftBarHigh;
   double leftBarLow;
   double leftBarOpen;
   double leftBarClose;
};

struct FvgDetectionResult
{
   bool hasNewFvg;
   FVG_DIRECTION direction;
   FvgBarData barData;
   double zoneLow;
   double zoneHigh;
};

#endif // __FVG_TYPES_MQH__

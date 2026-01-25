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
   double midBarHigh;
   double midBarLow;
   double leftBarHigh;
   double leftBarLow;
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

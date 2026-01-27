#ifndef __ZIGZAG_DETECTOR_MQH__
#define __ZIGZAG_DETECTOR_MQH__

#include "ZigZagTypes.mqh"

static ZIGZAG_DIRECTION g_lastDirection = ZIGZAG_NONE;
static datetime g_segmentStartTime = 0;
static double g_segmentStartPrice = 0.0;
static int g_segmentStartBarIndex = 0;

bool ZigZagDetector_IsCandleBullish(int barIndex)
{
   double open = iOpen(_Symbol, _Period, barIndex);
   double close = iClose(_Symbol, _Period, barIndex);
   return (close > open);
}

bool ZigZagDetector_IsCandleBearish(int barIndex)
{
   double open = iOpen(_Symbol, _Period, barIndex);
   double close = iClose(_Symbol, _Period, barIndex);
   return (close < open);
}

ZIGZAG_DIRECTION ZigZagDetector_GetCandleDirection(int barIndex)
{
   if(ZigZagDetector_IsCandleBullish(barIndex))
      return ZIGZAG_UP;
   
   if(ZigZagDetector_IsCandleBearish(barIndex))
      return ZIGZAG_DOWN;
   
   return ZIGZAG_NONE;
}

bool ZigZagDetector_DetectNewSegment(int lastClosedBarIndex, ZigZagSegment &segment)
{
   ZIGZAG_DIRECTION currentDirection = ZigZagDetector_GetCandleDirection(lastClosedBarIndex);
   
   // Ignore doji candles
   if(currentDirection == ZIGZAG_NONE)
      return false;
   
   // First candle - initialize
   if(g_lastDirection == ZIGZAG_NONE)
   {
      g_lastDirection = currentDirection;
      g_segmentStartTime = iTime(_Symbol, _Period, lastClosedBarIndex);
      g_segmentStartPrice = iClose(_Symbol, _Period, lastClosedBarIndex);
      g_segmentStartBarIndex = lastClosedBarIndex;
      return false;
   }
   
   // Direction changed - create segment
   if(currentDirection != g_lastDirection)
   {
      segment.startTime = g_segmentStartTime;
      segment.startPrice = g_segmentStartPrice;
      segment.startBarIndex = g_segmentStartBarIndex;
      
      // End point is the close of previous bar (last bar of previous series)
      segment.endTime = iTime(_Symbol, _Period, lastClosedBarIndex + 1);
      segment.endPrice = iClose(_Symbol, _Period, lastClosedBarIndex + 1);
      segment.endBarIndex = lastClosedBarIndex + 1;
      segment.direction = g_lastDirection;
      
      // Update state for new segment
      g_lastDirection = currentDirection;
      g_segmentStartTime = segment.endTime;
      g_segmentStartPrice = segment.endPrice;
      g_segmentStartBarIndex = segment.endBarIndex;
      
      return true;
   }
   
   // Same direction - continue current segment
   return false;
}

void ZigZagDetector_Reset()
{
   g_lastDirection = ZIGZAG_NONE;
   g_segmentStartTime = 0;
   g_segmentStartPrice = 0.0;
   g_segmentStartBarIndex = 0;
}

#endif // __ZIGZAG_DETECTOR_MQH__

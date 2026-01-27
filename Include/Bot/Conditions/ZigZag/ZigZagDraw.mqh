#ifndef __ZIGZAG_DRAW_MQH__
#define __ZIGZAG_DRAW_MQH__

#include "ZigZagTypes.mqh"

// Global offset calculated once per chart update
static double g_zigzagOffset = 0;

void ZigZagDraw_CalculateOffset()
{
   // Find highest price in last 200 bars
   double highestPrice = 0;
   for(int i = 0; i < 200; i++)
   {
      double high = iHigh(_Symbol, _Period, i);
      if(high > highestPrice)
         highestPrice = high;
   }
   
   // Set offset to 0.2% above highest price
   g_zigzagOffset = highestPrice * 0.002;
}

void ZigZagDraw_DrawSegment(const ZigZagSegment &segment)
{
   string objName = "ZZ#" + TimeToString(segment.startTime) 
                    + "#" + TimeToString(segment.endTime);
   
   // Apply the same offset to all segments to keep them connected
   double adjustedStartPrice = segment.startPrice + g_zigzagOffset;
   double adjustedEndPrice = segment.endPrice + g_zigzagOffset;
   
   if(ObjectCreate(0, objName, OBJ_TREND, 0, segment.startTime, adjustedStartPrice, segment.endTime, adjustedEndPrice))
   {
      ObjectSetInteger(0, objName, OBJPROP_COLOR, clrYellow);
      ObjectSetInteger(0, objName, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, objName, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, objName, OBJPROP_RAY_LEFT, false);
      ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, objName, OBJPROP_HIDDEN, false);
      ObjectSetInteger(0, objName, OBJPROP_BACK, false);
   }
}

void ZigZagDraw_DeleteAll()
{
   int total = ObjectsTotal(0, 0, OBJ_TREND);
   
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i, 0, OBJ_TREND);
      
      if(StringFind(name, "ZZ#") == 0)
         ObjectDelete(0, name);
   }
}

#endif // __ZIGZAG_DRAW_MQH__

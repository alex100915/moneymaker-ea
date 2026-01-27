#ifndef __ZIGZAG_DRAW_MQH__
#define __ZIGZAG_DRAW_MQH__

#include "ZigZagTypes.mqh"

void ZigZagDraw_DrawSegment(const ZigZagSegment &segment)
{
   string objName = "ZZ#" + TimeToString(segment.startTime) 
                    + "#" + TimeToString(segment.endTime);
   
   if(ObjectCreate(0, objName, OBJ_TREND, 0, segment.startTime, segment.startPrice, segment.endTime, segment.endPrice))
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

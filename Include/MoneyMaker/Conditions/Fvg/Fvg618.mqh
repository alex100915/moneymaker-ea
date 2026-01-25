#ifndef __FVG618_MQH__
#define __FVG618_MQH__

#include <MoneyMaker/Signals/FVG/FVG.mqh>

bool Fvg618_IsValid618Bar(const FVG_DIRECTION fvgDirection)
{
   const datetime lastClosedBarTime = iTime(_Symbol, _Period, LAST_CLOSED_BAR_INDEX);

   const double high  = iHigh(_Symbol, _Period, LAST_CLOSED_BAR_INDEX);
   const double low   = iLow(_Symbol, _Period, LAST_CLOSED_BAR_INDEX);
   const double close = iClose(_Symbol, _Period, LAST_CLOSED_BAR_INDEX);

   const double range = high - low;

   const double level = fvgDirection == FVG_BULLISH
      ? (low  + 0.618 * range)      // bullish: from low upward
      : (high - 0.618 * range);     // bearish: from high downward

   const bool valid618Bar = fvgDirection == FVG_BULLISH
      ? (close >= level)
      : (close <= level);

   return valid618Bar;
}

bool Fvg618_DrawLabel(FVG_DIRECTION fvgDirection, bool valid618Bar)
{
   const datetime lastClosedBarTime = iTime(_Symbol, _Period, LAST_CLOSED_BAR_INDEX);

   const string objName = "C618#" + TimeToString(lastClosedBarTime);
   
   const double barHigh = iHigh(_Symbol, _Period, LAST_CLOSED_BAR_INDEX);
   const double barLow  = iLow(_Symbol, _Period, LAST_CLOSED_BAR_INDEX);

   // place above/below candle, centered in time
   const datetime midTime = lastClosedBarTime + (datetime)(PeriodSeconds(_Period) / 2);

   const double offset = 25 * _Point;
   const double labelPositionY = fvgDirection == FVG_BULLISH ? (barHigh + offset) : (barLow - offset);

   const string label = valid618Bar ? "0.618 ✓" : "0.618 ✗";
   const color  col  = valid618Bar ? clrLime : clrRed;

   if(!ObjectCreate(0, objName, OBJ_TEXT, 0, midTime, labelPositionY))
      return false;

   ObjectSetString (0, objName, OBJPROP_TEXT, label);
   ObjectSetInteger(0, objName, OBJPROP_COLOR, col);
   ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, 10);
   ObjectSetInteger(0, objName, OBJPROP_ANCHOR, ANCHOR_CENTER);
   ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, objName, OBJPROP_HIDDEN, false);
   ObjectSetInteger(0, objName, OBJPROP_BACK, false);

   return true;
}

#endif // __FVG618_MQH__

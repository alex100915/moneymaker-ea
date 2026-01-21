#ifndef __FVG618LABEL_MQH__
#define __FVG618LABEL_MQH__

#include <MoneyMaker/Signals/FVG/FVG.mqh>

// --- internal state (for de-dup / one label per candle) ---
static datetime g_last618LabeledBarTime = 0;

void Fvg618_Init()
{
   g_last618LabeledBarTime = 0;
}

bool Fvg618Process(const int barIndex, const ENUM_FVG_DIRECTION direction, bool draw)
{
   const datetime barTime = iTime(_Symbol, _Period, barIndex);

   const double high  = iHigh(_Symbol, _Period, barIndex);
   const double low   = iLow(_Symbol, _Period, barIndex);
   const double close = iClose(_Symbol, _Period, barIndex);

   const double range = high - low;

   const double level = direction == FVG_BULLISH
      ? (low  + 0.618 * range)      // bullish: from low upward
      : (high - 0.618 * range);     // bearish: from high downward

   const bool validSignal = direction == FVG_BULLISH
      ? (close >= level)
      : (close <= level);

   if(draw)
      Fvg618_DrawLabel(barIndex, barTime, direction, validSignal);

   return validSignal;
}

// Draw ONLY (no evaluation). Caller decides whether to call this.
bool Fvg618_DrawLabel(int barIndex, datetime barTime, ENUM_FVG_DIRECTION direction, bool validSignal)
{
   // de-dup: one label per candle time
   if(barTime == g_last618LabeledBarTime)
      return true;

   // IMPORTANT: do not start with "FVG" (FVG module deletes "FVG*")
   const string objName = "C618#" + TimeToString(barTime);

   // already exists => treat as drawn
   if(ObjectFind(0, objName) >= 0)
   {
      g_last618LabeledBarTime = barTime;
      return true;
   }
   
   const double high = iHigh(_Symbol, _Period, barIndex);
   const double low  = iLow(_Symbol, _Period, barIndex);
   if(high <= low) return false;

   // place above/below candle, centered in time
   const datetime midTime = barTime + (datetime)(PeriodSeconds(_Period) / 2);

   const double offset = 25 * _Point;
   const double y = direction == FVG_BULLISH ? (high + offset) : (low - offset);

   const string text = validSignal ? "0.618 ✓" : "0.618 ✗";
   const color  col  = validSignal ? clrLime : clrRed;

   if(!ObjectCreate(0, objName, OBJ_TEXT, 0, midTime, y))
      return false;

   ObjectSetString (0, objName, OBJPROP_TEXT, text);
   ObjectSetInteger(0, objName, OBJPROP_COLOR, col);
   ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, 10);
   ObjectSetInteger(0, objName, OBJPROP_ANCHOR, ANCHOR_CENTER);
   ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, objName, OBJPROP_HIDDEN, false);
   ObjectSetInteger(0, objName, OBJPROP_BACK, false);

   g_last618LabeledBarTime = barTime;
   return true;
}

#endif // __FVG618LABEL_MQH__

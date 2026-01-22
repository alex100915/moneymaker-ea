#ifndef __FVG_SYSTEM_MQH__
#define __FVG_SYSTEM_MQH__

#include <MoneyMaker/Signals/FVG/FVG.mqh>
#include <MoneyMaker/Signals/FVG/Fvg618Label.mqh>

// --- active tracking state ---
static bool g_hasActiveFvg = false;
static ENUM_FVG_DIRECTION g_activeDir = FVG_NONE;
static double g_fvgZoneLow = 0.0;
static double g_fvgZoneHigh = 0.0;

// module's own new-bar gate (so EA doesn't need any logic)
static datetime g_systemLastBarTime = 0;

bool FvgSystem_IsNewBar()
{
   datetime t0 = iTime(_Symbol, _Period, 0);
   if(t0 != g_systemLastBarTime)
   {
      g_systemLastBarTime = t0;
      return true;
   }
   return false;
}

void FvgSystem_Init()
{
   FvgInit();
   Fvg618_Init();

   g_hasActiveFvg = false;
   g_activeDir = FVG_NONE;
   g_fvgZoneLow = 0.0;
   g_fvgZoneHigh = 0.0;

   g_systemLastBarTime = 0;
}

// Optional: if you ever want to cleanup rectangles on stop
void FvgSystem_Deinit(bool draw)
{
   // If you want: delete FVG rectangles when EA stops
   // FvgDeinit(draw);
}

// Draw "MITIGATED" label on a specific bar
void FvgSystem_DrawMitigatedLabel(bool draw, int barIndex, ENUM_FVG_DIRECTION dir)
{
   if(!draw) return;
   if(barIndex < 0) return;
   if(dir == FVG_NONE) return;

   datetime barTime = iTime(_Symbol, _Period, barIndex);
   if(barTime == 0) return;

   // IMPORTANT: do not start with "FVG"
   string name = "MIT#" + TimeToString(barTime);

   if(ObjectFind(0, name) >= 0)
      return;

   double high = iHigh(_Symbol, _Period, barIndex);
   double low  = iLow(_Symbol, _Period, barIndex);
   if(high <= low) return;

   datetime midTime = barTime + (datetime)(PeriodSeconds(_Period) / 2);

   double offset = 35 * _Point;
   double y = (dir == FVG_BULLISH) ? (high + offset) : (low - offset);

   // You can change color/text if you want
   string text = "M";
   color  col  = clrRed;

   if(!ObjectCreate(0, name, OBJ_TEXT, 0, midTime, y))
      return;

   ObjectSetString (0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, col);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 10);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_CENTER);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
}

// Main orchestrator (call this on every tick from EA)
void FvgSystem_Process(bool draw)
{
   // Only once per bar
   if(!FvgSystem_IsNewBar())
      return;

   // 1) FVG module: update continuated boxes + detect NEW FVG + draw box (if draw)
   int fvgBarIndex;
   ENUM_FVG_DIRECTION fvgDir;

   bool newFvg = FvgProcess(fvgBarIndex, fvgDir, draw);

   // 2) If NEW FVG formed -> start tracking + compute its zone (same bars 1/2/3 logic)
   if(newFvg && fvgDir != FVG_NONE)
   {
      const int i = 1; // last closed bar used by detector

      double rightHigh = iHigh(_Symbol, _Period, i);
      double rightLow  = iLow(_Symbol, _Period, i);
      double leftHigh  = iHigh(_Symbol, _Period, i+2);
      double leftLow   = iLow(_Symbol, _Period, i+2);

      double zoneA = 0.0;
      double zoneB = 0.0;

      if(fvgDir == FVG_BULLISH)
      {
         // bullish FVG zone: between leftHigh and rightLow
         zoneA = leftHigh;
         zoneB = rightLow;
      }
      else if(fvgDir == FVG_BEARISH)
      {
         // bearish FVG zone: between rightHigh and leftLow
         zoneA = rightHigh;
         zoneB = leftLow;
      }

      g_fvgZoneLow  = MathMin(zoneA, zoneB);
      g_fvgZoneHigh = MathMax(zoneA, zoneB);

      g_activeDir = fvgDir;
      g_hasActiveFvg = true;
   }

   // 3) If active FVG -> evaluate 0.618 each bar (bar 1) until PASS or "mitigated/invalidated"
   if(g_hasActiveFvg && g_activeDir != FVG_NONE)
   {
      // "Stop" rule:
      // - bullish: stop if close is inside zone OR below zone  => close1 <= zoneHigh
      // - bearish: stop if close is inside zone OR above zone  => close1 >= zoneLow
      const double close1 = iClose(_Symbol, _Period, 1);

      bool stopByMitigationOrInvalidation = false;

      if(g_activeDir == FVG_BULLISH)
      {
         stopByMitigationOrInvalidation = (close1 <= g_fvgZoneHigh);
      }
      else if(g_activeDir == FVG_BEARISH)
      {
         stopByMitigationOrInvalidation = (close1 >= g_fvgZoneLow);
      }

      if(stopByMitigationOrInvalidation)
      {
         // draw "MITIGATED" label on the bar where we stop counting
         FvgSystem_DrawMitigatedLabel(draw, 1, g_activeDir);

         // stop tracking
         g_hasActiveFvg = false;
         g_activeDir = FVG_NONE;
      }
      else
      {
         // draw/evaluate 0.618 on the last closed bar (index 1)
         bool validSignal = Fvg618Process(1, g_activeDir, draw);

         // stop when green
         if(validSignal)
         {
            g_hasActiveFvg = false;
            g_activeDir = FVG_NONE;
         }
      }
   }

   if(draw)
      ChartRedraw(0);
}

#endif // __FVG_SYSTEM_MQH__

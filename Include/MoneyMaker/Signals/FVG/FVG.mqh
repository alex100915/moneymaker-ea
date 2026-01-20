#ifndef __FVG_MQH__
#define __FVG_MQH__

//+------------------------------------------------------------------+
//|                                                   FVG.mqh        |
//|  Fixed-config module that draws Fair Value Gaps like indicator   |
//|  Call from main EA: FvgInit(); FvgTick(draw); FvgDeinit(draw);   |
//|                                                                  |
//|  EXTRA: FvgGetMostRecentFvgBar(outBarIndex,outDir)               |
//|         -> finds the most recent (closest to present) FVG bar    |
//+------------------------------------------------------------------+

// types
enum ENUM_BORDER_STYLE
{
   BORDER_STYLE_SOLID = STYLE_SOLID,
   BORDER_STYLE_DASH  = STYLE_DASH
};

// -------------------- FIXED CONFIG (edit here) --------------------
// Main
static const bool CFG_ContinueToMitigation = false; // true = extend until mitigation / current
static const int  CFG_BoxLength            = 5;     // used only when mitigation disabled
static const int  CFG_ScanBars             = 500;   // how many recent bars to scan

// Style
static const color CFG_DownTrendColor = clrLightPink;
static const color CFG_UpTrendColor   = clrLightGreen;
static const bool  CFG_Fill           = true;
static const ENUM_BORDER_STYLE CFG_BorderStyle = BORDER_STYLE_SOLID;
static const int   CFG_BorderWidth    = 2;

// Dev
static const bool CFG_DebugEnabled = false;
// ------------------------------------------------------------------

// constants
const string OBJECT_PREFIX             = "FVG";
const string OBJECT_PREFIX_CONTINUATED = OBJECT_PREFIX + "CNT";
const string OBJECT_SEP                = "#";

static datetime g_lastBarTime = 0;

//+------------------------------------------------------------------+
bool FvgIsNewBar()
{
   datetime t = iTime(_Symbol, _Period, 0);
   if(t != g_lastBarTime)
   {
      g_lastBarTime = t;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
// EXACT naming scheme like original indicator
void FvgDrawBox(bool draw, datetime leftDt, double leftPrice, datetime rightDt, double rightPrice, bool continuated)
{
   if(!draw) return;

   string objName = (continuated ? OBJECT_PREFIX_CONTINUATED : OBJECT_PREFIX)
                    + OBJECT_SEP
                    + TimeToString(leftDt)
                    + OBJECT_SEP
                    + DoubleToString(leftPrice, _Digits)
                    + OBJECT_SEP
                    + TimeToString(rightDt)
                    + OBJECT_SEP
                    + DoubleToString(rightPrice, _Digits);

   if(ObjectFind(0, objName) < 0)
   {
      if(!ObjectCreate(0, objName, OBJ_RECTANGLE, 0, leftDt, leftPrice, rightDt, rightPrice))
      {
         if(CFG_DebugEnabled)
            PrintFormat("ObjectCreate failed for %s. Err=%d", objName, GetLastError());
         return;
      }

      ObjectSetInteger(0, objName, OBJPROP_COLOR, leftPrice < rightPrice ? CFG_UpTrendColor : CFG_DownTrendColor);
      ObjectSetInteger(0, objName, OBJPROP_FILL,  CFG_Fill);
      ObjectSetInteger(0, objName, OBJPROP_STYLE, (int)CFG_BorderStyle);
      ObjectSetInteger(0, objName, OBJPROP_WIDTH, CFG_BorderWidth);
      ObjectSetInteger(0, objName, OBJPROP_BACK, true);
      ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, objName, OBJPROP_SELECTED, false);
      ObjectSetInteger(0, objName, OBJPROP_HIDDEN, false);
      ObjectSetInteger(0, objName, OBJPROP_ZORDER, 0);

      if(CFG_DebugEnabled)
         PrintFormat("Draw box: %s", objName);
   }
}

//+------------------------------------------------------------------+
void FvgClearObjects(bool draw)
{
   if(!draw) return;

   ObjectsDeleteAll(0, OBJECT_PREFIX);
   ObjectsDeleteAll(0, OBJECT_PREFIX_CONTINUATED);
}

//+------------------------------------------------------------------+
// Core scan + optional draw (same as your fixed EA)
void FvgScanAndDraw(bool draw)
{
   int bars = Bars(_Symbol, _Period);
   if(bars < 10) return;

   int need = MathMin(CFG_ScanBars, bars);
   if(need < 10) need = MathMin(300, bars);

   MqlRates rates[];
   ArraySetAsSeries(rates, true);

   int copied = CopyRates(_Symbol, _Period, 0, need, rates);
   if(copied < 10) return;

   // redraw from scratch on each new bar -> clean like indicator
   FvgClearObjects(draw);

   int limit = copied - 3;
   if(limit < 1) return;

   if(CFG_DebugEnabled)
      PrintFormat("Scan bars copied=%d limit=%d", copied, limit);

   for(int i = 1; i <= limit; i++)
   {
      double rightHighPrice = rates[i].high;
      double rightLowPrice  = rates[i].low;
      double midHighPrice   = rates[i+1].high;
      double midLowPrice    = rates[i+1].low;
      double leftHighPrice  = rates[i+2].high;
      double leftLowPrice   = rates[i+2].low;

      datetime rightTime = rates[i].time;
      datetime leftTime  = rates[i+2].time;

      // Up trend
      bool upLeft  = (midLowPrice <= leftHighPrice && midLowPrice > leftLowPrice);
      bool upRight = (midHighPrice >= rightLowPrice && midHighPrice < rightHighPrice);
      bool upGap   = (leftHighPrice < rightLowPrice);

      if(upLeft && upRight && upGap)
      {
         if(CFG_ContinueToMitigation)
         {
            rightTime = rates[0].time;

            for(int j = i - 1; j > 0; j--)
            {
               if( (rightLowPrice < rates[j].high && rightLowPrice >= rates[j].low) ||
                   (leftHighPrice > rates[j].low && leftHighPrice <= rates[j].high) )
               {
                  rightTime = rates[j].time;
                  break;
               }
            }

            bool continuated = (rightTime == rates[0].time);
            FvgDrawBox(draw, leftTime, leftHighPrice, rightTime, rightLowPrice, continuated);
         }
         else
         {
            int rightIndex = MathMax(0, i + 2 - CFG_BoxLength);
            rightTime = rates[rightIndex].time;

            FvgDrawBox(draw, leftTime, leftHighPrice, rightTime, rightLowPrice, false);
         }

         continue;
      }

      // Down trend
      bool downLeft  = (midHighPrice >= leftLowPrice && midHighPrice < leftHighPrice);
      bool downRight = (midLowPrice <= rightHighPrice && midLowPrice > rightLowPrice);
      bool downGap   = (leftLowPrice > rightHighPrice);

      if(downLeft && downRight && downGap)
      {
         if(CFG_ContinueToMitigation)
         {
            rightTime = rates[0].time;

            for(int j = i - 1; j > 0; j--)
            {
               if( (rightHighPrice <= rates[j].high && rightHighPrice > rates[j].low) ||
                   (leftLowPrice >= rates[j].low && leftLowPrice < rates[j].high) )
               {
                  rightTime = rates[j].time;
                  break;
               }
            }

            bool continuated = (rightTime == rates[0].time);
            FvgDrawBox(draw, leftTime, leftLowPrice, rightTime, rightHighPrice, continuated);
         }
         else
         {
            int rightIndex = MathMax(0, i + 2 - CFG_BoxLength);
            rightTime = rates[rightIndex].time;

            FvgDrawBox(draw, leftTime, leftLowPrice, rightTime, rightHighPrice, false);
         }

         continue;
      }
   }

   if(draw)
      ChartRedraw(0);
}

//+------------------------------------------------------------------+
// EXTRA: Find most recent FVG bar within scan window.
// Returns: true if found.
// outBarIndex = shift of the "right" candle (i in scan), i>=1 (1 = last closed).
// outDir = 1 bullish, -1 bearish
bool FvgGetMostRecentFvgBar(int &outBarIndex, int &outDir)
{
   outBarIndex = -1;
   outDir = 0;

   int bars = Bars(_Symbol, _Period);
   if(bars < 10) return false;

   int need = MathMin(CFG_ScanBars, bars);
   if(need < 10) need = MathMin(300, bars);

   MqlRates rates[];
   ArraySetAsSeries(rates, true);

   int copied = CopyRates(_Symbol, _Period, 0, need, rates);
   if(copied < 10) return false;

   int limit = copied - 3;
   if(limit < 1) return false;

   // Most recent => smallest i that matches
   for(int i = 1; i <= limit; i++)
   {
      double rightHigh = rates[i].high;
      double rightLow  = rates[i].low;
      double midHigh   = rates[i+1].high;
      double midLow    = rates[i+1].low;
      double leftHigh  = rates[i+2].high;
      double leftLow   = rates[i+2].low;

      bool upLeft  = (midLow <= leftHigh && midLow > leftLow);
      bool upRight = (midHigh >= rightLow && midHigh < rightHigh);
      bool upGap   = (leftHigh < rightLow);
      if(upLeft && upRight && upGap)
      {
         outBarIndex = i;
         outDir = 1;
         return true;
      }

      bool downLeft  = (midHigh >= leftLow && midHigh < leftHigh);
      bool downRight = (midLow <= rightHigh && midLow > rightLow);
      bool downGap   = (leftLow > rightHigh);
      if(downLeft && downRight && downGap)
      {
         outBarIndex = i;
         outDir = -1;
         return true;
      }
   }

   return false;
}

//+------------------------------------------------------------------+
// Public API to call from main EA
void FvgInit()
{
   if(CFG_DebugEnabled)
      Print("Fvg module init");

   g_lastBarTime = 0;
}

void FvgDeinit(bool draw)
{
   // if you want boxes to stay, call with draw=false or comment next line
   FvgClearObjects(draw);
}

void FvgTick(bool draw)
{
   if(!FvgIsNewBar())
      return;

   FvgScanAndDraw(draw);
}

#endif // __FVG_MQH__

#ifndef __FVG_MQH__
#define __FVG_MQH__

//+------------------------------------------------------------------+
//|                                                   FVG.mqh        |
//|  EVENT-STYLE (incremental) FVG:                                 |
//|  - No full rescan, no full redraw                                |
//|  - Detects NEW FVG only on last closed bar (bars 1/2/3)          |
//|  - Optionally extends "continuated" rectangles until mitigation  |
//|                                                                  |
//|  API:                                                           |
//|    FvgInit();                                                   |
//|    bool FvgTickAndGetNew(bool draw, int &outBar, int &outDir);   |
//|    void FvgDeinit(bool draw);                                    |
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
static datetime g_lastReturnedNewFvgTime = 0;

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
// "Final" box naming like original (includes right time)
// Good for fixed-length boxes (not changing later)
void FvgDrawBoxFixed(bool draw, datetime leftDt, double leftPrice, datetime rightDt, double rightPrice)
{
   if(!draw) return;

   string objName = OBJECT_PREFIX
                    + OBJECT_SEP + TimeToString(leftDt)
                    + OBJECT_SEP + DoubleToString(leftPrice, _Digits)
                    + OBJECT_SEP + TimeToString(rightDt)
                    + OBJECT_SEP + DoubleToString(rightPrice, _Digits);

   if(ObjectFind(0, objName) >= 0)
      return;

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
      PrintFormat("Draw fixed box: %s", objName);
}

//+------------------------------------------------------------------+
// "Continuated" box naming MUST be stable (no right time inside name)
void FvgDrawBoxContinuated(bool draw, datetime leftDt, double leftPrice, double rightPrice)
{
   if(!draw) return;

   // stable name: prefix + leftTime + leftPrice + rightPrice
   string objName = OBJECT_PREFIX_CONTINUATED
                    + OBJECT_SEP + IntegerToString((long)leftDt)
                    + OBJECT_SEP + DoubleToString(leftPrice, _Digits)
                    + OBJECT_SEP + DoubleToString(rightPrice, _Digits);

   if(ObjectFind(0, objName) >= 0)
      return;

   datetime rightDt = iTime(_Symbol, _Period, 0); // extend to "now" (current bar open time)

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
      PrintFormat("Draw continuated box: %s", objName);
}

//+------------------------------------------------------------------+
// Update continuated boxes until mitigation (runs on each new bar)
void FvgUpdateContinuatedBoxes(bool draw)
{
   if(!draw) return;
   if(!CFG_ContinueToMitigation) return;

   int total = ObjectsTotal(0, 0, OBJ_RECTANGLE);
   if(total <= 0) return;

   // last closed bar (1) for mitigation check
   double h1 = iHigh(_Symbol, _Period, 1);
   double l1 = iLow(_Symbol, _Period, 1);
   datetime t1 = iTime(_Symbol, _Period, 1);
   datetime t0 = iTime(_Symbol, _Period, 0);

   for(int idx = total - 1; idx >= 0; --idx)
   {
      string objName = ObjectName(0, idx, 0, OBJ_RECTANGLE);
      if(StringFind(objName, OBJECT_PREFIX_CONTINUATED) != 0)
         continue;

      // parse: FVGCNT#<leftDtLong>#<leftPrice>#<rightPrice>
      string parts[];
      int n = StringSplit(objName, StringGetCharacter(OBJECT_SEP, 0), parts);
      if(n < 4) continue;

      datetime leftDt = (datetime)(long)StringToInteger(parts[1]);
      double leftPrice = StringToDouble(parts[2]);
      double rightPrice = StringToDouble(parts[3]);

      bool mitigated = false;

      // same logic as indicator: if rightPrice lies inside candle[1] range then mitigate
      if(rightPrice < h1 && rightPrice > l1)
         mitigated = true;

      if(mitigated)
      {
         // finalize: delete continuated and create fixed ending at bar[1]
         ObjectDelete(0, objName);
         FvgDrawBoxFixed(true, leftDt, leftPrice, t1, rightPrice);
      }
      else
      {
         // extend to current bar time
         ObjectMove(0, objName, 1, t0, rightPrice);
      }
   }
}

//+------------------------------------------------------------------+
// Event-style detection on last closed bar only (1/2/3), returns true only once per bar time
bool FvgDetectNewOnLastClosedBar(int &outBarIndex, int &outDir)
{
   outBarIndex = -1;
   outDir = 0;

   if(Bars(_Symbol, _Period) < 5)
      return false;

   const int i = 1; // right candle = last closed

   double rightHigh = iHigh(_Symbol, _Period, i);
   double rightLow  = iLow(_Symbol, _Period, i);
   double midHigh   = iHigh(_Symbol, _Period, i+1);
   double midLow    = iLow(_Symbol, _Period, i+1);
   double leftHigh  = iHigh(_Symbol, _Period, i+2);
   double leftLow   = iLow(_Symbol, _Period, i+2);

   datetime tRight = iTime(_Symbol, _Period, i);
   if(tRight == 0) return false;

   // Up trend
   bool upLeft  = (midLow <= leftHigh && midLow > leftLow);
   bool upRight = (midHigh >= rightLow && midHigh < rightHigh);
   bool upGap   = (leftHigh < rightLow);

   if(upLeft && upRight && upGap)
   {
      if(tRight == g_lastReturnedNewFvgTime) return false;
      g_lastReturnedNewFvgTime = tRight;

      outBarIndex = i;
      outDir = 1;
      return true;
   }

   // Down trend
   bool downLeft  = (midHigh >= leftLow && midHigh < leftHigh);
   bool downRight = (midLow <= rightHigh && midLow > rightLow);
   bool downGap   = (leftLow > rightHigh);

   if(downLeft && downRight && downGap)
   {
      if(tRight == g_lastReturnedNewFvgTime) return false;
      g_lastReturnedNewFvgTime = tRight;

      outBarIndex = i;
      outDir = -1;
      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
// Create box for the new FVG on bar=1 (right candle). Uses bars 1/2/3 like original.
void FvgDrawNewFromBar1(bool draw, int fvgDir)
{
   if(!draw) return;

   const int i = 1;

   datetime rightTime = iTime(_Symbol, _Period, i);
   datetime leftTime  = iTime(_Symbol, _Period, i+2);

   double rightHigh = iHigh(_Symbol, _Period, i);
   double rightLow  = iLow(_Symbol, _Period, i);
   double leftHigh  = iHigh(_Symbol, _Period, i+2);
   double leftLow   = iLow(_Symbol, _Period, i+2);

   // Bullish: box between leftHigh and rightLow
   if(fvgDir > 0)
   {
      double top = rightLow;   // in your original DrawBox call this is "rightLowPrice"
      double bot = leftHigh;   // "leftHighPrice"
      // Note: order doesn't matter for rectangle, but color uses leftPrice < rightPrice in our DrawBoxFixed.
      // We'll keep same as original: leftPrice = leftHigh, rightPrice = rightLow.
      double leftPrice = leftHigh;
      double rightPrice = rightLow;

      if(CFG_ContinueToMitigation)
      {
         FvgDrawBoxContinuated(true, leftTime, leftPrice, rightPrice);
      }
      else
      {
         // fixed length: start at leftTime (bar 3), end forward by CFG_BoxLength bars
         int rightIndex = MathMax(0, (i+2) - CFG_BoxLength);
         datetime endTime = iTime(_Symbol, _Period, rightIndex);
         FvgDrawBoxFixed(true, leftTime, leftPrice, endTime, rightPrice);
      }
      return;
   }

   // Bearish: box between leftLow and rightHigh
   if(fvgDir < 0)
   {
      double leftPrice = leftLow;
      double rightPrice = rightHigh;

      if(CFG_ContinueToMitigation)
      {
         FvgDrawBoxContinuated(true, leftTime, leftPrice, rightPrice);
      }
      else
      {
         int rightIndex = MathMax(0, (i+2) - CFG_BoxLength);
         datetime endTime = iTime(_Symbol, _Period, rightIndex);
         FvgDrawBoxFixed(true, leftTime, leftPrice, endTime, rightPrice);
      }
      return;
   }
}

//+------------------------------------------------------------------+
// Public API
void FvgInit()
{
   g_lastBarTime = 0;
   g_lastReturnedNewFvgTime = 0;
}

void FvgDeinit(bool draw)
{
   if(!draw) return;

   // usuń tylko obiekty FVG (rectangles)
   ObjectsDeleteAll(0, OBJECT_PREFIX);
   ObjectsDeleteAll(0, OBJECT_PREFIX_CONTINUATED);
}

bool FvgTickAndGetNew(bool draw, int &outBar, int &outDir)
{
   outBar = -1;
   outDir = 0;

   if(!FvgIsNewBar())
      return false;

   // 1) update continuated rectangles (if enabled)
   FvgUpdateContinuatedBoxes(draw);

   // 2) detect new FVG only on last closed bar
   int bar, dir;
   if(FvgDetectNewOnLastClosedBar(bar, dir))
   {
      // 3) draw just this new one (no history redraw)
      FvgDrawNewFromBar1(draw, dir);

      outBar = bar;
      outDir = dir;
      return true;
   }

   return false;
}

#endif // __FVG_MQH__

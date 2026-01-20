//+------------------------------------------------------------------+
//|                                                   FvgEA_Fixed.mq5|
//|  Fixed-config EA that draws Fair Value Gaps like original Fvg.mq5|
//+------------------------------------------------------------------+
#property strict
#property description "EA draws fair value gaps (FVG) rectangles like original indicator. Config is fixed in code (no inputs)."

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

datetime g_lastBarTime = 0;

//+------------------------------------------------------------------+
bool IsNewBar()
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
void DrawBox(datetime leftDt, double leftPrice, datetime rightDt, double rightPrice, bool continuated)
{
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
void ClearFvgObjects()
{
   ObjectsDeleteAll(0, OBJECT_PREFIX);
   ObjectsDeleteAll(0, OBJECT_PREFIX_CONTINUATED);
}

//+------------------------------------------------------------------+
void ScanAndDrawFVG()
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
   ClearFvgObjects();

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
            DrawBox(leftTime, leftHighPrice, rightTime, rightLowPrice, continuated);
         }
         else
         {
            int rightIndex = MathMax(0, i + 2 - CFG_BoxLength);
            rightTime = rates[rightIndex].time;

            DrawBox(leftTime, leftHighPrice, rightTime, rightLowPrice, false);
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
            DrawBox(leftTime, leftLowPrice, rightTime, rightHighPrice, continuated);
         }
         else
         {
            int rightIndex = MathMax(0, i + 2 - CFG_BoxLength);
            rightTime = rates[rightIndex].time;

            DrawBox(leftTime, leftLowPrice, rightTime, rightHighPrice, false);
         }

         continue;
      }
   }

   ChartRedraw(0);
}

//+------------------------------------------------------------------+
int OnInit()
{
   if(CFG_DebugEnabled)
      Print("FvgEA_Fixed init");

   g_lastBarTime = 0;
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Jeśli chcesz, żeby boxy zostały po zatrzymaniu EA, zakomentuj poniższą linię:
   ClearFvgObjects();
}

//+------------------------------------------------------------------+
void OnTick()
{
   if(!IsNewBar())
      return;

   ScanAndDrawFVG();
}
//+------------------------------------------------------------------+

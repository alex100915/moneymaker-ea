//+------------------------------------------------------------------+
//|                                                   FvgEA.mq5      |
//|     EA that draws Fair Value Gaps exactly like the Fvg.mq5       |
//|     (visualization-friendly for Strategy Tester -> Visualize)    |
//+------------------------------------------------------------------+
#property strict
#property description "EA draws fair value gaps (FVG) rectangles like original indicator for Strategy Tester visualization."

// types (same as indicator)
enum ENUM_BORDER_STYLE
{
   BORDER_STYLE_SOLID = STYLE_SOLID, // Solid
   BORDER_STYLE_DASH  = STYLE_DASH   // Dash
};

// config (same as indicator)
input group "Section :: Main";
input bool InpContinueToMitigation = false; // Continue to mitigation
input int  InpBoxLength            = 5;     // Fixed box length in bars (when mitigation disabled)
input int  InpScanBars             = 600;   // How many recent bars to scan (EA-only; increase if needed)

input group "Section :: Style";
input color InpDownTrendColor = clrLightPink;  // Down trend color
input color InpUpTrendColor   = clrLightGreen; // Up trend color
input bool  InpFill           = true;          // Fill solid (true) or transparent (false)
input ENUM_BORDER_STYLE InpBoderStyle = BORDER_STYLE_SOLID; // Border line style
input int   InpBorderWidth    = 2;             // Border line width

input group "Section :: Dev";
input bool InpDebugEnabled = false; // Enable debug (verbose logging)

// constants (same)
const string OBJECT_PREFIX             = "FVG";
const string OBJECT_PREFIX_CONTINUATED = OBJECT_PREFIX + "CNT";
const string OBJECT_SEP                = "#";

datetime g_lastBarTime = 0;

//+------------------------------------------------------------------+
//| Utility: detect new bar                                          |
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
//| Draws FVG box (same naming scheme as indicator)                  |
//+------------------------------------------------------------------+
void DrawBox(datetime leftDt, double leftPrice, datetime rightDt, double rightPrice, bool continuated)
{
   // EXACT naming pattern from indicator:
   // (continuated ? "FVGCNT" : "FVG") + "#" + TimeToString(leftDt) + "#" + DoubleToString(leftPrice)
   // + "#" + TimeToString(rightDt) + "#" + DoubleToString(rightPrice)
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
         if(InpDebugEnabled)
            PrintFormat("ObjectCreate failed for %s. Err=%d", objName, GetLastError());
         return;
      }

      ObjectSetInteger(0, objName, OBJPROP_COLOR, leftPrice < rightPrice ? InpUpTrendColor : InpDownTrendColor);
      ObjectSetInteger(0, objName, OBJPROP_FILL, InpFill);
      ObjectSetInteger(0, objName, OBJPROP_STYLE, (int)InpBoderStyle);
      ObjectSetInteger(0, objName, OBJPROP_WIDTH, InpBorderWidth);
      ObjectSetInteger(0, objName, OBJPROP_BACK, true);
      ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, objName, OBJPROP_SELECTED, false);
      ObjectSetInteger(0, objName, OBJPROP_HIDDEN, false);
      ObjectSetInteger(0, objName, OBJPROP_ZORDER, 0);

      if(InpDebugEnabled)
         PrintFormat("Draw box: %s", objName);
   }
}

//+------------------------------------------------------------------+
//| Delete all our objects (so no "trash leftovers")                 |
//+------------------------------------------------------------------+
void ClearFvgObjects()
{
   // Delete both prefixes
   ObjectsDeleteAll(0, OBJECT_PREFIX);
   ObjectsDeleteAll(0, OBJECT_PREFIX_CONTINUATED);
}

//+------------------------------------------------------------------+
//| Scan recent bars and draw boxes exactly like indicator           |
//+------------------------------------------------------------------+
void ScanAndDrawFVG()
{
   int bars = Bars(_Symbol, _Period);
   if(bars < 10) return;

   int need = MathMin(InpScanBars, bars);
   if(need < 10) need = MathMin(300, bars);

   MqlRates rates[];
   ArraySetAsSeries(rates, true);

   int copied = CopyRates(_Symbol, _Period, 0, need, rates);
   if(copied < 10) return;

   // We redraw from scratch each new bar => clean output like indicator
   ClearFvgObjects();

   // Same idea as indicator loop:
   // use i (right), i+1 (mid), i+2 (left), with i starting at 1
   int limit = copied - 3; // last usable i
   if(limit < 1) return;

   if(InpDebugEnabled)
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

      // Up trend (same conditions)
      bool upLeft  = (midLowPrice <= leftHighPrice && midLowPrice > leftLowPrice);
      bool upRight = (midHighPrice >= rightLowPrice && midHighPrice < rightHighPrice);
      bool upGap   = (leftHighPrice < rightLowPrice);

      if(upLeft && upRight && upGap)
      {
         if(InpContinueToMitigation)
         {
            // Default: continue to current bar
            rightTime = rates[0].time;

            // Search mitigation bar (same logic as indicator)
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
            // Fixed length (same idea as indicator)
            int rightIndex = MathMax(0, i + 2 - InpBoxLength);
            rightTime = rates[rightIndex].time;

            DrawBox(leftTime, leftHighPrice, rightTime, rightLowPrice, false);
         }

         continue;
      }

      // Down trend (same conditions)
      bool downLeft  = (midHighPrice >= leftLowPrice && midHighPrice < leftHighPrice);
      bool downRight = (midLowPrice <= rightHighPrice && midLowPrice > rightLowPrice);
      bool downGap   = (leftLowPrice > rightHighPrice);

      if(downLeft && downRight && downGap)
      {
         if(InpContinueToMitigation)
         {
            rightTime = rates[0].time;

            // Search mitigation bar (same logic as indicator)
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
            int rightIndex = MathMax(0, i + 2 - InpBoxLength);
            rightTime = rates[rightIndex].time;

            DrawBox(leftTime, leftLowPrice, rightTime, rightHighPrice, false);
         }

         continue;
      }
   }

   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Expert initialization                                            |
//+------------------------------------------------------------------+
int OnInit()
{
   if(InpDebugEnabled)
      Print("FvgEA init");

   // initialize last bar time to current bar so first tick draws immediately
   g_lastBarTime = 0;
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(InpDebugEnabled)
      Print("FvgEA deinit");

   ClearFvgObjects();
}

//+------------------------------------------------------------------+
//| Expert tick                                                      |
//+------------------------------------------------------------------+
void OnTick()
{
   // For Visual Tester: draw once per new bar (clean + light)
   if(!IsNewBar())
      return;

   ScanAndDrawFVG();
}
//+------------------------------------------------------------------+

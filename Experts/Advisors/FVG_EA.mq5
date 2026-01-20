//+------------------------------------------------------------------+
//|                                                   FvgEA.mq5      |
//|              EA version based on Fvg.mq5 (fair value gaps)       |
//+------------------------------------------------------------------+
#property strict
#property description "EA draws fair value gaps (FVG) rectangles for Strategy Tester visualization."

// types (same as indicator)
enum ENUM_BORDER_STYLE
{
   BORDER_STYLE_SOLID = STYLE_SOLID,
   BORDER_STYLE_DASH  = STYLE_DASH
};

// config (same idea as indicator)
input group "Section :: Main";
input bool InpContinueToMitigation = false; // Continue to mitigation
input int  InpBoxLength            = 5;     // Fixed box length in bars (when mitigation disabled)
input int  InpScanBars             = 500;   // How many recent bars to scan/draw (EA-only)

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
//| Draws FVG box (same concept as indicator)                        |
//+------------------------------------------------------------------+
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
//| Update continued boxes to mitigation                             |
//+------------------------------------------------------------------+
void UpdateContinuedBoxes(const MqlRates &rates[])
{
   // rates[] is series: rates[0] current, rates[1] last closed, etc.
   int total = ObjectsTotal(0, 0, OBJ_RECTANGLE);
   for(int i = 0; i < total; i++)
   {
      string objName = ObjectName(0, i, 0, OBJ_RECTANGLE);
      if(StringFind(objName, OBJECT_PREFIX_CONTINUATED) != 0)
         continue;

      string parts[];
      int n = StringSplit(objName, StringGetCharacter(OBJECT_SEP, 0), parts);
      if(n < 5) // expected: PREFIX#leftTime#leftPrice#rightTime#rightPrice
         continue;

      datetime leftTime  = StringToTime(parts[1]);
      double   leftPrice = StringToDouble(parts[2]);
      datetime rightTime = rates[0].time;           // extend to current by default
      double   rightPrice = StringToDouble(parts[4]); // fixed price border used in original code

      // If "rightPrice" is inside last closed candle -> mitigate now, finalize box to that candle time
      if(rightPrice < rates[1].high && rightPrice > rates[1].low)
      {
         rightTime = rates[1].time;

         if(ObjectDelete(0, objName))
         {
            // redraw final (non-continued) box
            DrawBox(leftTime, leftPrice, rightTime, rightPrice, false);
         }
      }
      else
      {
         // move point 1 (right corner) to current time, same price
         ObjectMove(0, objName, 1, rightTime, rightPrice);

         if(InpDebugEnabled)
            PrintFormat("Expand box %s", objName);
      }
   }
}

//+------------------------------------------------------------------+
//| Scan recent bars and draw boxes                                  |
//+------------------------------------------------------------------+
void ScanAndDrawFVG()
{
   // Need enough bars
   int bars = Bars(_Symbol, _Period);
   if(bars < 10)
      return;

   int need = MathMin(InpScanBars, bars);
   if(need < 10) need = MathMin(200, bars);

   MqlRates rates[];
   ArraySetAsSeries(rates, true);

   int copied = CopyRates(_Symbol, _Period, 0, need, rates);
   if(copied < 10)
      return;

   // Update continued boxes first (uses rates[0]/rates[1])
   if(InpContinueToMitigation)
      UpdateContinuedBoxes(rates);

   // We replicate indicator loop:
   // for i=1 .. limit-1, we use bars i (right), i+1 (mid), i+2 (left)
   int limit = copied - 3; // last usable i is copied-3
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
         double top    = rightLowPrice;  // higher price of FVG box corner in original SetBuffers call
         double bottom = leftHighPrice;

         if(InpContinueToMitigation)
         {
            rightTime = rates[0].time;
            // Search mitigation bar
            for(int j = i - 1; j > 0; j--)
            {
               if((rightLowPrice < rates[j].high && rightLowPrice >= rates[j].low) ||
                  (leftHighPrice > rates[j].low && leftHighPrice <= rates[j].high))
               {
                  rightTime = rates[j].time;
                  break;
               }
            }
            DrawBox(leftTime, leftHighPrice, rightTime, rightLowPrice, (rightTime == rates[0].time));
         }
         else
         {
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
            // Search mitigation bar
            for(int j = i - 1; j > 0; j--)
            {
               if((rightHighPrice <= rates[j].high && rightHighPrice > rates[j].low) ||
                  (leftLowPrice >= rates[j].low && leftLowPrice < rates[j].high))
               {
                  rightTime = rates[j].time;
                  break;
               }
            }
            DrawBox(leftTime, leftLowPrice, rightTime, rightHighPrice, (rightTime == rates[0].time));
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
}

//+------------------------------------------------------------------+
//| Expert initialization                                            |
//+------------------------------------------------------------------+
int OnInit()
{
   if(InpDebugEnabled)
      Print("FvgEA initialization started");

   // Make sure chart redraws smoothly in visual tester
   ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, false);

   if(InpDebugEnabled)
      Print("FvgEA initialization finished");

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(InpDebugEnabled)
      Print("FvgEA deinitialization started");

   // Delete our objects (both prefixes)
   ObjectsDeleteAll(0, OBJECT_PREFIX);
   ObjectsDeleteAll(0, OBJECT_PREFIX_CONTINUATED);

   if(InpDebugEnabled)
      Print("FvgEA deinitialization finished");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // You can draw on every tick, but it's heavier.
   // For Strategy Tester visualization, new bar is enough.
   if(!IsNewBar())
      return;

   ScanAndDrawFVG();
   ChartRedraw(0);
}
//+------------------------------------------------------------------+

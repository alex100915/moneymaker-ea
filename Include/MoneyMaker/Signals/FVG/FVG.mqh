#ifndef __FVG_MQH__
#define __FVG_MQH__

// Config and constants
static const bool  CFG_ContinueToMitigation = false; // extend until mitigation
static const int   CFG_BoxLength            = 10;     // fixed length when mitigation disabled

static const color CFG_DownTrendColor = clrLightPink;
static const color CFG_UpTrendColor   = clrLightGreen;
static const bool  CFG_Fill           = true;
static const int   CFG_BorderStyle    = STYLE_SOLID; // STYLE_SOLID / STYLE_DASH / ...
static const int   CFG_BorderWidth    = 2;

const string OBJECT_PREFIX             = "FVG";
const string OBJECT_PREFIX_CONTINUATED = "FVGCNT";
const string OBJECT_SEP                = "#";

static datetime g_lastReturnedNewFvgTime = 0;

enum FVG_DIRECTION
{
   FVG_NONE    = 0,
   FVG_BULLISH = 1,
   FVG_BEARISH = -1
};

struct FvgBarData
{
   double rightBarHigh;
   double rightBarLow;
   double midBarHigh;
   double midBarLow;
   double leftBarHigh;
   double leftBarLow;
};

struct FvgDetectionResult
{
   bool hasNewFvg;
   FVG_DIRECTION direction;
   FvgBarData barData;
   double zoneLow;
   double zoneHigh;
};

FvgBarData FvgGetBarData(int lastClosedBarIndex)
{
   FvgBarData barData;
   barData.rightBarHigh = iHigh(_Symbol, _Period, lastClosedBarIndex);
   barData.rightBarLow  = iLow(_Symbol, _Period, lastClosedBarIndex);
   barData.midBarHigh   = iHigh(_Symbol, _Period, lastClosedBarIndex+1);
   barData.midBarLow    = iLow(_Symbol, _Period, lastClosedBarIndex+1);
   barData.leftBarHigh  = iHigh(_Symbol, _Period, lastClosedBarIndex+2);
   barData.leftBarLow   = iLow(_Symbol, _Period, lastClosedBarIndex+2);
   
   return barData;
}

bool FvgCheckBullishPattern(const FvgBarData &barData)
{
   bool midBarConnectsToLeft  = (barData.midBarLow <= barData.leftBarHigh && barData.midBarLow > barData.leftBarLow);
   bool midBarConnectsToRight = (barData.midBarHigh >= barData.rightBarLow && barData.midBarHigh < barData.rightBarHigh);
   bool gapExistsBetweenBars  = (barData.leftBarHigh < barData.rightBarLow);
   
   return midBarConnectsToLeft && midBarConnectsToRight && gapExistsBetweenBars;
}

bool FvgCheckBearishPattern(const FvgBarData &barData)
{
   bool midBarConnectsToLeft  = (barData.midBarHigh >= barData.leftBarLow && barData.midBarHigh < barData.leftBarHigh);
   bool midBarConnectsToRight = (barData.midBarLow <= barData.rightBarHigh && barData.midBarLow > barData.rightBarLow);
   bool gapExistsBetweenBars  = (barData.leftBarLow > barData.rightBarHigh);
   
   return midBarConnectsToLeft && midBarConnectsToRight && gapExistsBetweenBars;
}

FVG_DIRECTION FvgDetectDirection(const FvgBarData &barData)
{
   if(FvgCheckBullishPattern(barData))
      return FVG_BULLISH;
   
   if(FvgCheckBearishPattern(barData))
      return FVG_BEARISH;
   
   return FVG_NONE;
}

bool FvgCheckMitigation(FVG_DIRECTION direction, double zoneLow, double zoneHigh)
{
   const double lastClosedBarPrice = iClose(_Symbol, _Period, LAST_CLOSED_BAR_INDEX);
   
   if(direction == FVG_BULLISH)
   {
      // Bullish: mitigated if close is inside zone OR below zone
      return (lastClosedBarPrice <= zoneHigh);
   }
   else if(direction == FVG_BEARISH)
   {
      // Bearish: mitigated if close is inside zone OR above zone
      return (lastClosedBarPrice >= zoneLow);
   }

   return false;
}

void FvgInit()
{
   g_lastReturnedNewFvgTime = 0;
}

FvgDetectionResult Fvg_Detect()
{
   FvgDetectionResult result = {};

   datetime rightBarOpenTime = iTime(_Symbol, _Period, LAST_CLOSED_BAR_INDEX);

   FvgBarData barData = FvgGetBarData(LAST_CLOSED_BAR_INDEX);

   FVG_DIRECTION detectedDirection = FvgDetectDirection(barData);
   
   if(detectedDirection == FVG_NONE)
      return result;
   
   if(rightBarOpenTime == g_lastReturnedNewFvgTime)
      return result;

   g_lastReturnedNewFvgTime = rightBarOpenTime;

   result.hasNewFvg = true;
   result.barData = barData;
   result.direction = detectedDirection;
   result.zoneLow = (detectedDirection == FVG_BULLISH) ? barData.leftBarHigh : barData.rightBarHigh;
   result.zoneHigh = (detectedDirection == FVG_BULLISH) ? barData.rightBarLow : barData.leftBarLow;
   return result;
}

void FvgDraw(const FvgDetectionResult &result)
{
   datetime leftBarTime = iTime(_Symbol, _Period, LAST_CLOSED_BAR_INDEX+2);
   
   int rightIndex = MathMax(0, (LAST_CLOSED_BAR_INDEX+2) - CFG_BoxLength);
   datetime endTime = iTime(_Symbol, _Period, rightIndex);
   
   string objName = OBJECT_PREFIX
                    + OBJECT_SEP + TimeToString(leftBarTime)
                    + OBJECT_SEP + DoubleToString(result.zoneLow, _Digits)
                    + OBJECT_SEP + TimeToString(endTime)
                    + OBJECT_SEP + DoubleToString(result.zoneHigh, _Digits);

   if(ObjectFind(0, objName) >= 0)
      return;

   if(!ObjectCreate(0, objName, OBJ_RECTANGLE, 0, leftBarTime, result.zoneLow, endTime, result.zoneHigh))
      return;

   ObjectSetInteger(0, objName, OBJPROP_COLOR, result.direction == FVG_BULLISH ? CFG_UpTrendColor : CFG_DownTrendColor);
   ObjectSetInteger(0, objName, OBJPROP_FILL,  CFG_Fill);
   ObjectSetInteger(0, objName, OBJPROP_STYLE, CFG_BorderStyle);
   ObjectSetInteger(0, objName, OBJPROP_WIDTH, CFG_BorderWidth);
   ObjectSetInteger(0, objName, OBJPROP_BACK, true);
   ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, objName, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, objName, OBJPROP_HIDDEN, false);
   ObjectSetInteger(0, objName, OBJPROP_ZORDER, 0);
}

// Draw "MITIGATED" label on a specific bar
void Fvg618DrawMitigatedLabel(FVG_DIRECTION fvgDirection)
{
   const datetime lastClosedBarTime = iTime(_Symbol, _Period, LAST_CLOSED_BAR_INDEX);
   
   string name = "MIT#" + TimeToString(lastClosedBarTime);

   if(ObjectFind(0, name) >= 0)
      return;

   double lastBarHigh = iHigh(_Symbol, _Period, LAST_CLOSED_BAR_INDEX);
   double lastBarLow  = iLow(_Symbol, _Period, LAST_CLOSED_BAR_INDEX);

   datetime midTime = lastClosedBarTime + (datetime)(PeriodSeconds(_Period) / 2);

   double offset = 35 * _Point;
   double labelPositionY = (fvgDirection == FVG_BULLISH) ? (lastBarHigh + offset) : (lastBarLow - offset);

   // You can change color/text if you want
   string label = "M";
   color col  = clrRed;

   if(!ObjectCreate(0, name, OBJ_TEXT, 0, midTime, labelPositionY))
      return;

   ObjectSetString (0, name, OBJPROP_TEXT, label);
   ObjectSetInteger(0, name, OBJPROP_COLOR, col);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 10);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_CENTER);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
}

void FvgDeinit()
{
   ObjectsDeleteAll(0, OBJECT_PREFIX);
   ObjectsDeleteAll(0, OBJECT_PREFIX_CONTINUATED);
}

#endif // __FVG_MQH__

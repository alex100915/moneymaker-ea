#ifndef __FVG_MQH__
#define __FVG_MQH__

#include "FvgTypes.mqh"

static const int CFG_BoxLength = 10;

FvgDetectionResult Fvg_Detect()
{
   FvgDetectionResult result = {};

   FvgBarData barData = Fvg_GetBarData(LAST_CLOSED_BAR_INDEX);

   FVG_DIRECTION detectedDirection = Fvg_DetectDirection(barData);
   
   if(detectedDirection == FVG_NONE)
      return result;

   result.hasNewFvg = true;
   result.barData = barData;
   result.direction = detectedDirection;
   result.zoneLow = (detectedDirection == FVG_BULLISH) ? barData.leftBarHigh : barData.rightBarHigh;
   result.zoneHigh = (detectedDirection == FVG_BULLISH) ? barData.rightBarLow : barData.leftBarLow;
   return result;
}

FvgBarData Fvg_GetBarData(int lastClosedBarIndex)
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

FVG_DIRECTION Fvg_DetectDirection(const FvgBarData &barData)
{
   if(Fvg_CheckBullishPattern(barData))
      return FVG_BULLISH;
   
   if(Fvg_CheckBearishPattern(barData))
      return FVG_BEARISH;
   
   return FVG_NONE;
}

bool Fvg_CheckBullishPattern(const FvgBarData &barData)
{
   bool midBarConnectsToLeft  = (barData.midBarLow <= barData.leftBarHigh && barData.midBarLow > barData.leftBarLow);
   bool midBarConnectsToRight = (barData.midBarHigh >= barData.rightBarLow && barData.midBarHigh < barData.rightBarHigh);
   bool gapExistsBetweenBars  = (barData.leftBarHigh < barData.rightBarLow);
   
   return midBarConnectsToLeft && midBarConnectsToRight && gapExistsBetweenBars;
}

bool Fvg_CheckBearishPattern(const FvgBarData &barData)
{
   bool midBarConnectsToLeft  = (barData.midBarHigh >= barData.leftBarLow && barData.midBarHigh < barData.leftBarHigh);
   bool midBarConnectsToRight = (barData.midBarLow <= barData.rightBarHigh && barData.midBarLow > barData.rightBarLow);
   bool gapExistsBetweenBars  = (barData.leftBarLow > barData.rightBarHigh);
   
   return midBarConnectsToLeft && midBarConnectsToRight && gapExistsBetweenBars;
}

bool Fvg_CheckMitigation(FVG_DIRECTION direction, double zoneLow, double zoneHigh)
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

void Fvg_Draw(const FvgDetectionResult &result)
{
   datetime leftBarTime = iTime(_Symbol, _Period, LAST_CLOSED_BAR_INDEX+2);
   
   int rightIndex = MathMax(0, (LAST_CLOSED_BAR_INDEX+2) - CFG_BoxLength);
   datetime endTime = iTime(_Symbol, _Period, rightIndex);
   
   string objName = "FVG#" + TimeToString(leftBarTime)
                    + "#" + DoubleToString(result.zoneLow, _Digits)
                    + "#" + TimeToString(endTime)
                    + "#" + DoubleToString(result.zoneHigh, _Digits);

   ObjectSetInteger(0, objName, OBJPROP_COLOR, result.direction == FVG_BULLISH ? clrLightGreen : clrLightPink);
   ObjectSetInteger(0, objName, OBJPROP_FILL, true);
   ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, objName, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, objName, OBJPROP_BACK, true);
   ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, objName, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, objName, OBJPROP_HIDDEN, false);
   ObjectSetInteger(0, objName, OBJPROP_ZORDER, 0);
}

void Fvg_DrawMitigatedLabel(FVG_DIRECTION fvgDirection)
{
   const datetime lastClosedBarTime = iTime(_Symbol, _Period, LAST_CLOSED_BAR_INDEX);
   
   string name = "MIT#" + TimeToString(lastClosedBarTime);

   double lastBarHigh = iHigh(_Symbol, _Period, LAST_CLOSED_BAR_INDEX);
   double lastBarLow  = iLow(_Symbol, _Period, LAST_CLOSED_BAR_INDEX);

   datetime midTime = lastClosedBarTime + (datetime)(PeriodSeconds(_Period) / 2);

   double offset = 35 * _Point;
   double labelPositionY = (fvgDirection == FVG_BULLISH) ? (lastBarHigh + offset) : (lastBarLow - offset);

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

#endif // __FVG_MQH__

#ifndef __FVG_MQH__
#define __FVG_MQH__

// Config and constants
static const bool  CFG_ContinueToMitigation = false; // extend until mitigation
static const int   CFG_BoxLength            = 5;     // fixed length when mitigation disabled

static const color CFG_DownTrendColor = clrLightPink;
static const color CFG_UpTrendColor   = clrLightGreen;
static const bool  CFG_Fill           = true;
static const int   CFG_BorderStyle    = STYLE_SOLID; // STYLE_SOLID / STYLE_DASH / ...
static const int   CFG_BorderWidth    = 2;

const string OBJECT_PREFIX             = "FVG";
const string OBJECT_PREFIX_CONTINUATED = "FVGCNT";
const string OBJECT_SEP                = "#";

static datetime g_lastBarTime = 0;
static datetime g_lastReturnedNewFvgTime = 0;

enum ENUM_FVG_DIRECTION
{
   FVG_NONE    = 0,
   FVG_BULLISH = 1,
   FVG_BEARISH = -1
};

void FvgInit()
{
   g_lastBarTime = 0;
   g_lastReturnedNewFvgTime = 0;
}

bool FvgProcess(int &outBarIndex, ENUM_FVG_DIRECTION &outFvgDirection, bool draw)
{
   outBarIndex = -1;
   outFvgDirection = FVG_NONE;

   if(!FvgIsNewBar())
      return false;

   FvgUpdateContinuatedBoxes(draw);

   if(FvgDetectNewOnLastClosedBar(outBarIndex, outFvgDirection))
   {
      FvgDraw(draw, outFvgDirection);
      return true;
   }

   return false;
}

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

bool FvgDetectNewOnLastClosedBar(int &outBarIndex, ENUM_FVG_DIRECTION &outFvgDirection)
{
   if(Bars(_Symbol, _Period) < 5)
      return false;

   const int i = 1;

   double rightHigh = iHigh(_Symbol, _Period, i);
   double rightLow  = iLow(_Symbol, _Period, i);
   double midHigh   = iHigh(_Symbol, _Period, i+1);
   double midLow    = iLow(_Symbol, _Period, i+1);
   double leftHigh  = iHigh(_Symbol, _Period, i+2);
   double leftLow   = iLow(_Symbol, _Period, i+2);

   datetime tRight = iTime(_Symbol, _Period, i);
   if(tRight == 0)
      return false;

   bool upLeft  = (midLow <= leftHigh && midLow > leftLow);
   bool upRight = (midHigh >= rightLow && midHigh < rightHigh);
   bool upGap   = (leftHigh < rightLow);

   if(upLeft && upRight && upGap)
   {
      if(tRight == g_lastReturnedNewFvgTime)
         return false;

      g_lastReturnedNewFvgTime = tRight;

      outBarIndex = i;
      outFvgDirection = FVG_BULLISH;
      return true;
   }

   bool downLeft  = (midHigh >= leftLow && midHigh < leftHigh);
   bool downRight = (midLow <= rightHigh && midLow > rightLow);
   bool downGap   = (leftLow > rightHigh);

   if(downLeft && downRight && downGap)
   {
      if(tRight == g_lastReturnedNewFvgTime)
         return false;

      g_lastReturnedNewFvgTime = tRight;

      outBarIndex = i;
      outFvgDirection = FVG_BEARISH;
      return true;
   }

   return false;
}

// Starting from the last closed bar (index 1), draw FVG box
// Currently formed bar has index 0
void FvgDraw(bool draw, ENUM_FVG_DIRECTION fvgDirection)
{
   if(!draw) return;

   const int i = 1;

   datetime leftTime = iTime(_Symbol, _Period, i+2);

   double rightHigh = iHigh(_Symbol, _Period, i);
   double rightLow  = iLow(_Symbol, _Period, i);
   double leftHigh  = iHigh(_Symbol, _Period, i+2);
   double leftLow   = iLow(_Symbol, _Period, i+2);

   if(fvgDirection == FVG_BULLISH)
   {
      double leftPrice  = leftHigh;
      double rightPrice = rightLow;

      if(CFG_ContinueToMitigation)
      {
         FvgDrawBoxContinuated(draw, leftTime, leftPrice, rightPrice);
      }
      else
      {
         int rightIndex = MathMax(0, (i+2) - CFG_BoxLength);
         datetime endTime = iTime(_Symbol, _Period, rightIndex);
         FvgDrawBoxFixed(draw, leftTime, leftPrice, endTime, rightPrice);
      }
      return;
   }

   if(fvgDirection == FVG_BEARISH)
   {
      double leftPrice  = leftLow;
      double rightPrice = rightHigh;

      if(CFG_ContinueToMitigation)
      {
         FvgDrawBoxContinuated(draw, leftTime, leftPrice, rightPrice);
      }
      else
      {
         int rightIndex = MathMax(0, (i+2) - CFG_BoxLength);
         datetime endTime = iTime(_Symbol, _Period, rightIndex);
         FvgDrawBoxFixed(draw, leftTime, leftPrice, endTime, rightPrice);
      }
      return;
   }
}

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
      return;

   FvgApplyRectStyle(objName, leftPrice, rightPrice);
}

void FvgDrawBoxContinuated(bool draw, datetime leftDt, double leftPrice, double rightPrice)
{
   if(!draw) return;

   string objName = OBJECT_PREFIX_CONTINUATED
                    + OBJECT_SEP + IntegerToString((long)leftDt)
                    + OBJECT_SEP + DoubleToString(leftPrice, _Digits)
                    + OBJECT_SEP + DoubleToString(rightPrice, _Digits);

   if(ObjectFind(0, objName) >= 0)
      return;

   datetime rightDt = iTime(_Symbol, _Period, 0);

   if(!ObjectCreate(0, objName, OBJ_RECTANGLE, 0, leftDt, leftPrice, rightDt, rightPrice))
      return;

   FvgApplyRectStyle(objName, leftPrice, rightPrice);
}

void FvgUpdateContinuatedBoxes(bool draw)
{
   if(!draw) return;
   if(!CFG_ContinueToMitigation) return;

   int total = ObjectsTotal(0, 0, OBJ_RECTANGLE);
   if(total <= 0) return;

   // last closed bar data
   const double c1 = iClose(_Symbol, _Period, 1);
   const datetime t1 = iTime(_Symbol, _Period, 1);
   const datetime t0 = iTime(_Symbol, _Period, 0);

   for(int idx = total - 1; idx >= 0; --idx)
   {
      string objName = ObjectName(0, idx, 0, OBJ_RECTANGLE);
      if(StringFind(objName, OBJECT_PREFIX_CONTINUATED) != 0)
         continue;

      // parse name: FVGCNT#<leftDtLong>#<leftPrice>#<rightPrice>
      string parts[];
      int n = StringSplit(objName, StringGetCharacter(OBJECT_SEP, 0), parts);
      if(n < 4) continue;

      datetime leftDt   = (datetime)(long)StringToInteger(parts[1]);
      double leftPrice  = StringToDouble(parts[2]);
      double rightPrice = StringToDouble(parts[3]);

      // Mitigation ONLY if CLOSE of candle[1] is inside the FVG zone
      double zoneLow  = MathMin(leftPrice, rightPrice);
      double zoneHigh = MathMax(leftPrice, rightPrice);

      bool mitigated = (c1 >= zoneLow && c1 <= zoneHigh);

      if(mitigated)
      {
         ObjectDelete(0, objName);
         FvgDrawBoxFixed(draw, leftDt, leftPrice, t1, rightPrice);
      }
      else
      {
         // extend to current bar time
         ObjectMove(0, objName, 1, t0, rightPrice);
      }
   }
}

void FvgApplyRectStyle(const string name, const double leftPrice, const double rightPrice)
{
   ObjectSetInteger(0, name, OBJPROP_COLOR, leftPrice < rightPrice ? CFG_UpTrendColor : CFG_DownTrendColor);
   ObjectSetInteger(0, name, OBJPROP_FILL,  CFG_Fill);
   ObjectSetInteger(0, name, OBJPROP_STYLE, CFG_BorderStyle);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, CFG_BorderWidth);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 0);
}

void FvgDeinit(bool draw)
{
   if(!draw) return;
   ObjectsDeleteAll(0, OBJECT_PREFIX);
   ObjectsDeleteAll(0, OBJECT_PREFIX_CONTINUATED);
}

#endif // __FVG_MQH__

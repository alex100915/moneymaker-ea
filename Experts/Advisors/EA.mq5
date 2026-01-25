#property strict
#property description "Entry EA: EVENT-STYLE FVG + 0.618 system. One Draw parameter controls drawings."

#include <Bot/Conditions/Fvg/FvgSystem.mqh>

const int LAST_CLOSED_BAR_INDEX = 1;  // MT5: index 0 = currently forming bar, index 1 = last closed bar

input bool DrawChart = true;

static datetime g_lastBarTime = 0;

bool IsEnoughBars()
{
   int totalBars = Bars(_Symbol, _Period);
   return (totalBars >= 5);
}

bool IsNewBar()
{
   datetime t0 = iTime(_Symbol, _Period, 0);
   if(t0 != g_lastBarTime)
   {
      g_lastBarTime = t0;
      return true;
   }
   return false;
}

bool IsValidLastClosedBarTimeOpen()
{   
   datetime t1 = iTime(_Symbol, _Period, 1);
   if(t1 == 0)
      return false;
   
   return true;
}

bool IsValidLastClosedBarData()
{
   double high = iHigh(_Symbol, _Period, 1);
   double low  = iLow(_Symbol, _Period, 1);
   
   return (high > low);
}

int OnInit()
{
   g_lastBarTime = 0;
   return INIT_SUCCEEDED;
}

void OnTick()
{
   if(!IsEnoughBars())
      return;
   
   if(!IsNewBar())
      return;

   if(!IsValidLastClosedBarTimeOpen())
      return;

   if(!IsValidLastClosedBarData())
      return;

   // Business logic
   bool fvgResult = FvgSystem_IsFulfilled(DrawChart);
   
   if(fvgResult)
   {
      // Place your order logic here
   }
}

#property strict
#property description "Entry EA: EVENT-STYLE FVG + 0.618. One Draw parameter controls both drawings."

#include <MoneyMaker/Signals/FVG/FVG.mqh>
#include <MoneyMaker/Signals/FVG/Fvg618Label.mqh>

input bool Draw = true;

int OnInit()
{
   FvgInit();
   Fvg618_Init();
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   // Uncomment if you want to delete FVG rectangles when EA stops:
   // FvgDeinit(Draw);
}

void OnTick()
{
   int newBar, newDir;
   bool hasNew = FvgTickAndGetNew(Draw, newBar, newDir);

   if(hasNew)
   {
      bool ok = Fvg618_EvaluateAndMaybeDraw(Draw, newBar, newDir);
      // use 'ok' for entries
   }

   if(Draw)
      ChartRedraw(0);
}

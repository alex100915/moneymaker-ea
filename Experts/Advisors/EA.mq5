#property strict
#property description "Entry EA: EVENT-STYLE FVG + 0.618. One Draw parameter controls both drawings."

#include <MoneyMaker/Signals/FVG/FVG.mqh>
#include <MoneyMaker/Signals/FVG/Fvg618Label.mqh>

input bool draw = true;

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
   int barIndex;
   ENUM_FVG_DIRECTION fvgDirection;
   
   bool newFvg = FvgProcess(barIndex, fvgDirection, draw);

   if(newFvg)
   {
      bool ok = Fvg618Process(barIndex, fvgDirection, draw);
      // use 'ok' for entries
   }

   if(draw)
      ChartRedraw(0);
}

#property strict
#property description "Entry EA: main orchestrator. 1) detect/draw FVG 2) if FVG -> evaluate+draw 0.618 label. One Draw param controls both."

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
   //FvgDeinit(Draw);
}

void OnTick()
{
   int newBar, newDir;

   // Jedno wywołanie: aktualizacja + ewentualnie nowy FVG
   bool hasNew = FvgTickAndGetNew(Draw, newBar, newDir);

   // 0.618 tylko jeśli pojawił się NOWY FVG
   if(hasNew)
   {
      bool ok = Fvg618_EvaluateAndMaybeDraw(Draw, newBar, newDir);

      // tutaj możesz użyć ok do entry
      // if(ok) { ... }
   }

   if(Draw)
      ChartRedraw(0);
}

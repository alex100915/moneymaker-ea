#include <MoneyMaker/Signals/FVG/FVG.mqh>

input bool DrawFvg = true;

int OnInit()
{
   FvgInit();
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   FvgDeinit(DrawFvg);
}

void OnTick()
{
   FvgTick(DrawFvg);

   // reszta strategii...
}
#property strict
#property description "Entry EA: EVENT-STYLE FVG + 0.618 system. One Draw parameter controls drawings."

#include <MoneyMaker/Signals/FVG/FvgSystem.mqh>

input bool Draw = true;

int OnInit()
{
   FvgSystem_Init();
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   FvgSystem_Deinit(Draw);
}

void OnTick()
{
   FvgSystem_Process(Draw);
}

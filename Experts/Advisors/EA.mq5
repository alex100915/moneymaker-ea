#property strict
#property description "Entry EA: main orchestrator. 1) detect/draw FVG 2) if FVG -> evaluate+draw 0.618 label. One Draw param controls both."

#include <MoneyMaker/Signals/FVG/FVG.mqh>
#include <MoneyMaker/Signals/FVG/Fvg618Label.mqh>

input bool Draw = true; // JEDEN parametr: steruje FVG + 0.618

static datetime g_mainLastBarTime = 0;

bool IsNewBarMain()
{
   datetime t = iTime(_Symbol, _Period, 0);
   if(t != g_mainLastBarTime)
   {
      g_mainLastBarTime = t;
      return true;
   }
   return false;
}

int OnInit()
{
   FvgInit();
   Fvg618_Init();
   g_mainLastBarTime = 0;
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   // FVG boxy: zgodnie z Draw
   FvgDeinit(Draw);

   // 0.618 labeli NIE kasujemy (zostają na wykresie)
}

void OnTick()
{
   if(!IsNewBarMain())
      return;

   // 1) FVG (logika + rysowanie zależne od Draw)
   FvgTick(Draw);

   // 2) Główny moduł sprawdza czy jest FVG
   int fvgBar, fvgDir;
   if(FvgGetMostRecentFvgBar(fvgBar, fvgDir))
   {
      // 3) Jeśli jest FVG, sprawdza 0.618 na tej świecy + opcjonalnie rysuje label (Draw)
      bool ok = Fvg618_EvaluateAndMaybeDraw(Draw, fvgBar, fvgDir);

      // (opcjonalnie) możesz tu użyć 'ok' do logiki wejścia
      // if(ok) { ... }
   }

   if(Draw)
      ChartRedraw(0);
}

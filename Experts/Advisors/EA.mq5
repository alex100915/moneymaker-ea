#include <MoneyMaker/Signals/FVG/FVG.mqh>
#property strict
#property description "Entry EA: Uses FVG.mqh. Draws FVG optionally and draws permanent 0.618 labels on the most recent FVG candle. 0.618 computed by FVG direction."

// Jedyny input (opcjonalny)
input bool DrawFvg = true;   // rysuj boxy FVG (label 0.618 i tak zawsze będzie rysowane)

// wewnętrzne zmienne
static datetime g_mainLastBarTime = 0;
static datetime g_lastLabeledFvgTime = 0;

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

// FINAL: pozycja labela wg kierunku FVG (bullish nad, bearish pod),
// kolor+symbol wg ok/fail, 0.618 liczone zgodnie z kierunkiem FVG.
void Draw618TextOnMostRecentFvgCandle_KeepHistory()
{
   int fvgBar, fvgDir;
   if(!FvgGetMostRecentFvgBar(fvgBar, fvgDir))
      return;

   // "ostatnia świeca z FVG" = fvgBar (right candle z detekcji)
   datetime t = iTime(_Symbol, _Period, fvgBar);

   // nie duplikuj tego samego wpisu w kółko
   if(t == g_lastLabeledFvgTime)
      return;

   double H = iHigh(_Symbol, _Period, fvgBar);
   double L = iLow(_Symbol, _Period, fvgBar);
   double C = iClose(_Symbol, _Period, fvgBar);

   if(H <= L) return;

   double range = H - L;

   // 0.618 zgodnie z kierunkiem ruchu (jak w Twoim opisie + zgodnie z fibo z platformy)
   // bullish FVG: "close wysoko" => poziom 0.618 od dołu
   // bearish FVG: "close nisko"  => poziom 0.618 od góry
   double levelBull = L + 0.618 * range; // 0.618 (0->Low, 1->High)
   double levelBear = H - 0.618 * range; // 0.618 (0->High, 1->Low)

   bool ok = (fvgDir >= 0) ? (C >= levelBull) : (C <= levelBear);

   // środek świecy w osi czasu
   datetime tMid = t + (datetime)(PeriodSeconds(_Period) / 2);

   // pionowy offset żeby nie siedziało na knocie
   double offset = 25 * _Point;

   // pozycja zależna od KIERUNKU FVG (nie od ok/fail)
   double y = (fvgDir >= 0) ? (H + offset) : (L - offset);

   // tekst i kolor zależne od ok/fail
   string txt = ok ? "0.618 ✓" : "0.618 ✗";
   color  col = ok ? clrLime : clrRed;

   // prefix nie może zaczynać się od "FVG", bo moduł czyści "FVG*"
   string name = "C618#" + TimeToString(t);

   // jeśli już istnieje (np. restart EA), nie dubluj
   if(ObjectFind(0, name) >= 0)
   {
      g_lastLabeledFvgTime = t;
      return;
   }

   if(!ObjectCreate(0, name, OBJ_TEXT, 0, tMid, y))
   {
      Print("OBJ_TEXT create failed: ", GetLastError());
      return;
   }

   ObjectSetString(0, name, OBJPROP_TEXT, txt);
   ObjectSetInteger(0, name, OBJPROP_COLOR, col);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 10);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_CENTER);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);

   g_lastLabeledFvgTime = t;
}

int OnInit()
{
   FvgInit();
   g_mainLastBarTime = 0;
   g_lastLabeledFvgTime = 0;
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   // FVG boxy kasujemy tylko jeśli były rysowane
   FvgDeinit(DrawFvg);

   // labeli 0.618 NIE kasujemy (historia zostaje)
}

void OnTick()
{
   if(!IsNewBarMain())
      return;

   // FVG boxy (opcjonalnie)
   FvgTick(DrawFvg);

   // 0.618 (zostaje na wykresie)
   Draw618TextOnMostRecentFvgCandle_KeepHistory();

   ChartRedraw(0);
}

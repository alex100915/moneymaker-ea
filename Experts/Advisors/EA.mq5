#property strict
#property description "Entry EA: Uses FVG.mqh. Draws FVG optionally and draws permanent 0.618 labels on candle CLOSE of the most recent FVG candle. Test depends on FVG direction."

#include "FVG.mqh"

// Jedyny input (opcjonalny)
input bool DrawFvg = true;   // rysuj boxy FVG (0.618 i tak zawsze będzie rysowane)

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

// Rysuje napis "0.618" na ZAMKNIĘCIU świecy z ostatnim wykrytym FVG.
// Warunek zależy od kierunku FVG (a nie od koloru świecy):
// - bullish FVG: OK jeśli Close >= High - 0.618*(High-Low)
// - bearish FVG: OK jeśli Close <= Low  + 0.618*(High-Low)
void Draw618TextOnMostRecentFvgCandle_KeepHistory()
{
   int fvgBar, fvgDir;
   if(!FvgGetMostRecentFvgBar(fvgBar, fvgDir))
      return;

   datetime t = iTime(_Symbol, _Period, fvgBar);

   // nie duplikuj tego samego wpisu w kółko
   if(t == g_lastLabeledFvgTime)
      return;

   double H = iHigh(_Symbol, _Period, fvgBar);
   double L = iLow(_Symbol, _Period, fvgBar);
   double C = iClose(_Symbol, _Period, fvgBar);

   if(H <= L) return;

   double range = H - L;

   // progi 0.618
   double levelFromTop    = H - 0.618 * range; // close ma być >= dla bullish FVG
   double levelFromBottom = L + 0.618 * range; // close ma być <= dla bearish FVG

   bool ok;
   if(fvgDir >= 0) // bullish FVG
      ok = (C >= levelFromTop);
   else            // bearish FVG
      ok = (C <= levelFromBottom);

   // prefix NIE może zaczynać się od "FVG" (bo FVG.mqh kasuje "FVG*")
   string name = "C618#" + TimeToString(t);

   if(ObjectFind(0, name) >= 0)
   {
      g_lastLabeledFvgTime = t;
      return;
   }

   // napis na CENIE ZAMKNIĘCIA świecy
   if(!ObjectCreate(0, name, OBJ_TEXT, 0, t, C))
   {
      Print("OBJ_TEXT create failed: ", GetLastError());
      return;
   }

   ObjectSetString(0, name, OBJPROP_TEXT, "0.618");
   ObjectSetInteger(0, name, OBJPROP_COLOR, ok ? clrLime : clrRed);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 10);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT);
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

   // 0.618 labeli NIE KASUJEMY
}

void OnTick()
{
   if(!IsNewBarMain())
      return;

   // 1) FVG boxy (opcjonalnie)
   FvgTick(DrawFvg);

   // 2) 0.618 zawsze i zostaje na wykresie
   Draw618TextOnMostRecentFvgCandle_KeepHistory();

   ChartRedraw(0);
}

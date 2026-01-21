#ifndef __FVG618LABEL_MQH__
#define __FVG618LABEL_MQH__

// Stan, żeby nie dublować labela dla tej samej świecy FVG
static datetime g_fvg618_lastLabeledTime = 0;

void Fvg618_Init()
{
   g_fvg618_lastLabeledTime = 0;
}

// Zwraca: true jeśli warunek OK, false jeśli FAIL (gdy nie da się policzyć -> false)
// Parametry:
// - draw: steruje rysowaniem (jak false -> tylko oblicza, nie rysuje)
// - fvgBar: shift świecy "z FVG" (to co zwraca FvgGetMostRecentFvgBar)
// - fvgDir: 1 bullish, -1 bearish
bool Fvg618_EvaluateAndMaybeDraw(bool draw, int fvgBar, int fvgDir)
{
   if(fvgBar < 0) return false;

   datetime t = iTime(_Symbol, _Period, fvgBar);
   if(t == 0) return false;

   double H = iHigh(_Symbol, _Period, fvgBar);
   double L = iLow(_Symbol, _Period, fvgBar);
   double C = iClose(_Symbol, _Period, fvgBar);

   if(H <= L) return false;

   double range = H - L;

   // 0.618 wg kierunku FVG:
   // bullish: level = Low + 0.618*range, OK jeśli Close >= level
   // bearish: level = High - 0.618*range, OK jeśli Close <= level
   double levelBull = L + 0.618 * range;
   double levelBear = H - 0.618 * range;

   bool ok = (fvgDir >= 0) ? (C >= levelBull) : (C <= levelBear);

   // Jeśli nie rysujemy – tylko zwracamy wynik
   if(!draw) return ok;

   // Nie dubluj na każdej świecy/ticku
   if(t == g_fvg618_lastLabeledTime)
      return ok;

   // Środek świecy w osi czasu
   datetime tMid = t + (datetime)(PeriodSeconds(_Period) / 2);

   // Pozycja labela zależna od kierunku FVG (bull nad, bear pod)
   double offset = 25 * _Point;
   double y = (fvgDir >= 0) ? (H + offset) : (L - offset);

   string txt = ok ? "0.618 ✓" : "0.618 ✗";
   color  col = ok ? clrLime : clrRed;

   // UWAGA: prefix nie może zaczynać się od "FVG" bo FVG.mqh czyści "FVG*"
   string name = "C618#" + TimeToString(t);

   // jeśli już istnieje (np. restart EA) – nie twórz drugi raz
   if(ObjectFind(0, name) >= 0)
   {
      g_fvg618_lastLabeledTime = t;
      return ok;
   }

   if(!ObjectCreate(0, name, OBJ_TEXT, 0, tMid, y))
   {
      Print("OBJ_TEXT create failed: ", GetLastError());
      return ok;
   }

   ObjectSetString(0, name, OBJPROP_TEXT, txt);
   ObjectSetInteger(0, name, OBJPROP_COLOR, col);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 10);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_CENTER);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);

   g_fvg618_lastLabeledTime = t;
   return ok;
}

#endif // __FVG618LABEL_MQH__

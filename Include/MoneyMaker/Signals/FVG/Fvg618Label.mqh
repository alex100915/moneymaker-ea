#ifndef __FVG618LABEL_MQH__
#define __FVG618LABEL_MQH__

static datetime g_fvg618_lastLabeledTime = 0;

void Fvg618_Init()
{
   g_fvg618_lastLabeledTime = 0;
}

// Zwraca: true=OK, false=FAIL. Rysuje tylko gdy draw=true.
// Pozycja labela: bullish FVG nad świecą, bearish FVG pod świecą.
// Kolor: OK zielony ✓, FAIL czerwony ✗.
// 0.618 wg kierunku FVG:
// bullish: level=Low+0.618*(H-L), ok jeśli Close>=level
// bearish: level=High-0.618*(H-L), ok jeśli Close<=level
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

   double levelBull = L + 0.618 * range;
   double levelBear = H - 0.618 * range;

   bool ok = (fvgDir >= 0) ? (C >= levelBull) : (C <= levelBear);

   if(!draw) return ok;

   // nie dubluj
   if(t == g_fvg618_lastLabeledTime)
      return ok;

   datetime tMid = t + (datetime)(PeriodSeconds(_Period) / 2);

   double offset = 25 * _Point;
   double y = (fvgDir >= 0) ? (H + offset) : (L - offset);

   string txt = ok ? "0.618 ✓" : "0.618 ✗";
   color  col = ok ? clrLime : clrRed;

   // prefix nie może zaczynać się od "FVG", bo FVG.mqh kasuje "FVG*"
   string name = "C618#" + TimeToString(t);

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

#ifndef IMPULSE_DRAWER_MQH
#define IMPULSE_DRAWER_MQH

#include <MoneyMaker/Signals/ImpulseTypes.mqh>

// =====================================================
// Drawer dla impulsu 1-2-3 (linie + etykiety)
// =====================================================
class CImpulseDrawer
{
private:
   string m_prefix;
   int    m_keepLast;
   int    m_counter;

public:
   CImpulseDrawer()
   {
      m_prefix   = "imp123_";
      m_keepLast = 5;
      m_counter  = 0;
   }

   void Init(const string prefix, const int keepLastPatterns)
   {
      m_prefix   = prefix;
      m_keepLast = keepLastPatterns;
   }

   void Reset()
   {
      ClearAll();
      m_counter = 0;
   }

   void Draw(const SImpulse123 &sig)
   {
      if(!sig.valid) return;

      m_counter++;
      CleanupOld();

      string base = m_prefix + IntegerToString(m_counter) + "_";

      // Fale
      CreateLine(base+"AB", sig.A.t, sig.A.p, sig.B.t, sig.B.p);
      CreateLine(base+"BC", sig.B.t, sig.B.p, sig.C.t, sig.C.p);
      CreateLine(base+"CD", sig.C.t, sig.C.p, sig.D.t, sig.D.p);

      // Etykiety
      CreateText(base+"L1", sig.B.t, sig.B.p, "1");
      CreateText(base+"L2", sig.C.t, sig.C.p, "2");
      CreateText(base+"L3", sig.D.t, sig.D.p, "3");

      // Tag
      CreateText(base+"TAG", sig.D.t, sig.D.p, sig.up ? "IMPULS UP" : "IMPULS DOWN");
   }

   void DrawPivotD(const SImpulse123 &sig, int arrowCode = 233)
   {
      if(!sig.valid) return;

      m_counter++;
      CleanupOld();

      string base = m_prefix + IntegerToString(m_counter) + "_";
      CreateArrow(base+"D", sig.D.t, sig.D.p, arrowCode);
   }

   void ClearAll()
   {
      for(int i=1; i<=m_counter; i++)
         DeletePattern(i);
   }

private:
   void SafeDelete(const string name)
   {
      if(ObjectFind(0, name) >= 0)
         ObjectDelete(0, name);
   }

   void CreateLine(const string name,
                   datetime t1, double p1,
                   datetime t2, double p2)
   {
      SafeDelete(name);
      ObjectCreate(0, name, OBJ_TREND, 0, t1, p1, t2, p2);
      ObjectSetInteger(0, name, OBJPROP_RAY, false);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
   }

   void CreateText(const string name,
                   datetime t, double p,
                   const string text)
   {
      SafeDelete(name);
      ObjectCreate(0, name, OBJ_TEXT, 0, t, p);
      ObjectSetString(0, name, OBJPROP_TEXT, text);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 10);
      ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_CENTER);
   }

   void CreateArrow(const string name,
                    datetime t, double p,
                    int code)
   {
      SafeDelete(name);
      ObjectCreate(0, name, OBJ_ARROW, 0, t, p);
      ObjectSetInteger(0, name, OBJPROP_ARROWCODE, code);
   }

   void DeletePattern(const int id)
   {
      string b = m_prefix + IntegerToString(id) + "_";
      SafeDelete(b+"AB");
      SafeDelete(b+"BC");
      SafeDelete(b+"CD");
      SafeDelete(b+"L1");
      SafeDelete(b+"L2");
      SafeDelete(b+"L3");
      SafeDelete(b+"TAG");
      SafeDelete(b+"D");
   }

   void CleanupOld()
   {
      int killBelow = m_counter - m_keepLast;
      if(killBelow <= 0) return;

      for(int i=1; i<=killBelow; i++)
         DeletePattern(i);
   }
};

#endif // IMPULSE_DRAWER_MQH

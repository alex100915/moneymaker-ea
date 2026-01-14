#ifndef IMPULSE123_COLOR_PIVOTS_MQH
#define IMPULSE123_COLOR_PIVOTS_MQH

#include <MoneyMaker/Signals/ImpulseTypes.mqh>

// anchors+extremes (jak opisałem): w stałym trendzie zawsze powstaje sekwencja H/L/H/L
class CImpulse123ColorPivots
{
private:
   string symbol;
   ENUM_TIMEFRAMES tf;

   int trendLookback;
   int scanBars;

   int atrPeriod;
   double minPivotATR;   // opcjonalnie, może być 0.0 = OFF

   double minWaveATR;
   double minRet2;
   double maxRet2;
   double minWave3x1;
   double maxWave3x1;

   datetime lastDTime;

public:
   CImpulse123ColorPivots()
   {
      symbol = _Symbol;
      tf = _Period;

      trendLookback = 30;
      scanBars = 1200;

      atrPeriod = 14;
      minPivotATR = 0.0;

      minWaveATR = 0.20;
      minRet2 = 0.10;
      maxRet2 = 0.95;
      minWave3x1 = 0.40;
      maxWave3x1 = 5.00;

      lastDTime = 0;
   }

   // ✅ WERSJA 11-param (kompatybilna z Twoim błędem: "11 requires")
   bool Init(string sym, ENUM_TIMEFRAMES timeframe,
             int pTrendLookback, int pScanBars, int pATRPeriod,
             double pMinPivotATR,
             double pMinWaveATR, double pMinRet2, double pMaxRet2,
             double pMinWave3x1, double pMaxWave3x1)
   {
      symbol = sym;
      tf = timeframe;

      trendLookback = pTrendLookback;
      scanBars = pScanBars;

      atrPeriod = pATRPeriod;
      minPivotATR = pMinPivotATR;

      minWaveATR = pMinWaveATR;
      minRet2 = pMinRet2;
      maxRet2 = pMaxRet2;
      minWave3x1 = pMinWave3x1;
      maxWave3x1 = pMaxWave3x1;

      lastDTime = 0;
      return true;
   }

   // ✅ WERSJA 10-param (bez minPivotATR)
   bool Init(string sym, ENUM_TIMEFRAMES timeframe,
             int pTrendLookback, int pScanBars, int pATRPeriod,
             double pMinWaveATR, double pMinRet2, double pMaxRet2,
             double pMinWave3x1, double pMaxWave3x1)
   {
      return Init(sym, timeframe,
                  pTrendLookback, pScanBars, pATRPeriod,
                  0.0,
                  pMinWaveATR, pMinRet2, pMaxRet2,
                  pMinWave3x1, pMaxWave3x1);
   }

   void Deinit() {}

   bool Poll(SImpulse123 &out)
   {
      out.valid = false;

      SPivot A,B,C,D;
      if(!GetLastPivots4(A,B,C,D))
         return false;

      if(D.t == 0 || D.t == lastDTime)
         return false;

      lastDTime = D.t;

      bool up = IsImpulseUp(A,B,C,D);
      bool dn = (!up) && IsImpulseDown(A,B,C,D);
      if(!up && !dn)
         return false;

      out.A = A; out.B = B; out.C = C; out.D = D;
      out.up = up;
      out.valid = true;
      return true;
   }

private:
   bool PrevailingTrendUp()
   {
      int bars = iBars(symbol, tf);
      if(bars <= trendLookback + 10) return false;

      double c0 = iClose(symbol, tf, 0);
      double cL = iClose(symbol, tf, trendLookback);
      return (c0 > cL);
   }

   bool IsBull(const int i) { return iClose(symbol, tf, i) > iOpen(symbol, tf, i); }
   bool IsBear(const int i) { return iClose(symbol, tf, i) < iOpen(symbol, tf, i); }

   double GetATRNow()
   {
      double atr[];
      ArraySetAsSeries(atr, true);
      int h = iATR(symbol, tf, atrPeriod);
      if(h == INVALID_HANDLE) return 0.0;
      int copied = CopyBuffer(h, 0, 0, 1, atr);
      IndicatorRelease(h);
      if(copied <= 0) return 0.0;
      return atr[0];
   }

   SPivot MinLowBetween(int iFrom, int iTo)
   {
      SPivot p; p.i=iFrom; p.p=iLow(symbol,tf,iFrom); p.t=iTime(symbol,tf,iFrom); p.isHigh=false;
      for(int k=iFrom; k<=iTo; k++)
      {
         double L=iLow(symbol,tf,k);
         if(L < p.p){ p.i=k; p.p=L; p.t=iTime(symbol,tf,k); }
      }
      return p;
   }

   SPivot MaxHighBetween(int iFrom, int iTo)
   {
      SPivot p; p.i=iFrom; p.p=iHigh(symbol,tf,iFrom); p.t=iTime(symbol,tf,iFrom); p.isHigh=true;
      for(int k=iFrom; k<=iTo; k++)
      {
         double H=iHigh(symbol,tf,k);
         if(H > p.p){ p.i=k; p.p=H; p.t=iTime(symbol,tf,k); }
      }
      return p;
   }

   bool GetLastPivots4(SPivot &A, SPivot &B, SPivot &C, SPivot &D)
   {
      bool trendUp = PrevailingTrendUp();

      int bars = iBars(symbol, tf);
      if(bars < 200) return false;

      int limit = scanBars;
      if(limit > bars-2) limit = bars-2;

      // anchors: trendUp -> bearish candles (anchor LOW)
      //          trendDn -> bullish candles (anchor HIGH)
      int anchors[];
      ArrayResize(anchors, 0);

      for(int i=0; i<limit; i++)
      {
         bool isAnchor = trendUp ? IsBear(i) : IsBull(i);
         if(!isAnchor) continue;

         int n = ArraySize(anchors);
         ArrayResize(anchors, n+1);
         anchors[n] = i;

         if(ArraySize(anchors) >= 5) break; // wystarczy do zbudowania 4 pivotów
      }

      if(ArraySize(anchors) < 2) return false;

      SPivot pivs[];
      ArrayResize(pivs, 0);

      for(int j=0; j<ArraySize(anchors)-1; j++)
      {
         int i0 = anchors[j];     // newer
         int i1 = anchors[j+1];   // older

         if(trendUp)
         {
            // anchor LOW
            SPivot low; low.i=i0; low.p=iLow(symbol,tf,i0); low.t=iTime(symbol,tf,i0); low.isHigh=false;
            PushPivot(pivs, low);
            if(ArraySize(pivs) >= 4) break;

            SPivot high = MaxHighBetween(i0, i1);
            PushPivot(pivs, high);
            if(ArraySize(pivs) >= 4) break;
         }
         else
         {
            // anchor HIGH
            SPivot high; high.i=i0; high.p=iHigh(symbol,tf,i0); high.t=iTime(symbol,tf,i0); high.isHigh=true;
            PushPivot(pivs, high);
            if(ArraySize(pivs) >= 4) break;

            SPivot low = MinLowBetween(i0, i1);
            PushPivot(pivs, low);
            if(ArraySize(pivs) >= 4) break;
         }
      }

      if(ArraySize(pivs) < 4) return false;

      // optional: minimalny dystans pivotów (OFF gdy minPivotATR<=0)
      if(minPivotATR > 0.0)
      {
         double atr = GetATRNow();
         if(atr > 0.0)
         {
            if(MathAbs(pivs[0].p - pivs[1].p) < minPivotATR*atr) return false;
            if(MathAbs(pivs[1].p - pivs[2].p) < minPivotATR*atr) return false;
            if(MathAbs(pivs[2].p - pivs[3].p) < minPivotATR*atr) return false;
         }
      }

      // pivs[0] newest => D, pivs[3] older => A
      D = pivs[0];
      C = pivs[1];
      B = pivs[2];
      A = pivs[3];
      return true;
   }

   void PushPivot(SPivot &arr[], const SPivot &p)
   {
      int n = ArraySize(arr);
      ArrayResize(arr, n+1);
      arr[n] = p;
   }

   bool IsImpulseUp(const SPivot &A,const SPivot &B,const SPivot &C,const SPivot &D)
   {
      if(!(B.p > A.p)) return false;
      if(!(C.p < B.p && C.p > A.p)) return false;
      if(!(D.p > B.p)) return false;

      double ab = B.p - A.p;
      double bc = B.p - C.p;
      double cd = D.p - C.p;

      double atr = GetATRNow();
      if(atr <= 0.0) return false;

      if(ab < minWaveATR*atr) return false;
      if(cd < minWaveATR*atr) return false;

      double ret2 = bc/ab;
      if(ret2 < minRet2 || ret2 > maxRet2) return false;

      double k = cd/ab;
      if(k < minWave3x1 || k > maxWave3x1) return false;

      return true;
   }

   bool IsImpulseDown(const SPivot &A,const SPivot &B,const SPivot &C,const SPivot &D)
   {
      if(!(B.p < A.p)) return false;
      if(!(C.p > B.p && C.p < A.p)) return false;
      if(!(D.p < B.p)) return false;

      double ab = A.p - B.p;
      double bc = C.p - B.p;
      double cd = C.p - D.p;

      double atr = GetATRNow();
      if(atr <= 0.0) return false;

      if(ab < minWaveATR*atr) return false;
      if(cd < minWaveATR*atr) return false;

      double ret2 = bc/ab;
      if(ret2 < minRet2 || ret2 > maxRet2) return false;

      double k = cd/ab;
      if(k < minWave3x1 || k > maxWave3x1) return false;

      return true;
   }
};

#endif // IMPULSE123_COLOR_PIVOTS_MQH

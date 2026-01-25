#ifndef __FVG_CONDITION_MQH__
#define __FVG_CONDITION_MQH__

#include <MoneyMaker/Signals/FVG/FVG.mqh>
#include <MoneyMaker/Signals/FVG/Fvg618.mqh>

// --- active tracking state ---
static bool g_hasActiveFvg = false;
static FVG_DIRECTION g_activeFvgDirection = FVG_NONE;
static double g_fvgZoneLow = 0.0;
static double g_fvgZoneHigh = 0.0;

bool FvgCondition_IsFulfilled(bool draw)
{
   FvgDetectionResult fvgResult = Fvg_Detect();
   
   // If NEW FVG formed -> start tracking   
   if(fvgResult.hasNewFvg)
   {
      g_fvgZoneLow = fvgResult.zoneLow;
      g_fvgZoneHigh = fvgResult.zoneHigh;
      g_activeFvgDirection = fvgResult.direction;
      g_hasActiveFvg = true;

      if(draw)
         Fvg_Draw(fvgResult);
   }

   // If active FVG -> evaluate 0.618 on each bar until mitigated or 0.618 fulfilled
   if(g_hasActiveFvg && g_activeFvgDirection != FVG_NONE)
   {         
      bool isFvgMitigated = Fvg_CheckMitigation(g_activeFvgDirection, g_fvgZoneLow, g_fvgZoneHigh);

      if(isFvgMitigated)
      {
         if(draw)
            Fvg_DrawMitigatedLabel(g_activeFvgDirection);
         
         g_hasActiveFvg = false;
         g_activeFvgDirection = FVG_NONE;
         
         return false;
      }
      else
      {
         bool valid618Bar = Fvg618_IsValid618Bar(g_activeFvgDirection);

         if(draw)
            Fvg618DrawLabel(g_activeFvgDirection, valid618Bar);

         if(valid618Bar)
         {         
            g_hasActiveFvg = false;
            g_activeFvgDirection = FVG_NONE;
            
            return true;
         }
      }
   }

   return false;
}

#endif // __FVG_CONDITION_MQH__

#ifndef __FVG_SYSTEM_MQH__
#define __FVG_SYSTEM_MQH__

#include "FvgDetector.mqh"
#include "Fvg618.mqh"

// --- active tracking state ---
static bool g_hasActiveFvg = false;
static FVG_DIRECTION g_activeFvgDirection = FVG_NONE;
static double g_fvgZoneLow = 0.0;
static double g_fvgZoneHigh = 0.0;

bool FvgSystem_IsFulfilled(bool draw)
{
   FvgDetectionResult fvgResult = FvgDetector_Detect();
   
   // If NEW FVG formed -> start tracking   
   if(fvgResult.hasNewFvg)
   {
      g_fvgZoneLow = fvgResult.zoneLow;
      g_fvgZoneHigh = fvgResult.zoneHigh;
      g_activeFvgDirection = fvgResult.direction;
      g_hasActiveFvg = true;

      if(draw)
         FvgDetector_Draw(fvgResult);
   }

   // If active FVG -> evaluate 0.618 on each bar until mitigated or 0.618 fulfilled
   if(g_hasActiveFvg && g_activeFvgDirection != FVG_NONE)
   {         
      bool isFvgMitigated = FvgDetector_CheckMitigation(g_activeFvgDirection, g_fvgZoneLow, g_fvgZoneHigh);

      if(isFvgMitigated)
      {
         if(draw)
            FvgDetector_DrawMitigatedLabel(g_activeFvgDirection);
         
         g_hasActiveFvg = false;
         g_activeFvgDirection = FVG_NONE;
         
         return false;
      }
      else
      {
         bool valid618Bar = Fvg618_IsValid618Bar(g_activeFvgDirection);

         if(draw)
            Fvg618_DrawLabel(g_activeFvgDirection, valid618Bar);

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

#endif // __FVG_SYSTEM_MQH__

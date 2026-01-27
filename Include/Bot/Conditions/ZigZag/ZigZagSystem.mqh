#ifndef __ZIGZAG_SYSTEM_MQH__
#define __ZIGZAG_SYSTEM_MQH__

#include "ZigZagDetector.mqh"
#include "ZigZagDraw.mqh"

void ZigZagSystem_Process(bool draw, int lastClosedBarIndex)
{
   ZigZagSegment segment;
   
   if(ZigZagDetector_DetectNewSegment(lastClosedBarIndex, segment))
   {
      if(draw)
      {
         ZigZagDraw_DrawSegment(segment);
      }
   }
}

void ZigZagSystem_Init()
{
   ZigZagDetector_Reset();
}

void ZigZagSystem_Deinit(bool draw)
{   
   ZigZagDetector_Reset();
}

#endif // __ZIGZAG_SYSTEM_MQH__

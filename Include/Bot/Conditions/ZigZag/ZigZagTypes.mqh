#ifndef __ZIGZAG_TYPES_MQH__
#define __ZIGZAG_TYPES_MQH__

enum ZIGZAG_DIRECTION
{
   ZIGZAG_NONE = 0,
   ZIGZAG_UP = 1,
   ZIGZAG_DOWN = -1
};

struct ZigZagSegment
{
   datetime startTime;
   double startPrice;
   datetime endTime;
   double endPrice;
   ZIGZAG_DIRECTION direction;
   int startBarIndex;
   int endBarIndex;
};

#endif // __ZIGZAG_TYPES_MQH__

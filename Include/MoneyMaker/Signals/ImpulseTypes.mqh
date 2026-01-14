#ifndef IMPULSE_TYPES_MQH
#define IMPULSE_TYPES_MQH

struct SPivot
{
   int i;          // index świecy (series)
   double p;       // cena
   datetime t;     // czas
   bool isHigh;    // true=high pivot, false=low pivot (czasem nieużywane)
};

struct SImpulse123
{
   SPivot A,B,C,D;
   bool up;
   bool valid;
};

#endif // IMPULSE_TYPES_MQH

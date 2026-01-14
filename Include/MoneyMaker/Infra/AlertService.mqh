#ifndef ALERT_SERVICE_MQH
#define ALERT_SERVICE_MQH

class CAlertService
{
private:
   bool m_enableAlerts;
   bool m_enablePush;

public:
   CAlertService()
   {
      m_enableAlerts = true;
      m_enablePush   = false;
   }

   void Init(const bool enableAlerts, const bool enablePush)
   {
      m_enableAlerts = enableAlerts;
      m_enablePush   = enablePush;
   }

   void Fire(const string msg)
   {
      Print(msg);

      if(m_enableAlerts)
         Alert(msg);

      if(m_enablePush)
         SendNotification(msg);
   }
};

#endif // ALERT_SERVICE_MQH

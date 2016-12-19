//+------------------------------------------------------------------+
//|                                         bigCandle_conditions.mqh |
//|                                                                  |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright ""
#property link      ""
//+------------------------------------------------------------------+
//|   Trading conditions                                             |
//+------------------------------------------------------------------+

bool checkGeneralTradeConditionsMet() {
  Print("Checking for general conditions before trading...");
  return (
    thereIsNoOpenTrade() &&
    isGoodDayToTrade() &&
    isGoodTimeToTrade()
  ) ? true : false; // false if at least one fails
}

bool thereIsNoOpenTrade(){
   return m_Position.Select(current_symbol) ? false : true;
}

bool isGoodDayToTrade(){
   MqlDateTime time;
   TimeCurrent(time);
   int weekDay = time.day_of_week;
   switch(weekDay) {
         case 0: // Sunday
         case 1: // Monday
		   case 5: // Friday
		   case 6: // Saturday
		   Print("Today is: " + weekDay + "th day of the week (Sunday=0),so not a good day to trade");
            return false; // = bad day to trade
            break;
         default:
          Print("Today is: " + weekDay + "th day of the week (Sunday=0),so a good day to trade");
            return true;
            break;
        }
}

bool isGoodTimeToTrade() {
   MqlDateTime time;
   TimeCurrent(time);
   int tradingStartHour = 2;
   int tradingEndHour = 20;
   int current_hour = time.hour;
   Print("Hour of day that just started: " + current_hour);
   return (current_hour >= tradingStartHour && current_hour <= tradingEndHour)? true : false ;
}


//+------------------------------------------------------------------+
//|   General conditions and checkers                                |
//+------------------------------------------------------------------+


int checkMinBars(){
      if(Bars(_Symbol,_Period)<60) {
      Alert("We have less than 60 bars, EA will now exit!!");
       return(-1);
     }  
     return(0);
}

bool checkIsNewBar(){

   static datetime Old_Time;
   datetime New_Time[1];
   int lastBarTime = CopyTime(current_symbol,current_timeframe,0,1,New_Time);
   if(lastBarTime > 0) {
      if(Old_Time!=New_Time[0]){   
         Old_Time=New_Time[0]; 
         return true; // We have a new bar
        } else {
        return false;
        }
     } else {
         alertCopyTimeFailed();
         return false;
     }
}
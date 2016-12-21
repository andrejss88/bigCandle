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
  
  if(thereIsNoOpenTrade()
    && isGoodDayToTrade() /* &&   isGoodTimeToTrade() */ ){
    return true;
    } else {
    
    return false;
    }

}

/*
 * Checks if there are ANY open trades
 * Returns: true if there is at least one trade open (Buy or Sell)
 */
 
bool thereIsNoOpenTrade(){
   if(m_Position.Select(current_symbol)){
     Print("There is an open position already. Will not trade.");
     return false;
   } else {
    Print("There is no open Trade.");
    return true;
   }
}

/*
 * Checks if trading is allowed on specific days
 * Returns: true if attempt to trade is within allowed range
 */
bool isGoodDayToTrade(){
   MqlDateTime time;
   TimeCurrent(time);
   int weekDay = time.day_of_week;
   switch(weekDay) {
         case 0: // Sunday
         case 1: // Monday
		   case 5: // Friday
		   case 6: // Saturday
		   Print("Today is: " + weekDay + "th day of the week (Monday=1 ... Saturday = 6 ... Sunday=0),so not a good day to trade");
            return false; // = bad day to trade
            break;
         default:
          Print("Today is: " + weekDay + "nd/rd day of the week (Monday=1 ... Saturday = 6 ... Sunday=0),so a good day to trade");
            return true;
            break;
        }
}
/*
 * Checks if trading is allowed during specific times
 * Returns: true if attempt to trade is within allowed range
 */
bool isGoodTimeToTrade() {
   MqlDateTime time;
   TimeCurrent(time);
   int tradingStartHour = 7;
   int tradingEndHour = 20;
   int current_hour = time.hour;
   Print("Hour of day that just started: " + current_hour);
   
   if(current_hour >= tradingStartHour && current_hour <= tradingEndHour){
      Print("Now is a good time to trade");
      return true;
   } else {
      Print("Now is NOT a good time to trade");
      return false;
   }
}

/*
 * Check if current price > open of candle on other (multiple) TimeFrames
 * Returns: true if (Current price > open of current Daily/Weekly)
 */
bool trendIsUp(MqlRates& currentBarRates[]){

   bool dailyIsUp = checkCandleIsUp(currentBarRates, PERIOD_D1);
   bool weeklyIsUp = checkCandleIsUp(currentBarRates, PERIOD_W1);
   
   if (dailyIsUp && weeklyIsUp ) {
      Print("Larger TimeFrame candles are up. Trend is upwards. So OK to Buy.");
      return true;
   } else {
      Print("Larger TimeFrame candles are NOT up. Trend is not upwards. So will NOT  Buy.");
      return false;
   }
}

/*
 * Check if current price < open of candle on other (multiple) TimeFrames
 * Returns: true if (Current price < open of current Daily/Weekly)
 */
 
bool trendIsDown(MqlRates& currentBarRates[]){

   bool dailyIsUp = checkCandleIsUp(currentBarRates, PERIOD_D1);
   bool weeklyIsUp = checkCandleIsUp(currentBarRates, PERIOD_W1);
   
   if (!dailyIsUp && !weeklyIsUp ) {
      Print("Larger TimeFrame candles are down. Trend is downwards. So OK to Sell.");
      return true;
   } else {
      Print("Larger TimeFrame candles are NOT down. Trend is not downwards. So will NOT  Sell.");
      return false;
   }
}

/*
 * Check if current price < open of candle on a single TimeFrame
 * Returns: true if (Current price > open of given TimeFrame)
 */
 
bool checkCandleIsUp(MqlRates & barRates[], ENUM_TIMEFRAMES timeFrame) {
  
  MqlTick last_tick;
  string timeFrameName = convertTimeFrameIDToString(timeFrame);
  Print("Checking if higher TimeFrame(",timeFrameName ,") candle is up."); 
  
    if (SymbolInfoTick(current_symbol, last_tick)) {   
      double difference = NormalizeDouble(last_tick.ask - barRates[1].open,5);
      Print("Ask = ", last_tick.ask," and current bar open:", barRates[1].open, " on timeFrame: ", timeFrameName, ". So difference is: ", difference);
      return difference > 0? true : false;
    
    } else {Print("SymbolInfoTick() failed, error = ", GetLastError());}
 
   // fail the checking if we got this far
   Print("Something went wrong. Failing the candle direction checking on purpose.");
   return false;
}

string convertTimeFrameIDToString(ENUM_TIMEFRAMES timeFrame) {

  switch (timeFrame) {
    case 16408:
      return "Daily";
      break;
    case 32769:
      return "Weekly";
      break;
    default:
      return "Could not identify TimeFrame";
      break;
  }
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
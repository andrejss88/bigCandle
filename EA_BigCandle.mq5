//+------------------------------------------------------------------+
//|                                                 EA_BigCandle.mq5 |
//|                        Copyright 2016, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2016, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>
//--- input parameters
input int      StopLoss=40;
input int      TakeProfit=60;
input int      EA_Magic=220788;
input int      Candles_to_count=5;
input double   Bigger_by=1;
input double   Lot=0.01;
int SL, TP;   // To be used for Stop Loss & Take Profit values
string          current_symbol; 
ENUM_TIMEFRAMES current_timeframe; 

CTrade            m_Trade; 
CPositionInfo     m_Position; 
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
   current_symbol=Symbol();  
   current_timeframe = PERIOD_CURRENT;
   SL = StopLoss;
   TP = TakeProfit;
   
   checkMinBars();
   adaptPointsToBroker();

   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
 
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick(){
  MqlRates barRates[];
  ArraySetAsSeries(barRates,true);
      
  bool isNewBar = checkIsNewBar();  
  if(isNewBar==false){ return; } // else continue
  
  int lastBarInfo = getLastBarInfo(barRates);
  if(lastBarInfo<0) { alertCopyRatesFailed();  return; }
  
  double lastBarBody = calculateLastClosedBarBodySize(barRates); 
  double historicBodyAverage = calculateAverageBarBodySize(barRates, Candles_to_count);  
    
  Print("Last bar body vs. Historic Average: " + lastBarBody + " vs. " + historicBodyAverage);
  
   if(lastBarBody >= historicBodyAverage*Bigger_by) {
     Print("Big candle spotted");
     bool isBullish = checkCandleIsBullish(barRates);
      if(isBullish){
         Print("Candle is bullish");
          openBuy(barRates); 
      } else {
      Print("Candle is bearish");
          openSell(barRates);
      }     
  }  
 
  }
//+------------------------------------------------------------------+

void openBuy(MqlRates& barRates[]){
      if(m_Position.Select(current_symbol)){  //if the position for this symbol already exists
         return;
      } else {
          m_Trade.Buy(Lot,current_symbol,0,barRates[0].close - SL*_Point, barRates[0].close + TP*_Point, "Trying to open a Buy" ); 
      }                   
} 

void openSell(MqlRates& barRates[]){   
       if(m_Position.Select(current_symbol)){  //if the position for this symbol already exists
         return;
      } else {
          m_Trade.Sell(Lot,current_symbol,0,barRates[0].close + SL*_Point, barRates[0].close - TP*_Point, "Trying to open a Sell" ); 
      }
} 



double calculateLastClosedBarBodySize(MqlRates& lastBarRates[]){  
      return NormalizeDouble(MathAbs(lastBarRates[0].open-lastBarRates[0].close),5);
}

bool checkIsNewBar(){

   static datetime Old_Time;
   datetime New_Time[1];
   // https://www.mql5.com/en/docs/series/copytime
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

double calculateAverageBarBodySize(MqlRates& barRates[],int candlesNum){
       int START_POS = 2; // we don't want the last bar, but start with the one after it
       int copied = CopyRates(current_symbol,current_timeframe,START_POS,candlesNum,barRates); 
       double sum = 0;
       double averageBodySize = 0;      
       for(int i=0;i<copied;i++){
          sum = sum +  NormalizeDouble(MathAbs(barRates[i].open-barRates[i].close),5); 
       }
       averageBodySize = NormalizeDouble(sum/candlesNum,5);
       return averageBodySize;
} 

int getLastBarInfo(MqlRates& lastBarRates[]){
   int START_POS = 1;
   return CopyRates(current_symbol,current_timeframe,START_POS,1,lastBarRates);    // https://www.mql5.com/en/docs/series/copyrates
}

bool  checkCandleIsBullish(MqlRates& lastBarRates[]){
      int copied = getLastBarInfo(lastBarRates);   
      if(copied > 0){
         return lastBarRates[0].open < lastBarRates[0].close ? true : false ;
      }  else {
      alertCopyRatesFailed();
      return -1;
     }
}
void alertCopyRatesFailed(){
     Alert("Error in copying rates, error =",GetLastError());
     ResetLastError(); 
}

void alertCopyTimeFailed(){
     Alert("Error in copying historical times data, error =",GetLastError());
     ResetLastError(); 
}
 
int checkMinBars(){
      if(Bars(_Symbol,_Period)<60) {
      Alert("We have less than 60 bars, EA will now exit!!");
       return(-1);
     }  
     return(0);
}

void adaptPointsToBroker(){
    if(_Digits==5 || _Digits==3) {
      SL = SL*10;
      TP = TP*10;
     }
}
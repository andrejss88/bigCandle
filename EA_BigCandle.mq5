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
#include <bigCandle_conditions.mqh> // path needs changing if file is moved
//--- input parameters
input int      StopLoss=3;   // Pips below/above big candle
input int      TakeProfit_scalp=20; // Scalp- Actual num of pips to take
input int      TakeProfit_normal=60; // Normal - Actual num of pips to take
input int      EA_Magic=220788;
input int      Candles_to_count=5;
input double   Bigger_by=2;
input double   Lot=0.01;
int SL, TP_scalp, TP_normal;   // To be used for Stop Loss & Take Profit values
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
   TP_scalp = TakeProfit_scalp;
   TP_normal = TakeProfit_normal;
      
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
    
   if(lastBarBody >= historicBodyAverage*Bigger_by) {
     Print("Big candle spotted." + "Last bar body vs. Historic Average: " + lastBarBody + " vs. " + historicBodyAverage);
     bool isGoodToTrade = checkGeneralTradeConditionsMet();
     if(isGoodToTrade) trade(barRates);
    }  
  }
//+------------------------------------------------------------------+

void trade(MqlRates & barRates[]) {

  bool isBullish = checkCandleIsBullish(barRates);
  
  if (isBullish) {
    Print("Candle is bullish");
    openBuy(barRates);
  } else {
    Print("Candle is bearish");
    openSell(barRates);
  }
}

void openBuy(MqlRates& lastBarRates[]){
   double bullishSL = calculateBullishStopLoss(lastBarRates);
   double barMiddle = calculateLastBarMiddle(lastBarRates);
   datetime expiration=TimeTradeServer()+PeriodSeconds(PERIOD_CURRENT)*2; // multiplier == number of bars that the order will last
   
     // Trade 1 - candle_end_scalp 
    // m_Trade.Buy(Lot,current_symbol,0,bullishSL, lastBarRates[0].close + TP_scalp*_Point, "Trying to open Candle End Scalp Buy" );                  
     
     // Trade 2 - candle_end_normal 
     // m_Trade.Buy(Lot,current_symbol,0,bullishSL, lastBarRates[0].close + TP_normal*_Point, "Trying to open Candle End Normal Buy" );
     
    // Trade 3 - candle_mid_scalp -- the signature has a different order from Buy!!!
     m_Trade.BuyLimit(Lot,barMiddle,current_symbol,bullishSL, lastBarRates[0].close, ORDER_TIME_SPECIFIED,expiration,"Trying to open mid candle Scalp Buy");  
     
    // Trade 4 - candle_mid_normal -- the signature has a different order from Buy!!!
    // TODO - consider playing with this particular TP - maybe use close instead of middle
     m_Trade.BuyLimit(Lot,barMiddle,current_symbol,bullishSL, barMiddle + TP_normal*_Point, ORDER_TIME_SPECIFIED,expiration,"Trying to open mid candle Normal Buy");                
                        
} 

void openSell(MqlRates& lastBarRates[]){   

      double bearishSL = calculateBearishStopLoss(lastBarRates);
      double barMiddle = calculateLastBarMiddle(lastBarRates);
      datetime expiration=TimeTradeServer()+PeriodSeconds(PERIOD_CURRENT)*2; // multiplier == number of bars that the order will last
         
     // Trade 1 - candle_end_scalp 
     m_Trade.Sell(Lot,current_symbol,0,bearishSL, lastBarRates[0].close - TP_scalp*_Point, "Trying to open Candle End Scalp Sell" ); 
     
     // Trade 2 - candle_end_normal  
     m_Trade.Sell(Lot,current_symbol,0,bearishSL, lastBarRates[0].close - TP_normal*_Point,  "Trying to open Candle End Normal Sell" ); 
     
     // Trade 3 - candle_mid_scalp 
     m_Trade.SellLimit(Lot,barMiddle, current_symbol,bearishSL, lastBarRates[0].close - TP_scalp*_Point, ORDER_TIME_SPECIFIED,expiration, "Trying to open mid candle Scalp Sell" ); 
     
     // Trade 4 - candle_mid_normal  
     // TODO - consider playing with this particular TP - maybe use close instead of middle
     m_Trade.SellLimit(Lot,barMiddle, current_symbol,bearishSL, barMiddle - TP_normal*_Point, ORDER_TIME_SPECIFIED,expiration, "Trying to open mid candle Normal Sell"); 
} 

double calculateLastBarMiddle(MqlRates& lastBarRates[]){
 return NormalizeDouble(MathAbs((lastBarRates[0].open+lastBarRates[0].close)/2),5);
}

double calculateBullishStopLoss(MqlRates& lastBarRates[]){
   return lastBarRates[0].open - SL*_Point ;
}

double calculateBearishStopLoss(MqlRates& lastBarRates[]){
   return lastBarRates[0].open + SL*_Point;
}


double calculateLastClosedBarBodySize(MqlRates& lastBarRates[]){  
      return NormalizeDouble(MathAbs(lastBarRates[0].open-lastBarRates[0].close),5);
}

double calculateAverageBarBodySize(MqlRates & barRates[], int candlesNum) {
  int START_POS = 2; // we don't want the last bar, but start with the one after it
  int copied = CopyRates(current_symbol, current_timeframe, START_POS, candlesNum, barRates);
  double sum = 0;
  double averageBodySize = 0;
  for (int i = 0; i < copied; i++) {
    sum = sum + NormalizeDouble(MathAbs(barRates[i].open - barRates[i].close), 5);
  }
  averageBodySize = NormalizeDouble(sum / candlesNum, 5);
  return averageBodySize;
}

int getLastBarInfo(MqlRates & lastBarRates[]) {
  int START_POS = 1;
  return CopyRates(current_symbol, current_timeframe, START_POS, 1, lastBarRates);
}

bool checkCandleIsBullish(MqlRates & lastBarRates[]) {
  int copied = getLastBarInfo(lastBarRates);
  if (copied > 0) {
    return lastBarRates[0].open < lastBarRates[0].close ? true : false;
  } else {
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
 


void adaptPointsToBroker(){
    if(_Digits==5 || _Digits==3) {
      SL = SL*10;
      TP_scalp = TP_scalp*10;
      TP_normal = TP_normal*10;
     }
}

/**
* Quick links: 
* 
* https://www.mql5.com/en/docs/constants/structures
* https://www.mql5.com/en/docs/series/
*/
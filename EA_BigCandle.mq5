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
input int    Bigger_by=6;
input double minPipNumberBeforeMovingStopLoss = 50;
/* optimized to 10. higher = worse, cause SL gets prematurely triggered */
input int      moveSL_by = 10; 
//input int      maxSL_allowed=90;             // maxSL_allowed
input int      TakeProfit_scalp=35;         // TP - scalp
input int      TakeProfit_normal=280;      //  TP - normal
input int      TakeProfit_Big=600;        //  TP - Big
 input double   scalpTrade_Lot=0.02; 
input double   normalTrade_Lot=0.01; 
input double   bigTrade_Lot=0.01;  
int  Candles_to_count, TP_scalp, TP_normal, TP_big, moveSL_by_adjusted;   // To be used for Stop Loss & Take Profit values
double minBigCandleBarSize, maxSL_allowed_adjusted;
int gbpusdMultiplier = 10000;
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
   TP_scalp = TakeProfit_scalp;
   TP_normal = TakeProfit_normal;
   TP_big = TakeProfit_Big;
   moveSL_by_adjusted = moveSL_by; 
  // maxSL_allowed_adjusted = maxSL_allowed;
   // tested these a lot. It doesn't matter much. TP and SL much matter more
   Candles_to_count = 3; 
   minBigCandleBarSize = 60; // 60 overall better than 50, filters out much more, so less trades, 
                             // but improves DrawDown quite a bit

      
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
      
  updateOpenTradeStopLoss();
      
  bool isNewBar = checkIsNewBar();  
  if(isNewBar==false){ return; } // else continue
  
  int lastBarInfo = getBarInfo(barRates);
  if(lastBarInfo<0) { alertCopyRatesFailed();  return; }
  
   
  
  double lastBarBody = calculateLastClosedBarBodySize(barRates); 
  double historicBodyAverage = calculateAverageBarBodySize(barRates, Candles_to_count);  
    
   if(lastBarBody >= historicBodyAverage*Bigger_by) {
     Print("Big candle spotted." + "Last bar body vs. Historic Average: " + lastBarBody + " vs. " + historicBodyAverage);
      bool isGoodToTrade = checkGeneralTradeConditionsMet(barRates);
     if(isGoodToTrade) trade(barRates);
     
    }  
  }
//+------------------------------------------------------------------+

/*
 * Move SL to Open of a position if price moves in favourable direction by X    
*/
void updateOpenTradeStopLoss() {
  MqlTick last_tick;
  double currentPrice;
  if (SymbolInfoTick(current_symbol, last_tick)) {
    currentPrice = last_tick.bid;
  }
  // If there is an open trade
  if (m_Position.Select(current_symbol)) {
    double currentTradeSL = m_Position.StopLoss();
    double currentTradeOpen = m_Position.PriceOpen();
    double currentTradeTP = m_Position.TakeProfit();

    double difference = NormalizeDouble(currentPrice - currentTradeOpen, 5);
    double adjustedDifference = difference * gbpusdMultiplier;

    if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
      if (adjustedDifference > minPipNumberBeforeMovingStopLoss)
        moveBuyStopLoss(currentTradeSL, currentTradeOpen, currentTradeTP);
    } else if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL) {
      // additional check needed for Sell logic
      // to avoid false signals when to move StopLoss
      if (currentPrice < currentTradeOpen) {
        if (adjustedDifference > minPipNumberBeforeMovingStopLoss)
          moveSellStopLoss(currentTradeSL, currentTradeOpen, currentTradeTP);
      }
    }
  }
}

/*
 * Check if SL was already moved, and if not - move it   
*/
void moveBuyStopLoss(double currentTradeSL, double currentTradeOpen, double currentTradeTP) {
  if (currentTradeSL < currentTradeOpen) {
    double newStopLoss = currentTradeOpen + (moveSL_by_adjusted * _Point) ;
    double newTakeProfit = currentTradeTP; // keep TP as is
    Print("Price moved far enough in favourable direction. Moving SL up for protection.");
    m_Trade.PositionModify(current_symbol, newStopLoss, newTakeProfit);
  } /* else { Print("SL is already greater than or equal to Buy's Open. Not going to do anything."); } */
}

/*
 * Check if SL was already moved, and if not - move it   
*/
void moveSellStopLoss(double currentTradeSL, double currentTradeOpen, double currentTradeTP) {
  if (currentTradeSL > currentTradeOpen) {
    double newStopLoss = currentTradeOpen - (moveSL_by_adjusted * _Point);
    double newTakeProfit = currentTradeTP; // keep TP as is
    Print("Price moved far enough in favourable direction. Moving SL down for protection.");
    m_Trade.PositionModify(current_symbol, newStopLoss, newTakeProfit);
  } /*else {  Print("SL is already lower than or equal to Sell's Open. Not going to do anything."); } */

}



void trade(MqlRates & barRates[]) {

  bool isBullish = checkCandleIsBullish(barRates);

  if (isBullish) {
    Print("Candle is bullish");
   // if (trendIsUp()) 
    
    openBuy(barRates);
  } else {
    Print("Candle is bearish");
   // if (trendIsDown())
     openSell(barRates);
  }
}

void openBuy(MqlRates& barRates[]){

   double bullishSL = calculateBullishStopLoss(barRates);
           
      // Trade 1 - candle_end_scalp 
      m_Trade.Buy(scalpTrade_Lot,current_symbol,0,bullishSL, barRates[1].close + TP_scalp*_Point, "Trying to open Candle End Scalp Buy" );               
       
     // Trade 2 - candle_end_normal 
     m_Trade.Buy(normalTrade_Lot,current_symbol,0,bullishSL, barRates[1].close + TP_normal*_Point, "Trying to open Candle End Normal Buy" );   
      
     // Trade 3 - candle_end_normal 
     m_Trade.Buy(bigTrade_Lot,current_symbol,0,bullishSL, barRates[1].close + TP_big*_Point, "Trying to open Candle End Big Buy" );   
      
       

     
     /* mid candle rarely works - decided to eliminate for now - also simplifies logic, which is good */     
     /* what about buy stops ? */ 
                        
} 

void openSell(MqlRates& barRates[]){   

      double bearishSL = calculateBearishStopLoss(barRates);
      
      // Trade 1 - candle_end_scalp 
      m_Trade.Sell(scalpTrade_Lot,current_symbol,0,bearishSL, barRates[1].close - TP_scalp*_Point, "Trying to open Candle End Scalp Sell" ); 
       
      // Trade 2  - candle_end_normal  
      m_Trade.Sell(normalTrade_Lot,current_symbol,0,bearishSL, barRates[1].close - TP_normal*_Point,  "Trying to open Candle End Normal Sell" ); 
    
       // Trade 3  - candle_end_Big 
       m_Trade.Sell(bigTrade_Lot,current_symbol,0,bearishSL, barRates[1].close - TP_big*_Point,  "Trying to open Candle End Big  Sell" ); 
     
} 

double calculateLastBarMiddle(MqlRates & barRates[]) {
  return NormalizeDouble(MathAbs((barRates[1].open + barRates[1].close) / 2), 5);
}

/**
 * Set StopLoss at bottom of candle
 */
double calculateBullishStopLoss(MqlRates & barRates[]) {
   /* double maxStopLoss = getMaxStopLoss(barRates, true);
    double difference = NormalizeDouble((barRates[1].close - barRates[1].low)*gbpusdMultiplier,5);
    return difference < maxStopLoss ? barRates[1].low : maxStopLoss;
    */
     return barRates[1].low   /*- SL*_Point   */ ;
}

/**
 * Set StopLoss at top of candle
 */
double calculateBearishStopLoss(MqlRates & barRates[]) {
/*
   double maxStopLoss = getMaxStopLoss(barRates, false);
   double difference = NormalizeDouble((barRates[1].high - barRates[1].close)*gbpusdMultiplier,5);
   return difference < maxStopLoss ? barRates[1].high : maxStopLoss;
   */ 
   return barRates[1].high  /*+ SL * _Point*/;
}

/**
 * Get max allowed Stop Loss defined as Input
 */
double getMaxStopLoss(MqlRates & barRates[], bool isBullishCandle){
      double candleClose = barRates[1].close ;
      
      if(isBullishCandle) {
          return (candleClose - maxSL_allowed_adjusted*_Point);
      } else {
         return (candleClose + maxSL_allowed_adjusted*_Point);
      }
}

/**
* For comparison with last closed
*/
double calculateAverageBarBodySize(MqlRates & barRates[], int candlesNum) {
  int start_pos = 2 ; // we don't want 0 (current open bar) nor 1 (last Closed bar, which is compared against the rest)
  double sum = 0;
  double averageBodySize = 0;
  for (int i = start_pos; i <= candlesNum; i++) {
    sum = sum + NormalizeDouble(MathAbs(barRates[i].open - barRates[i].close), 5);
  }
  averageBodySize = NormalizeDouble(sum / candlesNum, 5);
  return averageBodySize;
}

int getBarInfo(MqlRates & barRates[]) {
  int START_POS = 0;
  int bars_to_copy = 10; // don't need more than 10 for the purpose of this EA
  return CopyRates(current_symbol, current_timeframe, START_POS, bars_to_copy, barRates);
}

bool checkCandleIsBullish(MqlRates & barRates[]) {
  int copied = getBarInfo(barRates);
  if (copied > 0) {
    return barRates[1].open < barRates[1].close ? true : false;
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
      TP_scalp = TP_scalp*10;
      TP_normal = TP_normal*10;
      TP_big = TP_big*10;
      moveSL_by_adjusted = moveSL_by_adjusted *10; 
     // maxSL_allowed_adjusted = maxSL_allowed_adjusted * 10;
     }
}

/**
* Quick links: 
* 
* https://www.mql5.com/en/docs/constants/structures
* https://www.mql5.com/en/docs/series/
*/
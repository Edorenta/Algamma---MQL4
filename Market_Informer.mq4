/*      .=====================================.
       /                                       \
      .               Market Info               .
      |               by Edorenta               |
      '                 Algamma                 '
       \                                       /
        '====================================='
*/

#property link "https://github.com/Edorenta"
#property indicator_chart_window

/*    .-----------------------.
      |    EXTERNAL INPUTS    |
      '-----------------------'
*/
extern bool ShowMarketInfo = true;
extern bool ShowAccountStatus = true;
extern string myobj = "azerty";           // random string to give unique name to the objects
extern double startinglevel = 2.03;
extern color textcolor = White;
extern int startbarno = 1;
extern int spacebetweenlines = 5;

/*    .-----------------------.
      |       STATICS         |
      '-----------------------'
*/
int counter = 0;
double nextlinelevel = 0;
double ModeLow;
double ModeHigh;
double ModeTime;
double ModeBid;
double ModeAsk;
double ModePoint;
double ModeDigits;
double ModeSpread;
double ModeStopLevel;
double ModeFreezeLevel;
double ModeLotSize;
double ModeTickValue;
double ModeTickSize;
double ModeSwapLong;
double ModeSwapShort;
double ModeStarting;
double ModeExpiration;
double ModeTradeAllowed;
double ModeMinLot, ModeMaxLot;
double ModeLotStep;

/*    .-----------------------.
      |         INIT          |
      '-----------------------'
*/
int init()
{
   AccountStatus();  
   GetMarketInfo();
   return(0);
}

/*    .-----------------------.
      |        DEINIT         |
      '-----------------------'
*/
int deinit()
{
   for (int i=counter;i>0;i--)
   ObjectDelete(myobj+i);  

   return(0);
}

/*    .-----------------------.
      |        PRINT          |
      '-----------------------'
*/
int start()
{
   int counted_bars=IndicatorCounted();

   return(0);
}
  
int PrintOnGraph(string mytext)
{
   if (nextlinelevel == 0)
      nextlinelevel = startinglevel;
   else
      nextlinelevel = nextlinelevel;
   counter++;   

          ObjectCreate(myobj+counter, OBJ_LABEL, 0, Time[startbarno], nextlinelevel);
          ObjectSet(myobj+counter, OBJPROP_CORNER, 0);                    
          ObjectSet(myobj+counter, OBJPROP_XDISTANCE, nextlinelevel);                    
          ObjectSet(myobj+counter, OBJPROP_YDISTANCE, nextlinelevel+counter*spacebetweenlines);                    
          ObjectSet(myobj+counter, OBJPROP_COLOR, textcolor);                    
          ObjectSet(myobj+counter, OBJPROP_BACK, true);          
          ObjectSetText(myobj+counter, mytext, 12);   
          
   return ( 0 );
}

int AccountStatus()
{
   if(ShowAccountStatus == True )
   {
   double tickSize        = MarketInfo(Symbol(), MODE_TICKSIZE);
   double tickValue       = MarketInfo(Symbol(), MODE_TICKVALUE);
   double marginRequired  = MarketInfo(Symbol(), MODE_MARGINREQUIRED);
   double lotValue        = Close[0]/tickSize * tickValue;
   double leverage        = lotValue/marginRequired;

       Print ("Intrument Leverage: (1:", DoubleToStr(MathRound(leverage), 0) +")");
       Print ("Account Leverage:", AccountLeverage());
       Print ("Account Company:", AccountCompany());
       Print ("Account Credit:", AccountCredit());
       Print ("Account Currency:", AccountCurrency());
       Print ("Account FreeMargin:", AccountFreeMargin());
       Print ("Account Margin:", AccountMargin());
       Print ("Account Name:", AccountName());
       Print ("Account Number:", AccountNumber());

       PrintOnGraph ("Account Leverage: "+ AccountLeverage());
       PrintOnGraph ("Intrument Leverage: (1:"+ DoubleToStr(MathRound(leverage), 0) +")");
       PrintOnGraph ("Account Company: "+ AccountCompany());
       PrintOnGraph ("Account Credit: "+ AccountCredit());
       PrintOnGraph ("Account Currency: "+ AccountCurrency());
       PrintOnGraph ("Account FreeMargin: "+ AccountFreeMargin());
       PrintOnGraph ("Account Margin: "+ AccountMargin());
       PrintOnGraph ("Account Name: "+ AccountName());
       PrintOnGraph ("Account Number: "+ AccountNumber());
   }    
   return ( 0 );
}

int GetMarketInfo()
{
   ModePoint = MarketInfo(Symbol(), MODE_POINT);
   ModeDigits = MarketInfo(Symbol(), MODE_DIGITS);
   ModeSpread = MarketInfo(Symbol(), MODE_SPREAD);
   ModeStopLevel = MarketInfo(Symbol(), MODE_STOPLEVEL);
   ModeFreezeLevel = MarketInfo(Symbol(), MODE_FREEZELEVEL);
   ModeLotSize = MarketInfo(Symbol(), MODE_LOTSIZE);
   ModeTickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
   ModeTickSize = MarketInfo(Symbol(), MODE_TICKSIZE);
   ModeSwapLong = MarketInfo(Symbol(), MODE_SWAPLONG);
   ModeSwapShort = MarketInfo(Symbol(), MODE_SWAPSHORT);
   ModeStarting = MarketInfo(Symbol(), MODE_STARTING);
   ModeExpiration = MarketInfo(Symbol(), MODE_EXPIRATION);
   ModeTradeAllowed = MarketInfo(Symbol(), MODE_TRADEALLOWED);
   ModeMinLot = MarketInfo(Symbol(), MODE_MINLOT);
   ModeMaxLot = MarketInfo(Symbol(), MODE_MAXLOT);
   ModeLotStep = MarketInfo(Symbol(), MODE_LOTSTEP);

   if ( ShowMarketInfo == True )
   {
       Print("Mode Point:",ModePoint);
       Print("Mode Digits:",ModeDigits);
       Print("Mode Spread:",ModeSpread);
       Print("Mode StopLevel:",ModeStopLevel);
       Print("Mode FreezeLevel:",ModeFreezeLevel);
       Print("Mode LotSize:",ModeLotSize);
       Print("Mode TickValue:",ModeTickValue);
       Print("Mode TickSize:",ModeTickSize);
       Print("Mode SwapLong:",ModeSwapLong);
       Print("Mode SwapShort:",ModeSwapShort);
       Print("Mode Starting:",ModeStarting);
       Print("Mode Expiration:",ModeExpiration);
       Print("Mode TradeAllowed:",ModeTradeAllowed);
       Print("Mode MinLot:",ModeMinLot);
       Print("Mode LotStep:",ModeLotStep);
       
       PrintOnGraph("Mode Point: "+ModePoint);
       PrintOnGraph("Mode Digits: "+ModeDigits);
       PrintOnGraph("Mode Spread: "+ModeSpread);
       PrintOnGraph("Mode StopLevel: "+ModeStopLevel);
       PrintOnGraph("Mode FreezeLevel: "+ModeFreezeLevel);
       PrintOnGraph("Mode LotSize: "+ModeLotSize);
       PrintOnGraph("Mode TickValue: "+ModeTickValue);
       PrintOnGraph("Mode TickSize: "+ModeTickSize);
       PrintOnGraph("Mode SwapLong: "+ModeSwapLong);
       PrintOnGraph("Mode SwapShort: "+ModeSwapShort);
       PrintOnGraph("Mode Starting: "+ModeStarting);
       PrintOnGraph("Mode Expiration: "+ModeExpiration);
       PrintOnGraph("Mode TradeAllowed: "+ModeTradeAllowed);
       PrintOnGraph("Mode MinLot: "+ModeMinLot);
       PrintOnGraph("Mode LotStep: "+ModeLotStep);  
   }
   return (0);
}

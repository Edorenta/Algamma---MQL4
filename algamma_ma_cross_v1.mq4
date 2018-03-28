/*      .=====================================.
       /            Algamma MA Cross           \
      |               by Edorenta               |
       \                Algamma                /
        '====================================='
*/
#property link          "https://github.com/Edorenta"
#property copyright     "Algamma, Paul de Renty"
#property description   "MA Based Algorithm"
#property version       "1.0"
string    version =     "1.0";
#property strict
#include <stdlib.mqh>

    /*    .-----------------------.
          |    EXTERNAL INPUTS    |
          '-----------------------'
    */

extern bool one_trade_per_bar = true; //Trade Once a Candle
extern int ma1_p = 50; //MA1 Calculation Period
extern ENUM_APPLIED_PRICE ma1_price_mode = 0; //Applied MA1 Price Type
extern ENUM_MA_METHOD ma1_mode = MODE_EMA; //MA1 Type

extern int ma2_p = 100; //MA2 Calculation Period
extern ENUM_APPLIED_PRICE ma2_price_mode = 0; //Applied MA2 Price Type
extern ENUM_MA_METHOD ma2_mode = MODE_EMA; //MA2 Type

enum rkm {
    fixed_m_risk, //Fixed Money $$ [AL0]
    fixed_pct_risk, //Fixed Equity %(on init) [AL1]
    dyna_pct_risk, //Dynamic Equity % [AL2]
};
extern rkm risk_mode = dyna_pct_risk; //Money at Risk Calculation [Auto Lotsize]

extern double b_money = 1; //Base $ Investment [AL0]
extern double b_money_risk = 0.02; //Base % Equity Investment [AL1/AL2]

extern string __5__ = "---------------------------------------------------------------------------------------------------------"; //[------------   SCALE SETTINGS   ------------]

enum mm {
    classic, //Classic [MM0]
    mart, //Martingale [MM1]
    r_mart, //Anti-Martingale [MM1]
    scale, //Scale-in Loss [MM2]
    r_scale, //Scale-in Profit [MM2]
};
extern mm mm_mode = classic; //Money Management Mode [Custom MM]

extern double xtor = 1.6; //Martingale Target Multiplier [MM1]
extern double increment = 100; //Scaler Target Increment % [MM2]

extern string __6__ = "---------------------------------------------------------------------------------------------------------"; //[------------   RISK SETTINGS   ------------]

extern double max_xtor = 30; //Max Multiplier [MM1]
extern double max_increment = 1000; //Max Increment % [MM2]

extern int max_risk_trades = 7; //Max Recovery Trades
extern double emergency_stop_pc = 10; //Equity Drawdown Stop (%K)
extern bool negative_margin = false; //Allow Negative Margin

extern string __7__ = "---------------------------------------------------------------------------------------------------------"; //[------------   BROKER SETTINGS   ------------]

extern int max_spread = 15; //Max Spread (Points)
extern int magic = 101; //Orders Magic Number
extern int slippage = 15; //Execution Slippage

extern string __8__ = "---------------------------------------------------------------------------------------------------------"; //[------------   GUI SETTINGS   ------------]

extern bool show_gui = true; //Show The EA GUI
extern color color1 = LightGray; //EA's name color
extern color color2 = DarkOrange; //EA's balance & info color
extern color color3 = Turquoise; //EA's profit color
extern color color4 = Magenta; //EA's loss color

//Data count variables initialization

double max_acc_dd = 0;
double max_acc_dd_pc = 0;
double max_dd = 0;
double max_dd_pc = 0;
double max_acc_runup = 0;
double max_acc_runup_pc = 0;
double max_runup = 0;
double max_runup_pc = 0;
int max_chain_win = 0;
int max_chain_loss = 0;
int max_histo_spread = 0;

bool ongoing_long = false;
bool ongoing_short = false;

double starting_equity = 0;
int current_bar = 0;

/*    .-----------------------.
      |        ON INIT        |
      '-----------------------'
*/

int OnInit() {
    starting_equity = AccountEquity();
    if (show_gui == true) {
        HUD();
    }
    EA_name();
    return (INIT_SUCCEEDED);
}

/*    .-----------------------.
      |       ON DEINIT       |
      '-----------------------'
*/
/*
int OnDeinit(){
   return(0);
}
*/

/*    .-----------------------.
      |        ON TICK        |
      '-----------------------'
*/

void OnTick() {

    if (show_gui == true) {
        GUI();
    }

    check_if_close();

    if (current_bar != Bars) {
        if (one_trade_per_bar == true) current_bar = Bars;
        if (trading_authorized() == true) {

            int nb_longs = trades_info(1);
            int nb_shorts = trades_info(2);
            int nb_trades = nb_longs + nb_shorts;

            entry_logic();
        }
    }
}

/*    .-----------------------.
      |        ON INIT        |
      '-----------------------'
*/

void check_if_close() {

    if (negative_margin == false && AccountFreeMargin() <= 0) close_all();
    if ((AccountEquity() - AccountBalance()) / AccountBalance() < -(emergency_stop_pc / 100)) close_all();
}

void close_all() {

    for (int i = OrdersTotal() - 1; i >= 0; i--) {
        if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
        if (OrderSymbol() == Symbol() && OrderMagicNumber() == magic) {
            if (OrderType() == OP_BUY) {
                int ticket = OrderClose(OrderTicket(), OrderLots(), Bid, slippage, Turquoise);
            }
            if (OrderType() == OP_SELL) {
                int ticket = OrderClose(OrderTicket(), OrderLots(), Ask, slippage, Magenta);
            }
        }
    }
}

void close_longs() {

    for (int i = OrdersTotal() - 1; i >= 0; i--) {
        if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
        if (OrderSymbol() == Symbol() && OrderMagicNumber() == magic) {
            if (OrderType() == OP_BUY) {
                int ticket = OrderClose(OrderTicket(), OrderLots(), Bid, slippage, Turquoise);
            }
        }
    }
}

void close_shorts() {

    for (int i = OrdersTotal() - 1; i >= 0; i--) {
        if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
        if (OrderSymbol() == Symbol() && OrderMagicNumber() == magic) {
            if (OrderType() == OP_SELL) {
                int ticket = OrderClose(OrderTicket(), OrderLots(), Ask, slippage, Magenta);
            }
        }
    }
}

/*    .-----------------------.
      |      ENTRY LOGIC      |
      '-----------------------'
*/

void entry_logic() {

    double MA1 = iMA(Symbol(), 0, ma1_p, 0, ma1_mode, ma1_price_mode, 0);
    double MA2 = iMA(Symbol(), 0, ma2_p, 0, ma2_mode, ma2_price_mode, 0);

    if (MA1 >= MA2) {
        if (trades_info(1) == 0) BUY();
        if (trades_info(2) != 0) close_shorts();
    }
    if (MA2 >= MA1) {
        if (trades_info(2) == 0) SELL();
        if (trades_info(1) != 0) close_longs();
    }
}

/*    .-----------------------.
      |      ORDER SEND       |
      '-----------------------'
*/

void BUY() {
    int ticket = OrderSend(Symbol(), OP_BUY, lotsize(), Ask, slippage, 0, 0, "Algamma MA Cross " + DoubleToStr(lotsize(), 2) + " on " + Symbol(), magic, 0, Turquoise);
    if (ticket < 0) {
        Comment("OrderSend Error: ", ErrorDescription(GetLastError()));
    } else {
        Comment("Order Sent Successfully, Ticket # is: " + string(ticket));
    }
}

void SELL() {
    int ticket = OrderSend(Symbol(), OP_SELL, lotsize(), Bid, slippage, 0, 0, "Algamma MA Cross " + DoubleToStr(lotsize(), 2) + " on " + Symbol(), magic, 0, Magenta);
    if (ticket < 0) {
        Comment("OrderSend Error: ", ErrorDescription(GetLastError()));
    } else {
        Comment("Order Sent Successfully, Ticket # is: " + string(ticket));
    }
}

/*    .-----------------------.
      |      L/S COUNTER      |
      '-----------------------'
*/

double trades_info(int key) {

    double nb_longs = 0, nb_shorts = 0, nb_trades = 0, nb = 0;

    for (int i = OrdersTotal() - 1; i >= 0; i--) {
        if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
        if (OrderSymbol() == Symbol() && OrderMagicNumber() == magic) {
            if (OrderType() == OP_BUY) {
                nb_longs++;
            }
            if (OrderType() == OP_SELL) {
                nb_shorts++;
            }
        }
    }
    nb_trades = nb_longs + nb_shorts;

    switch (key) {
    case 1:
        nb = nb_longs;
        break;
    case 2:
        nb = nb_shorts;
        break;
    case 3:
        nb = nb_trades;
        break;
    }
    return (nb);
}

/*    .-----------------------.
      |     LOTSIZE CALC      |
      '-----------------------'
*/
double lotsize() {

    int chain_win = data_counter(6);
    int chain_loss = data_counter(5);

    double temp_lots = 0, mlots = 0;
    double equity = AccountEquity();
    double margin = AccountFreeMargin();
    double maxlot = MarketInfo(Symbol(), MODE_MAXLOT);
    double minlot = MarketInfo(Symbol(), MODE_MINLOT);
    double pip_value = MarketInfo(Symbol(), MODE_TICKVALUE);
    double pip_size = MarketInfo(Symbol(), MODE_TICKSIZE);
    double lot_qt = MarketInfo(Symbol(), MODE_LOTSIZE);
    double margin_req = MarketInfo(Symbol(), MODE_MARGINREQUIRED);
    double lot_value = Close[0] / pip_size * pip_value;
    double leverage = lot_value / margin_req;
    double money_in = 0;
    int lot_digits = (int) - MathLog(MarketInfo(Symbol(), MODE_LOTSTEP));

    switch (risk_mode) {
    case fixed_m_risk:
        money_in = b_money;
        break;
    case fixed_pct_risk:
        money_in = b_money_risk * starting_equity;
        break;
    case dyna_pct_risk:
        money_in = b_money_risk * equity;
        break;
    }

    temp_lots = NormalizeDouble((money_in / lot_value), lot_digits);

    switch (mm_mode) {
    case mart:
        mlots = NormalizeDouble(temp_lots * (MathPow(xtor, (chain_loss + 1))), 2);
        if (mlots > temp_lots * max_xtor) mlots = NormalizeDouble(temp_lots * max_xtor, 2);
        break;
    case scale:
        mlots = temp_lots + ((increment / 100) * chain_loss) * temp_lots;
        if (mlots > temp_lots * (1 + (max_increment / 100))) mlots = temp_lots * (1 + (max_increment / 100));
        break;
    case r_mart:
        mlots = NormalizeDouble(temp_lots * (MathPow(xtor, (chain_win + 1))), 2);
        if (mlots > temp_lots * max_xtor) mlots = NormalizeDouble(temp_lots * max_xtor, 2);
        break;
    case r_scale:
        mlots = temp_lots + ((increment / 100) * chain_win) * temp_lots;
        if (mlots > temp_lots * (1 + (max_increment / 100))) mlots = temp_lots * (1 + (max_increment / 100));
        break;
    case classic:
        mlots = temp_lots;
        break;
    }

    if (mlots < minlot) mlots = minlot;
    if (mlots > maxlot) mlots = maxlot;

    return (mlots);
}

/*    .-----------------------.
      |        FILTERS        |
      '-----------------------'
*/

bool trading_authorized() {
    int trade_condition = 1;

    if (spread_okay() == false) trade_condition = 0;

    if (trade_condition == 1) {
        return (true);
    } else {
        return (false);
    }
}

bool spread_okay() {
    bool spread_filter_off = true;
    if (trades_info(3) == 0) {
        if (MarketInfo(Symbol(), MODE_SPREAD) >= max_spread) {
            spread_filter_off = false;
        }
    }
    return (spread_filter_off);
}

/*    .-----------------------.
      |       EARNINGS        |
      '-----------------------'
*/

double earnings(int shift) {
    double aggregated_profit = 0;
    for (int position = 0; position < OrdersHistoryTotal(); position++) {
        if (!(OrderSelect(position, SELECT_BY_POS, MODE_HISTORY))) break;
        if (OrderSymbol() == Symbol() && OrderMagicNumber() == magic)
            if (OrderCloseTime() >= iTime(Symbol(), PERIOD_D1, shift) && OrderCloseTime() < iTime(Symbol(), PERIOD_D1, shift) + 86400) aggregated_profit = aggregated_profit + OrderProfit() + OrderCommission() + OrderSwap();
    }
    return (aggregated_profit);
}

/*    .-----------------------.
      |        GET DATA       |
      '-----------------------'
*/

double data_counter(int key) {

    double count_tot = 0, balance = AccountBalance(), equity = AccountEquity();
    double drawdown = 0, runup = 0, lots = 0, profit = 0;

    switch (key) {

    case (1): //All time wins counter
        for (int i = 0; i < OrdersHistoryTotal(); i++) {
            if (!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) continue;
            if (OrderMagicNumber() == magic && OrderSymbol() == Symbol() && OrderProfit() > 0) {
                count_tot++;
            }
        }
        break;

    case (2): //All time loss counter
        for (int i = 0; i < OrdersHistoryTotal(); i++) {
            if (!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) continue;
            if (OrderMagicNumber() == magic && OrderSymbol() == Symbol() && OrderProfit() < 0) {
                count_tot++;
            }
        }
        break;

    case (3): //All time profit
        for (int i = 0; i < OrdersHistoryTotal(); i++) {
            if (!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) continue;
            if (OrderMagicNumber() == magic && OrderSymbol() == Symbol()) {
                profit = profit + OrderProfit() + OrderCommission() + OrderSwap();
            }
            count_tot = profit;
        }
        break;

    case (4): //All time lots
        for (int i = 0; i < OrdersHistoryTotal(); i++) {
            if (!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) continue;
            if (OrderMagicNumber() == magic && OrderSymbol() == Symbol()) {
                lots = lots + OrderLots();
            }
            count_tot = lots;
        }
        break;

    case (5): //Chain Loss
        for (int i = 0; i < OrdersHistoryTotal(); i++) {
            if (!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) continue;
            if (OrderMagicNumber() == magic && OrderSymbol() == Symbol() && OrderProfit() < 0) {
                count_tot++;
            }
            if (OrderMagicNumber() == magic && OrderSymbol() == Symbol() && OrderProfit() > 0) {
                count_tot = 0;
            }
            if (OrderMagicNumber() == magic && OrderSymbol() == Symbol() && OrderProfit() < 0 && count_tot > max_risk_trades) count_tot = 0;
        }
        break;

    case (6): //Chain Win
        for (int i = 0; i < OrdersHistoryTotal(); i++) {
            if (!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) continue;
            if (OrderMagicNumber() == magic && OrderSymbol() == Symbol() && OrderProfit() > 0) {
                count_tot++;
            }
            if (OrderMagicNumber() == magic && OrderSymbol() == Symbol() && OrderProfit() < 0) {
                count_tot = 0;
            }
            if (OrderMagicNumber() == magic && OrderSymbol() == Symbol() && OrderProfit() > 0 && count_tot > max_risk_trades) count_tot = 0;
        }
        break;

    case (7): //Chart Drawdown % (if equity < balance)
        for (int i = 0; i < OrdersTotal(); i++) {
            if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
            if (OrderMagicNumber() == magic && OrderSymbol() == Symbol()) {
                profit = profit + OrderProfit() + OrderCommission() + OrderSwap();
            }
        }
        if (profit > 0) drawdown = 0;
        else drawdown = NormalizeDouble((profit / balance) * 100, 2);
        count_tot = drawdown;
        break;

    case (8): //Acc Drawdown % (if equity < balance)
        if (equity >= balance) drawdown = 0;
        else drawdown = NormalizeDouble(((equity - balance) * 100) / balance, 2);
        count_tot = drawdown;
        break;

    case (9): //Chart dd money (if equity < balance)
        for (int i = 0; i < OrdersTotal(); i++) {
            if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
            if (OrderMagicNumber() == magic && OrderSymbol() == Symbol()) {
                profit = profit + OrderProfit() + OrderCommission() + OrderSwap();
            }
        }
        if (profit >= 0) drawdown = 0;
        else drawdown = profit;
        count_tot = drawdown;
        break;

    case (10): //Acc dd money (if equiy < balance)
        if (equity >= balance) drawdown = 0;
        else drawdown = equity - balance;
        count_tot = drawdown;
        break;

    case (11): //Chart Runup %
        for (int i = 0; i < OrdersTotal(); i++) {
            if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
            if (OrderMagicNumber() == magic && OrderSymbol() == Symbol()) {
                profit = profit + OrderProfit() + OrderCommission() + OrderSwap();
            }
        }
        if (profit < 0) runup = 0;
        else runup = NormalizeDouble((profit / balance) * 100, 2);
        count_tot = runup;
        break;

    case (12): //Acc Runup %
        if (equity < balance) runup = 0;
        else runup = NormalizeDouble(((equity - balance) * 100) / balance, 2);
        count_tot = runup;
        break;

    case (13): //Chart runup money
        for (int i = 0; i < OrdersTotal(); i++) {
            if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
            if (OrderMagicNumber() == magic && OrderSymbol() == Symbol()) {
                profit = profit + OrderProfit() + OrderCommission() + OrderSwap();
            }
        }
        if (profit < 0) runup = 0;
        else runup = profit;
        count_tot = runup;
        break;

    case (14): //Acc runup money
        if (equity < balance) runup = 0;
        else runup = equity - balance;
        count_tot = runup;
        break;

    case (15): //Current profit here
        for (int i = 0; i < OrdersTotal(); i++) {
            if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
            if (OrderMagicNumber() == magic && OrderSymbol() == Symbol()) {
                profit = profit + OrderProfit() + OrderCommission() + OrderSwap();
            }
        }
        count_tot = profit;
        break;

    case (16): //Current profit acc
        count_tot = AccountProfit();
        break;

    case (17): //Gross profits
        for (int i = 0; i < OrdersHistoryTotal(); i++) {
            if (!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) continue;
            if (OrderMagicNumber() == magic && OrderSymbol() == Symbol() && OrderProfit() > 0) {
                profit = profit + OrderProfit() + OrderCommission() + OrderSwap();
            }
        }
        count_tot = profit;
        break;

    case (18): //Gross loss
        for (int i = 0; i < OrdersHistoryTotal(); i++) {
            if (!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) continue;
            if (OrderMagicNumber() == magic && OrderSymbol() == Symbol() && OrderProfit() < 0) {
                profit = profit + OrderProfit() + OrderCommission() + OrderSwap();
            }
        }
        count_tot = profit;
        break;

    case (19): //Weird Sum 4 Target calculation
        for (int i = 0; i < OrdersTotal(); i++) {
            if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
            if (OrderMagicNumber() == magic && OrderSymbol() == Symbol()) {
                count_tot = OrderLots() * (OrderCommission() + OrderOpenPrice());
            }
        }

    case (20): //Current lots long
        for (int i = 0; i < OrdersTotal(); i++) {
            if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
            if (OrderMagicNumber() == magic && OrderSymbol() == Symbol() && OrderType() == OP_BUY) {
                count_tot = count_tot + OrderLots();
            }
        }

    case (21): //Current lots short
        for (int i = 0; i < OrdersTotal(); i++) {
            if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
            if (OrderMagicNumber() == magic && OrderSymbol() == Symbol() && OrderType() == OP_SELL) {
                count_tot = count_tot + OrderLots();
            }
        }
        break;
    }
    return (count_tot);
}

/*    .-----------------------.
      |       GUI BUILD       |
      '-----------------------'
*/

//--- HUD Rectangle
void HUD() {
    ObjectCreate(ChartID(), "HUD", OBJ_RECTANGLE_LABEL, 0, 0, 0);
    //--- set label coordinates
    ObjectSetInteger(ChartID(), "HUD", OBJPROP_XDISTANCE, 0);
    ObjectSetInteger(ChartID(), "HUD", OBJPROP_YDISTANCE, 28);
    //--- set label size
    ObjectSetInteger(ChartID(), "HUD", OBJPROP_XSIZE, 280);
    ObjectSetInteger(ChartID(), "HUD", OBJPROP_YSIZE, 600);
    //--- set background color
    ObjectSetInteger(ChartID(), "HUD", OBJPROP_BGCOLOR, clrBlack);
    //--- set border type
    ObjectSetInteger(ChartID(), "HUD", OBJPROP_BORDER_TYPE, BORDER_FLAT);
    //--- set the chart's corner, relative to which point coordinates are defined
    ObjectSetInteger(ChartID(), "HUD", OBJPROP_CORNER, 4);
    //--- set flat border color (in Flat mode)
    ObjectSetInteger(ChartID(), "HUD", OBJPROP_COLOR, clrWhite);
    //--- set flat border line style
    ObjectSetInteger(ChartID(), "HUD", OBJPROP_STYLE, STYLE_SOLID);
    //--- set flat border width
    ObjectSetInteger(ChartID(), "HUD", OBJPROP_WIDTH, 1);
    //--- display in the foreground (false) or background (true)
    ObjectSetInteger(ChartID(), "HUD", OBJPROP_BACK, false);
    //--- enable (true) or disable (false) the mode of moving the label by mouse
    ObjectSetInteger(ChartID(), "HUD", OBJPROP_SELECTABLE, false);
    ObjectSetInteger(ChartID(), "HUD", OBJPROP_SELECTED, false);
    //--- hide (true) or display (false) graphical object name in the object list
    ObjectSetInteger(ChartID(), "HUD", OBJPROP_HIDDEN, true);
    //--- set the priority for receiving the event of a mouse click in the chart
    ObjectSetInteger(ChartID(), "HUD", OBJPROP_ZORDER, 0);
}

void GUI() {

    int total_wins = data_counter(1);
    int total_loss = data_counter(2);
    int total_trades = total_wins + total_loss;
    int total_opened_trades = trades_info(3);

    double total_profit = data_counter(3);
    double total_volumes = data_counter(4);
    int chain_loss = data_counter(5);
    int chain_win = data_counter(6);

    double chart_dd_pc = data_counter(7);
    double acc_dd_pc = data_counter(8);
    double chart_dd = data_counter(9);
    double acc_dd = data_counter(10);

    double chart_runup_pc = data_counter(11);
    double acc_runup_pc = data_counter(12);
    double chart_runup = data_counter(13);
    double acc_runup = data_counter(14);

    double chart_profit = data_counter(15);
    double acc_profit = data_counter(16);

    double gross_profits = data_counter(17);
    double gross_loss = data_counter(18);

    //pnl vs profit factor
    double profit_factor;
    if (gross_loss != 0 && gross_profits != 0) profit_factor = NormalizeDouble(gross_profits / MathAbs(gross_loss), 2);

    //Total volumes vs Average
    double av_volumes;
    if (total_volumes != 0 && total_trades != 0) av_volumes = NormalizeDouble(total_volumes / total_trades, 2);

    //Total trades vs winrate
    int winrate;
    if (total_trades != 0) winrate = (total_wins * 100 / total_trades);

    //Relative DD vs Max DD %
    if (chart_dd_pc < max_dd_pc) max_dd_pc = chart_dd_pc;
    if (acc_dd_pc < max_acc_dd_pc) max_acc_dd_pc = acc_dd_pc;
    //Relative DD vs Max DD $$
    if (chart_dd < max_dd) max_dd = chart_dd;
    if (acc_dd < max_acc_dd) max_acc_dd = acc_dd;

    //Relative runup vs Max runup %
    if (chart_runup_pc > max_runup_pc) max_runup_pc = chart_runup_pc;
    if (acc_runup_pc > max_acc_runup_pc) max_acc_runup_pc = acc_runup_pc;
    //Relative runup vs Max runup $$
    if (chart_runup > max_runup) max_runup = chart_runup;
    if (acc_runup > max_acc_runup) max_acc_runup = acc_runup;

    //Spread vs Maxspread
    if (MarketInfo(Symbol(), MODE_SPREAD) > max_histo_spread) max_histo_spread = MarketInfo(Symbol(), MODE_SPREAD);

    //Chains vs Max chains
    if (chain_loss > max_chain_loss) max_chain_loss = chain_loss;
    if (chain_win > max_chain_win) max_chain_win = chain_win;

    //--- Currency crypt

    string curr = "none";

    if (AccountCurrency() == "USD") curr = "$";
    if (AccountCurrency() == "JPY") curr = "¥";
    if (AccountCurrency() == "EUR") curr = "€";
    if (AccountCurrency() == "GBP") curr = "£";
    if (AccountCurrency() == "CHF") curr = "CHF";
    if (AccountCurrency() == "AUD") curr = "A$";
    if (AccountCurrency() == "CAD") curr = "C$";
    if (AccountCurrency() == "RUB") curr = "руб";

    if (curr == "none") curr = AccountCurrency();

    //--- Equity / balance / floating

    string txt1, content;
    int content_len = StringLen(content);

    txt1 = version + "50";
    if (ObjectFind(txt1) == -1) {
        ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
        ObjectSet(txt1, OBJPROP_CORNER, 4);
        ObjectSet(txt1, OBJPROP_XDISTANCE, 0);
        ObjectSet(txt1, OBJPROP_YDISTANCE, 75);
    }
    ObjectSetText(txt1, "_______________________________", 13, "Century Gothic", color1);

    txt1 = version + "51";
    if (ObjectFind(txt1) == -1) {
        ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
        ObjectSet(txt1, OBJPROP_CORNER, 4);
        ObjectSet(txt1, OBJPROP_XDISTANCE, 108);
        ObjectSet(txt1, OBJPROP_YDISTANCE, 94);
    }
    ObjectSetText(txt1, "Portfolio", 12, "Century Gothic", color1);

    txt1 = version + "52";
    if (ObjectFind(txt1) == -1) {
        ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
        ObjectSet(txt1, OBJPROP_CORNER, 4);
        ObjectSet(txt1, OBJPROP_XDISTANCE, 0);
        ObjectSet(txt1, OBJPROP_YDISTANCE, 99);
    }
    ObjectSetText(txt1, "_______________________________", 13, "Century Gothic", color1);

    txt1 = version + "100";
    if (AccountEquity() >= AccountBalance()) {
        if (ObjectFind(txt1) == -1) {
            ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
            ObjectSet(txt1, OBJPROP_CORNER, 4);
            ObjectSet(txt1, OBJPROP_XDISTANCE, 15);
            ObjectSet(txt1, OBJPROP_YDISTANCE, 117);
        }

        if (chart_profit == 0) ObjectSetText(txt1, "Equity : " + DoubleToStr(AccountEquity(), 2) + curr, 16, "Century Gothic", color3);
        if (chart_profit != 0) ObjectSetText(txt1, "Equity : " + DoubleToStr(AccountEquity(), 2) + curr, 11, "Century Gothic", color3);
    }
    if (AccountEquity() < AccountBalance()) {
        if (ObjectFind(txt1) == -1) {
            ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
            ObjectSet(txt1, OBJPROP_CORNER, 4);
            ObjectSet(txt1, OBJPROP_XDISTANCE, 15);
            ObjectSet(txt1, OBJPROP_YDISTANCE, 117);
        }
        if (chart_profit == 0) ObjectSetText(txt1, "Equity : " + DoubleToStr(AccountEquity(), 2) + curr, 16, "Century Gothic", color4);
        if (chart_profit != 0) ObjectSetText(txt1, "Equity : " + DoubleToStr(AccountEquity(), 2) + curr, 11, "Century Gothic", color4);
    }

    txt1 = version + "101";
    if (chart_profit > 0) {
        if (ObjectFind(txt1) == -1) {
            ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
            ObjectSet(txt1, OBJPROP_CORNER, 4);
            ObjectSet(txt1, OBJPROP_XDISTANCE, 15);
            ObjectSet(txt1, OBJPROP_YDISTANCE, 135);
        }
        ObjectSetText(txt1, "Floating chart P&L : +" + DoubleToStr(chart_profit, 2) + curr, 9, "Century Gothic", color3);
    }
    if (chart_profit < 0) {
        if (ObjectFind(txt1) == -1) {
            ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
            ObjectSet(txt1, OBJPROP_CORNER, 4);
            ObjectSet(txt1, OBJPROP_XDISTANCE, 15);
            ObjectSet(txt1, OBJPROP_YDISTANCE, 135);
        }
        ObjectSetText(txt1, "Floating chart P&L : " + DoubleToStr(chart_profit, 2) + curr, 9, "Century Gothic", color4);
    }
    if (total_opened_trades == 0) ObjectDelete(txt1);

    txt1 = version + "102";
    if (ObjectFind(txt1) == -1) {
        ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
        ObjectSet(txt1, OBJPROP_CORNER, 4);
        ObjectSet(txt1, OBJPROP_XDISTANCE, 15);
        if (total_opened_trades == 0) ObjectSet(txt1, OBJPROP_YDISTANCE, 152);
        if (total_opened_trades != 0) ObjectSet(txt1, OBJPROP_YDISTANCE, 152);
    }
    if (total_opened_trades == 0) ObjectSetText(txt1, "Balance : " + DoubleToStr(AccountBalance(), 2) + curr, 9, "Century Gothic", color2);
    if (total_opened_trades != 0) ObjectSetText(txt1, "Balance : " + DoubleToStr(AccountBalance(), 2) + curr, 9, "Century Gothic", color2);

    //--- Analytics

    txt1 = version + "53";
    if (ObjectFind(txt1) == -1) {
        ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
        ObjectSet(txt1, OBJPROP_CORNER, 4);
        ObjectSet(txt1, OBJPROP_XDISTANCE, 0);
        ObjectSet(txt1, OBJPROP_YDISTANCE, 156);
    }
    ObjectSetText(txt1, "_______________________________", 13, "Century Gothic", color1);

    txt1 = version + "54";
    if (ObjectFind(txt1) == -1) {
        ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
        ObjectSet(txt1, OBJPROP_CORNER, 4);
        ObjectSet(txt1, OBJPROP_XDISTANCE, 108);
        ObjectSet(txt1, OBJPROP_YDISTANCE, 175);
    }
    ObjectSetText(txt1, "Analytics", 12, "Century Gothic", color1);

    txt1 = version + "55";
    if (ObjectFind(txt1) == -1) {
        ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
        ObjectSet(txt1, OBJPROP_CORNER, 4);
        ObjectSet(txt1, OBJPROP_XDISTANCE, 0);
        ObjectSet(txt1, OBJPROP_YDISTANCE, 180);
    }
    ObjectSetText(txt1, "_______________________________", 13, "Century Gothic", color1);

    txt1 = version + "200";
    if (ObjectFind(txt1) == -1) {
        ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
        ObjectSet(txt1, OBJPROP_CORNER, 4);
        ObjectSet(txt1, OBJPROP_XDISTANCE, 15);
        ObjectSet(txt1, OBJPROP_YDISTANCE, 200);
    }
    if (chart_runup >= 0) {
        ObjectSetText(txt1, "Chart runup : " + DoubleToString(chart_runup_pc, 2) + "% [" + DoubleToString(chart_runup, 2) + curr + "]", 8, "Century Gothic", color3);
    }
    if (chart_dd < 0) {
        ObjectSetText(txt1, "Chart drawdown : " + DoubleToString(chart_dd_pc, 2) + "% [" + DoubleToString(chart_dd, 2) + curr + "]", 8, "Century Gothic", color4);
    }

    txt1 = version + "201";
    if (ObjectFind(txt1) == -1) {
        ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
        ObjectSet(txt1, OBJPROP_CORNER, 4);
        ObjectSet(txt1, OBJPROP_XDISTANCE, 15);
        ObjectSet(txt1, OBJPROP_YDISTANCE, 212);
    }
    if (acc_runup >= 0) {
        ObjectSetText(txt1, "Acc runup : " + DoubleToString(acc_runup_pc, 2) + "% [" + DoubleToString(acc_runup, 2) + curr + "]", 8, "Century Gothic", color3);
    }
    if (acc_dd < 0) {
        ObjectSetText(txt1, "Acc DD : " + DoubleToString(acc_dd_pc, 2) + "% [" + DoubleToString(acc_dd, 2) + curr + "]", 8, "Century Gothic", color4);
    }

    txt1 = version + "202";
    if (ObjectFind(txt1) == -1) {
        ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
        ObjectSet(txt1, OBJPROP_CORNER, 4);
        ObjectSet(txt1, OBJPROP_XDISTANCE, 15);
        ObjectSet(txt1, OBJPROP_YDISTANCE, 224);
    }
    ObjectSetText(txt1, "Max chart runup : " + DoubleToString(max_runup_pc, 2) + "% [" + DoubleToString(max_runup, 2) + curr + "]", 8, "Century Gothic", color2);

    txt1 = version + "203";
    if (ObjectFind(txt1) == -1) {
        ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
        ObjectSet(txt1, OBJPROP_CORNER, 4);
        ObjectSet(txt1, OBJPROP_XDISTANCE, 15);
        ObjectSet(txt1, OBJPROP_YDISTANCE, 236);
    }
    ObjectSetText(txt1, "Max chart drawdon : " + DoubleToString(max_dd_pc, 2) + "% [" + DoubleToString(max_dd, 2) + curr + "]", 8, "Century Gothic", color2);

    txt1 = version + "204";
    if (ObjectFind(txt1) == -1) {
        ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
        ObjectSet(txt1, OBJPROP_CORNER, 4);
        ObjectSet(txt1, OBJPROP_XDISTANCE, 15);
        ObjectSet(txt1, OBJPROP_YDISTANCE, 248);
    }
    ObjectSetText(txt1, "Max acc runup : " + DoubleToString(max_acc_runup_pc, 2) + "% [" + DoubleToString(max_acc_runup, 2) + curr + "]", 8, "Century Gothic", color2);

    txt1 = version + "205";
    if (ObjectFind(txt1) == -1) {
        ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
        ObjectSet(txt1, OBJPROP_CORNER, 4);
        ObjectSet(txt1, OBJPROP_XDISTANCE, 15);
        ObjectSet(txt1, OBJPROP_YDISTANCE, 260);
    }
    ObjectSetText(txt1, "Max acc drawdown : " + DoubleToString(max_acc_dd_pc, 2) + "% [" + DoubleToString(max_acc_dd, 2) + curr + "]", 8, "Century Gothic", color2);

    txt1 = version + "206";
    if (ObjectFind(txt1) == -1) {
        ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
        ObjectSet(txt1, OBJPROP_CORNER, 4);
        ObjectSet(txt1, OBJPROP_XDISTANCE, 15);
        ObjectSet(txt1, OBJPROP_YDISTANCE, 271);
    }
    ObjectSetText(txt1, "Trades won : " + IntegerToString(total_wins, 0) + " II Trades lost : " + IntegerToString(total_loss, 0) + " [" + DoubleToString(winrate, 0) + "% winrate]", 8, "Century Gothic", color2);

    txt1 = version + "207";
    if (ObjectFind(txt1) == -1) {
        ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
        ObjectSet(txt1, OBJPROP_CORNER, 4);
        ObjectSet(txt1, OBJPROP_XDISTANCE, 15);
        ObjectSet(txt1, OBJPROP_YDISTANCE, 284);
    }
    ObjectSetText(txt1, "W-Chain : " + IntegerToString(chain_win, 0) + " [Max : " + IntegerToString(max_chain_win, 0) + "] II L-Chain : " + IntegerToString(chain_loss, 0) + " [Max : " + IntegerToString(max_chain_loss, 0) + "]", 8, "Century Gothic", color2);

    txt1 = version + "208";
    if (ObjectFind(txt1) == -1) {
        ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
        ObjectSet(txt1, OBJPROP_CORNER, 4);
        ObjectSet(txt1, OBJPROP_XDISTANCE, 15);
        ObjectSet(txt1, OBJPROP_YDISTANCE, 296);
    }
    ObjectSetText(txt1, "Overall volume traded : " + DoubleToString(total_volumes, 2) + " lots", 8, "Century Gothic", color2);

    txt1 = version + "209";
    if (ObjectFind(txt1) == -1) {
        ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
        ObjectSet(txt1, OBJPROP_CORNER, 4);
        ObjectSet(txt1, OBJPROP_XDISTANCE, 15);
        ObjectSet(txt1, OBJPROP_YDISTANCE, 308);
    }
    ObjectSetText(txt1, "Average volume /trade : " + DoubleToString(av_volumes, 2) + " lots", 8, "Century Gothic", color2);

    txt1 = version + "210";
    if (ObjectFind(txt1) == -1) {
        ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
        ObjectSet(txt1, OBJPROP_CORNER, 4);
        ObjectSet(txt1, OBJPROP_XDISTANCE, 15);
        ObjectSet(txt1, OBJPROP_YDISTANCE, 320);
    }
    string expectancy;
    if (total_trades != 0) expectancy = DoubleToStr(total_profit / total_trades, 2);

    if (total_trades != 0 && total_profit / total_trades > 0) {
        ObjectSetText(txt1, "Payoff expectancy /trade : " + expectancy + curr, 8, "Century Gothic", color3);
    }
    if (total_trades != 0 && total_profit / total_trades < 0) {
        ObjectSetText(txt1, "Payoff expectancy /trade : " + expectancy + curr, 8, "Century Gothic", color4);
    }
    if (total_trades == 0) {
        ObjectSetText(txt1, "Payoff expectancy /trade : NA", 8, "Century Gothic", color3);
    }

    txt1 = version + "211";
    if (total_trades != 0 && profit_factor >= 1) {
        if (ObjectFind(txt1) == -1) {
            ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
            ObjectSet(txt1, OBJPROP_CORNER, 4);
            ObjectSet(txt1, OBJPROP_XDISTANCE, 15);
            ObjectSet(txt1, OBJPROP_YDISTANCE, 332);
        }
        ObjectSetText(txt1, "Profit factor : " + DoubleToString(profit_factor, 2), 8, "Century Gothic", color3);
    }
    if (total_trades != 0 && profit_factor < 1) {
        if (ObjectFind(txt1) == -1) {
            ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
            ObjectSet(txt1, OBJPROP_CORNER, 4);
            ObjectSet(txt1, OBJPROP_XDISTANCE, 15);
            ObjectSet(txt1, OBJPROP_YDISTANCE, 332);
        }
        ObjectSetText(txt1, "Profit factor : " + DoubleToString(profit_factor, 2), 8, "Century Gothic", color4);
    }
    if (total_trades == 0) {
        if (ObjectFind(txt1) == -1) {
            ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
            ObjectSet(txt1, OBJPROP_CORNER, 4);
            ObjectSet(txt1, OBJPROP_XDISTANCE, 15);
            ObjectSet(txt1, OBJPROP_YDISTANCE, 332);
        }
        ObjectSetText(txt1, "Profit factor : NA", 8, "Century Gothic", color3);
    }
    //--- earnings

    txt1 = version + "56";
    if (ObjectFind(txt1) == -1) {
        ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
        ObjectSet(txt1, OBJPROP_CORNER, 4);
        ObjectSet(txt1, OBJPROP_XDISTANCE, 0);
        ObjectSet(txt1, OBJPROP_YDISTANCE, 335);
    }
    ObjectSetText(txt1, "_______________________________", 13, "Century Gothic", color1);

    txt1 = version + "57";
    if (ObjectFind(txt1) == -1) {
        ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
        ObjectSet(txt1, OBJPROP_CORNER, 4);
        ObjectSet(txt1, OBJPROP_XDISTANCE, 108);
        ObjectSet(txt1, OBJPROP_YDISTANCE, 354);
    }
    ObjectSetText(txt1, "Earnings", 12, "Century Gothic", color1);

    txt1 = version + "58";
    if (ObjectFind(txt1) == -1) {
        ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
        ObjectSet(txt1, OBJPROP_CORNER, 4);
        ObjectSet(txt1, OBJPROP_XDISTANCE, 0);
        ObjectSet(txt1, OBJPROP_YDISTANCE, 360);
    }
    ObjectSetText(txt1, "_______________________________", 13, "Century Gothic", color1);

    double profitx = earnings(0);
    txt1 = version + "300";
    if (ObjectFind(txt1) == -1) {
        ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
        ObjectSet(txt1, OBJPROP_CORNER, 4);
        ObjectSet(txt1, OBJPROP_XDISTANCE, 15);
        ObjectSet(txt1, OBJPROP_YDISTANCE, 380);
    }
    ObjectSetText(txt1, "earnings today : " + DoubleToStr(profitx, 2) + curr, 8, "Century Gothic", color2);

    profitx = earnings(1);
    txt1 = version + "301";
    if (ObjectFind(txt1) == -1) {
        ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
        ObjectSet(txt1, OBJPROP_CORNER, 4);
        ObjectSet(txt1, OBJPROP_XDISTANCE, 15);
        ObjectSet(txt1, OBJPROP_YDISTANCE, 392);
    }
    ObjectSetText(txt1, "earnings yesterday : " + DoubleToStr(profitx, 2) + curr, 8, "Century Gothic", color2);

    profitx = earnings(2);
    txt1 = version + "302";
    if (ObjectFind(txt1) == -1) {
        ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
        ObjectSet(txt1, OBJPROP_CORNER, 4);
        ObjectSet(txt1, OBJPROP_XDISTANCE, 15);
        ObjectSet(txt1, OBJPROP_YDISTANCE, 404);
    }
    ObjectSetText(txt1, "earnings before yesterday : " + DoubleToStr(profitx, 2) + curr, 8, "Century Gothic", color2);

    txt1 = version + "303";
    if (total_profit >= 0) {
        if (ObjectFind(txt1) == -1) {
            ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
            ObjectSet(txt1, OBJPROP_CORNER, 4);
            ObjectSet(txt1, OBJPROP_XDISTANCE, 15);
            ObjectSet(txt1, OBJPROP_YDISTANCE, 416);
        }
        ObjectSetText(txt1, "All time profit : " + DoubleToString(total_profit, 2) + curr, 8, "Century Gothic", color3);
    }
    if (total_profit < 0) {
        if (ObjectFind(txt1) == -1) {
            ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
            ObjectSet(txt1, OBJPROP_CORNER, 4);
            ObjectSet(txt1, OBJPROP_XDISTANCE, 15);
            ObjectSet(txt1, OBJPROP_YDISTANCE, 416);
        }
        ObjectSetText(txt1, "All time loss : " + DoubleToString(total_profit, 2) + curr, 8, "Century Gothic", color4);
    }

    //--- Broker & Account

    txt1 = version + "59";
    if (ObjectFind(txt1) == -1) {
        ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
        ObjectSet(txt1, OBJPROP_CORNER, 4);
        ObjectSet(txt1, OBJPROP_XDISTANCE, 0);
        ObjectSet(txt1, OBJPROP_YDISTANCE, 419);
    }
    ObjectSetText(txt1, "_______________________________", 13, "Century Gothic", color1);

    txt1 = version + "60";
    if (ObjectFind(txt1) == -1) {
        ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
        ObjectSet(txt1, OBJPROP_CORNER, 4);
        ObjectSet(txt1, OBJPROP_XDISTANCE, 70);
        ObjectSet(txt1, OBJPROP_YDISTANCE, 438);
    }
    ObjectSetText(txt1, "Broker Information", 12, "Century Gothic", color1);

    txt1 = version + "61";
    if (ObjectFind(txt1) == -1) {
        ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
        ObjectSet(txt1, OBJPROP_CORNER, 4);
        ObjectSet(txt1, OBJPROP_XDISTANCE, 0);
        ObjectSet(txt1, OBJPROP_YDISTANCE, 443);
    }
    ObjectSetText(txt1, "_______________________________", 13, "Century Gothic", color1);

    txt1 = version + "400";
    if (ObjectFind(txt1) == -1) {
        ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
        ObjectSet(txt1, OBJPROP_CORNER, 4);
        ObjectSet(txt1, OBJPROP_XDISTANCE, 15);
        ObjectSet(txt1, OBJPROP_YDISTANCE, 463);
    }
    ObjectSetText(txt1, "Spread : " + DoubleToString(MarketInfo(Symbol(), MODE_SPREAD), 0) + " pts [Max : " + DoubleToString(max_histo_spread, 0) + " pts]", 8, "Century Gothic", color2);

    txt1 = version + "401";
    if (ObjectFind(txt1) == -1) {
        ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
        ObjectSet(txt1, OBJPROP_CORNER, 4);
        ObjectSet(txt1, OBJPROP_XDISTANCE, 15);
        ObjectSet(txt1, OBJPROP_YDISTANCE, 475);
    }
    ObjectSetText(txt1, "ID : " + AccountCompany(), 8, "Century Gothic", color2);

    txt1 = version + "402";
    if (ObjectFind(txt1) == -1) {
        ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
        ObjectSet(txt1, OBJPROP_CORNER, 4);
        ObjectSet(txt1, OBJPROP_XDISTANCE, 15);
        ObjectSet(txt1, OBJPROP_YDISTANCE, 487);
    }
    ObjectSetText(txt1, "Server : " + AccountServer(), 8, "Century Gothic", color2);

    txt1 = version + "403";
    if (ObjectFind(txt1) == -1) {
        ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
        ObjectSet(txt1, OBJPROP_CORNER, 4);
        ObjectSet(txt1, OBJPROP_XDISTANCE, 15);
        ObjectSet(txt1, OBJPROP_YDISTANCE, 499);
    }
    ObjectSetText(txt1, "Freeze lvl : " + IntegerToString(MarketInfo(Symbol(), MODE_FREEZELEVEL), 0) + " pts II Stop lvl : " + IntegerToString(MarketInfo(Symbol(), MODE_STOPLEVEL), 0) + " pts", 8, "Century Gothic", color2);

    txt1 = version + "404";
    if (ObjectFind(txt1) == -1) {
        ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
        ObjectSet(txt1, OBJPROP_CORNER, 4);
        ObjectSet(txt1, OBJPROP_XDISTANCE, 15);
        ObjectSet(txt1, OBJPROP_YDISTANCE, 511);
    }
    ObjectSetText(txt1, "L-Swap : " + DoubleToStr(MarketInfo(Symbol(), MODE_SWAPLONG), 2) + curr + "/lot II S-Swap : " + DoubleToStr(MarketInfo(Symbol(), MODE_SWAPSHORT), 2) + curr + "/lot", 8, "Century Gothic", color2);

    txt1 = version + "62";
    if (ObjectFind(txt1) == -1) {
        ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
        ObjectSet(txt1, OBJPROP_CORNER, 4);
        ObjectSet(txt1, OBJPROP_XDISTANCE, 0);
        ObjectSet(txt1, OBJPROP_YDISTANCE, 514);
    }
    ObjectSetText(txt1, "_______________________________", 13, "Century Gothic", color1);

    txt1 = version + "63";
    if (ObjectFind(txt1) == -1) {
        ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
        ObjectSet(txt1, OBJPROP_CORNER, 4);
        ObjectSet(txt1, OBJPROP_XDISTANCE, 108);
        ObjectSet(txt1, OBJPROP_YDISTANCE, 533);
    }
    ObjectSetText(txt1, "Account", 12, "Century Gothic", color1);

    txt1 = version + "64";
    if (ObjectFind(txt1) == -1) {
        ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
        ObjectSet(txt1, OBJPROP_CORNER, 4);
        ObjectSet(txt1, OBJPROP_XDISTANCE, 0);
        ObjectSet(txt1, OBJPROP_YDISTANCE, 538);
    }
    ObjectSetText(txt1, "_______________________________", 13, "Century Gothic", color1);

    txt1 = version + "500";
    if (ObjectFind(txt1) == -1) {
        ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
        ObjectSet(txt1, OBJPROP_CORNER, 4);
        ObjectSet(txt1, OBJPROP_XDISTANCE, 15);
        ObjectSet(txt1, OBJPROP_YDISTANCE, 558);
    }
    ObjectSetText(txt1, "ID : " + AccountName() + " [#" + IntegerToString(AccountNumber(), 0) + "]", 8, "Century Gothic", color2);

    txt1 = version + "501";
    if (ObjectFind(txt1) == -1) {
        ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
        ObjectSet(txt1, OBJPROP_CORNER, 4);
        ObjectSet(txt1, OBJPROP_XDISTANCE, 15);
        ObjectSet(txt1, OBJPROP_YDISTANCE, 570);
    }
    ObjectSetText(txt1, "Leverage : " + (string) AccountLeverage() + ":1", 8, "Century Gothic", color2);

    txt1 = version + "502";
    if (ObjectFind(txt1) == -1) {
        ObjectCreate(txt1, OBJ_LABEL, 0, 0, 0);
        ObjectSet(txt1, OBJPROP_CORNER, 4);
        ObjectSet(txt1, OBJPROP_XDISTANCE, 15);
        ObjectSet(txt1, OBJPROP_YDISTANCE, 582);
    }
    ObjectSetText(txt1, "Currency : " + AccountCurrency() + " [" + curr + "]", 8, "Century Gothic", color2);
}

/*       ____________________________________________
         T                                          T
         T                WRITE NAME                T
         T__________________________________________T
*/

void EA_name() {
    string txt2 = version + "20";
    if (ObjectFind(txt2) == -1) {
        ObjectCreate(txt2, OBJ_LABEL, 0, 0, 0);
        ObjectSet(txt2, OBJPROP_CORNER, 0);
        ObjectSet(txt2, OBJPROP_XDISTANCE, 30);
        ObjectSet(txt2, OBJPROP_YDISTANCE, 27);
    }
    ObjectSetText(txt2, "MA CROSS v1", 25, "Century Gothic", color1);

    txt2 = version + "21";
    if (ObjectFind(txt2) == -1) {
        ObjectCreate(txt2, OBJ_LABEL, 0, 0, 0);
        ObjectSet(txt2, OBJPROP_CORNER, 0);
        ObjectSet(txt2, OBJPROP_XDISTANCE, 78);
        ObjectSet(txt2, OBJPROP_YDISTANCE, 68);
    }
    ObjectSetText(txt2, "by Algamma || version " + version, 8, "Arial", Gray);

    txt2 = version + "22";
    if (ObjectFind(txt2) == -1) {
        ObjectCreate(txt2, OBJ_LABEL, 0, 0, 0);
        ObjectSet(txt2, OBJPROP_CORNER, 0);
        ObjectSet(txt2, OBJPROP_XDISTANCE, 32);
        ObjectSet(txt2, OBJPROP_YDISTANCE, 51);
    }
    ObjectSetText(txt2, "___________________________", 11, "Arial", Gray);
    /*
       txt2 = version + "23";
       if (ObjectFind(txt2) == -1) {
          ObjectCreate(txt2, OBJ_LABEL, 0, 0, 0);
          ObjectSet(txt2, OBJPROP_CORNER, 0);
          ObjectSet(txt2, OBJPROP_XDISTANCE, 32);
          ObjectSet(txt2, OBJPROP_YDISTANCE, 67);
       }
       ObjectSetText(txt2, "___________________________", 11, "Arial", Gray);

    */
}

/*    .-----------------------.
      |        THE END        |
      '-----------------------'
*/

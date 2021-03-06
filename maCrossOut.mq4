//+------------------------------------------------------------------+
//|                                                   kurukur_02.mq4 |
//|                        Copyright 2015, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2015, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

// マイライブラリー
#include <MyLib_01.mqh>

#define VERSION				"Ver. 004"
#define COMMENT 			"WBR_Chiku"

#define EA_CURRENCY_SAVE	"expertCurrency"

#define	MAGIC_NO				(5000)
#define	ORDER_TYPE_NONE			(100)
#define	SLIPPAGE				(30)
#define LOTS					(0.01)
#define	RSI_PERIOD				(9)
#define	SL_MARGIN				(3)
#define	TAKE_PROFIT				(70)
#define	ENTRY_MARGIN			(3)
#define	LOOP_MAX				(100)
#define PENDING_ORDER_MAX		(24)
#define	SL_MAX					(70)
#define	SL_MIN					(70)
#define MAIL_PRICE_DIGITS		(5)

#define DISP_COORD_X			(5)
#define DISP_COORD_Y			(20)
#define DISP_FONT_SIZE		(10)
//#define DISP_FONT_TYPE		"ＭＳ　ゴシック"
#define DISP_FONT_TYPE		"Consoles"

#define MA_PERIOD_SHORT			(20)
#define MA_PERIOD_MIDDLE		(75)
#define MA_PERIOD_LONG			(200)

enum en_tradeType {
	TRADE_TYPE_BUY,				//買い
	TRADE_TYPE_SELL				//売り
};

enum en_tradeStyle {
	TRADE_TYPE_2CHIKU_OV_MA,		//中線越えチクが2つでエントリ
	TRADE_TYPE_1CHIKU_OV_MA,		//中線越えチクが1つでエントリ
	TRADE_TYPE_1CHIKU,				//チクが2つでエントリ
	TRADE_TYPE_2CHIKU,				//チクが1つでエントリ
};

extern double SlMargin_pips = SL_MARGIN; 	//Stop Lossのマージン (pips)
extern double SlMax_pips = SL_MAX;				//Stop Lossの値(pips)
extern double SlMin_pips = SL_MIN;				//Stop Lossの値(pips)
extern double TakeProfit_pips = TAKE_PROFIT;	//tp pips
extern double EntryMargin_pips = ENTRY_MARGIN;		//エントリマージン (pips)
extern int Slippage = SLIPPAGE; 	//スリッページを入力（下２桁口座の場合3にして下さい）
extern double Lots = LOTS; //ロット数を入力 

enum {
	SEQ_0 = 0,
	SEQ_1_BUY,
	SEQ_2_BUY,
	SEQ_1_SELL,
	SEQ_2_SELL,
	SEQ_3,
	SEQ_REMOVE,
	SEQ_END
};

enum {
	ORDER_STATUS_PENDING_OP_SELLSTOP,
	ORDER_STATUS_FILLED_OP_SELLSTOP,
	ORDER_STATUS_CANCELED_OP_SELLSTOP,
	ORDER_STATUS_CLOSED_OP_SELL,
	ORDER_STATUS_PENDING_OP_BUYSTOP,
	ORDER_STATUS_FILLED_OP_BUYSTOP,
	ORDER_STATUS_CANCELED_OP_BUYSTOP,
	ORDER_STATUS_CLOSED_OP_BUY,
	ORDER_STATUS_FILLED_OP_BUY,
	ORDER_STATUS_FILLED_OP_SELL,
	ORDER_STATUS_END
};

class CProc {
	int m_id;
	CProc *m_next;
	CProc *m_prev;
	int m_seqNo;;
	bool m_initf;
	int m_ticket;
	int m_type;
	datetime m_openTime1st;
	double m_entryPrice;
	double m_sl;
	double m_tp;
	datetime m_timePrev;
	CProc* m_obj;
	bool m_alertDisp;
	int m_pendingOrderCtr;

	int proc_0();
	int proc_1_buy();
	int proc_2_buy();
	int proc_1_sell();
	int proc_2_sell();
	int proc_3();
	bool checkOrderLifeTime();
	int proc_end();
	
	bool makeBuyOrder();
	bool makeSellOrder();
	bool makeSellLimitOrder();
public:
	CProc();
	~CProc();
	int GetId();
	int DoProc();
	int GetSeqNo();	
	void SetTicket(int val);
	int GetTicket();
	datetime GetTimePrev();
	void SetTimePrev(datetime tim);
	void SetObj(CProc* obj);
	CProc* GetObj();

	void Next(CProc *item);
	CProc* Next();
	void Prev(CProc *item);
	CProc* Prev();
};

class CList {
	CProc *m_top;
	CProc *m_end;
	int m_size;
	datetime m_timeCreateObjPrev;
public:
	CList();
	~CList();
	void insertToEnd();
	bool remove();
	int Size();
	void DoProc();
};	
	
//グローバル変数
int fd0;								//ファイルデイスクリプタ
int g_magicNo;
double SlMargin;
double SlMax;
double SlMin;
double TakeProfit;
double EntryMargin;
int RsiPeriod;

datetime OpenTimePrev;
CList *ma3_list;
int ProcId ;
color ArrowColor[6] = {Blue, Red, Blue, Red, Blue, Red};	// 注文時の矢印の色
uint MyOrderWaitingTime =10;		// 注文待ち時間(秒)


//Proto Type
bool isNewBar(CProc* obj);
bool closeOneOrder(int ticket, int type, int slippage);
bool isPendingOrder(CProc* obj);
bool isClosed(int objId, int seqNo, int ticket);
void mySendMail(int ticket, int orderStatus);
void drawSlLine();
void candleColor();

bool test_routine();

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- create timer
   EventSetTimer(60);
      
//---
 	string sb = Symbol();
	string appVersion = VERSION;

	string strTradeType;

 	//File open
 	string fileName = "fileSave_" + COMMENT + "_" + sb;
	string fileName1 = EA_CURRENCY_SAVE;
	
	fd0 = fileInit(fileName);

	g_magicNo = MAGIC_NO;
	OpenTimePrev = 0;
	ProcId = 1;
	ma3_list = new CList();

  	SlMargin = SlMargin_pips * Point() * 10;
  	SlMax = SlMax_pips * Point() * 10;
  	SlMin = SlMin_pips * Point() * 10;
  	TakeProfit = TakeProfit_pips * Point() *10;
  	EntryMargin = EntryMargin_pips * Point() * 10;
  	RsiPeriod = RSI_PERIOD;
	
	saveData02(fd0, "OnInit", strTradeType, Time[0], 0, 0, 0, Point(), 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0); //dbg_save	

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
  	drawSlLine();
 	candleColor();

//--- destroy timer
   EventKillTimer();

   FileClose(fd0);
  }

//*******************************************************************************************
//*   Function    :  CProc::CProc()
//*   Description : 
//*   Return      : 
//*******************************************************************************************
 CProc::CProc()
 {
	m_next = NULL;
	m_prev = NULL;
	m_seqNo = SEQ_0;
	m_initf = false;
	m_ticket = 0;
	m_type = ORDER_TYPE_NONE;
	m_openTime1st = 0;
	m_entryPrice = 0.0;
	m_sl = 0.0;
	m_tp = 0.0;

	m_id = ProcId++;
	m_timePrev = 0;
	m_obj = NULL;
	m_alertDisp = false;
	m_pendingOrderCtr = 0;
}

//*******************************************************************************************
//*   Function    :  CProc::~CProc()
//*   Description : 
//*   Return      : 
//*******************************************************************************************
CProc::~CProc()
{
}

//*******************************************************************************************
//*   Function    :  int CProc::GetId()
//*   Description : 
//*   Return      : 
//*******************************************************************************************
int CProc::GetId()
{
	return m_id;
}

//*******************************************************************************************
//*   Function    :  int CProc::DoProc()
//*   Description : 
//*   Return      : 
//*******************************************************************************************
int CProc::DoProc()
{
	int ret = SEQ_0;

//	saveData02(fd0, "DoProc", "", Time[0], 0, 0, m_id, m_seqNo, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0); //dbg_save	

	switch(m_seqNo)
	{
		case SEQ_0:
			m_seqNo = proc_0();
			break;
		case SEQ_1_BUY:
			m_seqNo = proc_1_buy();
			break;
		case SEQ_2_BUY:
			m_seqNo = proc_2_buy();
			break;
		case SEQ_1_SELL:
			m_seqNo = proc_1_sell();
			break;
		case SEQ_2_SELL:
			m_seqNo = proc_2_sell();
			break;
		case SEQ_END:
			m_seqNo = proc_end();
			break;
		default:
			break;
	}
	return ret;
}

//*******************************************************************************************
//*   Function    :  int CProc::GetSeqNo()
//*   Description : 
//*   Return      : 
//*******************************************************************************************
int CProc::GetSeqNo()
{
	return m_seqNo;
}

//*******************************************************************************************
//*   Function    : void CProc::SetTicket(int val)
//*   Description : 
//*   Return      : 
//*******************************************************************************************
void CProc::SetTicket(int val)
{
	m_ticket = val;
}

//*******************************************************************************************
//*   Function    : int CProc::GetTicket()
//*   Description : 
//*   Return      : 
//*******************************************************************************************
int CProc::GetTicket()
{
	return m_ticket;
}

//*******************************************************************************************
//*   Function    :  datetime CProc::GetTimePrev()
//*   Description : 
//*   Return      : 
//int*******************************************************************************************
datetime CProc::GetTimePrev()
{
	return m_timePrev;
}

//*******************************************************************************************
//*   Function    :  datetime CProc::SetTimePrev()
//*   Description : 
//*   Return      : 
//int*******************************************************************************************
void CProc::SetTimePrev(datetime val)
{
	m_timePrev = val;
}

//*******************************************************************************************
//*   Function    :  void CProc::Next(CProc *item)
//*   Description : 
//*   Return      : 
//*******************************************************************************************
void CProc::Next(CProc *item)
{
	m_next = item;
}

//*******************************************************************************************
//*   Function    :  CProc* CProc::Next()
//*   Description : 
//*   Return      : 
//*******************************************************************************************
CProc* CProc::Next()
{
	return m_next;
}

//*******************************************************************************************
//*   Function    :  void CProc::Prev(CProc *item)
//*   Description : 
//*   Return      : 
//*******************************************************************************************
void CProc::Prev(CProc *item)
{
	m_prev = item;
}

//*******************************************************************************************
//*   Function    :  CProc* CProc::Prev()
//*   Description : 
//*   Return      : 
//*******************************************************************************************
CProc* CProc::Prev()
{
	return m_prev;
}

//*******************************************************************************************
//*   Function    :  void CProc::SetObj(CProc* obj)
//*   Description : 
//*   Return      : 
//*******************************************************************************************
void CProc::SetObj(CProc* obj)
{
	m_obj = obj;
}

//*******************************************************************************************
//*   Function    :  void CProc::GetObj(CProc* obj)
//*   Description : 
//*   Return      : 
//*******************************************************************************************
CProc* CProc::GetObj()
{
	return m_obj;
}

//*******************************************************************************************
//*   Function    : int CProc::proc_0()
//*   Description : MAクロス検出
//*   Return      : 
//*******************************************************************************************
int CProc::proc_0()
{
	int ret = SEQ_0;
	double ma_75_1;
	double ma_200_1;
	double ma_75_2;
	double ma_200_2;
	int shift = 1;

	//新しいバーか
	if(!isNewBar(m_obj))
	{
		return ret;
	}

	shift =1;
	ma_75_1 = iMA(NULL, 0, MA_PERIOD_MIDDLE, 0, MODE_EMA, PRICE_CLOSE, shift);
	ma_200_1 = iMA(NULL, 0, MA_PERIOD_LONG, 0, MODE_EMA, PRICE_CLOSE, shift);
	shift =2;
	ma_75_2 = iMA(NULL, 0, MA_PERIOD_MIDDLE, 0, MODE_EMA, PRICE_CLOSE, shift);
	ma_200_2 = iMA(NULL, 0, MA_PERIOD_LONG, 0, MODE_EMA, PRICE_CLOSE, shift);
	
	//ゴールデンキロスカ
	if((ma_75_1 >= ma_200_1) && (ma_75_2 < ma_200_2))
	{
		m_pendingOrderCtr = 0;
		ret = SEQ_1_BUY;
	}
	//デッド、クロスか
	else if((ma_75_1 <= ma_200_1) && (ma_75_2 > ma_200_2))
	{
		m_pendingOrderCtr = 0;
		ret = SEQ_1_SELL;
	}
	else
	{
		//クロス待ち
		ret = SEQ_REMOVE;
	}
	return ret;
}	
	
//*******************************************************************************************
//*   Function    : int CProc::proc_1_buy()
//*   Description : MA割れ検出
//*   Return      : 
//*******************************************************************************************
int CProc::proc_1_buy()
{
	int ret = SEQ_1_BUY;
	double ma_20_1;
	double ma_75_1;
	double ma_200_1;
	double ma_75_2;
	double ma_200_2;
	int shift = 1;

	//新しいバーか
	if(!isNewBar(m_obj))
	{
		return ret;
	}

	shift =1;
	ma_20_1 = iMA(NULL, 0, MA_PERIOD_SHORT, 0, MODE_EMA, PRICE_CLOSE, shift);
	ma_75_1 = iMA(NULL, 0, MA_PERIOD_MIDDLE, 0, MODE_EMA, PRICE_CLOSE, shift);
	ma_200_1 = iMA(NULL, 0, MA_PERIOD_LONG, 0, MODE_EMA, PRICE_CLOSE, shift);
	shift =2;
	ma_75_2 = iMA(NULL, 0, MA_PERIOD_MIDDLE, 0, MODE_EMA, PRICE_CLOSE, shift);
	ma_200_2 = iMA(NULL, 0, MA_PERIOD_LONG, 0, MODE_EMA, PRICE_CLOSE, shift);
	
	//デッド、クロスか
	if((ma_75_1 <= ma_200_1) && (ma_75_2 > ma_200_2))
	{
		ret = SEQ_1_SELL;		//シーケンスをSellへ
	}
	//MA20を下回ったか
	else if(Close[1] < ma_20_1)
	{
		ret = SEQ_2_BUY;
	}
	
	return ret;
}

//*******************************************************************************************
//*   Function    : int CProc::proc_1_sell()
//*   Description : MA割れ検出
//*   Return      : 
//*******************************************************************************************
int CProc::proc_1_sell()
{
	int ret = SEQ_1_SELL;
	double ma_20_1;
	double ma_75_1;
	double ma_200_1;
	double ma_75_2;
	double ma_200_2;
	int shift = 1;

	//新しいバーか
	if(!isNewBar(m_obj))
	{
		return ret;
	}

	shift =1;
	ma_20_1 = iMA(NULL, 0, MA_PERIOD_SHORT, 0, MODE_EMA, PRICE_CLOSE, shift);
	ma_75_1 = iMA(NULL, 0, MA_PERIOD_MIDDLE, 0, MODE_EMA, PRICE_CLOSE, shift);
	ma_200_1 = iMA(NULL, 0, MA_PERIOD_LONG, 0, MODE_EMA, PRICE_CLOSE, shift);
	shift =2;
	ma_75_2 = iMA(NULL, 0, MA_PERIOD_MIDDLE, 0, MODE_EMA, PRICE_CLOSE, shift);
	ma_200_2 = iMA(NULL, 0, MA_PERIOD_LONG, 0, MODE_EMA, PRICE_CLOSE, shift);
	
	//ゴールデン、クロスか
	if((ma_75_1 >= ma_200_1) && (ma_75_2 < ma_200_2))
	{
		ret = SEQ_1_BUY;		//シーケンスをBuyへ
	}
	//MA20を上回ったか
	else if(Close[1] > ma_20_1)
	{
		ret = SEQ_2_SELL;
	}
	
	return ret;
}

//*******************************************************************************************
//*   Function    : int CProc::proc_2_buy()
//*   Description : MA戻り検出
//*   Return      : 
//*******************************************************************************************
int CProc::proc_2_buy()
{
	int ret = SEQ_2_BUY;
	double ma_20_1;
	double ma_75_1;
	double ma_200_1;
	double ma_75_2;
	double ma_200_2;
	int shift = 1;
	bool retFunc;
	//新しいバーか
	if(!isNewBar(m_obj))
	{
		return ret;
	}

	shift =1;
	ma_20_1 = iMA(NULL, 0, MA_PERIOD_SHORT, 0, MODE_EMA, PRICE_CLOSE, shift);
	ma_75_1 = iMA(NULL, 0, MA_PERIOD_MIDDLE, 0, MODE_EMA, PRICE_CLOSE, shift);
	ma_200_1 = iMA(NULL, 0, MA_PERIOD_LONG, 0, MODE_EMA, PRICE_CLOSE, shift);
	shift =2;
	ma_75_2 = iMA(NULL, 0, MA_PERIOD_MIDDLE, 0, MODE_EMA, PRICE_CLOSE, shift);
	ma_200_2 = iMA(NULL, 0, MA_PERIOD_LONG, 0, MODE_EMA, PRICE_CLOSE, shift);

	//デッド、クロスか
	if((ma_75_1 <= ma_200_1) && (ma_75_2 > ma_200_2))
	{
		ret = SEQ_1_SELL;		//シーケンスをSellへ
	}
	//戻ってきたか
	else if(Close[1] > ma_20_1)
	{
		//オーダ
		retFunc = makeBuyOrder();
		saveData02(fd0, "proc_0_chiku Buy", "", Time[0], 0, 0, m_id, 0, 0, 0, retFunc, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0); //dbg_save	
		if(retFunc)
		{
			ret = SEQ_3;
		}
		else
		{
			ret = SEQ_0;		//シーケンスを戻す
		}
	}
	
	return ret;
}

//*******************************************************************************************
//*   Function    : int CProc::proc_2_sell()
//*   Description : MA戻り検出
//*   Return      : 
//*******************************************************************************************
int CProc::proc_2_sell()
{
	int ret = SEQ_2_SELL;
	double ma_20_1;
	double ma_75_1;
	double ma_200_1;
	double ma_75_2;
	double ma_200_2;
	int shift = 1;
	bool retFunc;

	//新しいバーか
	if(!isNewBar(m_obj))
	{
		return ret;
	}

	shift =1;
	ma_20_1 = iMA(NULL, 0, MA_PERIOD_SHORT, 0, MODE_EMA, PRICE_CLOSE, shift);
	ma_75_1 = iMA(NULL, 0, MA_PERIOD_MIDDLE, 0, MODE_EMA, PRICE_CLOSE, shift);
	ma_200_1 = iMA(NULL, 0, MA_PERIOD_LONG, 0, MODE_EMA, PRICE_CLOSE, shift);
	shift =2;
	ma_75_2 = iMA(NULL, 0, MA_PERIOD_MIDDLE, 0, MODE_EMA, PRICE_CLOSE, shift);
	ma_200_2 = iMA(NULL, 0, MA_PERIOD_LONG, 0, MODE_EMA, PRICE_CLOSE, shift);

	//ゴールデン、クロスか
	if((ma_75_1 >= ma_200_1) && (ma_75_2 < ma_200_2))
	{
		ret = SEQ_1_BUY;		//シーケンスをBuyへ
	}
	//戻ってきたか
	else if(Close[1] < ma_20_1)
	{
		//オーダ
		retFunc = makeSellOrder();
		saveData02(fd0, "proc_2_sell", "", Time[0], 0, 0, m_id, 0, 0, 0, retFunc, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0); //dbg_save	
		if(retFunc)
		{
			ret = SEQ_3;
		}
		else
		{
			ret = SEQ_0;		//シーケンスを戻す
		}
	}					

	return ret;
}
//*******************************************************************************************
//*   Function    : int CProc::proc_3()
//*   Description : 機オーダが一定期間たったらクロース
//*   Return      : 
//*******************************************************************************************
int CProc::proc_3()
{
	int ret = SEQ_3;
	double ma_75_1;
	double ma_200_1;
	double ma_75_2;
	double ma_200_2;
	int shift = 1;
	bool goldenCross = false;
	bool deadCross = false;

	//新しいバーか
	if(!isNewBar(m_obj))
	{
		return ret;
	}

	shift =1;
	ma_75_1 = iMA(NULL, 0, MA_PERIOD_MIDDLE, 0, MODE_EMA, PRICE_CLOSE, shift);
	ma_200_1 = iMA(NULL, 0, MA_PERIOD_LONG, 0, MODE_EMA, PRICE_CLOSE, shift);
	shift =2;
	ma_75_2 = iMA(NULL, 0, MA_PERIOD_MIDDLE, 0, MODE_EMA, PRICE_CLOSE, shift);
	ma_200_2 = iMA(NULL, 0, MA_PERIOD_LONG, 0, MODE_EMA, PRICE_CLOSE, shift);

	//ゴールデン、クロスか
	if((ma_75_1 >= ma_200_1) && (ma_75_2 < ma_200_2))
	{
		goldenCross = true;
	}

	//デッド、クロスか
	if((ma_75_1 <= ma_200_1) && (ma_75_2 > ma_200_2))
	{
		deadCross = true;
	}
	
	//待機オーダが一定期間たったらクロース
	if(isPendingOrder(m_obj))
	{
		m_pendingOrderCtr++;
		//待機オーダが一定期間たったか
		if(m_pendingOrderCtr >= PENDING_ORDER_MAX)
		{
			//クローズ
			deletePendingOrder(m_obj);
			saveData02(fd0, "proc_3 Delete Timer over", "", Time[0], 0, 0, m_id, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0); //dbg_save	
			ret = SEQ_0;
		}
		//ゴールデンクロス
		else if(goldenCross)
		{
			//クローズ
			deletePendingOrder(m_obj);
			saveData02(fd0, "proc_3 Delete Golden cross", "", Time[0], 0, 0, m_id, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0); //dbg_save	
			ret = SEQ_1_BUY;
		}
		//デッドうロス
		else if(deadCross)
		{
			//クローズ
			deletePendingOrder(m_obj);
			saveData02(fd0, "proc_3 Delete Dead cross", "", Time[0], 0, 0, m_id, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0); //dbg_save	
			ret = SEQ_1_SELL;
		}
		else
		{
			//Pending Order 中
		}
	}
	//決済されたか
	else if(isClosed(m_obj))
	{
		saveData02(fd0, "proc_3 Closed", "", Time[0], 0, 0, m_id, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0); //dbg_save	
		ret = SEQ_0;
	}
	else
	{
		//ゴールデンクロス
		if(goldenCross)
		{
			//決済
			closeOneOrder(m_ticket, m_type, Slippage);
			saveData02(fd0, "proc_3 Open Position -> Close Golden cross", "", Time[0], 0, 0, m_id, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0); //dbg_save	
			ret = SEQ_1_BUY;
		}
		//デッドうロス
		else if(deadCross)
		{
			//決済
			closeOneOrder(m_ticket, m_type, Slippage);
			saveData02(fd0, "proc_3 Open Position -> Close Dead cross", "", Time[0], 0, 0, m_id, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0); //dbg_save	
			ret = SEQ_1_SELL;
		}
	}
	
	return ret;
}

//*******************************************************************************************
//*   Function    : int CProc::proc_end()
//*   Description : シーケンス終了
//*   Return      : 
//*******************************************************************************************
int CProc::proc_end()
{
	int ret = SEQ_END;
	string str = "EA End ";
	
	str += Symbol();
	
	if(!m_alertDisp)
	{
		Alert(str);
		m_alertDisp = true;
	}

	return ret;
}

//*******************************************************************************************
//*   Function    : bool CProc::makeBuyOrder()
//*   Description : 
//*   Return      : 
//*******************************************************************************************
bool CProc::makeBuyOrder()
{
	bool ret = true;
	int barNo;
	double rsi_1;
	double rsi_2;
	double rsi_3;
	int orderType = OP_BUYSTOP;
	double entryPrice = Ask;
	double sl = 0;
	double tp = 0;
	color cl = Blue;
	int err;
	double spread;
	double slDiff;

	//前回のところの高値に逆差値 SLは直近の谷チクの安値で、20pips未満なら20pips
	entryPrice = iHigh(NULL, 0, 1) + EntryMargin;
	spread = Ask - Bid;
	tp = entryPrice + TakeProfit + spread;
	for(barNo=1; barNo< LOOP_MAX; barNo++)
	{
		rsi_1 = iRSI(NULL, 0, RsiPeriod, PRICE_CLOSE,barNo);	//WBA_MA
		rsi_2 = iRSI(NULL, 0, RsiPeriod, PRICE_CLOSE, barNo+1);	//WBA_MA
		rsi_3 = iRSI(NULL, 0, RsiPeriod, PRICE_CLOSE, barNo+2);	//WBA_MA
		
		if((rsi_1 > rsi_2) && (rsi_2 < rsi_3))
		{
			sl = iLow(NULL, 0, barNo+1) - SlMargin;
			slDiff = entryPrice - sl;
			if(slDiff > SlMax)
			{
//				sl = entryPrice - SlMax - SlMargin;
			}
			if(slDiff< SlMax)
			{
				sl = entryPrice - SlMin - SlMargin;
			}
			break;
		}
	}
		
	if(barNo == LOOP_MAX)
	{
		saveData02(fd0, "makeBuyOrder Loop over ", "", Time[0], 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0); //dbg_save	
		return false;
	}

	//オーダ
	if(OrderSend(Symbol(), orderType, Lots, entryPrice, Slippage, sl, tp, "", g_magicNo, 0, cl) > 0)
	{
		//チケット番号を保持
		m_type = orderType;
		m_entryPrice = entryPrice;
		m_sl = sl;
		m_tp = tp;
		m_ticket = getTicket(m_id, m_seqNo, g_magicNo);
		mySendMail(m_ticket, ORDER_STATUS_PENDING_OP_BUYSTOP);			//メール送信
		saveData02(fd0, "makeBuyOrder 1st", "", Time[0], 0, 0, m_ticket, m_id, m_type, Close[0], m_entryPrice, m_sl, m_tp, Close[1], Close[2], 0, 0, 0, 0, 0, 0); //dbg_save	
	}
	else
	{
		err = GetLastError();
		saveData02(fd0, "makeBuyOrder1st  Error", "", Time[0], 0, 0, m_id, err, Close[0], orderType, entryPrice, sl, tp, Lots, g_magicNo, Ask, 0, 0, 0, 0, 0); //dbg_save	

		//待機オーダが無理だったら、成り行きで入る
		orderType = OP_BUY;
		entryPrice = Ask;
		tp = entryPrice + TakeProfit + spread;
		sl = entryPrice - SlMax - SlMargin;
		//オーダ
		if(OrderSend(Symbol(), orderType, Lots, entryPrice, Slippage, sl, tp, "", g_magicNo, 0, cl) > 0)
		{
			//チケット番号を保持
			m_type = orderType;
			m_entryPrice = entryPrice;
			m_sl = sl;
			m_tp = tp;
			m_ticket = getTicket(m_id, m_seqNo, g_magicNo);
			mySendMail(m_ticket, ORDER_STATUS_FILLED_OP_BUY);		//メール送信
			saveData02(fd0, "makeBuyOrder 2nd", "", Time[0], 0, 0, m_ticket, m_id, m_type, Close[0], m_entryPrice, m_sl, m_tp, Close[1], Close[2], 0, 0, 0, 0, 0, 0); //dbg_save	
		}
		else
		{
			err = GetLastError();
			ret = false;
			saveData02(fd0, "makeBuyOrder Error", "", Time[0], 0, 0, m_id, err, Close[0], orderType, entryPrice, sl, tp, Lots, g_magicNo, 0, 0, 0, 0, 0, 0); //dbg_save	
		}

	}
	g_magicNo++;
	
	return ret;
}

//*******************************************************************************************
//*   Function    : bool CProc::makeSellOrder()
//*   Description : 
//*   Return      : 
//*******************************************************************************************
bool CProc::makeSellOrder()
{
	int barNo;
	bool ret = true;
	double rsi_1;
	double rsi_2;
	double rsi_3;
	int orderType = OP_SELLSTOP;
	double entryPrice = Bid;
	double sl = 0;
	double tp = 0;
	color cl = Red;
	int err;
	double spread;
	double slDiff;

	entryPrice = iLow(NULL, 0, 1) - EntryMargin;
	spread = Ask - Bid;
	tp = entryPrice - TakeProfit - spread;
			
	//前回のところの安値に逆差値 SLは直近の山チクの高値で、20pips未満なら20pips
	for(barNo=1; barNo< LOOP_MAX; barNo++)
	{
		rsi_1 = iRSI(NULL, 0, RsiPeriod, PRICE_CLOSE,barNo);	//WBA_MA
		rsi_2 = iRSI(NULL, 0, RsiPeriod, PRICE_CLOSE, barNo+1);	//WBA_MA
		rsi_3 = iRSI(NULL, 0, RsiPeriod, PRICE_CLOSE, barNo+2);	//WBA_MA
				
		if((rsi_1 < rsi_2) && (rsi_2 > rsi_3))
		{
			sl = iHigh(NULL, 0, barNo+1) + SlMargin;
			slDiff = sl - entryPrice;
			if(slDiff > SlMax)
			{
//				sl = entryPrice + SlMax + SlMargin;
			}
			if(slDiff < SlMin)
			{
				sl = entryPrice + SlMin + SlMargin;
			}
			break;
		}
	}
		
	if(barNo == LOOP_MAX)
	{
		saveData02(fd0, "makeSellOrder Loop over ", "", Time[0], 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0); //dbg_save	
	}

	//オーダ
	if(OrderSend(Symbol(), orderType, Lots, entryPrice, Slippage, sl, tp, "", g_magicNo, 0, cl) > 0)
	{
		//チケット番号を保持
		m_type = orderType;
		m_entryPrice = entryPrice;
		m_sl = sl;
		m_tp = tp;
		m_ticket = getTicket(m_id, m_seqNo, g_magicNo);
		mySendMail(m_ticket, ORDER_STATUS_PENDING_OP_SELLSTOP);		//メール送信
		saveData02(fd0, "makeSellOrder 1st", "", Time[0], 0, 0, m_ticket, m_id, m_type, Close[0], m_entryPrice, m_sl, m_tp, Close[1], Close[2], 0, 0, 0, 0, 0, 0); //dbg_save	
	}
	else
	{
		err = GetLastError();
		saveData02(fd0, "makeSellOrder  Error", "", Time[0], 0, 0, m_id, err, Close[0], orderType, entryPrice, sl, tp, Lots, g_magicNo, Bid, 0, 0, 0, 0, 0); //dbg_save	

		//待機オーダが無理だったら、成り行きで入る
		orderType = OP_SELL;
		entryPrice = Bid;
		tp = entryPrice - TakeProfit - spread;
		sl = entryPrice + SlMax + SlMargin;
		//オーダ
		if(OrderSend(Symbol(), orderType, Lots, entryPrice, Slippage, sl, tp, "", g_magicNo, 0, cl) > 0)
		{
			//チケット番号を保持
			m_type = orderType;
			m_entryPrice = entryPrice;
			m_sl = sl;
			m_tp = tp;
			m_ticket = getTicket(m_id, m_seqNo, g_magicNo);
			mySendMail(m_ticket, ORDER_STATUS_FILLED_OP_SELL);		//メール送信
			saveData02(fd0, "makeSellOrder 2nd", "", Time[0], 0, 0, m_ticket, m_id, m_type, Close[0], m_entryPrice, m_sl, m_tp, Close[1], Close[2], 0, 0, 0, 0, 0, 0); //dbg_save	
		}
		else
		{
			err = GetLastError();
			ret = false;
			saveData02(fd0, "makeSellOrder Error", "", Time[0], 0, 0, m_id, err, Close[0], orderType, entryPrice, sl, tp, Lots, g_magicNo, 0, 0, 0, 0, 0, 0); //dbg_save	
		}
	}
	g_magicNo++;
	
	return ret;
}

//*******************************************************************************************
//*   Function    : bool CProc::makeSellLimitOrder()
//*   Description : 
//*   Return      : 
//*******************************************************************************************
bool CProc::makeSellLimitOrder()
{
	bool ret = true;
	int barNo;
	double rsi_1;
	double rsi_2;
	double rsi_3;
	int orderType = OP_SELLLIMIT;
	double entryPrice = Bid;
	double sl = 0;
	double tp = 0;
	color cl = Blue;
	int err;
	double spread;

	//前回のところの高値に逆差値 SLは直近の谷チクの安値で、20pips未満なら20pips
	entryPrice = iHigh(NULL, 0, 2) + EntryMargin;
	spread = Ask - Bid;
	sl = entryPrice + SlMax + SlMargin;

	for(barNo=1; barNo< LOOP_MAX; barNo++)
	{
		rsi_1 = iRSI(NULL, 0, RsiPeriod, PRICE_CLOSE,barNo);	//WBA_MA
		rsi_2 = iRSI(NULL, 0, RsiPeriod, PRICE_CLOSE, barNo+1);	//WBA_MA
		rsi_3 = iRSI(NULL, 0, RsiPeriod, PRICE_CLOSE, barNo+2);	//WBA_MA
		
		if((rsi_1 > rsi_2) && (rsi_2 < rsi_3))
		{
			tp = iLow(NULL, 0, barNo+1) - spread;
			break;
		}
	}
		
	if(barNo == LOOP_MAX)
	{
		saveData02(fd0, "makeSellLimitOrder Loop over ", "", Time[0], 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0); //dbg_save	
		return false;
	}

	//オーダ
	if(OrderSend(Symbol(), orderType, Lots, entryPrice, Slippage, sl, tp, "", g_magicNo, 0, cl) > 0)
	{
		//チケット番号を保持
		m_type = orderType;
		m_entryPrice = entryPrice;
		m_sl = sl;
		m_tp = tp;
		m_ticket = getTicket(m_id, m_seqNo, g_magicNo);
		saveData02(fd0, "makeSellLimitOrder 1st", "", Time[0], 0, 0, m_ticket, m_id, m_type, Close[0], m_entryPrice, m_sl, m_tp, Close[1], Close[2], 0, 0, 0, 0, 0, 0); //dbg_save	
	}
	else
	{
		err = GetLastError();
		saveData02(fd0, "makeSellLimitOrder  Error", "", Time[0], 0, 0, m_id, err, Close[0], orderType, entryPrice, sl, tp, Lots, g_magicNo, Ask, 0, 0, 0, 0, 0); //dbg_save	

		//待機オーダが無理だったら、成り行きで入る
		orderType = OP_SELL;
		entryPrice = Bid;
		sl = 0;
		//オーダ
		if(OrderSend(Symbol(), orderType, Lots, entryPrice, Slippage, sl, tp, "", g_magicNo, 0, cl) > 0)
		{
			//チケット番号を保持
			m_type = orderType;
			m_entryPrice = entryPrice;
			m_sl = sl;
			m_tp = tp;
			m_ticket = getTicket(m_id, m_seqNo, g_magicNo);
			saveData02(fd0, "makeSellLimitOrder 2nd", "", Time[0], 0, 0, m_ticket, m_id, m_type, Close[0], m_entryPrice, m_sl, m_tp, Close[1], Close[2], 0, 0, 0, 0, 0, 0); //dbg_save	
		}
		else
		{
			err = GetLastError();
			ret = false;
			saveData02(fd0, "makeSellLimitOrder Error", "", Time[0], 0, 0, m_id, err, Close[0], orderType, entryPrice, sl, tp, Lots, g_magicNo, 0, 0, 0, 0, 0, 0); //dbg_save	
		}
	}
	g_magicNo++;
	
	return ret;
}
//*******************************************************************************************
//*   Function    : CList::CList
//*   Description : 
//*   Return      : 
//*******************************************************************************************
CList::CList()
{
	m_top = new CProc();
	m_end = new CProc();

	m_top.Next(m_end);
	m_top.Prev(NULL);
	m_end.Next(NULL);
	m_end.Prev(m_top);

	saveData02(fd0, "CList::CList 1", "", Time[0], 0, 0, m_top.GetId(), m_end.GetId(),0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0); //dbg_save	
	saveData02(fd0, "CList::CList 1", "", Time[0], 0, 0, m_top.GetId(), m_end.GetId(),0, m_top.Next().GetId(), 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0); //dbg_save	
	saveData02(fd0, "CList::CList 2", "", Time[0], 0, 0, m_top.GetId(), m_end.GetId(),0, m_top.Next().GetId(), m_end.Prev().GetId(), 0, 0, 0, 0, 0, 0, 0, 0, 0, 0); //dbg_save	
	
	m_size = 0;
	m_timeCreateObjPrev = 0;
}

//*******************************************************************************************
//*   Function    : CList::~CList
//*   Description : 
//*   Return      : 
//*******************************************************************************************
CList::~CList()
{
}

//*******************************************************************************************
//*   Function    : void CList::insertToEnd()
//*   Description : 
//*   Return      : 
//*******************************************************************************************
void CList::insertToEnd()
{
	CProc *item;
	
	item = new CProc();

	//オブジェクトポインタを入れる
	item.SetObj(item);

	//Endの前に入れる
	item.Next(m_end);
	item.Prev(m_end.Prev());
	item.Prev().Next(item);
	m_end.Prev(item);

//	saveData02(fd0, "CList::insertToEnd", "", Time[0], 0, 0, item.GetId(), 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0); //dbg_save	

	//サイズ
	m_size++;
}

//*******************************************************************************************
//*   Function    : bool CList::remove()
//*   Description : SEQ_のオブジェクトをサーチし、削除する。
//*   Return      : 
//*******************************************************************************************
bool CList::remove()
{
	CProc *pProc;
	CProc *tmpProc;
	bool ret = false;

	//Search
	pProc = m_top.Next();
	while(pProc != m_end)
	{
		if(pProc.GetSeqNo() == SEQ_END)
		{
			//リストからはずす
			tmpProc = pProc.Prev();
			tmpProc.Next(pProc.Next());
			tmpProc = pProc.Next();
			tmpProc.Prev(pProc.Prev());
			saveData02(fd0, "CList::remove", "", Time[0], 0, 0, pProc.GetId(), 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0); //dbg_save	

			//削除
			delete pProc;

			//サイズ更新
			m_size--;
			if(m_size < 0)
			{
				m_size = 0;
			}
			
			//次のサーチ対象		
			pProc = tmpProc;
		}
		else
		{
			//次のサーチ対象		
			pProc = pProc.Next();
		}
	}

	return ret;
}

//*******************************************************************************************
//*   Function    : int CList::Size
//*   Description : 
//*   Return      : 
//*******************************************************************************************
int CList::Size()
{
	return m_size;
}

//*******************************************************************************************
//*   Function    : void CList::DoProc()
//*   Description : 
//*   Return      : 
//*******************************************************************************************
void CList::DoProc()
{
	CProc *pProc;
	int ret;
	datetime timeNow = Time[0];
	
	//新しいバーか
	if(m_timeCreateObjPrev != timeNow)
	{
		//新しいオブジェクトを生成
		insertToEnd();
		saveData02(fd0, "CList::DoProc 新しいオブジェクト", "", Time[0], 0, 0, m_end.Prev().GetId(), 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0); //dbg_save	
		m_timeCreateObjPrev = timeNow;
	}

	//オブジェクトを実行
	pProc = m_top.Next();
	while(pProc != m_end)
	{
		ret = pProc.DoProc();
		pProc = pProc.Next();
	}
	
	//SEQ_ENDのオブジェクトを削除
	remove();
}

//*******************************************************************************************
//*   Function    : getTicket
//*   Description : 
//*   Return      : 
//*******************************************************************************************
int getTicket(int objId, int seqNo, int magicNo)
{
	int i;
	int total;
	int ticket = 0;;

	total = OrdersTotal();
	for(i=0; i<total; i++)
	{
		if(OrderSelect(i, SELECT_BY_POS) == false) break;
		if((OrderSymbol() != Symbol())) continue;
		if(OrderMagicNumber() != magicNo) continue;

		ticket = OrderTicket();
		break;
	}
	return(ticket);
}

//*******************************************************************************************
//*   Function    : bool isNewBar(CProc* obj)
//*   Description : 
//*   Return      : 
//*******************************************************************************************
bool isNewBar(CProc* obj)
{
	bool ret = false;
	datetime timeNow;
	datetime timePrev;
	
	//今の時刻を取得
	timeNow = iTime(NULL, 0,0);
	//前回の時刻を取得
	timePrev = obj.GetTimePrev();
//	saveData02(fd0, "isNewBar Env", "", timePrev, timeNow, 0, obj.GetId(), obj.GetSeqNo(), timeframe, ret, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0); //dbg_save	

	//新しいバーか
	if(timeNow != timePrev)
	{
		obj.SetTimePrev(timeNow);
		ret = true;
	}

	return ret;
}

//*******************************************************************************************
//*   Function    : deletePendingOrder
//*   Description : 待機オーダを削除する
//*   Return      : 
//*******************************************************************************************
bool deletePendingOrder(CProc* obj)
{
   int starttime = (int)GetTickCount();
   int ticket = obj.GetTicket();
 
   while(true)
   {
      if(GetTickCount() - starttime > MyOrderWaitingTime*1000)
      {
         Alert("OrderDelete timeout. Check the experts log.");
         return(false);
      }
      if(IsTradeAllowed() == true)
      {
         if(OrderDelete(ticket) == true) return(true);
         int err = GetLastError();
         Print("[OrderDeleteError] : ", err, " ", ErrorDescription(err));
		saveData02(fd0, "deletePendingOrder Error", "", Time[0], 0, 0, obj.GetId(), ticket, err, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0); //dbg_save	
      }
      Sleep(100);
   }
}

//*******************************************************************************************
//*   Function    : allOrderClose
//*   Description : ひとつのオープンポジションを決済する
//*   Return      : 
//*******************************************************************************************
bool closeOneOrder(int ticket, int type, int slippage)
{
	uint starttime = GetTickCount();
	double closePrice;
	int cl;
	
	while(true)
	{
		if((GetTickCount() - starttime) > MyOrderWaitingTime*1000)
		{
			Alert("OrderClose timeout. Check the experts log.");
			return(false);
		}
		if(IsTradeAllowed() == true)
		{
			RefreshRates();
			if(type == OP_BUY)
			{
				closePrice = Bid;
				cl = 0;
			}
			else
			{
				closePrice = Ask;
				cl = 1;
			}
			if(OrderClose(ticket, OrderLots(), closePrice, slippage, ArrowColor[cl]) == true) 	//dg_code
//			if(OrderClose(ticket, OrderLots(), OrderClosePrice(), slippage, ArrowColor[type]) == true) 
			{
				saveData02(fd0, "closeOneOrder OK", "", Time[0], 0, 0, ticket, OrderLots(), OrderClosePrice(), slippage, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0); //dbg_save	
				return(true);
			}
			int err = GetLastError();
			Print("[OrderCloseError] : ", err, " ", ErrorDescription(err));
			saveData02(fd0, "closeOneOrder Error", "", Time[0], 0, 0, ticket, OrderLots(), OrderClosePrice(), slippage, err, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0); //dbg_save	
			
			if(err == ERR_INVALID_PRICE) break;
		}
		Sleep(100);
	}
	return(false);
}    

//*******************************************************************************************
//*   Function    : isPendingOrder
//*   Description : 
//*   Return      : 
//*******************************************************************************************
bool isPendingOrder(CProc* obj)
{
	bool ret = false;
	int ticket;
	int type;

	ticket = obj.GetTicket();
	
	if(OrderSelect(ticket, SELECT_BY_TICKET) == true)
	{
		type = OrderType();
		switch(type)
		{
			case OP_BUYLIMIT:
			case OP_SELLLIMIT:
			case OP_BUYSTOP:
			case OP_SELLSTOP:
				ret = true;
				break;
			default:
				break;
		}
	}

	return ret;
}

//*******************************************************************************************
//*   Function    : isClosed
//*   Description : 決済されているか
//*   Return      : 
//*******************************************************************************************
bool isClosed(CProc* obj)
{
	bool ret = false;
	int ticket;
	datetime closeTime = 0;

	ticket = obj.GetTicket();

	if(OrderSelect(ticket, SELECT_BY_TICKET) == true)
	{
  		closeTime = OrderCloseTime();
		if((closeTime > 0) && (closeTime < Time[0]))
		{
			ret = true;
			saveData02(fd0, "isClosed MODE_TRADES ", "", Time[0], closeTime, 0, obj.GetId(), obj.GetSeqNo(), ticket, ret, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0); //dbg_save	
		}
	}

	
	return ret;

}
	
//*******************************************************************************************
//*   Function    : mySendMail
//*   Description : 
//*   Return      : 
//*******************************************************************************************
void mySendMail(int ticket, int orderStatus)
{
	string str ;
	string strType;
	string strTitle;
	double entryPrice;
	double sl;
	double tp;
	int type;
	double lots;
	double pl;
	bool plFlg = false;
	
	if(OrderSelect(ticket, SELECT_BY_TICKET) == true)
	{
		entryPrice = OrderOpenPrice();
		sl = OrderStopLoss();
		tp = OrderTakeProfit();
		type = OrderType();
		lots = OrderLots();
		pl = OrderProfit();
		
		switch(orderStatus)
		{
			case ORDER_STATUS_PENDING_OP_SELLSTOP:
				strType = "OP_SELLSTOP";
				break;
			case ORDER_STATUS_FILLED_OP_SELLSTOP:
				strType = "Filled OP_SELLSTOP";
				break;
			case ORDER_STATUS_CANCELED_OP_SELLSTOP:
				strType = "Canceled OP_SELLSTOP";
				break;
			case ORDER_STATUS_CLOSED_OP_SELL:
				strType = "Closed OP_SELLSTOP";
				plFlg = true;
				break;
			case ORDER_STATUS_PENDING_OP_BUYSTOP:
				strType = "OP_BUYSTOP";
				break;
			case ORDER_STATUS_FILLED_OP_BUYSTOP:
				strType = "Filled OP_BUYSTOP";
				break;
			case ORDER_STATUS_CANCELED_OP_BUYSTOP:
				strType = "Canceled OP_BUYSTOP";
				break;
			case ORDER_STATUS_CLOSED_OP_BUY:
				strType = "Closed OP_BUYSTOP";
				plFlg = true;
				break;
			case ORDER_STATUS_FILLED_OP_BUY:
				strType = "Filled OP_BUY";
				break;
			case ORDER_STATUS_FILLED_OP_SELL:
				strType = "Filled OP_SELL";
				break;
			default:
				strType = "Order Type None";
		}
		
		strTitle = Symbol();
		strTitle += " " + strType;

		str = TimeToStr(Time[0], TIME_DATE | TIME_MINUTES) + "\r\n";
		str += Symbol() + "\r\n";
		str += "type:      " + strType + "\r\n";
		str += "entryPrice:" + DoubleToStr(entryPrice) + "\r\n";
		str += "sl:        " + DoubleToStr(sl) + "\r\n";
		str += "tp:        " + DoubleToStr(tp) + "\r\n";
		str += "lots:      " + DoubleToStr(lots) + "\r\n";
		if(plFlg)
		{
			str += "PL:      " + DoubleToStr(pl) + "\r\n";
		}

		str += "\r\n";

//		saveData02(fd0, strTitle, str, Time[0], 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0); //dbg_save	
		
		SendMail(strTitle, str);
	}
}

//*******************************************************************************************
//*   Function    : drawSlLine
//*   Description : 損失のあったバーに垂直線を引く
//*   Return      : 
//*******************************************************************************************
void drawSlLine()
{
	int total;
	int ctr;
	datetime closeTime;
	string objNameBase = "slLine_";
	string objName = "";
	double pl;
	color cl;
	
	total = OrdersHistoryTotal();
	
	for(ctr=0; ctr<total; ctr++)
	{
		if(OrderSelect(ctr, SELECT_BY_POS, MODE_HISTORY) == false) break;
		if((OrderSymbol() != Symbol())) continue;
		
		pl = OrderProfit();
		closeTime = OrderCloseTime();
		if(pl < 0)
		{
			cl = Red;
			objName = objNameBase + IntegerToString(ctr);
			ObjectCreate(objName, OBJ_VLINE, 0, closeTime, 0, 0, 0, 0, 0);
			ObjectSet(objName, OBJPROP_COLOR, cl);
			saveData02(fd0, "drawSlLine Minus", objName, closeTime, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0); //dbg_save	
		}
		else if(pl > 0)
		{
			cl = Turquoise;
			objName = objNameBase + IntegerToString(ctr);
			ObjectCreate(objName, OBJ_VLINE, 0, closeTime, 0, 0, 0, 0, 0);
			ObjectSet(objName, OBJPROP_COLOR, cl);
			saveData02(fd0, "drawSlLine Plus", objName, closeTime, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0); //dbg_save	
		}
		ObjectSet(objName, OBJPROP_COLOR, cl);
	}
}

//*******************************************************************************************
//*   Function    : candleColor
//*   Description : ローソク足表示にする
//*   Return      : 
//*******************************************************************************************
void candleColor()
{
	long chartId = 0;
	color chartColorChartUp = Lime;
	color chartColorChartDown = Red;
	color chartColorCandleBull = Lime;
	color chartColorCandleBear = Red;
	long charMode = CHART_CANDLES;
	
	//チャートの上昇バー色
	ChartSetInteger(chartId, CHART_COLOR_CHART_UP, chartColorChartUp);
	//チャートの下落バー色
	ChartSetInteger(chartId, CHART_COLOR_CHART_DOWN, chartColorChartDown);
	//ローソク足の上昇色
	ChartSetInteger(chartId, CHART_COLOR_CANDLE_BULL, chartColorCandleBull);
	//ローソク足の下落色
	ChartSetInteger(chartId, CHART_COLOR_CANDLE_BEAR, chartColorCandleBear);
	//チャートの種類(ローソク足、バーチャート、ラインチャート)
	ChartSetInteger(chartId, CHART_MODE, charMode);
}

//*******************************************************************************************
//*   Function    : ma3_main
//*   Description : 
//*   Return      : 
//*******************************************************************************************
void ma3_main()
{
	//関数実行
	ma3_list.DoProc();
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
	int tmp = 1;
	ma3_main();
	
  }

//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
  {
//---
   
  }
//+------------------------------------------------------------------+
//| Tester function                                                  |
//+------------------------------------------------------------------+
double OnTester()
  {
//---
   double ret=0.0;
//---

//---
   return(ret);
  }
//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
  {
//---
   
  }
//+------------------------------------------------------------------+

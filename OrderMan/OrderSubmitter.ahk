/*
  Copyright (C) 2015  SpiffSpaceman

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <http://www.gnu.org/licenses/>
*/

/*
	entryOrderNOW, stopOrderNOW = objects linked with our entry and stop orders in orderbook
*/
limitOrder( direction, scrip, entry, stop ){
	global TITLE_NOW, entryOrderNOW, stopOrderNOW
		
	entry.orderType := "LIMIT"
	entry.trigger	:= 0
	stop.orderType	:= "SL-M"
	stop.price		:= 0
	
	if ( !checkOpenOrderEmpty() )
		return
	
	entryOrderNOW := newOrderCommon(direction, scrip, entry)
	
	if( ! IsObject(entryOrderNOW)  )
		return
	
	stopOrderNOW  := newOrderCommon( reverseDirection(direction), scrip, stop )
	
	updateStatus()
}

modifyLimitOrder( scrip, entry, stop  ){
	
	global entryOrderNOW, stopOrderNOW	
	
	if( IsObject(entryOrderNOW) && entry != "" ){
		
		entry.orderType := "LIMIT"
		entry.trigger	:= 0
		
		direction 	    := getDirectionFromOrder( entryOrderNOW )			// same direction as linked order
		entryOrderNOW   := modifyOrderCommon( entryOrderNOW, direction, scrip, entry )
	}
	
	if( IsObject(stopOrderNOW) && stop != "" ){
		
		stop.orderType	:= "SL-M"
		stop.price		:= 0
		
		direction 	    := getDirectionFromOrder( stopOrderNOW )
		stopOrderNOW    := modifyOrderCommon( stopOrderNOW, direction, scrip, stop )
	}
	
	updateStatus()
}




// --  Private -- 

modifyOrderCommon( orderNOW,  direction, scrip, orderDetails ){
	
	global TITLE_BUY, TITLE_SELL	
	
	winTitle := direction == "B" ? TITLE_BUY : TITLE_SELL	
	
	opened := openModifyOrderForm( orderNOW, winTitle )						// Open Order by clicking on Modify in Order Book	
	if( !opened )
		return
	
	SubmitOrderCommon( winTitle, scrip, orderDetails )						// Fill up new details and submit	
	orderNOW := getOrderDetails( orderNOW.nowOrderNo )						// Get updated order details

	if( orderNOW = -1 ){
		MsgBox, % 262144,,  Bug? - Updated Order not found in Orderbook after Modification
	}
	return orderNOW
}

newOrderCommon( direction, scrip, order ){
	
	global ORDER_STATUS_COMPLETE, ORDER_STATUS_OPEN, ORDER_STATUS_TRIGGER_PENDING, ORDER_STATUS_PUT, ORDER_STATUS_VP
	
	readOrderBook()															// Read current status so that we can identify new order
	
	winTitle := openOrderForm( direction )
	SubmitOrder( winTitle, scrip, order )
	
	orderNOW := getNewOrder()
	
	if( orderNOW == -1 ){													// New order found in Orderbook ?
		
		identifier := orderIdentifier( direction, order.price, order.trigger) 				
		MsgBox, % 262144+4,,  Order( %identifier%  ) Not Found yet in Order Book. Do you want to continue?
		IfMsgBox No
			return -1
		orderNOW := getNewOrder()
	}

	status := orderNOW.status												// check status
	
	Loop, 12{																// Wait for upto 3 seconds for order to be validated
		if( status == ORDER_STATUS_PUT || status == ORDER_STATUS_VP )
			Sleep, 250
		else
			break
	}	
																			// if Entry order may have failed, ask
	if( status != ORDER_STATUS_OPEN && status != ORDER_STATUS_TRIGGER_PENDING && status != ORDER_STATUS_COMPLETE  ){

		identifier := orderIdentifier( orderNOW.buySell, orderNOW.price, orderNOW.triggerPrice)
		MsgBox, % 262144+4,,  Order( %identifier%  ) has status - %status%. Do you want to continue?
		IfMsgBox No
			return -2
	}
	
	return orderNOW
}

openOrderForm( direction ){
	global TITLE_NOW, TITLE_BUY, TITLE_SELL
	
	if( direction == "B" ){
		winTitle := TITLE_BUY
		WinMenuSelectItem, %TITLE_NOW%,, Orders and Trades, Buy Order Entry	// F1 F2 F3 sometimes (rarely) does not work. Menu Does
	}
	else if( direction == "S" ){
		winTitle := TITLE_SELL
		WinMenuSelectItem, %TITLE_NOW%,, Orders and Trades, Sell Order Entry
	}		
	WinWait, %winTitle%,,5
	
	return winTitle
}

openModifyOrderForm( orderNOW, winTitle ){
	global TITLE_ORDER_BOOK, OpenOrdersColumnIndex
		
	orderNoColIndex := OpenOrdersColumnIndex.nowOrderNo							// column number containing NOW Order no in Order Book > open orders
	searchMeOrderNo	:= orderNOW.nowOrderNo
		
	Loop, 3{																	// Select order in Order Book. Search 3 times as a precaution
		ControlGet, RowCount, List, Count, SysListView321, %TITLE_ORDER_BOOK%	// No of rows in open orders
		ControlSend, SysListView321, {Home 2}, %TITLE_ORDER_BOOK%				// Start from top and search for order

		Loop, %RowCount%{														// Get order number of selected row and compare
			ControlGet, RowOrderNo, List, Selected Col%orderNoColIndex%, SysListView321, %TITLE_ORDER_BOOK%
		
			if( RowOrderNo = searchMeOrderNo ){									// Found, Click on Modify
				ControlClick, Button1, %TITLE_ORDER_BOOK%,,,, NA				
				WinWait, %winTitle%,,5
				
				return true
			}
			ControlSend, SysListView321, {Down}, %TITLE_ORDER_BOOK%				// Move Down to next row if not found yet
		}				
	}
	
	MsgBox, Order %searchMeOrderNo% Not Found in OrderBook > Open Orders
	return false
}

SubmitOrder( winTitle, scrip, order ){										// Fill up opened Buy/Sell window and verify
	
	Control, ChooseString , % scrip.segment,     ComboBox1,  %winTitle%		// Exchange Segment - NFO/NSE etc
	Control, ChooseString , % scrip.instrument,  ComboBox5,  %winTitle%		// Inst Name - FUTIDX / EQ  etc
	Control, ChooseString , % scrip.symbol, 	 ComboBox6,  %winTitle%		// Scrip Symbol
	Control, ChooseString , % scrip.type,  	   	 ComboBox7,  %winTitle%		// Type - XX/PE/CE
	Control, ChooseString , % scrip.strikePrice, ComboBox8,  %winTitle%		// Strike Price for options
	Control, Choose		  , % scrip.expiryIndex, ComboBox9,  %winTitle%		// Expiry Date - Set by Position Index (1/2 etc)

	Control, ChooseString , % order.orderType,   ComboBox3,  %winTitle%		// Order Type - LIMIT/MARKET/SL/SL-M
	Control, ChooseString , % order.prodType,    ComboBox10, %winTitle%		// Prod Type - MIS/NRML/CNC
	Control, ChooseString , DAY, 			   	 ComboBox11, %winTitle%		// Validity - Day/IOC
	
	SubmitOrderCommon( winTitle, scrip, order  )
}

/*
	Fills up stuff that is relevant to both create and update orders
*/
SubmitOrderCommon( winTitle, scrip, order ){
	global	TITLE_TRANSACTION_PASSWORD, AutoSubmit

	ControlSetText, Edit3, % order.qty,     %winTitle%						// Qty
	if( order.price != 0 )
		ControlSetText, Edit4, % order.price,   %winTitle%					// Price
	if( order.trigger != 0 )
		ControlSetText, Edit7, % order.trigger, %winTitle%					// Trigger
	
	if( AutoSubmit ){		
		ControlClick, Button4, %winTitle%,,,, NA							// Submit Order		
		WinWaitClose, %winTitle%, 2											// Wait for order window to close. If password needed, notify	
		IfWinExist, %TITLE_TRANSACTION_PASSWORD%
			MsgBox, 262144,, Enter Transaction password in NOW and then click ok
	}
	
	WinWaitClose, %winTitle%
}

checkOpenOrderEmpty(){
	if( doOpenOrdersExist() ){												// Entry
		MsgBox, % 262144+4,, Some Open Orders already exist . Continue?
		IfMsgBox No
			return false
	}
	return true
}

orderIdentifier( direction, price, trigger ){
	identifier := direction . ", Price " . price . ", Trigger " . trigger
	return identifier
}

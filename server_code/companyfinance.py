import yfinance as yf
import pandas as pd
from flask import jsonify

def stock_info(company: str, symbol: str):
    """
    Fetch stock profile information.
    Returns a JSON-compatible dictionary.
    """
    symbol_ns = symbol.strip().upper() + ".NS"
    stock = yf.Ticker(symbol_ns)

    try:
        info = stock.info
        description = info.get("longBusinessSummary", "No description available.")
        country = info.get("country", "Unknown")
        sector = info.get("sector", "Unknown")
        exchange = info.get("exchange", "Unknown")

        return {
            "company": company,
            "symbol": symbol,
            "description": description,
            "country": country,
            "sector": sector,
            "exchange": exchange,
        }

    except Exception as e:
        return {"error": f"Error retrieving data: {e}"}


def stock_balance(company: str, symbol: str):
    """
    Fetch stock balance sheet and income statement data.
    Returns a JSON-compatible dictionary.
    """
    stock_symbol = symbol.strip().upper() + ".NS"
    stock = yf.Ticker(stock_symbol)

    try:
        balance_sheet = stock.balance_sheet
        income_stmt = stock.financials

        if balance_sheet.empty and income_stmt.empty:
            return {"error": "No financial data available."}

        balance_data = {}

        if not balance_sheet.empty:
            balance_sheet_crores = (balance_sheet / 1e7).round(2)
            for col in balance_sheet_crores.columns:
                year = str(col.year)
                balance_data[year] = {}
                for index, value in balance_sheet_crores[col].items():
                    balance_data[year][index] = f"{value:.2f} Cr" if pd.notnull(value) else "nan Cr"

        keys_of_interest = ['Operating Revenue', 'Operating Income', 'Net Income', 'Gross Profit', 'Total Revenue']

        if not income_stmt.empty:
            income_stmt_crores = (income_stmt / 1e7).round(2)
            for key in keys_of_interest:
                if key in income_stmt_crores.index:
                    row = income_stmt_crores.loc[key]
                    for date, value in row.items():
                        year = str(date.year)
                        if year not in balance_data:
                            balance_data[year] = {}
                        balance_data[year][key] = f"{value:.2f} Cr" if pd.notnull(value) else "nan Cr"

        ordered_balance_data = {}
        for year, data in balance_data.items():
            ordered = {}
            for key in keys_of_interest:
                if key in data:
                    ordered[key] = data.pop(key)
            ordered.update(data)
            ordered_balance_data[year] = ordered

        return {
            "company": company,
            "symbol": symbol,
            "balance_sheet": ordered_balance_data
        }

    except Exception as e:
        return {"error": str(e)}






#correct from above#




def week_price(symbol: str):
    """
    Fetches last 7 trading days' closing prices for the given stock symbol.
    
    Args:
        symbol (str): Stock symbol (e.g., 'INFY')
    
    Returns:
        List[dict]: List of dictionaries containing 'date', 'day', and 'closing_price'
    """
    symbol = symbol.strip().upper() + ".NS"
    
    end_date = datetime.datetime.today()
    start_date = end_date - datetime.timedelta(days=14)  # Last 2 weeks to ensure at least 7 trading days
    
    stock = yf.Ticker(symbol)
    df = stock.history(start=start_date, end=end_date, interval="1d")
    
    if df.empty:
        return []
    
    df = df.tail(7)  # Take only last 7 trading days
    
    closing_prices = []
    for index, row in df.iterrows():
        closing_prices.append({
            "date": index.strftime('%Y-%m-%d'),
            "day": index.strftime('%a'),
            "closing_price": round(row['Close'], 2)
        })
    
    return closing_prices


def stock_balance(company: str, symbol: str):
    """
    Fetch stock balance sheet and income statement data.
    Returns a JSON-compatible dictionary.
    """
    stock_symbol = symbol.strip().upper() + ".NS"
    stock = yf.Ticker(stock_symbol)

    try:
        balance_sheet = stock.balance_sheet
        income_stmt = stock.financials

        if balance_sheet.empty and income_stmt.empty:
            return {"error": "No financial data available."}

        balance_data = {}

        # Convert balance sheet to crores
        if not balance_sheet.empty:
            balance_sheet_crores = (balance_sheet / 1e7).round(2)
            for col in balance_sheet_crores.columns:
                year = str(col.year)
                balance_data[year] = {}
                for index, value in balance_sheet_crores[col].items():
                    balance_data[year][index] = f"{value:.2f} Cr" if pd.notnull(value) else "nan Cr"

        # Include important income statement metrics
        keys_of_interest = ['Operating Revenue', 'Operating Income', 'Net Income', 'Gross Profit', 'Total Revenue']
        if not income_stmt.empty:
            income_stmt_crores = (income_stmt / 1e7).round(2)
            for key in keys_of_interest:
                if key in income_stmt_crores.index:
                    row = income_stmt_crores.loc[key]
                    for date, value in row.items():
                        year = str(date.year)
                        if year not in balance_data:
                            balance_data[year] = {}
                        balance_data[year][key] = f"{value:.2f} Cr" if pd.notnull(value) else "nan Cr"

        # Order keys
        ordered_balance_data = {}
        for year, data in balance_data.items():
            ordered = {}
            for key in keys_of_interest:
                if key in data:
                    ordered[key] = data.pop(key)
            ordered.update(data)
            ordered_balance_data[year] = ordered

        return {
            "company": company,
            "symbol": symbol,
            "balance_sheet": ordered_balance_data
        }

    except Exception as e:
        return {"error": str(e)}





def f_25_data(symbol):
    try:
        symbol_ns = symbol.upper() + ".NS"   # NSE format
        stock = yf.Ticker(symbol_ns)
        hist = stock.history(period="25wk")

        if hist.empty:
            return []

        hist = hist.reset_index()

        data = []
        for idx, row in hist.iterrows():
            data.append({
                "week": row['Date'].strftime("%d-%b"),
                "closing_price": row['Close']
            })
        return data

    except Exception as e:
        print(f"Error fetching 25-week data for {symbol}: {e}")
        return []   # return empty list instead of crashing














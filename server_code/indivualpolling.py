import requests
from bs4 import BeautifulSoup
from fuzzywuzzy import process
import pandas as pd
from io import BytesIO
import datetime
import yfinance as yf
import pickle
import traceback
from flask import jsonify

# Constants
DATA_URL = "https://nsearchives.nseindia.com/content/equities/EQUITY_L.csv"
GOOGLE_FINANCE_CLASS = "YMlKec fxKbKc"
HEADERS = {'User-Agent': 'Mozilla/5.0'}

def load_symbol_data():
    """Load NSE equity symbol data."""
    response = requests.get(DATA_URL, headers=HEADERS)
    return pd.read_csv(BytesIO(response.content))

def is_market_open() -> bool:
    """Check if market is open (Mon-Fri, 9:15 AM - 3:30 PM IST)."""
    now = datetime.datetime.now()
    if now.strftime('%a') in ['Sat', 'Sun']:
        return False
    market_open = now.replace(hour=9, minute=15, second=0, microsecond=0)
    market_close = now.replace(hour=15, minute=30, second=0, microsecond=0)
    return market_open <= now <= market_close

def fetch_live_price(symbol: str) -> tuple[str | None, str]:
    """
    Fetch live price and market cap using yfinance.
    Returns a tuple: (price, market_cap)
    - price: string like "2456.50" or None if not found
    - market_cap: string like "15.30T" or "N/A" if not found
    """
    try:
        ticker = yf.Ticker(f"{symbol}.NS")
        info = ticker.info
        price = info.get("regularMarketPrice")
        price_str = "{:.2f}".format(price) if price is not None else None
        market_cap = info.get("marketCap")
        if market_cap is None:
            market_cap_str = "N/A"
        elif market_cap >= 1e12:
            market_cap_str = f"{market_cap/1e12:.2f}T"
        elif market_cap >= 1e9:
            market_cap_str = f"{market_cap/1e9:.2f}B"
        elif market_cap >= 1e6:
            market_cap_str = f"{market_cap/1e6:.2f}M"
        else:
            market_cap_str = str(market_cap)
        return price_str, market_cap_str
    except Exception as e:
        print("Price & Market cap fetch error:", e)
        return None, "N/A"

def get_stock_info(query: str) -> dict:
    """Return company name, symbol, live price, and market status."""
    df = load_symbol_data()
    choices = df['SYMBOL'].tolist() + df['NAME OF COMPANY'].tolist()
    match, score = process.extractOne(query.upper(), choices)
    if match in df['SYMBOL'].values:
        row = df[df['SYMBOL'] == match].iloc[0]
    else:
        row = df[df['NAME OF COMPANY'] == match].iloc[0]
    symbol = row['SYMBOL']
    company = row['NAME OF COMPANY']
    price = fetch_live_price(symbol)
    return {
        "company": company,
        "symbol": symbol,
        "price": price,
        "market_status": "Open" if is_market_open() else "Closed"
    }

def get_pe_ratio(symbol: str) -> float | None:
    try:
        ticker_symbol = symbol.upper() + ".NS"
        ticker = yf.Ticker(ticker_symbol)
        shares_outstanding = ticker.info.get("sharesOutstanding")
        financials = ticker.financials
        if "Net Income" in financials.index:
            latest_net_profit = int(financials.loc["Net Income"].iloc[0])
        else:
            latest_net_profit = None
        if shares_outstanding and latest_net_profit:
            earnings = latest_net_profit / shares_outstanding
            price = ticker.history(period="1d")["Close"].iloc[-1]
            pe_ratio = price / earnings
            return round(pe_ratio, 2)
        else:
            return None
    except Exception as e:
        print("Error calculating P/E:", e)
        return None

############################INDEXPOLLING########################################
PKL_FILE_PATH = r"C:\Users\Admin\Desktop\rangmahal (2)\MarketSutra\server_code\index_symbols.pkl"
HEADERS = {'User-Agent': 'Mozilla/5.0'}
GOOGLE_FINANCE_CLASS = "YMlKec fxKbKc"

def market_status() -> str:
    """Check if Indian stock market is open (Mon–Fri, 9:15 AM – 3:30 PM)."""
    now = datetime.now()
    market_open_time = dt_time(9, 15)
    market_close_time = dt_time(15, 30)
    if now.strftime("%a") in ["Sat", "Sun"]:
        return "Closed"
    return "Open" if market_open_time <= now.time() <= market_close_time else "Closed"

def symbols() -> dict:
    """Load index symbols from pickle file safely."""
    try:
        with open(PKL_FILE_PATH, 'rb') as f:
            symbols_data = pickle.load(f)
            return dict(symbols_data)
    except Exception as e:
        print(f"Error loading symbols: {e}")
        return {}

def fetch_index_price(index_name=None, symbol=None):
    from flask import jsonify
    import pickle, requests
    from bs4 import BeautifulSoup
    from datetime import datetime, time as dt_time
    FILE_PATH = r"C:\Users\Admin\Desktop\rangmahal (2)\MarketSutra\server_code\index_symbols.pkl"
    HEADERS = {'User-Agent': 'Mozilla/5.0'}

    def market_status():
        now = datetime.now()
        return dt_time(9, 15) <= now.time() <= dt_time(15, 30) and now.strftime("%a") not in ["Sat", "Sun"]

    if symbol is None:
        try:
            with open(FILE_PATH, 'rb') as f:
                symbols_dict = pickle.load(f)
        except Exception as e:
            return jsonify({"error": f"Error loading pickle file: {e}"})
        if not index_name or index_name not in symbols_dict:
            return jsonify({"error": f"Index '{index_name}' not found in pickle file"})
        symbol = symbols_dict[index_name]

    symbol_code = f"{index_name}:{symbol}" if index_name else symbol
    try:
        url = f"https://www.google.com/finance/quote/{symbol_code}"
        resp = requests.get(url, headers=HEADERS, timeout=10)
        soup = BeautifulSoup(resp.text, "html.parser")
        price_tag = soup.find("div", class_="YMlKec fxKbKc")
        price = float(price_tag.text.replace(",", "").replace("₹", "").strip()) if price_tag else None
    except Exception as e:
        return jsonify({"error": f"Error fetching {symbol_code}: {e}"})
    response = {
        "price": price,
        "market_status": "OPEN" if market_status() else "CLOSED",
        "symbol_code": symbol_code,
        "timestamp": datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    }
    return jsonify(response)

def market_status() -> str:
    """Check if Indian stock market is open (Mon–Fri, 9:15 AM – 3:30 PM)."""
    now = datetime.now()
    market_open_time = dt_time(9, 15)
    market_close_time = dt_time(15, 30)
    if now.strftime("%a") in ["Sat", "Sun"]:
        return "Closed"
    return "Open" if market_open_time <= now.time() <= market_close_time else "Closed"

PKL_FILE_PATH = r"C:\Users\Admin\Desktop\rangmahal (2)\MarketSutra\server_code\symbols_info.pkl"

def fetch_25_week_prices(index_name, days=25):
    """Fetch last 'days' closing prices for a given index_name from Yahoo Finance."""
    try:
        with open(PKL_FILE_PATH, "rb") as f:
            symbols_dict = pickle.load(f)
    except Exception as e:
        print("[ERROR] Failed to load pickle file:", e)
        return None
    symbol = symbols_dict.get(index_name)
    if not symbol:
        print(f"[ERROR] No symbol found for index_name '{index_name}'")
        return None
    print(f"[INFO] Fetching {days} days for index '{index_name}' symbol '{symbol}'")
    try:
        data = yf.download(
            tickers=symbol,
            period=f"{days+10}d",
            interval="1d",
            progress=False,
            auto_adjust=False
        )
        if data.empty:
            print(f"[ERROR] No data returned from yfinance for '{symbol}'")
            return None
        if isinstance(data.columns, pd.MultiIndex):
            close_cols = [col for col in data.columns if 'Close' in col]
            if not close_cols:
                print(f"[ERROR] No 'Close' column found in multi-index for '{symbol}'")
                return None
            close_series = data[close_cols[0]].dropna().tail(days)
        else:
            if 'Close' not in data.columns:
                print(f"[ERROR] No 'Close' column found for '{symbol}'")
                return None
            close_series = data['Close'].dropna().tail(days)
        if close_series.empty:
            print(f"[ERROR] No valid closing prices for '{symbol}'")
            return None
        prices_list = close_series.astype(float).tolist()
        print(f"[INFO] Last {len(prices_list)} prices for {symbol}: {prices_list[:5]} ...")
        return prices_list
    except Exception as e:
        print(f"[ERROR] Exception fetching data for symbol '{symbol}': {e}")
        return None

def four_25_week_data(symbol, days=25):
    """Fetch last 'days' closing prices for a symbol."""
    try:
        data = yf.download(
            tickers=symbol,
            period=f"{days+10}d",
            interval="1d",
            progress=False,
            auto_adjust=False
        )
        if data.empty or 'Close' not in data:
            ticker = yf.Ticker(symbol)
            current_price = ticker.history(period="1d")['Close'].iloc[-1]
            return [float(current_price)] * days
        close_series = data['Close']
        if hasattr(close_series, 'columns'):
            close_series = close_series.iloc[:, 0]
        close_series = close_series.dropna().tail(days)
        close_list = close_series.astype(float).tolist()
        while len(close_list) < days:
            close_list.insert(0, close_list[0])
        return close_list
    except Exception as e:
        print(f"[ERROR] Failed to fetch {symbol}: {e}")
        return [0.0] * days

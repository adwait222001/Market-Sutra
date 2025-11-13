import requests
from bs4 import BeautifulSoup
from fuzzywuzzy import process
import pandas as pd
from io import BytesIO
import datetime
import yfinance as yf

# ==============================
# CONSTANTS
# ==============================
DATA_URL = "https://nsearchives.nseindia.com/content/equities/EQUITY_L.csv"
GOOGLE_FINANCE_CLASS = "YMlKec fxKbKc"
HEADERS = {'User-Agent': 'Mozilla/5.0'}

# ==============================
# HELPER FUNCTIONS
# ==============================
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

def fetch_live_price(symbol: str) -> str | None:
    """Fetch live price from Google Finance."""
    try:
        url = f"https://www.google.com/finance/quote/{symbol}:NSE"
        response = requests.get(url, headers=HEADERS)
        soup = BeautifulSoup(response.text, 'html.parser')
        price_tag = soup.find(class_=GOOGLE_FINANCE_CLASS)
        if not price_tag:
            return None
        price_text = price_tag.text.strip()
        return "{:.2f}".format(float(price_text.strip()[1:].replace(",", "")))
    except Exception as e:
        print("Price fetch error:", e)
        return None

def get_stock_pe_ratio(symbol: str) -> dict:
    """
    Fetch EPS and P/E ratio for a given NSE stock symbol using yfinance.
    """
    try:
        ticker_symbol = symbol + ".NS"
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
        else:
            earnings = None
            pe_ratio = None

        return {
            "symbol": symbol,
            "shares_outstanding": shares_outstanding,
            "net_profit": latest_net_profit,
            "eps": round(earnings, 2) if earnings else None,
            "pe_ratio": round(pe_ratio, 2) if pe_ratio else None
        }

    except Exception as e:
        print(f"Error fetching P/E data for {symbol}: {e}")
        return None

# ==============================
# MAIN FUNCTION
# ==============================
def get_stock_info(query: str) -> dict:
    """Return company name, symbol, live price, EPS, P/E ratio, and market status."""
    df = load_symbol_data()

    # Fuzzy match with SYMBOL and NAME OF COMPANY
    choices = df['SYMBOL'].tolist() + df['NAME OF COMPANY'].tolist()
    match, score = process.extractOne(query.upper(), choices)

    # Extract row
    if match in df['SYMBOL'].values:
        row = df[df['SYMBOL'] == match].iloc[0]
    else:
        row = df[df['NAME OF COMPANY'] == match].iloc[0]

    symbol = row['SYMBOL']
    company = row['NAME OF COMPANY']

    # --- Keep the live price fetching loop as-is ---
    price = fetch_live_price(symbol)

    pe_data = get_stock_pe_ratio(symbol)

    return {
        "company": company,
        "symbol": symbol,
        "price": price,
        "eps": pe_data["eps"] if pe_data else None,
        "pe_ratio": pe_data["pe_ratio"] if pe_data else None,
        "market_status": "Open" if is_market_open() else "Closed"
    }

# ==============================
# TEST / USAGE EXAMPLE
# ==============================
if __name__ == "__main__":
    query = input("Enter company name or symbol: ")
    info = get_stock_info(query)
    print("\n--- STOCK INFORMATION ---")
    for k, v in info.items():
        print(f"{k.capitalize()}: {v}")

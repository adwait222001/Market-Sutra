import requests
from bs4 import BeautifulSoup
from datetime import datetime, time as dt_time
import pickle
import threading
from time import sleep

# ---------------- Market data setup ---------------- #
FILE_PATH = r"C:\Users\Admin\Desktop\rangmahal (2)\MarketSutra\server_code\index_symbols.pkl"
HEADERS = {'User-Agent': 'Mozilla/5.0'}

cached_data = {
    "prices": {},  # e.g. { "NIFTY 50": {"price": 19725.2, "difference": 24.5, "direction": "↑", "previous_close": 19700.7}, ... }
    "status": "Loading..."
}
cache_lock = threading.Lock()


# ---------------- Helper functions ---------------- #
def market_status():
    """Check if market is open based on time and weekday."""
    now = datetime.now()
    if now.strftime("%a") in ["Sat", "Sun"]:
        return False
    return dt_time(9, 15) <= now.time() <= dt_time(15, 30)


def fetch_price_and_close(symbol_code):
    """Fetch current price and previous close from Google Finance."""
    price = None
    previous_close = None
    try:
        url = f"https://www.google.com/finance/quote/{symbol_code}"
        resp = requests.get(url, headers=HEADERS, timeout=5)
        soup = BeautifulSoup(resp.text, "html.parser")

        # Current price
        price_tag = soup.find("div", class_="YMlKec fxKbKc")
        if price_tag and price_tag.text:
            price = float(price_tag.text.replace(",", "").replace("₹", ""))

        # Previous close
        labels = soup.find_all("div", class_="mfs7Fc")
        for label in labels:
            if label.text.strip().lower() == "previous close":
                parent = label.find_parent("div")
                if parent:
                    value_div = parent.find("div", class_="P6K39c")
                    if value_div:
                        text = value_div.text.strip().replace(",", "")
                        previous_close = float(text)
                break
    except Exception:
        pass
    return price, previous_close


# ---------------- Updated update_prices function ---------------- #
def update_prices():
    try:
        with open(FILE_PATH, 'rb') as f:
            symbols = pickle.load(f)

        # Keep only NIFTY_50 (NSE) and SENSEX (BSE)
        symbols = {
            "NIFTY_50": symbols.get("NIFTY_50", "INDEXNSE"),
            "SENSEX": symbols.get("SENSEX", "INDEXBOM"),
            "NIFTY_PHARMA": symbols.get("NIFTY_PHARMA","INDEXNSE"),
            "BSE-BANK": symbols.get("BSE-BANK","INDEXBOM"),
            "NIFTY_BANK": symbols.get("NIFTY_BANK","INDEXNSE"),
            "BSE-HC": symbols.get("BSE-HC","INDEXBOM")
            
        }

    except Exception as e:
        print(f"Error loading symbols: {e}")
        return

    is_open = market_status()
    status_msg = "Market is open" if is_open else "Market is closed"
    results = {}

    for name, exchange in symbols.items():
        symbol_code = f"{name}:{exchange}"
        price = None
        previous_close = None

        # Try to fetch live price and previous close
        fetched_price, fetched_close = fetch_price_and_close(symbol_code)
        if fetched_price is not None:
            price = fetched_price
        if fetched_close is not None:
            previous_close = fetched_close

        # Fallback to cached data if fetch failed
        with cache_lock:
            last_entry = cached_data["prices"].get(name)
        if price is None:
            if last_entry and last_entry.get("price") is not None:
                price = last_entry["price"]
        if previous_close is None:
            if last_entry and last_entry.get("previous_close") is not None:
                previous_close = last_entry["previous_close"]

        # If both fail (first run with no cache)
        if price is None:
            price = None
        if previous_close is None:
            previous_close = None

        # Calculate difference and direction
        if price is not None and previous_close is not None:
            diff = round(price - previous_close, 2)
            direction = "↑" if diff > 0 else "↓" if diff < 0 else "-"
        else:
            diff = None
            direction = "-"

        results[name] = {
            "price": price,
            "difference": diff,
            "direction": direction,
            "previous_close": previous_close
        }

    with cache_lock:
        cached_data["prices"] = results
        cached_data["status"] = status_msg

    print(f"Prices updated at {datetime.now().strftime('%Y-%m-%d %H:%M:%S')} - {status_msg}")


# ---------------- Scheduler & Accessor ---------------- #
def scheduler(interval=60):
    """Run the update every `interval` seconds."""
    while True:
        update_prices()
        sleep(interval)


def get_cached_prices():
    """Return a safe copy of cached data."""
    with cache_lock:
        return cached_data.copy()

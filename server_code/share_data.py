import pandas as pd
import requests
from io import BytesIO
from fuzzywuzzy import process

# Set headers for NSE data fetch
HEADERS = {'User-Agent': 'Mozilla/5.0'}
DATA_URL = "https://nsearchives.nseindia.com/content/equities/EQUITY_L.csv"
def load_symbol_data():
    """
    Load NSE symbol data CSV from official source and return as DataFrame.
    """
    response = requests.get(DATA_URL, headers=HEADERS)
    df = pd.read_csv(BytesIO(response.content))
    return df
def match_company(query, choice=None):
    """
    Match a query string to NSE company names or symbols.

    Parameters:
        query (str): Company name or symbol to search.
        choice (int or str, optional): If provided, selects a specific match by its index (1-based).

    Returns:
        list of dicts or single dict: Matching companies and symbols.
    """
    query = query.strip().upper()
    if not query:
        raise ValueError("Missing 'query' parameter.")

    df = load_symbol_data()
    combined = df['NAME OF COMPANY'].tolist() + df['SYMBOL'].tolist()
    matches = process.extract(query, combined, limit=10)

    results = []
    seen = set()
    for text, score in matches:
        if score < 60:
            continue
        rows = df[(df['NAME OF COMPANY'] == text) | (df['SYMBOL'] == text)]
        for _, row in rows.iterrows():
            company, symbol = row['NAME OF COMPANY'], row['SYMBOL']
            if (company, symbol) not in seen:
                results.append({
                    "company": company,
                    "symbol": symbol,
                    "score": score
                })
                seen.add((company, symbol))

    if not results:
        return []

    if choice:
        index = int(choice) - 1
        if index < 0 or index >= len(results):
            raise ValueError(f"Invalid choice. Please choose a number between 1 and {len(results)}.")
        return results[index]

    return results

####################################INDEX-POLLING########################################

file_path = r"C:\Users\Admin\Desktop\rangmahal (2)\MarketSutra\server_code\index_symbols_df.pkl"
def load_index_data():
    """Load NSE equity symbol data."""
    response = pd.read_pickle(file_path)
    return response
def match_index(query, choice=None):
    query = query.strip().upper()
    if not query:
        raise ValueError("Missing 'query' parameter.")
    df = load_index_data()
    combined = df['INDEX_NAME'].tolist() + df['SYMBOL'].tolist()
    matches = process.extract(query, combined, limit=10)
    results = []
    seen = set()
    for text, score in matches:
        if score < 60:
            continue
        rows = df[(df['INDEX_NAME'] == text) | (df['SYMBOL'] == text)]
        for _, row in rows.iterrows():
            company, symbol = row['NAME OF COMPANY'], row['SYMBOL']
            if (company, symbol) not in seen:
                results.append({
                    "company": company,
                    "symbol": symbol,
                    "score": score
                })
                seen.add((company, symbol))

    if not results:
        return []

    if choice:
        index = int(choice) - 1
        if index < 0 or index >= len(results):
            raise ValueError(f"Invalid choice. Please choose a number between 1 and {len(results)}.")
        return results[index]

    return results
    















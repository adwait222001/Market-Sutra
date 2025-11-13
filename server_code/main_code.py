from flask import Flask, jsonify, request, send_from_directory
from flask_cors import CORS
import os
import sqlite3
import details
import yfinance as yf
from fuzzywuzzy import process
import traceback
import pandas as pd
import pickle
from datetime import datetime,time as dt_time
import math as math
from details import init_db
from pan_card_details import init_ab
import pan_card_details
import indexfile
from indexfile import get_cached_prices, update_prices, scheduler
from indivualpolling import fetch_live_price,load_symbol_data,is_market_open
from indivualpolling import get_pe_ratio
from indivualpolling import fetch_index_price
from indivualpolling import symbols
from flask_socketio import SocketIO
from share_data import load_symbol_data,match_company
from share_data import load_index_data,match_index
from companyfinance import stock_info,stock_balance
from indivualpolling import fetch_25_week_prices
from companyfinance import week_price
from companyfinance import f_25_data
from indivualpolling import four_25_week_data
import paymentfile
from paymentfile import create_order,capture,return_from_paypal,cancel
#try-news-code here
from news import finance_news
from transaction_db import init_transaction_db, insert_transaction,fetch_all_transactions
from transaction_db import sell_transaction
from details import check_data_complete
UPLOAD_FOLDER = r"C:\Users\Admin\Desktop\rangmahal (2)\MarketSutra\server_code\uploads"
PKL_FILE_PATH = r"C:\Users\Admin\Desktop\rangmahal (2)\MarketSutra\server_code\symbols_info.pkl"
# Initialize databases
init_db()
init_ab()
init_transaction_db()

# ✅ Correct usage of __name__ instead of _name_
app = Flask(__name__)
CORS(app)
DATABASE = 'transactions.db'
# ---------------- Existing routes ---------------- #
app.add_url_rule('/image', 'handle_image', details.handle_image, methods=["POST", "GET"])
app.add_url_rule('/tdetail', 'add_name', details.add_name, methods=["POST", "GET"])
app.add_url_rule('/name', 'show_name', details.show_name, methods=["POST", "GET"])

# ---------------- PAN card routes ---------------- #
print("Registering /upload, /process_ocr, /process, /users, /animal routes...")
app.add_url_rule('/upload', 'save_uploaded_file', pan_card_details.save_uploaded_file, methods=["POST"])
app.add_url_rule('/process_ocr', 'process_ocr', pan_card_details.process_ocr, methods=["POST"])
app.add_url_rule('/process', 'confirm', pan_card_details.confirm, methods=["POST"])
app.add_url_rule('/users', 'list_users', pan_card_details.list_users, methods=["GET"])
app.add_url_rule('/animal', 'update_animal', pan_card_details.update_animal, methods=["POST"])

# ---------------- Utility routes ---------------- #
@app.route('/uploads/<filename>')
def uploaded_file(filename):
    return send_from_directory(UPLOAD_FOLDER, filename)

@app.route('/health')
def health():
    return jsonify({"status": "ok", "message": "Server is running"}), 200

# ---------------- Market data route ---------------- #
@app.route('/livedata')
def ticker():
    update_prices()
    return jsonify(get_cached_prices())


@app.route('/match', methods=['GET'])
def match_company():
    query = request.args.get("query", "").strip().upper()
    choice = request.args.get("choice")

    if not query:
        return jsonify({"error": "Missing 'query' parameter."}), 400

    try:
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
            return jsonify({"message": "No matching companies found with confidence > 60."})

        if choice:
            if not choice.isdigit():
                return jsonify({"error": "'choice' must be a number."}), 400
            index = int(choice) - 1
            if index < 0 or index >= len(results):
                return jsonify({"error": f"Invalid choice. Please choose a number between 1 and {len(results)}."}), 400

            selected = results[index]
            return jsonify({
                "selected": {
                    "company": selected["company"],
                    "symbol": selected["symbol"]
                }
            })

        numbered_results = {
            str(i + 1): {
                "company": item["company"],
                "symbol": item["symbol"]
            } for i, item in enumerate(results)
        }

        return jsonify({
            "matches": numbered_results,
            "instruction": "To select a specific company, use /match?query=XYZ&choice=number"
        })

    except Exception as e:
        return jsonify({"error": str(e)}), 500


'''
@app.route('/price', methods=['GET'])
def price_route():
    symbol = request.args.get('symbol', '').strip().upper()
    if not symbol:
        return jsonify({"error": "Please provide a 'symbol' parameter"}), 400

    try:
        # Load NSE symbols
        df = load_symbol_data()
        symbol_list = df['SYMBOL']

        # Fuzzy match symbol
        match = process.extractOne(symbol, symbol_list)
        if not match or match[1] < 50:
            return jsonify({"error": "Symbol not found or match score too low"}), 404

        matched_symbol = match[0]
        price = fetch_live_price(matched_symbol)
        if not price:
            return jsonify({"error": "Could not fetch current price"}), 500

        return jsonify({
            "symbol": matched_symbol,
            "market_status": "Open" if is_market_open() else "Closed",
            "price": price
        })

    except Exception as e:
        return jsonify({"error": str(e)}), 500

'''

@app.route('/price', methods=['GET'])
def price_route():
    symbol = request.args.get('symbol', '').strip().upper()
    if not symbol:
        return jsonify({"error": "Please provide a 'symbol' parameter"}), 400

    try:
        df = load_symbol_data()
        symbol_list = df['SYMBOL']
        match = process.extractOne(symbol, symbol_list)
        if not match or match[1] < 50:
            return jsonify({"error": "Symbol not found or match score too low"}), 404

        matched_symbol = match[0]

        # Fetch price and market cap
        price, market_cap = fetch_live_price(matched_symbol)
        if price is None:
            return jsonify({"error": "Could not fetch current price"}), 500

        return jsonify({
            "symbol": matched_symbol,
            "price": price,
            "market_cap": market_cap,
            "market_status": "Open" if is_market_open() else "Closed"
        })

    except Exception as e:
        import traceback
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500



@app.route('/finance', methods=['GET'])
def company_finance():
    company_input = request.args.get('company', '').strip()
    if not company_input:
        return jsonify({"error": "Please provide a 'company' parameter"}), 400

    try:
        df = load_symbol_data()

        # Normalize company names in DataFrame
        df['NAME OF COMPANY'] = df['NAME OF COMPANY'].str.strip().str.upper()
        company_input_norm = company_input.upper()

        # Fuzzy match
        match = process.extractOne(company_input_norm, df['NAME OF COMPANY'].tolist())

        if not match:
            return jsonify({"error": "Company not found"}), 404

        matched_company = match[0]
        match_score = match[1]

        # Get symbol
        symbol = df.loc[df['NAME OF COMPANY'] == matched_company, 'SYMBOL'].values[0]

        # Call finance functions with parameters
        balance = stock_balance(company=matched_company, symbol=symbol)
        info = stock_info(company=matched_company, symbol=symbol)

        response = {
            "company": matched_company,
            "symbol": symbol,
            "balance_sheet": balance,
            "stock_info": info
        }

        # Include warning if fuzzy match score is low
        if match_score < 60:
            response['warning'] = f"Match score is low ({match_score}); data may not be exact."

        return jsonify(response)

    except Exception as e:
        return jsonify({"error": str(e)}), 500
#check the path from here#


@app.route('/balancesheet', methods=['GET'])
def balance_sheet_route():
    company_input = request.args.get('company', '').strip()
    if not company_input:
        return jsonify({"error": "Please provide a 'company' parameter"}), 400

    try:
        df = load_symbol_data()
        df['NAME OF COMPANY'] = df['NAME OF COMPANY'].str.strip().str.upper()
        company_input_norm = company_input.upper()

        match = process.extractOne(company_input_norm, df['NAME OF COMPANY'].tolist())
        if not match:
            return jsonify({"error": "Company not found"}), 404

        matched_company = match[0]
        symbol = df.loc[df['NAME OF COMPANY'] == matched_company, 'SYMBOL'].values[0]

        balance = stock_balance(company=matched_company, symbol=symbol)

        # Include a warning if fuzzy match is low
        response = balance
        if match[1] < 60:
            response['warning'] = f"Match score is low ({match[1]}); data may not be exact."

        return jsonify(response)

    except Exception as e:
        return jsonify({"error": str(e)}), 500   


@app.route('/weekprice', methods=['GET'])
def week_price():
    import yfinance as yf
    import datetime
    from flask import request, jsonify

    symbol = request.args.get("symbol", "").strip().upper()
    if not symbol:
        return jsonify({"error": "Missing 'symbol' parameter."}), 400

    stock_symbol = f"{symbol}.NS"

    try:
        stock = yf.Ticker(stock_symbol)
        end_date = datetime.datetime.today()
        start_date = end_date - datetime.timedelta(days=60)  # buffer

        df = stock.history(start=start_date, end=end_date, interval="1d")

        if df.empty:
            return jsonify({"error": f"No trading data available for {stock_symbol}."}), 404

        df = df[df['Close'].notna()]  # remove rows with NaN close
        df = df.tail(7)

        if df.empty:
            return jsonify({"error": f"No valid closing prices for {stock_symbol}."}), 404

        closing_prices = []
        for index, row in df.iterrows():
            closing_prices.append({
                "date": index.strftime('%Y-%m-%d'),
                "day": index.strftime('%a'),
                "closing_price": f"₹{round(row['Close'], 2)}"
            })

        return jsonify({
            "symbol": symbol,
            "last_7_days": closing_prices
        }), 200

    except Exception as e:
        return jsonify({"error": f"Error fetching data for {stock_symbol}: {str(e)}"}), 500

@app.route('/25weekprice', methods=['GET'])
def get_25_week_price():
    symbol = request.args.get("symbol", "").strip().upper()
    
    if not symbol:
        return jsonify({"error": "Missing 'symbol' parameter."}), 400

    data = f_25_data(symbol)

    if not data:
        return jsonify({"error": f"No data available for {symbol}"}), 404

    return jsonify({
        "symbol": symbol,
        "data_points": len(data),
        "prices": data
    }), 200

@app.route('/livepe', methods=['GET'])
def live_pe_ratio():
    query = request.args.get("query", "").strip()
    if not query:
        return jsonify({"error": "Missing 'query' parameter."}), 400

    try:
        df = load_symbol_data()
        df['NAME OF COMPANY'] = df['NAME OF COMPANY'].str.strip().str.upper()
        query_upper = query.upper()

        choices = df['SYMBOL'].tolist() + df['NAME OF COMPANY'].tolist()
        match, score = process.extractOne(query_upper, choices)

        if score < 60:
            return jsonify({"error": "No matching company found"}), 404

        if match in df['SYMBOL'].values:
            row = df[df['SYMBOL'] == match].iloc[0]
        elif match in df['NAME OF COMPANY'].str.upper().values:
            row = df[df['NAME OF COMPANY'].str.upper() == match].iloc[0]
        else:
            return jsonify({"error": "No matching company found"}), 404

        symbol = row['SYMBOL']
        pe = get_pe_ratio(symbol)

        if pe is None:
            return jsonify({"error": f"Could not calculate P/E for {symbol}"}), 404

        return jsonify({
            "company": row['NAME OF COMPANY'],
            "symbol": symbol,
            "pe_ratio": pe
        }), 200

    except Exception as e:
        return jsonify({"error": str(e)}), 500








#####now here####

@app.route('/match_index', methods=['GET'])
def match_index():
    query = request.args.get("query", "").strip().upper()
    choice = request.args.get("choice")

    if not query:
        return jsonify({"error":"Missing 'query' Parameter."}), 400

    try:
        df = load_index_data()
        combined = df['INDEX_NAME'].tolist() + df['SYMBOL'].tolist()
        matches = process.extract(query, combined, limit=10)

        results = []
        seen = set()

        # Collect matches
        for text, score in matches:
            if score < 60:
                continue
            rows = df[(df['INDEX_NAME'] == text) | (df['SYMBOL'] == text)]
            for _, row in rows.iterrows():
                index_name, symbol = row['INDEX_NAME'], row['SYMBOL']
                if (index_name, symbol) not in seen:
                    results.append({
                        "index": index_name,
                        "symbol": symbol,
                        "score": score
                    })
                    seen.add((index_name, symbol))

        # After collecting matches
        if not results:
            return jsonify({"message": "No matching indices found with confidence > 60."})

        # Handle choice
        if choice:
            if not choice.isdigit():
                return jsonify({"error": "'choice' must be a number."}), 400
            choice_index = int(choice) - 1
            if choice_index < 0 or choice_index >= len(results):
                return jsonify({"error": f"Invalid choice. Please choose a number between 1 and {len(results)}."}), 400
            selected = results[choice_index]
            return jsonify({
                "selected": {
                    "index": selected["index"],
                    "symbol": selected["symbol"]
                }
            })

        # Return all matches
        numbered_results = {
            str(i+1): {
                "index": item["index"],
                "symbol": item["symbol"]
            } for i, item in enumerate(results)
        }

        return jsonify({
            "matches": numbered_results,
            "instruction": "To select a specific index, use /match_index?query=XYZ&choice=number"
        })

    except Exception as e:
        return jsonify({"error": str(e)}), 500






@app.route('/index-price', methods=['GET'])
def index_price():
    index_name = request.args.get("name")
    symbol = request.args.get("symbol")  # optional
    return fetch_index_price(index_name, symbol)


 
@app.route("/historical_prices", methods=["GET"])
def get_25_week_prices():
    index_name = request.args.get("index_name")
    if not index_name:
        return jsonify({"error": "Please provide index_name as a query parameter"}), 400

    prices = fetch_25_week_prices(index_name)
    if not prices:
        return jsonify({"error": f"No 25-week data found for {index_name}"}), 404

    return jsonify({
        "index_name": index_name,
        "25_week_prices": prices
    })

@app.route("/four-group", methods=["GET"])
def four_group():
    """
    Divide all indexes into 4 groups and return their last 25-day closing prices.
    """
    try:
        with open(PKL_FILE_PATH, "rb") as f:
            symbols_dict = pickle.load(f)
    except Exception as e:
        return jsonify({"error": f"Failed to load symbols: {e}"}), 500

    indexes = list(symbols_dict.items())
    total_indexes = len(indexes)
    group_size = math.ceil(total_indexes / 4)

    response = {}
    for i in range(4):
        group_indexes = indexes[i*group_size:(i+1)*group_size]
        group_data = {}
        for name, symbol in group_indexes:
            group_data[name] = four_25_week_data(symbol)
        response[f"group_{i+1}"] = group_data

    return jsonify(response)

@app.route("/marketcap", methods=["GET"])
def marketcap():
    """
    Fetch market cap for a given company name.
    Returns market cap divided by 1000.
    """
    company_name = request.args.get("company")
    if not company_name:
        return jsonify({"error": "Company name is required"}), 400

    try:
        df = load_symbol_data()

        # Fuzzy match
        choices = df['SYMBOL'].tolist() + df['NAME OF COMPANY'].tolist()
        match, score = process.extractOne(company_name.upper(), choices)

        # Get symbol
        if match in df['SYMBOL'].values:
            symbol = match
        else:
            symbol = df[df['NAME OF COMPANY'] == match]['SYMBOL'].iloc[0]

        # Fetch market cap
        ticker = yf.Ticker(symbol + ".NS")
        market_cap = ticker.info.get("marketCap")
        if market_cap:
            market_cap = round(market_cap / 1000, 2)
        else:
            market_cap = None

        return jsonify({
            "company": company_name,
            "symbol": symbol,
            "market_cap": market_cap
        })

    except Exception as e:
        return jsonify({"error": str(e)}), 500

app.add_url_rule('/news', 'f-news', finance_news, methods=['GET'])

@app.route('/add_transaction', methods=['POST'])
def add_transaction_route():
    """
    Receives JSON from frontend and inserts into the transactions DB.
    Expected JSON fields:
        uid, company, symbol, amount, sector, shares
    """
    data = request.get_json()
    try:
        uid = data['uid']
        company = data['company']
        symbol = data['symbol']
        #amount = float(data['amount'])
        sector = data['sector']
        shares = int(data['shares'])

        # Insert into DB
        #insert_transaction(uid, company, symbol, amount, sector, shares)
        insert_transaction(uid, company, symbol,sector, shares)

        return jsonify({"status": "success", "message": "Transaction added"}), 200

    except KeyError as ke:
        return jsonify({"status": "error", "message": f"Missing key: {ke}"}), 400
    except ValueError as ve:
        return jsonify({"status": "error", "message": f"Invalid data type: {ve}"}), 400
    except Exception as e:
        import traceback
        traceback.print_exc()
        return jsonify({"status": "error", "message": str(e)}), 500

@app.route("/get_transactions", methods=["GET"])
def get_transactions():
    try:
        transactions = fetch_all_transactions()
        return jsonify({"status": "success", "transactions": transactions}), 200
    except Exception as e:
        print(f"Exception in /get_transactions: {e}")
        return jsonify({"status": "error", "message": str(e)}), 500


###

@app.route('/sell_transaction', methods=['POST'])
def sell_transaction_route():
    data = request.get_json()
    uid = data.get("uid")
    company = data.get("company")
    symbol = data.get("symbol")
    shares = data.get("shares")

    result = sell_transaction(uid, company, symbol, shares)
    return jsonify(result)

app.add_url_rule('/create-order', 'create_order', paymentfile.create_order, methods=["POST", "GET"])
app.add_url_rule('/capture', 'capture_order', paymentfile.capture, methods=["GET"])
app.add_url_rule('/return', 'return_from_paypal', paymentfile.return_from_paypal, methods=["GET"])
app.add_url_rule('/cancel', 'cancel_payment', paymentfile.cancel, methods=["GET"])
app.add_url_rule('/check', 'check-in',details.check_data_complete,methods=["POST"])
# ---------------- Run server ---------------- #
# ✅ Correct usage of __name__ and __main__
if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=False, use_reloader=True)

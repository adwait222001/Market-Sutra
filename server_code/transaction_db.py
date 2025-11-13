import sqlite3
import os

# ✅ Always store DB in the same folder as this file
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DATABASE = os.path.join(BASE_DIR, "transactions.db")


def init_transaction_db():
    """
    Initialize the transactions database and create the table if it doesn't exist.
    """
    conn = sqlite3.connect(DATABASE)
    c = conn.cursor()
    c.execute('''
        CREATE TABLE IF NOT EXISTS transactions (
            id TEXT,                  -- Firebase UID
            company TEXT NOT NULL,
            symbol TEXT NOT NULL,
            sector TEXT NOT NULL,
            shares INTEGER NOT NULL,
            timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    conn.commit()
    conn.close()


def insert_transaction(uid: str, company: str, symbol: str, sector: str, shares: int):
    """
    Insert or update a transaction record.
    - If (uid, company, symbol) exists → update shares (add) and update sector.
    - If not → insert a new record.
    - ✅ If old sector exists and is not 'NA', keep it if new sector is 'NA'.
    """
    conn = sqlite3.connect(DATABASE)
    c = conn.cursor()

    # ✅ Check if record already exists
    c.execute("""
        SELECT shares, sector FROM transactions
        WHERE id = ? AND company = ? AND symbol = ?
    """, (uid, company, symbol))
    row = c.fetchone()

    if row:
        old_shares, old_sector = row

        # ✅ Determine which sector to use
        if sector.strip().upper() == "NA" and old_sector.strip().upper() != "NA":
            final_sector = old_sector  # keep the existing one
        else:
            final_sector = sector  # use new sector if valid or both NA

        new_shares = old_shares + shares

        c.execute("""
            UPDATE transactions
            SET shares = ?, sector = ?, timestamp = CURRENT_TIMESTAMP
            WHERE id = ? AND company = ? AND symbol = ?
        """, (new_shares, final_sector, uid, company, symbol))
    else:
        # ✅ New record → insert fresh
        c.execute("""
            INSERT INTO transactions (id, company, symbol, sector, shares)
            VALUES (?, ?, ?, ?, ?)
        """, (uid, company, symbol, sector, shares))

    conn.commit()
    conn.close()


def sell_transaction(uid: str, company: str, symbol: str, shares: int):
    conn = sqlite3.connect(DATABASE)
    c = conn.cursor()

    try:
        c.execute("""
            SELECT shares FROM transactions
            WHERE id = ? AND company = ? AND symbol = ?
        """, (uid, company, symbol))
        row = c.fetchone()

        if not row:
            raise ValueError("No existing record found for this stock.")

        owned_shares = row[0]

        if shares > owned_shares:
            raise ValueError(f"Cannot sell {shares} shares. Only {owned_shares} owned.")

        remaining = owned_shares - shares

        if remaining > 0:
            c.execute("""
                UPDATE transactions
                SET shares = ?, timestamp = CURRENT_TIMESTAMP
                WHERE id = ? AND company = ? AND symbol = ?
            """, (remaining, uid, company, symbol))
        else:
            c.execute("""
                DELETE FROM transactions
                WHERE id = ? AND company = ? AND symbol = ?
            """, (uid, company, symbol))

        conn.commit()
        return {"status": "success", "message": f"Sold {shares} shares successfully."}

    except Exception as e:
        conn.rollback()
        return {"status": "error", "message": str(e)}

    finally:
        conn.close()


def fetch_all_transactions():
    """
    Returns a list of all transactions in the database.
    Each transaction is a dictionary.
    """
    try:
        conn = sqlite3.connect(DATABASE)
        cursor = conn.cursor()
        cursor.execute("""
            SELECT id, company, symbol, sector, shares, timestamp
            FROM transactions
            ORDER BY timestamp DESC
        """)
        rows = cursor.fetchall()
        conn.close()

        transactions = []
        for row in rows:
            transactions.append({
                "uid": row[0],
                "company": row[1],
                "symbol": row[2],
                "sector": row[3],
                "shares": row[4],
                "timestamp": row[5]
            })
        return transactions
    except Exception as e:
        print(f"Error fetching transactions: {e}")
        return []

import sqlite3
db_path = r"C:\Users\Admin\Desktop\rangmahal (2)\MarketSutra\server_code\user_pan_data.db"
conn = sqlite3.connect(db_path)
cursor = conn.cursor()
cursor.execute("SELECT COUNT(*) FROM users;")
print("Number of rows:", cursor.fetchone()[0])
conn.close()

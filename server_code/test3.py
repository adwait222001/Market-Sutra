import sqlite3

# Path to your SQLite database file
DB_PATH = "transactions.db"  # Change to your actual DB path

def display_database():
    try:
        # Connect to the database
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()

        # Query all rows from the transactions table
        cursor.execute("SELECT * FROM transactions")
        rows = cursor.fetchall()

        # Print column headers
        column_names = [description[0] for description in cursor.description]
        print(" | ".join(column_names))
        print("-" * 60)

        # Print each row
        for row in rows:
            print(" | ".join(str(item) for item in row))

        conn.close()

    except sqlite3.Error as e:
        print(f"SQLite error: {e}")

if __name__ == "__main__":
    display_database()

"""
Swift Data Logistics - Automated Database Setup Script
Runs schema, sample data, and advanced SQL features in MySQL.
"""
import os
import re
import sys
import mysql.connector
from config import DB_CONFIG

def clean_sql(sql_text):
    # Remove single line comments
    sql_text = re.sub(r'--[^\n]*\n', '\n', sql_text)
    return sql_text

def execute_statements(cursor, sql_text, filename=""):
    print(f"--> Executing {filename}...")
    cleaned = clean_sql(sql_text)
    
    # Split by DELIMITER if present
    if "DELIMITER" in cleaned:
        chunks = re.split(r'DELIMITER\s+', cleaned)
        for chunk in chunks:
            chunk = chunk.strip()
            if not chunk:
                continue
            if chunk.startswith("$$"):
                # Inside $$ delimiter
                sub = chunk[2:]
                if "$$" in sub:
                    body, rest = sub.split("$$", 1)
                    body = body.strip()
                    if body:
                        cursor.execute(body)
            else:
                # Standard semicolon delimiter
                if chunk.startswith(";"):
                    chunk = chunk[1:]
                for stmt in chunk.split(";"):
                    stmt = stmt.strip()
                    if stmt and not stmt.upper().startswith("USE"):
                        try:
                            cursor.execute(stmt)
                        except mysql.connector.Error as err:
                            if "Unknown table" not in str(err) and "does not exist" not in str(err):
                                print(f"Notice: {err}")
    else:
        for stmt in cleaned.split(";"):
            stmt = stmt.strip()
            if stmt and not stmt.upper().startswith("USE"):
                try:
                    cursor.execute(stmt)
                except mysql.connector.Error as err:
                    if "Unknown table" not in str(err) and "does not exist" not in str(err):
                        print(f"Notice: {err}")

def main():
    print("=" * 60)
    print("       Swift Data Logistics - Database Setup Utility")
    print("=" * 60)
    
    password = DB_CONFIG.get("password") or os.environ.get("DB_PASSWORD", "")
    if not password and len(sys.argv) > 1:
        password = sys.argv[1]

    # Connect to MySQL server
    try:
        conn = mysql.connector.connect(
            host=DB_CONFIG["host"],
            port=DB_CONFIG["port"],
            user=DB_CONFIG["user"],
            password=password
        )
    except mysql.connector.Error as err:
        print(f"\n[Error] Unable to connect to MySQL: {err}")
        print("\nPlease check your password in .env or provide it directly:")
        print("  python setup_db.py <your_mysql_password>")
        sys.exit(1)

    conn.autocommit = True
    cursor = conn.cursor()

    # Create and select swift_data
    cursor.execute("CREATE DATABASE IF NOT EXISTS swift_data")
    cursor.execute("USE swift_data")
    conn.database = "swift_data"

    base_dir = os.path.dirname(os.path.abspath(__file__))
    sql_dir = os.path.join(base_dir, "sql")

    schema_file = os.path.join(sql_dir, "swift_data_schema.sql")
    sample_file = os.path.join(sql_dir, "swift_data_sample.sql")
    advanced_file = os.path.join(sql_dir, "swift_data_advanced.sql")

    with open(schema_file, "r", encoding="utf-8") as f:
        schema_sql = f.read()
    with open(sample_file, "r", encoding="utf-8") as f:
        sample_sql = f.read()
    with open(advanced_file, "r", encoding="utf-8") as f:
        advanced_sql = f.read()

    try:
        execute_statements(cursor, schema_sql, "1. Schema DDL")
        execute_statements(cursor, sample_sql, "2. Sample Data DML")
        execute_statements(cursor, advanced_sql, "3. Views, Triggers & Stored Procedure")

        cursor.execute("SHOW TABLES")
        tables = [t[0] for t in cursor.fetchall()]
        print("\n[Success] swift_data database initialized successfully!")
        print(f"Tables present: {', '.join(tables)}")

        cursor.execute("SELECT COUNT(*) FROM Shipment")
        s_count = cursor.fetchone()[0]
        cursor.execute("SELECT COUNT(*) FROM Tracking_Event")
        e_count = cursor.fetchone()[0]
        cursor.execute("SELECT COUNT(*) FROM Trip")
        t_count = cursor.fetchone()[0]
        print(f"Data verification: {s_count} Shipments, {t_count} Trips, {e_count} Tracking Events loaded.")
        print("=" * 60)

    except Exception as e:
        print(f"[Error] Failed to initialize database: {e}")
        sys.exit(1)
    finally:
        cursor.close()
        conn.close()

if __name__ == "__main__":
    main()

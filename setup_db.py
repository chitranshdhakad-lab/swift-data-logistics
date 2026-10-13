"""
Swift Data Logistics - Automated Database Setup Script
Runs schema, sample data, and advanced SQL features in MySQL.
"""
import os
import re
import sys
import mysql.connector
from config import DB_CONFIG

def load_sql_file(filepath):
    with open(filepath, "r", encoding="utf-8") as f:
        return f.read()

def run_script(cursor, full_sql, filename=""):
    print(f"--> Executing {filename}...")
    # Special handling for files with DELIMITER (triggers / stored procedures)
    if "DELIMITER" in full_sql:
        # Split by DELIMITER blocks
        parts = re.split(r'DELIMITER\s+(\$\$|;)', full_sql)
        current_delim = ";"
        i = 0
        while i < len(parts):
            chunk = parts[i].strip()
            if chunk in ("$$", ";"):
                current_delim = chunk
                i += 1
                continue
            if chunk:
                # If chunk was inside $$ delimiter
                if current_delim == "$$":
                    statements = [chunk]
                else:
                    statements = [s.strip() for s in chunk.split(";") if s.strip()]
                
                for stmt in statements:
                    # Clean out DELIMITER command if left
                    cleaned = re.sub(r'^DELIMITER\s+[^\n]+', '', stmt, flags=re.MULTILINE).strip()
                    if cleaned:
                        try:
                            cursor.execute(cleaned)
                        except mysql.connector.Error as err:
                            # Ignore drop errors on fresh setup
                            if "Unknown table" not in str(err) and "does not exist" not in str(err):
                                print(f"Warning in {filename}: {err}")
            i += 1
    else:
        # Standard statement execution
        for statement in full_sql.split(";"):
            cleaned = statement.strip()
            if cleaned and not cleaned.startswith("--"):
                try:
                    cursor.execute(cleaned)
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

    # Try connecting to MySQL server
    try:
        conn = mysql.connector.connect(
            host=DB_CONFIG["host"],
            port=DB_CONFIG["port"],
            user=DB_CONFIG["user"],
            password=password
        )
    except mysql.connector.Error as err:
        print(f"\n[Error] Unable to connect to MySQL: {err}")
        print("\nPlease ensure MySQL is running and provide the password:")
        print("  python setup_db.py <your_mysql_password>")
        print("Or set it in your environment / .env file:")
        print("  $env:DB_PASSWORD=\"your_password\"")
        sys.exit(1)

    conn.autocommit = True
    cursor = conn.cursor()

    base_dir = os.path.dirname(os.path.abspath(__file__))
    sql_dir = os.path.join(base_dir, "sql")

    schema_file = os.path.join(sql_dir, "swift_data_schema.sql")
    sample_file = os.path.join(sql_dir, "swift_data_sample.sql")
    advanced_file = os.path.join(sql_dir, "swift_data_advanced.sql")

    try:
        run_script(cursor, load_sql_file(schema_file), "1. Schema DDL")
        run_script(cursor, load_sql_file(sample_file), "2. Sample Data DML")
        run_script(cursor, load_sql_file(advanced_file), "3. Views, Triggers & Stored Procedure")

        cursor.execute("USE swift_data")
        cursor.execute("SHOW TABLES")
        tables = [t[0] for t in cursor.fetchall()]
        print("\n[Success] swift_data database initialized successfully!")
        print(f"Created {len(tables)} tables: {', '.join(tables)}")

        cursor.execute("SELECT COUNT(*) FROM Shipment")
        count = cursor.fetchone()[0]
        print(f"Sample shipments loaded: {count} shipments ready for tracking.\n")

    except Exception as e:
        print(f"[Error] Failed to initialize database: {e}")
        sys.exit(1)
    finally:
        cursor.close()
        conn.close()

if __name__ == "__main__":
    main()

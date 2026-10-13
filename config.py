import os

# Helper to automatically load key-value pairs from .env if present
def load_dotenv():
    env_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), ".env")
    if os.path.exists(env_path):
        with open(env_path, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#") and "=" in line:
                    k, v = line.split("=", 1)
                    k = k.strip()
                    v = v.strip().strip("'\"")
                    if k and k not in os.environ:
                        os.environ[k] = v

load_dotenv()

# Database configuration settings
DB_CONFIG = {
    "host": os.environ.get("DB_HOST", "127.0.0.1"),
    "port": int(os.environ.get("DB_PORT", "3306")),
    "user": os.environ.get("DB_USER", "root"),
    "password": os.environ.get("DB_PASSWORD", ""),
    "database": os.environ.get("DB_NAME", "swift_data"),
}

# Automatically enable SSL for remote cloud databases (like TiDB Cloud)
if DB_CONFIG["host"] not in ("127.0.0.1", "localhost") or os.environ.get("DB_SSL", "").lower() in ("true", "1"):
    DB_CONFIG["ssl_disabled"] = False

SECRET_KEY = os.environ.get("SECRET_KEY", "swift-data-dev-secret-key-2026")

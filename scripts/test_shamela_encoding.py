import sqlite3
c = sqlite3.connect(r'E:\shamela\database\book\022\22.db').cursor()
data = c.execute("SELECT cast(part as blob) FROM page LIMIT 1").fetchone()[0]
print("Raw bytes (first 50):", data[:50])
try:
    print("Decoded cp1256:", data.decode('cp1256')[:100])
except Exception as e:
    print("Error decoding cp1256:", e)

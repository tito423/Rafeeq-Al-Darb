import sqlite3
c = sqlite3.connect(r'E:\shamela\database\book\022\22.db').cursor()
# page table: id, part, page, number, services
page_row = c.execute("SELECT id, page FROM page LIMIT 2").fetchall()
for r in page_row:
    print(r)

# title table: id, page, parent
title_row = c.execute("SELECT id, title, page, parent FROM title LIMIT 2").fetchall()
for r in title_row:
    print(r)

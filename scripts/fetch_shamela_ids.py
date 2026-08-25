import urllib.request
import urllib.parse
from bs4 import BeautifulSoup
import ssl

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

def search_shamela(query):
    url = f"https://shamela.ws/search?q={urllib.parse.quote(query)}"
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
    try:
        response = urllib.request.urlopen(req, context=ctx)
        soup = BeautifulSoup(response.read().decode('utf-8'), 'html.parser')
        
        results = []
        for a in soup.find_all('a', href=True):
            href = a['href']
            if '/book/' in href:
                parts = href.split('/')
                try:
                    book_id = int(parts[-1])
                    title = a.get_text(strip=True)
                    if title:
                        results.append((book_id, title))
                except ValueError:
                    pass
        return results
    except Exception as e:
        return str(e)

if __name__ == '__main__':
    print("صيد الخاطر:", search_shamela("صيد الخاطر"))
    print("نوادر الأصول:", search_shamela("نوادر الأصول في أحاديث الرسول"))
    print("المحتضرين ابن أبي الدنيا:", search_shamela("المحتضرين"))

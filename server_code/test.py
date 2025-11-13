import requests
from bs4 import BeautifulSoup

# Economy section RSS feed
url = "https://www.moneycontrol.com/rss/business.xml"

# Step 1: Fetch the RSS XML content
headers = {'User-Agent': 'Mozilla/5.0'}
response = requests.get(url, headers=headers)
response.raise_for_status()

# Step 2: Parse the XML with BeautifulSoup
soup = BeautifulSoup(response.text, 'xml')

# Step 3: Extract article titles and links
for item in soup.find_all('item'):
    title = item.title.text
    link = item.link.text
    print(f"{title}\n{link}\n")
''''
import requests
from bs4 import BeautifulSoup

def get_reliance_news_links():
    url = "https://economictimes.indiatimes.com/reliance-industries-ltd/stocks/companyid-13215.cms"
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
                      'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0.0.0 Safari/537.36'
    }
    r = requests.get(url, headers=headers)
    soup = BeautifulSoup(r.text, "html.parser")

    all_links = [a.get("href") for a in soup.select("a") if a.get("href")]

    # Filter only Reliance articles
    reliance_links = []
    for link in all_links:
        if "/articleshow/" in link and "reliance" in link.lower():
            if link.startswith("/"):
                link = "https://economictimes.indiatimes.com" + link
            reliance_links.append(link)

    return reliance_links

links = get_reliance_news_links()
for l in links[:10]:  # latest 10 news links
    print(l)

'''

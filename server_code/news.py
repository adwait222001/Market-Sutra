from flask import Flask, jsonify
import requests
from bs4 import BeautifulSoup
import random

app = Flask(__name__)

USER_AGENTS = [
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 13_6) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.6 Safari/605.1.15",
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0 Safari/537.36",
    "Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Mobile/15E148 Safari/604.1"
]

def finance_news():
    url = "https://www.moneycontrol.com/rss/business.xml"
    headers = {
        "User-Agent": random.choice(USER_AGENTS),
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        "Accept-Language": "en-US,en;q=0.5",
        "Referer": "https://www.moneycontrol.com/",
        "Cache-Control": "no-cache",
        "Pragma": "no-cache",
        "Connection": "keep-alive"
    }
    session = requests.Session()
    session.cookies.clear()
    try:
        response = session.get(url, headers=headers, timeout=10)
        response.raise_for_status()
    except requests.exceptions.RequestException as e:
        return {
            "status": "error",
            "message": f"Failed to fetch data from source: {str(e)}",
            "count": 0,
            "data": []
        }
    try:
        soup = BeautifulSoup(response.text, "xml")
        items = soup.find_all("item")
        news_list = []
        for item in items:
            title = item.title.text if item.title else "No Title"
            link = item.link.text if item.link else "No Link"
            image_url = None
            media_content = item.find("media:content")
            if media_content and media_content.get("url"):
                image_url = media_content["url"]
            elif item.find("enclosure") and item.enclosure.get("url"):
                image_url = item.enclosure["url"]
            elif item.description:
                desc_soup = BeautifulSoup(item.description.text, "html.parser")
                img_tag = desc_soup.find("img")
                if img_tag and img_tag.get("src"):
                    image_url = img_tag["src"]
            try:
                article_res = session.get(link, headers=headers, timeout=8)
                article_soup = BeautifulSoup(article_res.text, "html.parser")
                og_image = article_soup.find("meta", property="og:image")
                if og_image and og_image.get("content"):
                    image_url = og_image["content"]
            except Exception:
                pass
            if not image_url:
                image_url = "No Image"
            news_list.append({
                "title": title,
                "link": link,
                "image": image_url
            })
        return {
            "status": "success",
            "count": len(news_list),
            "data": news_list
        }
    except Exception as e:
        return {
            "status": "error",
            "message": f"Error parsing RSS feed: {str(e)}",
            "count": 0,
            "data": []
        }

def get_news():
    news = finance_news()
    return jsonify(news)

def favicon():
    return '', 204

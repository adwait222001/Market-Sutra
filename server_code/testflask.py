from flask import Flask, jsonify
import requests
from bs4 import BeautifulSoup

app = Flask(__name__)

@app.route('/hello', methods=['GET'])
def finance_news():
    url = "https://www.moneycontrol.com/rss/business.xml"
    headers = {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
                'AppleWebKit/537.36 (KHTML, like Gecko) '
                'Chrome/124.0 Safari/537.36'}


    try:
        response = requests.get(url, headers=headers, timeout=10)
        response.raise_for_status()
    except requests.exceptions.RequestException as e:
        return jsonify({
            "status": "error",
            "message": f"Failed to fetch data from source: {str(e)}"
        }), 502

    try:
        soup = BeautifulSoup(response.text, 'xml')
        items = soup.find_all('item')

        if not items:
            return jsonify({
                "status": "error",
                "message": "No news items found in the RSS feed."
            }), 404

        news_list = []

        for item in items:
            title = item.title.text if item.title else "No Title"
            link = item.link.text if item.link else "No Link"

            # Initialize image as None
            image_url = None

            # Check for <media:content> tag (most common)
            media_content = item.find('media:content')
            if media_content and media_content.get('url'):
                image_url = media_content['url']

            # Check for <enclosure> tag
            elif item.find('enclosure') and item.enclosure.get('url'):
                image_url = item.enclosure['url']

            # If still None, try to extract <img> from description HTML
            elif item.description:
                desc_soup = BeautifulSoup(item.description.text, 'html.parser')
                img_tag = desc_soup.find('img')
                if img_tag and img_tag.get('src'):
                    image_url = img_tag['src']

            news_list.append({
                "title": title,
                "link": link,
                "image": image_url or "No Image"
            })

        return jsonify({
            "status": "success",
            "count": len(news_list),
            "data": news_list
        }), 200

    except Exception as e:
        return jsonify({
            "status": "error",
            "message": f"Error parsing RSS feed: {str(e)}"
        }), 500


if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)

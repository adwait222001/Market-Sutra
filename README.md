# MarketSutra

MarketSutra is a real-time stock market simulation platform built using **Flutter** (frontend) and **Flask** (backend). It provides live market data and an interactive virtual trading environment for users to practice stock trading.

---

## Features

### Real-Time Market Data
- Live stock prices from Google Finance  
- P/E ratio  
- Market capitalization  
- 25-week historical price graph  
- Nifty and Sensex tickers  

### Demo Trading System
- Virtual trading (buy/sell)  
- Real-time price updates  
- Portfolio tracking  

### User Verification
- PAN card OCR extraction  
- Extracts name, date of birth, and PAN number  
- Backend validation  

### Face Detection
- Implemented with CVZone  
- Identity and liveness detection  

### Live Market News
- Real-time news feed from MoneyControl  

---

## Tech Stack

### Frontend
- Flutter  
- State management (Provider/Bloc if applicable)  
- Charting libraries for financial graphs  

### Backend
- Flask  
- OCR libraries  
- CVZone (face detection)  
- Yfinance
- Scraping of googlefinance data
- backend calculations for the Price to equity ratio

---

Limitations

Market data depends on external sources such as Google Finance. While the data is generally accurate, it might lack certain real-time elements such as market depth, order book visibility, or microsecond-level tick updates.
Solution: Integrate official market data platforms like BOLT (BSE Online Trading Platform) or NEAT (National Exchange for Automated Trading Platform) for fully compliant and exchange-grade real-time data.

Buying and selling orders cannot be executed on the live market because the platform operates purely as a simulator with no direct broker connectivity.
Solution: Integrate official broker APIs such as Zerodha KiteConnect, Groww APIs, Angel One SmartAPI, or other SEBI-regulated broker interfaces to enable authenticated live order placements.

Demo trading does not replicate real-world trading factors such as liquidity, slippage, order priority, or actual exchange execution behavior.
## Setup Instructions
### Flutter
```bash
flutter pub get
flutter run
###

# Craveo: Food Ordering System & Delivery Time Estimation Engine
An AI-powered Django, MySQL, and Machine Learning web application that predicts food delivery durations in real-time.

---

## 1. Executive Summary
This application features a full-stack e-commerce system that browses partner restaurants, aggregates orders, manages driver dispatches, and utilizes an **XGBoost Regressor** trained on engineered delivery characteristics to output real-time estimates.

### Tech Stack
*   **Backend**: Python 3.12+, Django, Django REST Framework, PyMySQL
*   **Frontend**: Responsive HTML5, CSS3, Bootstrap 5, Chart.js
*   **Database**: MySQL / SQLite (fallback enabled)
*   **Machine Learning**: Pandas, NumPy, Scikit-Learn, XGBoost, Joblib

---

## 2. Project Architecture Diagrams

### System Flow Diagram
```
[Customer] ---> [Places Order] ---> [ML Prediction Engine] ---> [Displays ETA (Mins)]
                                           |
                                           v
[Driver Dashboard] <--- [Assigned] <--- [Delivery Table]
```

### Use Case Diagram
*   **Customer**: Browse menus, manage cart, place orders, track deliveries, submit feedback ratings.
*   **Restaurant Owner**: Manage outlet registrations, add/edit menu items, track incoming orders.
*   **Delivery Driver**: Inspect available delivery tasks, claim orders, update dispatch state (Picked Up, Delivered).
*   **Administrator**: Review KPIs, check predictive MAE accuracy, view traffic heatmaps, download Power BI datasets.

### Entity-Relationship Diagram (ERD)
*   `CustomUser` (1) --- (M) `Restaurant` (owns)
*   `CustomUser` (1) --- (M) `Order` (places)
*   `Restaurant` (1) --- (M) `MenuItem` (offers)
*   `Order` (1) --- (M) `OrderItem` (contains)
*   `Order` (1) --- (1) `Delivery` (has)
*   `Delivery` (1) --- (1) `Prediction` (defines)
*   `Order` (1) --- (1) `Feedback` (gets)

---

## 3. Project Directory Structure
```
FoodOrderingAI/
├── FoodOrderingAI/         # Project core settings and routes
│   ├── settings.py
│   ├── urls.py
│   └── views.py
├── users/                  # Custom accounts, profiles, registration
├── restaurants/            # CRUD management of outlets and food menus
├── orders/                 # Session cart, checkout, tracking
├── delivery/               # Logistics claiming, driver dispatches, ML predictions
│   └── estimator.py        # ML estimation caller module
├── analytics/              # Admin console metrics and Chart.js reporting
├── ml_model/               # Training pipelines and saved models
│   ├── train.py
│   ├── delivery_model.pkl
│   └── scaler.pkl
├── dataset/                # Data files
│   ├── raw_data.csv
│   └── processed_data.csv
├── db/                     # MySQL scripts
│   ├── schema.sql
│   └── seed_data.seed.py
├── templates/              # HTML layout templates
├── static/                 # Custom CSS / JS assets
└── requirements.txt
```

---

## 4. Machine Learning Outcomes
We trained three machine learning algorithms on 5,000 delivery instances:
1.  **Linear Regression**: $R^2 = 0.9141$, MAE = 4.47 mins
2.  **Random Forest**: $R^2 = 0.9571$, MAE = 3.01 mins
3.  **XGBoost Regressor**: $R^2 = 0.9593$, MAE = 2.79 mins (Auto-selected as best model)

The model features include: travel distance, preparation time, traffic densities, orders volumes, peak hour conditions, and active restaurant load.

---

## 5. Deployment Guide & Local Setup

### Prerequisite Check
Install Python 3.12+ and verify that pip is updated.

### 1. Clone & Configure Dependencies
```bash
pip install -r requirements.txt
```

### 2. Configure Database Connections
Configure the `.env` file credentials. By default, `USE_MYSQL=False` runs the system on an SQLite container out-of-the-box. To enable MySQL:
1. Create a MySQL database named `food_delivery_db`.
2. Run the SQL schemas in `db/schema.sql`.
3. Set `USE_MYSQL=True` in `.env` and fill in your DB credentials.

### 3. Generate & Preprocess Data
```bash
python ml_model/generate_dataset.py
```

### 4. Train Prediction Models
```bash
python ml_model/train.py
```

### 5. Run Migrations & Seed Data
```bash
python manage.py migrate
python db/seed_data.py
```

### 6. Start Server
```bash
python manage.py runserver
```
Visit the platform at `http://127.0.0.1:8000/`.

---

## 6. Default Seeder Accounts
*   **Customer**: `customer` / `password123`
*   **Restaurant Owner**: `owner` / `password123`
*   **Driver**: `driver` / `password123`
*   **Admin**: `admin` / `password123`

---

## 7. Presentation (PPT) Slide Layout
*   **Slide 1**: Title, Authors, Objective.
*   **Slide 2**: Problem Statement (High ETA variance, operational delays).
*   **Slide 3**: Proposed Architecture (Django + XGBoost + MySQL).
*   **Slide 4**: Machine Learning Engineering (Preprocessing, IQR, scaling, training).
*   **Slide 5**: Model Comparisons (Linear Regression vs RF vs XGBoost metrics).
*   **Slide 6**: Database Design (ER diagram, table constraints).
*   **Slide 7**: Core Application Features (Multi-role dashboards, cart checkout).
*   **Slide 8**: Power BI & Analytics (accuracy check, reporting export).
*   **Slide 9**: Key Takeaways & Conclusions.

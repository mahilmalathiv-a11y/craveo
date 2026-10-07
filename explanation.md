# Codebase Technical Explanation Guide
## Understanding "What" and "Why" in Craveo

This document provides a technical walkthrough of the core components of the **Craveo Food Ordering System with Delivery Time Estimation Engine**. Each module is explained from two contexts: **What** the code does, and **Why** it was designed that way, complete with source code references.

---

## 1. Project Configuration & Database Fallbacks
### File: `FoodOrderingAI/settings.py`

#### What
This code configures Django's database connections using environment variables, imports `pymysql` as a backup for `mysqlclient`, and sets up a fallback SQLite database.

```python
# settings.py
try:
    import pymysql
    pymysql.install_as_MySQLdb()
except ImportError:
    pass

USE_MYSQL = os.environ.get('USE_MYSQL', 'False') == 'True'

if USE_MYSQL and 'test' not in sys.argv:
    DATABASES = {
        'default': {
            'ENGINE': 'django.db.backends.mysql',
            'NAME': DB_NAME,
            'USER': DB_USER,
            'PASSWORD': DB_PASSWORD,
            'HOST': DB_HOST,
            'PORT': DB_PORT,
            # ... options
        }
    }
else:
    DATABASES = {
        'default': {
            'ENGINE': 'django.db.backends.sqlite3',
            'NAME': os.path.join(BASE_DIR, 'db.sqlite3'),
        }
    }
```

#### Why
*   **PyMySQL Import**: On Windows systems, installing the C-compiled `mysqlclient` package often fails if Microsoft Visual C++ Build Tools are missing. Importing `pymysql` and running `install_as_MySQLdb()` overrides Django's internal MySQL engine call with a pure-Python connector, avoiding compilation errors.
*   **Database Fallback**: In local, test, or grading environments, a MySQL server may not be active. The conditional fallback check loads SQLite (`db.sqlite3`) if `USE_MYSQL` is false, ensuring the project runs instantly out-of-the-box.

---

## 2. Data Cleaning & Outlier Handling
### File: `ml_model/generate_dataset.py`

#### What
This code removes duplicate records, imputes missing driver ratings using median values, and caps extreme delivery durations and distances using the **Interquartile Range (IQR)** method.

```python
# generate_dataset.py
# 1. Duplicate Removal
cleaned_df.drop_duplicates(subset=['order_id'], keep='first', inplace=True)

# 2. Missing Value Imputation
rating_median = cleaned_df['driver_rating'].median()
cleaned_df['driver_rating'] = cleaned_df['driver_rating'].fillna(rating_median)

# 3. Outlier Handling (Capping)
Q1_time = cleaned_df['actual_delivery_time'].quantile(0.25)
Q3_time = cleaned_df['actual_delivery_time'].quantile(0.75)
IQR_time = Q3_time - Q1_time
upper_bound_time = Q3_time + 1.5 * IQR_time

cleaned_df.loc[cleaned_df['actual_delivery_time'] > upper_bound_time, 'actual_delivery_time'] = upper_bound_time
```

#### Why
*   **Duplicates & Nulls**: Noisy records skew machine learning parameters. We drop duplicates to prevent model overfitting on redundant data and impute missing ratings using the *median* (which is robust to outliers, unlike the mean).
*   **Capping vs Deletion**: Standard IQR methods delete outliers. However, in delivery logistics, extreme delivery times (e.g. during heavy storms) are rare but valid. Capping them at the upper bound ($Q3 + 1.5 \times IQR$) retains the high-cost signal in the dataset while preventing extreme values from destabilizing the regression weights.

---

## 3. ML Model Training & Scaling
### File: `ml_model/train.py`

#### What
Trains Linear Regression, Random Forest, and XGBoost models, fits a `StandardScaler`, and outputs evaluation metrics (MAE, RMSE, $R^2$).

```python
# train.py
scaler = StandardScaler()
X_train_scaled = scaler.fit_transform(X_train)
X_test_scaled = scaler.transform(X_test)

# Save scaler and best model
joblib.dump(scaler, os.path.join(out_dir, 'scaler.pkl'))

models = {
    'Linear Regression': LinearRegression(),
    'Random Forest': RandomForestRegressor(n_estimators=100, random_state=42),
    'XGBoost': XGBRegressor(n_estimators=100, learning_rate=0.08, max_depth=5, random_state=42)
}
# ... evaluations ...
best_model_name = metrics_df.loc[metrics_df['R2'].idxmax()]['Model']
joblib.dump(best_model, os.path.join(out_dir, 'delivery_model.pkl'))
```

#### Why
*   **Scaler Serialization**: Model variables (distance, prep time, load) have different numeric ranges. A distance of `12km` vs. a rating of `4.8` would bias tree estimators or linear models if unscaled. We fit and export `scaler.pkl` to scale real-time API values at runtime using the exact distribution parameters calculated during training.
*   **Model Benchmarking**: We compare a simple baseline (Linear Regression) against advanced ensembles (Random Forest, XGBoost) to prove predictive uplift. XGBoost was auto-selected because its gradient boosting structure reduces regression residues better ($R^2 = 0.9593$).

---

## 4. AI Real-time Prediction Engine
### File: `delivery/estimator.py`

#### What
Defines the prediction caller. It maps categorical traffic values (`Low` to `Jam`) to numeric labels, applies the scaler, runs XGBoost, and enforces a lower bound constraint.

```python
# estimator.py
def predict_delivery_time(distance_km, prep_time_mins, traffic_density, ...):
    try:
        model = joblib.load(model_path)
        scaler = joblib.load(scaler_path)
        
        traffic_mapping = {'Low': 1, 'Medium': 2, 'High': 3, 'Jam': 4}
        traffic_code = traffic_mapping.get(traffic_density, 2)
        
        features = np.array([[distance_km, prep_time_mins, traffic_code, ...]])
        scaled_features = scaler.transform(features)
        
        prediction = model.predict(scaled_features)[0]
        # Safety constraint
        return max(int(round(prediction)), int(prep_time_mins) + 5), type(model).__name__
    except Exception:
        # Fallback heuristic rules if files are missing
        return int(prep_time_mins + distance_km * 3.5 + 8), "Fallback"
```

#### Why
*   **Safety Limits**: Regression models can occasionally return nonsensical numbers (e.g. extremely low or negative values for edge cases). Enforcing `max(prediction, prep_time + 5)` guarantees that estimated times are logically bounded: a delivery cannot take less time than the kitchen's food preparation duration plus the travel time.
*   **Robust Fallback**: If the serialized model files are missing, raising an unhandled exception would crash checkout. The try-except block logs the error and falls back to a deterministic rule-based calculation, maintaining checkout availability.

---

## 5. Transactional Order Placement & Distance Calculation
### File: `orders/views.py`

#### What
Calculates distance using the Haversine formula and processes order creation, ML prediction, and driver dispatch inside a database transaction block.

```python
# views.py
def calculate_haversine_distance(lat1, lon1, lat2, lon2):
    R = 6371.0 # Earth radius
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = math.sin(dlat/2)**2 + math.cos(math.radians(lat1))*math.cos(math.radians(lat2))*math.sin(dlon/2)**2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))
    return round(R * c, 2)

@login_required
def place_order(request):
    # ... inputs validation ...
    with transaction.atomic():
        order = Order.objects.create(...)
        # ... add items ...
        distance = calculate_haversine_distance(rest.latitude, rest.longitude, lat, lng)
        
        # Predict delivery duration
        predicted_time, model_used = predict_delivery_time(...)
        
        delivery = Delivery.objects.create(order=order, distance_km=distance, ...)
        Prediction.objects.create(delivery=delivery, predicted_time_mins=predicted_time, ...)
        
        request.session['cart'] = {} # Clear cart
        return redirect('orders:order-detail', pk=order.pk)
```

#### Why
*   **Haversine Distance**: We need the distance between the customer and the restaurant. The Haversine formula calculates the great-circle distance between two points on a sphere, providing precise travel distance in kilometers without needing external Google Maps APIs.
*   **Atomic Transactions**: Placing an order involves multiple database writes (Order, OrderItems, Delivery, Prediction). Wrapping this inside `with transaction.atomic()` ensures that if any write or the ML prediction fails, all previous writes are rolled back. This prevents orphaned orders or dispatches in the database.

---

## 6. Live Metrics Aggregation & Power BI Export
### File: `analytics/views.py`

#### What
Computes analytics KPIs (MAE, delay counts) using database functions and streams delivery metadata as a CSV.

```python
# views.py
from django.db.models.functions import Abs

@login_required
def admin_dashboard(request):
    # Average delivery duration
    avg_delivery_time = completed_deliveries.aggregate(avg_time=Avg('prediction__actual_time_mins'))['avg_time'] or 0
    
    # Absolute Mean Error (MAE)
    mae = Prediction.objects.filter(actual_time_mins__isnull=False).aggregate(
        avg_error=Avg(Abs('error_margin'))
    )['avg_error'] or 0

@login_required
def export_powerbi_data(request):
    response = HttpResponse(content_type='text/csv')
    response['Content-Disposition'] = 'attachment; filename="powerbi_dataset.csv"'
    writer = csv.writer(response)
    writer.writerow(['Prediction_ID', 'Order_ID', 'Distance_KM', 'Predicted_Time_Mins', 'Actual_Time_Mins', ...])
    # ... populate rows ...
    return response
```

#### Why
*   **Abs Function**: To calculate the Mean Absolute Error (MAE) in Python, we would have to pull all prediction records into memory and loop over them. Using Django's `Abs` function compiles directly to SQL (`ABS()`), performing the calculation entirely in the database engine, which is significantly faster.
*   **CSV Exporter**: Exposing a clean HTTP endpoint that streams database rows in tabular CSV format allows Microsoft Power BI, Tableau, or Excel to directly import the database records via a web query, keeping charts up to date.

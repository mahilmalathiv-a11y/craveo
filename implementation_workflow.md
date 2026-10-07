# Craveo Project: Implementation Workflow

This document details the step-by-step engineering workflow followed to design, build, and deploy **Craveo (Smart Food Ordering & Delivery Time Predictor)** at **Pydun Technology Private Limited**.

---

## Step 1: Environment Configuration
*   **What**: Declared project dependencies in `requirements.txt` (including `django`, `xgboost`, `scikit-learn`, `pymysql`, `pandas`) and set up environmental variables in `.env`.
*   **Why**: Pinning package versions ensures execution reproducibility across different platforms. Using a `USE_MYSQL` config flag allows the project to seamlessly fall back to SQLite when local MySQL servers are offline.

## Step 2: Django Modular Architecture
*   **What**: Generated the project skeleton and decoupled system operations into five dedicated Django apps:
    *   `users`: Custom authentication profiles for Customers, Owners, Drivers, and Admins.
    *   `restaurants`: CRUD interfaces for food outlets and menu configurations.
    *   `orders`: Session-based shopping carts and transactional checkouts.
    *   `delivery`: Order dispatch logs and the ML inference gateway.
    *   `analytics`: Operations control panel displaying metrics via Chart.js.
*   **Why**: Splitting modules limits code coupling, making the codebase easier to debug, extend, and scale.

## Step 3: Data Science & Anomaly Preprocessing
*   **What**: Built a data generator script (`generate_dataset.py`) to simulate 5,000 delivery instances and executed preprocessing:
    *   Removed duplicated records.
    *   Imputed null driver ratings using the column **median** and null traffic levels using the **mode**.
    *   Capped extreme delivery duration outliers using the **Interquartile Range (IQR)** upper fence.
*   **Why**: Outliers and duplicate data skew regression weights. Median imputation protects data distributions, while capping keeps high-cost congestion signals without destabilizing the gradient steps.

## Step 4: Machine Learning Model Development
*   **What**: Standardized feature magnitudes using a `StandardScaler`, trained Linear Regression, Random Forest, and XGBoost regressor models, and evaluated metrics:
    *   **Linear Regression**: $R^2 = 0.9141$, MAE = 4.47 minutes.
    *   **Random Forest**: $R^2 = 0.9571$, MAE = 3.01 minutes.
    *   **XGBoost Regressor**: $R^2 = 0.9593$, MAE = 2.79 minutes.
*   **Why**: Standardizing scales variables to a uniform range, preventing distance from dominating ratings. XGBoost was selected and serialized as `delivery_model.pkl` alongside `scaler.pkl` due to its superior variance explanation ($R^2 = 95.93\%$).

## Step 5: Relational Schema & Database Seeding
*   **What**: Generated and executed Django ORM migrations and wrote a database seeding script (`seed_data.py`) to populate initial users, outlets, menus, and 50 historical order predictions.
*   **Why**: Provides a ready-to-run environment with realistic customer, driver, and owner accounts, pre-populating Chart.js analytics graphs for staging evaluations.

## Step 6: Checkout Inference Gateway
*   **What**: Programmed the **Haversine formula** to calculate physical distance using coordinate offsets. Connected order checkouts to the prediction model inside a `transaction.atomic` database block, enforcing a lower-bound constraint:
    $$\text{ETA} = \max(\text{XGBoost Prediction}, \text{Prep Time} + 5\text{ minutes})$$
*   **Why**: Atomic transactions prevent incomplete orders (e.g. creating an order but failing driver dispatch). Enforcing safety boundaries prevents the ML model from outputting physically impossible values.

## Step 7: Operations Console & BI Export
*   **What**: Integrated dynamic Chart.js dashboards in the Admin panel to plot prediction deviations (MAE) and exposed a CSV data streaming URL (`/analytics/export/powerbi/`).
*   **Why**: SQL aggregations calculate MAE inside the database for speed, while the CSV endpoint allows Microsoft Power BI or Tableau to query and refresh metrics in real-time.

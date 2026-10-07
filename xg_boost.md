# XGBoost (Extreme Gradient Boosting) Method Explanation
## Why XGBoost is the Core Engine of Craveo

This document explains what **XGBoost** is and why it was selected as the optimal machine learning model for estimating food delivery times in the **Craveo** application.

---

## 1. What is XGBoost?
**XGBoost** stands for **Extreme Gradient Boosting**. It is an open-source, highly optimized implementation of the gradient boosted decision trees algorithm.

### Key ML Concepts:
*   **Ensemble Learning**: Instead of training a single deep decision tree (which is prone to overfitting), XGBoost trains hundreds of simple "weak learners" (shallow trees) and combines their predictions.
*   **Sequential Boosting**: Trees are built sequentially (one after another). Each new tree focuses on predicting the errors (residuals) made by the ensemble of previous trees.
*   **Gradient Descent**: It uses a gradient descent algorithm to minimize the loss function (the difference between actual and predicted delivery times) when adding new trees.

$$\text{Final Prediction} = \text{Tree}_1(X) + \text{Tree}_2(X_{\text{errors}}) + \text{Tree}_3(X_{\text{errors}}) + \dots$$

---

## 2. Why XGBoost is Used in Craveo
During Phase 3 training (see `ml_model/train.py`), we compared three different model architectures:
1.  **Linear Regression** ($R^2 = 0.9141$, MAE = 4.47 mins)
2.  **Random Forest Regressor** ($R^2 = 0.9571$, MAE = 3.01 mins)
3.  **XGBoost Regressor** ($R^2 = 0.9593$, MAE = 2.79 mins)

XGBoost was auto-selected as the best model. Below are the key engineering and business reasons why it is the optimal fit for our logistics system:

### A. Mapping Non-Linear Logistics Interactions
*   **The Challenge**: Delivery times are non-linear. For example, a $5\text{km}$ trip in `Low` traffic might take 10 minutes, but in `Jam` traffic it might take 45 minutes. A linear model assumes that doubling the distance always doubles the travel time, failing to capture these interaction peaks.
*   **XGBoost Solution**: By splitting feature ranges sequentially, XGBoost handles non-linear variables and multi-variable interactions naturally (e.g. *if distance > 5km AND traffic == Jam AND hour == 18:00, then apply an exponential time penalty*).

### B. Regularization (Guarding Against Noisy Data)
*   **The Challenge**: Real-world logistics data is noisy. Driver ratings fluctuate, cooking speeds vary slightly, and GPS coordinates can have errors. Models without constraints overfit this noise and fail when predicting real-time checkouts.
*   **XGBoost Solution**: XGBoost has built-in L1 (Lasso) and L2 (Ridge) regularization. This mathematically penalizes model complexity, preventing the decision trees from fitting to random noise and guaranteeing stable real-time estimates.

### C. Split-Second Inference Speeds
*   **The Challenge**: When a customer checkout is occurring, the ETA prediction must return almost instantly. A model that takes seconds to compute will degrade user experience.
*   **XGBoost Solution**: XGBoost is designed for speed. Because it stores its ensemble structure as a lightweight sequence of simple tabular thresholds, running inference on a new coordinate vector takes less than **10 milliseconds** on standard CPUs.

### D. Multi-Modal Feature Handling
*   **The Challenge**: Our feature vector contains mixed data: continuous variables (coordinates, distance in km), discrete values (order volume count), and categorical strings (traffic densities: Low, Medium, High, Jam).
*   **XGBoost Solution**: Tree-based algorithms do not require normal distributions or linear scaling to make split decisions, enabling high accuracy over diverse, multi-modal logistics features.

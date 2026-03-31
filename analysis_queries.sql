-- ============================================================
-- Multicity Unit Economics & Margin Optimization
-- SQL Analysis Queries
-- Author: Parichennayapalli Viswa Sai Reddy
-- ============================================================

-- ----------------------------------------------------------------
-- 1. City-Level Revenue & Contribution Margin Overview
-- ----------------------------------------------------------------
SELECT
    city,
    COUNT(*)                                    AS total_transactions,
    ROUND(AVG(gross_order_value), 2)           AS avg_order_value,
    ROUND(SUM(net_revenue), 2)                 AS total_revenue,
    ROUND(SUM(cogs), 2)                        AS total_cogs,
    ROUND(SUM(gross_profit), 2)                AS total_gross_profit,
    ROUND(SUM(total_variable_cost), 2)         AS total_variable_cost,
    ROUND(SUM(contribution_margin), 2)         AS total_contribution_margin,
    ROUND(AVG(contribution_margin), 2)         AS avg_contribution_margin,
    ROUND(
        SUM(contribution_margin) / SUM(net_revenue) * 100, 2
    )                                           AS contribution_margin_pct
FROM transactions
GROUP BY city
ORDER BY contribution_margin_pct ASC;

-- ----------------------------------------------------------------
-- 2. Discount Leakage Analysis by City
-- ----------------------------------------------------------------
WITH city_discount AS (
    SELECT
        city,
        COUNT(*)                                AS total_orders,
        ROUND(AVG(discount_pct), 2)            AS avg_discount_pct,
        ROUND(SUM(discount_amount), 2)         AS total_discount_given,
        ROUND(SUM(net_revenue), 2)             AS total_net_revenue,
        COUNT(CASE WHEN discount_pct > 20 THEN 1 END) AS high_discount_orders
    FROM transactions
    GROUP BY city
),
benchmark AS (
    SELECT ROUND(AVG(discount_pct), 2) AS overall_avg_discount
    FROM transactions
)
SELECT
    cd.*,
    b.overall_avg_discount,
    ROUND(cd.avg_discount_pct - b.overall_avg_discount, 2) AS discount_variance_vs_avg,
    ROUND(
        (cd.avg_discount_pct - b.overall_avg_discount) / 100.0 * cd.total_net_revenue, 2
    )                                                        AS estimated_leakage_rs
FROM city_discount cd
CROSS JOIN benchmark b
ORDER BY estimated_leakage_rs DESC;

-- ----------------------------------------------------------------
-- 3. CAC vs Contribution Margin — Breakeven Check
-- ----------------------------------------------------------------
SELECT
    city,
    ROUND(AVG(customer_acquisition_cost), 2)   AS avg_cac,
    ROUND(AVG(contribution_margin), 2)          AS avg_contribution_margin,
    ROUND(AVG(contribution_margin) - AVG(customer_acquisition_cost), 2) AS margin_after_cac,
    CASE
        WHEN AVG(contribution_margin) - AVG(customer_acquisition_cost) < 0
        THEN 'BELOW BREAKEVEN'
        ELSE 'ABOVE BREAKEVEN'
    END                                          AS breakeven_status,
    COUNT(CASE WHEN (contribution_margin - customer_acquisition_cost) < 0
               THEN 1 END)                       AS loss_making_transactions,
    ROUND(
        COUNT(CASE WHEN (contribution_margin - customer_acquisition_cost) < 0
                   THEN 1 END) * 100.0 / COUNT(*), 2
    )                                            AS loss_pct
FROM transactions
GROUP BY city
ORDER BY margin_after_cac ASC;

-- ----------------------------------------------------------------
-- 4. Monthly Trend — Contribution Margin Over Time (CTE + Window)
-- ----------------------------------------------------------------
WITH monthly_city AS (
    SELECT
        city,
        SUBSTR(date, 1, 7)                     AS month,
        SUM(net_revenue)                        AS revenue,
        SUM(contribution_margin)                AS contribution_margin
    FROM transactions
    GROUP BY city, SUBSTR(date, 1, 7)
),
ranked AS (
    SELECT
        *,
        ROUND(
            AVG(contribution_margin) OVER (
                PARTITION BY city
                ORDER BY month
                ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
            ), 2
        ) AS rolling_3m_avg_cm,
        ROUND(
            contribution_margin - LAG(contribution_margin, 1)
            OVER (PARTITION BY city ORDER BY month), 2
        ) AS mom_change
    FROM monthly_city
)
SELECT * FROM ranked ORDER BY city, month;

-- ----------------------------------------------------------------
-- 5. Category-Level Margin Analysis (Identify High-Margin Categories)
-- ----------------------------------------------------------------
SELECT
    city,
    category,
    COUNT(*)                                        AS orders,
    ROUND(AVG(gross_order_value), 2)               AS avg_aov,
    ROUND(AVG(discount_pct), 2)                    AS avg_discount_pct,
    ROUND(AVG(contribution_margin), 2)             AS avg_cm,
    ROUND(
        AVG(contribution_margin) / NULLIF(AVG(net_revenue), 0) * 100, 2
    )                                               AS cm_margin_pct,
    RANK() OVER (
        PARTITION BY city ORDER BY AVG(contribution_margin) DESC
    )                                               AS margin_rank_in_city
FROM transactions
GROUP BY city, category
ORDER BY city, margin_rank_in_city;

-- ----------------------------------------------------------------
-- 6. Revenue Optimization Opportunity — Estimate of Rs.22L
-- ----------------------------------------------------------------
WITH current_state AS (
    SELECT
        city,
        SUM(net_revenue)                            AS actual_revenue,
        SUM(discount_amount)                        AS total_discounts,
        AVG(discount_pct)                           AS avg_discount_pct
    FROM transactions
    GROUP BY city
),
optimized AS (
    SELECT
        city,
        actual_revenue,
        total_discounts,
        avg_discount_pct,
        -- If we bring discount rate down to 12% (optimal benchmark)
        ROUND(total_discounts * GREATEST(0, (avg_discount_pct - 12) / avg_discount_pct), 2) AS recoverable_discount
    FROM current_state
)
SELECT
    city,
    ROUND(actual_revenue / 100000, 2)              AS revenue_lakhs,
    ROUND(total_discounts / 100000, 2)             AS discounts_lakhs,
    ROUND(avg_discount_pct, 2)                     AS current_discount_pct,
    ROUND(recoverable_discount / 100000, 2)        AS recoverable_revenue_lakhs
FROM optimized
ORDER BY recoverable_discount DESC;

-- ----------------------------------------------------------------
-- 7. Channel Efficiency — CAC vs Revenue by Acquisition Channel
-- ----------------------------------------------------------------
SELECT
    acquisition_channel,
    COUNT(*)                                        AS orders,
    ROUND(AVG(customer_acquisition_cost), 2)       AS avg_cac,
    ROUND(AVG(net_revenue), 2)                     AS avg_revenue_per_order,
    ROUND(AVG(contribution_margin), 2)             AS avg_cm,
    ROUND(
        AVG(contribution_margin) / NULLIF(AVG(customer_acquisition_cost), 0), 2
    )                                               AS cm_to_cac_ratio,
    RANK() OVER (ORDER BY AVG(contribution_margin) / NULLIF(AVG(customer_acquisition_cost), 0) DESC)
                                                    AS efficiency_rank
FROM transactions
GROUP BY acquisition_channel
ORDER BY efficiency_rank;

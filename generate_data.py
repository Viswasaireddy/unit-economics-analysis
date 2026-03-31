import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import random

np.random.seed(42)
random.seed(42)

cities = ['Mumbai', 'Delhi', 'Bangalore', 'Hyderabad', 'Chennai']

# City-level characteristics (reflecting different market maturity)
city_config = {
    'Mumbai':    {'base_aov': 1850, 'base_cac': 420, 'discount_rate': 0.18, 'volume': 26000},
    'Delhi':     {'base_aov': 1720, 'base_cac': 390, 'discount_rate': 0.21, 'volume': 24000},
    'Bangalore': {'base_aov': 1950, 'base_cac': 380, 'discount_rate': 0.14, 'volume': 22000},
    'Hyderabad': {'base_aov': 1580, 'base_cac': 450, 'discount_rate': 0.25, 'volume': 16000},
    'Chennai':   {'base_aov': 1620, 'base_cac': 410, 'discount_rate': 0.22, 'volume': 14000},
}

categories = ['Electronics', 'Fashion', 'Home & Kitchen', 'Beauty', 'Sports', 'Books', 'Grocery']
acquisition_channels = ['Organic', 'Paid Search', 'Social Media', 'Referral', 'Email', 'Affiliate']
customer_segments = ['New', 'Returning', 'Loyal', 'At-Risk']

start_date = datetime(2023, 4, 1)
end_date = datetime(2024, 3, 31)

records = []
transaction_id = 1000

for city, config in city_config.items():
    n = config['volume']
    for i in range(n):
        date = start_date + timedelta(days=random.randint(0, 364))
        category = random.choices(categories, weights=[20, 18, 15, 12, 10, 8, 17])[0]
        segment = random.choices(customer_segments, weights=[30, 35, 20, 15])[0]
        channel = random.choices(acquisition_channels, weights=[25, 22, 20, 15, 10, 8])[0]

        aov = max(200, np.random.normal(config['base_aov'], config['base_aov'] * 0.3))

        # Discount leakage — Hyderabad and Chennai over-discounting
        discount_pct = max(0, min(0.6, np.random.normal(config['discount_rate'], 0.07)))
        discount_amount = aov * discount_pct
        revenue = aov - discount_amount

        # Variable costs
        delivery_cost = np.random.uniform(45, 120)
        packaging_cost = np.random.uniform(15, 40)
        payment_gw_cost = revenue * np.random.uniform(0.015, 0.025)
        returns_cost = revenue * np.random.uniform(0.03, 0.10) if random.random() < 0.15 else 0
        variable_cost = delivery_cost + packaging_cost + payment_gw_cost + returns_cost

        # CAC allocated per transaction
        cac = max(150, np.random.normal(config['base_cac'], 80))

        # COGS
        cogs = revenue * np.random.uniform(0.52, 0.68)

        gross_profit = revenue - cogs
        contribution_margin = gross_profit - variable_cost
        net_margin = contribution_margin - cac

        records.append({
            'transaction_id': f'TXN{transaction_id:06d}',
            'date': date.strftime('%Y-%m-%d'),
            'city': city,
            'category': category,
            'customer_segment': segment,
            'acquisition_channel': channel,
            'gross_order_value': round(aov, 2),
            'discount_amount': round(discount_amount, 2),
            'discount_pct': round(discount_pct * 100, 2),
            'net_revenue': round(revenue, 2),
            'cogs': round(cogs, 2),
            'gross_profit': round(gross_profit, 2),
            'delivery_cost': round(delivery_cost, 2),
            'packaging_cost': round(packaging_cost, 2),
            'payment_gateway_cost': round(payment_gw_cost, 2),
            'returns_cost': round(returns_cost, 2),
            'total_variable_cost': round(variable_cost, 2),
            'customer_acquisition_cost': round(cac, 2),
            'contribution_margin': round(contribution_margin, 2),
            'net_margin': round(net_margin, 2),
        })
        transaction_id += 1

df = pd.DataFrame(records)
df = df.sort_values('date').reset_index(drop=True)
df.to_csv('/home/claude/multicity-unit-economics/data/transactions.csv', index=False)
print(f"Generated {len(df)} transactions")
print(df.head(3))
print("\nCity distribution:")
print(df['city'].value_counts())
print(f"\nTotal transactions: {len(df):,}")

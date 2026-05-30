-- Run order: Analytic view: shipment volume and performance by period
CREATE OR REPLACE VIEW localuc.gold.v_shipment_analysis AS
SELECT
    YEAR(s.ship_date) AS ship_year,
    MONTH(s.ship_date) AS ship_month,
    s.carrier_name,
    COUNT(DISTINCT s.sk_shipment_id) AS total_shipments,
    ROUND(AVG(s.delivery_days), 1) AS avg_delivery_days,
    COUNT(DISTINCT CASE WHEN s.exception_flag THEN s.sk_shipment_id END) AS exception_count,
    ROUND(SUM(s.shipping_cost), 2) AS total_shipping_cost
FROM localuc.gold.fact_shipment s
WHERE s.ship_date >= date_sub(current_date(), 365)
GROUP BY YEAR(s.ship_date), MONTH(s.ship_date), s.carrier_name;

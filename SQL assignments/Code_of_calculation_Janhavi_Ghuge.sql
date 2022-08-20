create database cointab;
use cointab;

-- Steps to be followed:
-- 1. Calculate weight of each order from weight of SKUs.
-- 2. Assign weight slab to all calculated weights.
-- 3. Find delivery zones with respect to warehouse and customer pincode.
-- 4. Calculate the number of additional weights (in multiple of 0.5kg) over the first 0.5kg weight, if any.
-- 5. Find charges as per delivery zones
-- 6. Calculate delivery charges based on weight slab and zonal charges of each order. 
-- 7. Create final calculation table
-- 8. Create Summary table
-- 9. Exporting both the above tables to excel


-- Step 1: Calculating weight of each order
CREATE TEMPORARY TABLE weight
SELECT  DISTINCT companyx_orders.SKU,
		ExternOrderNo,
        `Order Qty`,
        `Weight (g)`, 
        `Order Qty`*`Weight (g)` as wt
FROM companyx_orders
JOIN companyx_sku
ON
	companyx_orders.sku = companyx_sku.sku;

CREATE TEMPORARY TABLE total_weights
SELECT  ExternOrderNo as order_id,
		SUM(wt) OVER (PARTITION BY ExternOrderNo) AS total_wt
FROM weight;

CREATE TEMPORARY TABLE total_weight_kg
SELECT DISTINCT order_id, total_wt/1000 AS Total_wt_kg
FROM total_weights;
-- Thus, we have total weight of all orders


-- Step 2: Assigning weight slabs to each order 
CREATE TEMPORARY TABLE total_wt_slab
SELECT order_id, total_wt_kg,
	CASE WHEN total_wt_kg <= 0.5 THEN 0.5
		 WHEN total_wt_kg <= 1.0 THEN 1.0
         WHEN total_wt_kg <= 1.5 THEN 1.5
         WHEN total_wt_kg <= 2.0 THEN 2.0
         WHEN total_wt_kg <= 2.5 THEN 2.5
         WHEN total_wt_kg <= 3.0 THEN 3.0
         WHEN total_wt_kg <= 3.5 THEN 3.5
         END AS wt_slab
FROM total_weight_kg;
-- Thus, we have assigned weight slabs to all orders
 
 
 -- Step 3: Finding delivery zones with respect to Address of Customers 
CREATE TEMPORARY TABLE order_zone_x
SELECT  courier_invoice.`Order ID`,
		courier_invoice.`Warehouse Pincode`,
        courier_invoice.`Customer Pincode`,
		companyx_zones.Zone AS zone_X
FROM courier_invoice
JOIN companyx_zones
ON
	courier_invoice.`Warehouse Pincode` = companyx_zones.`Warehouse Pincode`
    AND courier_invoice.`Customer Pincode` = companyx_zones.`Customer Pincode`;
 -- Zones found here are delivery zones according to company X 
 
 
-- Step 4: Calculating the number of additional weights
CREATE TEMPORARY TABLE order_wt_slabs
SELECT  order_id, 
		total_wt_kg, 
        wt_slab,
		order_zone_x.zone_X AS Zone_X,
		Zone AS Zone_courier,
        `Type of Shipment`,
        CASE WHEN `Type of Shipment` = 'Forward and RTO charges' THEN 'Yes' ELSE 'No' END AS is_rto,
        ROUND(CASE WHEN wt_slab > 0.5 THEN (wt_slab - 0.5)/0.5 ELSE 0 END,0) AS num_additional_wt
FROM total_wt_slab
JOIN courier_invoice
ON
	total_wt_slab.order_id = courier_invoice.`Order ID`
JOIN order_zone_x
ON
	courier_invoice.`Order ID` = order_zone_x.`Order ID`
;
-- Number of additional weights for orders weights more than 0.5kg found


-- Step 5: Finding charges as per delivery zone
CREATE TEMPORARY TABLE charges
SELECT distinct zone,
		CASE WHEN zone = "b" THEN fwd_b_fixed 
			 WHEN zone = "d" THEN fwd_d_fixed
             WHEN zone = "e" THEN fwd_e_fixed
		END AS fwd_fixed,
		CASE WHEN zone = "b" THEN fwd_b_additional
			 WHEN zone = "d" THEN fwd_d_additional
             WHEN zone = "e" THEN fwd_e_additional
		END AS fwd_additional,
        CASE WHEN zone = "b" THEN rto_b_fixed
			 WHEN zone = "d" THEN rto_d_fixed
             WHEN zone = "e" THEN rto_e_fixed
		END AS rto_fixed,
		CASE WHEN zone = "b" THEN rto_b_additional
			 WHEN zone = "d" THEN rto_d_additional
             WHEN zone = "e" THEN rto_e_additional
		END AS rto_additional
FROM courier_invoice
JOIN couriercompany_rates
ORDER BY zone;
-- Charges for only zones b,d and e were found since orders were placed from those zones.


-- Step 6: Calculating delivery charges based on weight slab and zonal charges
CREATE TEMPORARY TABLE order_charges_wrt_zones
SELECT  order_id, 
		total_wt_kg, 
        wt_slab,
		order_wt_slabs.Zone_X AS Zone_X,
		order_wt_slabs.Zone_courier AS Zone_courier,
        `Type of Shipment`,
        is_rto,
        num_additional_wt,
        fwd_fixed,
        CASE WHEN num_additional_wt > 0 THEN fwd_additional ELSE 0 END AS fwd_additional,
        CASE WHEN is_rto = 'Yes' THEN rto_fixed ELSE 0 END rto_fixed,
        CASE WHEN is_rto = 'Yes' AND num_additional_wt > 0 THEN rto_additional ELSE 0 END rto_additional
FROM order_wt_slabs
JOIN charges
ON 
	order_wt_slabs.Zone_X = charges.zone;

CREATE TEMPORARY TABLE final_charges
SELECT order_id,
		ROUND(fwd_fixed + num_additional_wt * fwd_additional + rto_fixed + num_additional_wt * rto_additional,1) AS total_charge_X
FROM order_charges_wrt_zones;

-- Total charges by company X are calculated


-- Step 7:
-- Assigning weight slabs to Weight charged by courier company
CREATE TEMPORARY TABLE order_wt_zones
SELECT  order_id, 
		`AWB Code`, 
		total_wt_kg AS Total_wt_X_kg, 
        wt_slab AS Weight_slab_X,
        `Charged Weight` AS Total_wt_courier_kg,
        CASE WHEN `Charged Weight` <= 0.5 THEN 0.5
			 WHEN `Charged Weight` <= 1.0 THEN 1.0
			 WHEN `Charged Weight`<= 1.5 THEN 1.5
			 WHEN `Charged Weight` <= 2.0 THEN 2.0
			 WHEN `Charged Weight` <= 2.5 THEN 2.5
			 WHEN `Charged Weight` <= 3.0 THEN 3.0
			 WHEN `Charged Weight` <= 3.5 THEN 3.5
             WHEN `Charged Weight` <= 4.0 THEN 4.0
             WHEN `Charged Weight` <= 4.5 THEN 4.5
		END AS Weight_slab_courier,
		Zone_X AS Delivery_Zone_X,
		Zone AS Delivery_Zone_courier
FROM order_wt_slabs
JOIN courier_invoice
ON
	order_wt_slabs.order_id = courier_invoice.`Order ID`;


-- FINAL CALCULATION TABLE
CREATE TEMPORARY TABLE calculation_table
SELECT  DISTINCT order_wt_zones.order_id, 
		order_wt_zones.`AWB Code`, 
		Total_wt_X_kg, 
        Weight_slab_X,
        Total_wt_courier_kg,
        Weight_slab_courier,
        Delivery_Zone_X,
        Delivery_Zone_courier,
        total_charge_X,
        `Billing Amount (Rs.)` AS total_charge_courier,
        ROUND(total_charge_X - `Billing Amount (Rs.)`,1) AS Difference_Rs
FROM order_wt_zones
JOIN final_charges
ON 
	order_wt_zones.order_id = final_charges.order_id
JOIN courier_invoice
ON
	order_wt_zones.order_id = courier_invoice.`Order ID`;


-- Step 8: Summary Table 
CREATE TEMPORARY TABLE states
SELECT *,
	CASE WHEN Difference_Rs = 0 THEN 'Correctly_charged'
		 WHEN Difference_Rs < 0 THEN 'Over_charged'
         WHEN Difference_Rs > 0 THEN 'Under_charged'
	END AS state
FROM calculation_table;

-- FINAL SUMMARY TABLE
SELECT state,
	COUNT(order_id) AS Count,
    CASE 
		WHEN state = 'Correctly_charged' THEN ROUND(SUM(total_charge_courier),1)
		WHEN state = 'Over_charged' THEN ABS(ROUND(SUM(Difference_Rs),1))
        WHEN state = 'Under_charged' THEN ROUND(SUM(Difference_Rs),1)
        END
        AS Amount
FROM states
GROUP BY state;


-- Exporting CALCULATION TABLE and SUMMARY TABLE to Excel
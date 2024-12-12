CREATE TABLE Collection
(
    Collection_ID character varying(10) PRIMARY KEY,
    Collection_Date date,
    Matrix character varying(4),
    Location_Desc character varying(30),
    Location_ID character varying(10),
    Sample_ID character varying(10),
    Submission_ID character varying(10)
  );
 
CREATE TABLE Locations
(
    Location_ID character varying(10) PRIMARY KEY,
    Station_No character varying(10),
    Location_Desc character varying(30),
    Latitude character varying(10),
    Longitude character varying(10),
    Ref_Point_Distance integer,
    Ref_Point_Degrees integer,
    Sample_ID character varying(10)
);
 
CREATE TABLE Sample
(
    Sample_ID character varying(10) PRIMARY KEY,
    Sample_No character varying(10),
    Collection_ID character varying(10),
    Sample_Desc character varying(55),
    Location_ID character varying(10),
    Water_Depth integer,
    Sample_Depth integer,
    Secchi_Depth integer
);
 
CREATE TABLE Test_Result
(
    Submission_ID character varying(10) PRIMARY KEY,
    LIMS_Sub_No character varying(10),
    LIMS_Method_Ref character varying(10),
    LIMS_Product character varying(10),
    LIMS_Par_Name character varying(35),
    Test_Code character varying(10),
    Results character varying(10),
    Unit character varying(15),
    Sample_ID character varying(10)
);


ALTER TABLE Collection
    ADD CONSTRAINT Location_ID FOREIGN KEY (Location_ID) REFERENCES Locations (Location_ID) 
	ON UPDATE NO ACTION
    ON DELETE NO ACTION
    NOT VALID;
ALTER TABLE Collection
	ADD CONSTRAINT Sample_ID FOREIGN KEY (Sample_ID) REFERENCES Sample (Sample_ID)
	ON UPDATE NO ACTION
    ON DELETE NO ACTION
    NOT VALID;
 
ALTER TABLE Collection
	ADD CONSTRAINT Submission_ID FOREIGN KEY (Submission_ID) REFERENCES Test_Result (Submission_ID)
	ON UPDATE NO ACTION
    ON DELETE NO ACTION
    NOT VALID;
 
ALTER TABLE Locations
    ADD CONSTRAINT Sample_ID FOREIGN KEY (Sample_ID) REFERENCES Sample (Sample_ID) 
	ON UPDATE NO ACTION
    ON DELETE NO ACTION
    NOT VALID;
 
ALTER TABLE Sample
    ADD CONSTRAINT Collection_ID FOREIGN KEY (Collection_ID) REFERENCES Collection (Collection_ID) 
	ON UPDATE NO ACTION
    ON DELETE NO ACTION
    NOT VALID;
 
ALTER TABLE Sample
	ADD CONSTRAINT Location_ID FOREIGN KEY (Location_ID) REFERENCES Locations (Location_ID) 
	ON UPDATE NO ACTION
    ON DELETE NO ACTION
    NOT VALID;
 
ALTER TABLE Test_Result
    ADD CONSTRAINT Sample_ID FOREIGN KEY (Sample_ID) REFERENCES Sample (Sample_ID) 
	ON UPDATE NO ACTION
    ON DELETE NO ACTION
    NOT VALID;



--Insights:



--1.  Nitrogen analysis

SELECT c.Location_Desc, AVG(CAST(tr.Results AS FLOAT)) as avg_nitrogen
FROM Collection c
JOIN Test_Result tr 
ON c.Submission_ID = tr.Submission_ID
WHERE tr.LIMS_Par_Name LIKE '%Nitrogen%'
GROUP BY c.Location_Desc
ORDER BY avg_nitrogen DESC



--2. Heavy metal analysis – Lead

SELECT c.Matrix, c.Location_Desc, AVG(CAST(tr.Results AS FLOAT)) as avg_lead
FROM Collection c
JOIN Test_Result tr ON c.Submission_ID = tr.Submission_ID
WHERE tr.LIMS_Par_Name = 'Lead' AND c.Matrix IN ('WS', 'SE')
GROUP BY c.Matrix, c.Location_Desc
ORDER BY avg_lead ASC;



--3. Locations with elements from the CDD family

SELECT c.Location_Desc, COUNT(*) as cdd_count
FROM Collection c
JOIN Test_Result tr ON c.Submission_ID = tr.Submission_ID
WHERE tr.LIMS_Par_Name LIKE '%CDD%'
GROUP BY c.Location_Desc
ORDER BY cdd_count DESC



--4. Average pH by lakes

SELECT c.Location_Desc, AVG(CAST(tr.Results AS FLOAT)) as avg_pH
FROM Collection c
JOIN Test_Result tr ON c.Submission_ID = tr.Submission_ID
WHERE tr.LIMS_Par_Name = 'pH'
GROUP BY c.Location_Desc
ORDER BY avg_pH DESC;



--5. Comparing the Secchi depth of all the lakes

SELECT c.Location_Desc, AVG(s.Secchi_Depth) as avg_secchi_depth
FROM Collection c
JOIN Sample s ON c.Sample_ID = s.Sample_ID
GROUP BY c.Location_Desc
ORDER BY avg_secchi_depth DESC;



--6. Comparing dissolved solids and suspended solids in all the locations

SELECT c.Location_Desc, 
       tr.LIMS_Par_Name,tr.test_code,
       AVG(CAST(tr.Results AS FLOAT)) as avg_quantity
FROM Collection c
JOIN Test_Result tr ON c.Submission_ID = tr.Submission_ID
WHERE tr.LIMS_Par_Name IN ('Solids -  dissolved', 'Solids -  suspended')
GROUP BY c.Location_Desc, tr.LIMS_Par_Name,tr.test_code
order by c.location_desc



--7.Percentage of organic pollutant vs inorganic pollutant

WITH ElementSums AS (
    SELECT
        c.Location_Desc,
        SUM(CASE WHEN tr.LIMS_Par_Name LIKE '%CDD%' AND tr.Results ~ E'^\\d+(\\.\\d+)?$'
                 THEN CAST(tr.Results AS NUMERIC) ELSE 0 END) AS cdd_sum,
        SUM(CASE WHEN tr.LIMS_Par_Name NOT LIKE '%CDD%' AND tr.Results ~ E'^\\d+(\\.\\d+)?$'
                 THEN CAST(tr.Results AS NUMERIC) ELSE 0 END) AS other_sum
    FROM
        Collection c
    JOIN
        Test_Result tr ON c.Submission_ID = tr.Submission_ID
    GROUP BY
        c.Location_Desc
)

SELECT
    es.Location_Desc,
    es.cdd_sum,
    es.other_sum,
    CASE WHEN (es.cdd_sum + es.other_sum) > 0
         THEN es.cdd_sum * 100.0 / (es.cdd_sum + es.other_sum)
         ELSE 0 END AS cdd_percentage,
    CASE WHEN (es.cdd_sum + es.other_sum) > 0
         THEN es.other_sum * 100.0 / (es.cdd_sum + es.other_sum)
         ELSE 0 END AS other_percentage
FROM
    ElementSums es
ORDER BY
    es.cdd_sum DESC;



--8. Top 5 elements with high variance between Moberley and Far Far field

WITH ParameterQuantities AS (
    SELECT
        LIMS_Par_Name AS LIMS_Parameter_Name,
        MAX(CASE WHEN L.Location_Desc = 'MOBERLEY BAY' AND TR.Results ~ E'^\\d+\\.?\\d*$' THEN TR.Results::numeric END) AS Quantity_MOBERLEY_BAY,
        MAX(CASE WHEN L.Location_Desc = 'FAR FAR FIELD' AND TR.Results ~ E'^\\d+\\.?\\d*$' THEN TR.Results::numeric END) AS Quantity_FAR_FAR_FIELD,
        COALESCE(MAX(CASE WHEN L.Location_Desc = 'MOBERLEY BAY' AND TR.Results ~ E'^\\d+\\.?\\d*$' THEN TR.Results::numeric END), 0) -
        COALESCE(MAX(CASE WHEN L.Location_Desc = 'FAR FAR FIELD' AND TR.Results ~ E'^\\d+\\.?\\d*$' THEN TR.Results::numeric END), 0) AS Quantity_Difference
    FROM
        Test_Result TR
    JOIN
        Sample S ON TR.Sample_ID = S.Sample_ID
    JOIN
        Collection C ON S.Collection_ID = C.Collection_ID
    JOIN
        Locations L ON C.Location_ID = L.Location_ID
    WHERE
        L.Location_Desc IN ('MOBERLEY BAY', 'FAR FAR FIELD')
    GROUP BY
        LIMS_Par_Name
)

SELECT
    LIMS_Parameter_Name,
    Quantity_MOBERLEY_BAY,
    Quantity_FAR_FAR_FIELD,
    Quantity_Difference,
    RANK() OVER (ORDER BY Quantity_Difference DESC) AS Rank
FROM
    ParameterQuantities;



--9. Location which has the highest amount of Phosphorus

SELECT c.Location_Desc, AVG(CAST(tr.Results AS FLOAT)) as avg_phosphorus
FROM Collection c
JOIN Test_Result tr ON c.Submission_ID = tr.Submission_ID
WHERE tr.LIMS_Par_Name LIKE '%Phosphorus%'
GROUP BY c.Location_Desc
ORDER BY avg_phosphorus DESC



--10. Average water depth vs average Secchi depth

SELECT 
    Location_Desc, 
    AVG(Water_Depth) as avg_water_depth,
    AVG(Secchi_Depth) as avg_secchi_depth
FROM 
    Sample
JOIN 
    Locations ON Sample.Location_ID = Locations.Location_ID
GROUP BY 
    Location_Desc;









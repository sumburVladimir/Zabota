-- Клиника 2523, задача 1455558. Только SELECT.
-- Запускать в базе wellness_new (USE ниже).

USE wellness_new;

-- A. Памятки из брифа, которых не было в выгрузке условий: id и флаги
SELECT delivery_id, dname, dactive, deleted, istemplate,
       sendwhatsapp, sendmax, sendtelegrampersonal, sendsms
FROM deliveries
WHERE dname LIKE N'%купер%' OR dname LIKE N'%шлифов%' OR dname LIKE N'%пластик%'
   OR dname LIKE N'%новообраз%' OR dname LIKE N'%чистк%' OR dname LIKE N'%плазм%'
   OR dname LIKE N'%пигмент%' OR dname LIKE N'%RF%' OR dname LIKE N'%игольч%'
   OR dname LIKE N'%ботул%'
ORDER BY dname;

-- B. Условия (сегменты) этих памяток: по имени условия или по id сценария в тексте условия
SELECT d.delivery_id, d.dname, c.Id AS cond_id, c.Name AS cond_name, c.Uni_key, c.Condition_Type,
       CAST(c.Expression AS NVARCHAR(MAX)) AS Expression
FROM deliveries d
JOIN deliv_conditions c
  ON c.Name = d.dname
  OR CAST(c.Expression AS NVARCHAR(MAX)) LIKE N'%:DID, ' + CAST(d.delivery_id AS NVARCHAR(20)) + N')%'
WHERE d.dname LIKE N'%купер%' OR d.dname LIKE N'%шлифов%' OR d.dname LIKE N'%пластик%'
   OR d.dname LIKE N'%новообраз%' OR d.dname LIKE N'%чистк%' OR d.dname LIKE N'%плазм%'
   OR d.dname LIKE N'%пигмент%' OR d.dname LIKE N'%RF%' OR d.dname LIKE N'%игольч%'
   OR d.dname LIKE N'%ботул%'
ORDER BY d.dname, c.Id;

-- C1. Значения параметров сценариев (здесь GROUPID для памятки 299)
SELECT * FROM deliv_params;

-- C2. Где стоят Диспорт, Ксеомин, Релатокс: id процедуры, название, группа
SELECT pr.Procedure_id, pr.Name, px.group_id
FROM procedures pr
JOIN procedurex px ON px.proc_id = pr.Procedure_id
WHERE pr.Name LIKE N'%Диспорт%' OR pr.Name LIKE N'%Ксеомин%' OR pr.Name LIKE N'%Релатокс%'
ORDER BY pr.Name;

-- D. Врачи, ID которых стоят в условиях памяток и приглашений
SELECT Doctor_ID, FullName
FROM doctors
WHERE Doctor_ID IN (203, 280, 24, 942, 582, 388, 51, 324, 118, 397, 334, 721, 724, 514,
                    673, 884, 902, 544, 1002, 660, 63, 986, 794, 846, 997, 429, 426)
ORDER BY Doctor_ID;

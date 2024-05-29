-- Demonstrates how the ServerType SQLCMD variable can alter script behaviour,
-- depending on the server selected by the user.

DECLARE @ValueToInsert NVARCHAR(255) = 
    CASE '$(ServerType)'
        WHEN 'LOCALDB' THEN 'LOCAL DEV SERVER'
        WHEN 'DEV' THEN 'REMOTE DEV SERVER'
        WHEN 'TEST' THEN 'TEST SERVER'
        WHEN 'UAT' THEN 'UAT SERVER'
        WHEN 'LIVE' THEN 'PRODUCTION SERVER'
        ELSE 'UNKNOWN SERVER'
    END;

MERGE INTO TestTable1 AS Target
USING (VALUES
        (1, @ValueToInsert)
    ) AS Source ([ID], [Name])
ON Target.[ID] = Source.[ID] 

--Update Source when ID Matched.
WHEN MATCHED THEN 
UPDATE SET [Name] = Source.[Name], 
    UpdateDate = SYSDATETIMEOFFSET() AT TIME ZONE 'New Zealand Standard Time'

--Add New When Not in Target
WHEN NOT MATCHED BY TARGET THEN 
INSERT ([ID], [Name]) 
VALUES (Source.[ID], Source.[Name]);
CREATE TABLE [dbo].[TestTable1]
(
    [Id]        INT            NOT NULL,
    [Name]      NVARCHAR(255)  NOT NULL, 
    [InsertDate]              DATETIMEOFFSET   CONSTRAINT DF_TestTable1_InsertDate DEFAULT (SYSDATETIMEOFFSET() AT TIME ZONE 'New Zealand Standard Time')    NOT NULL,
    [UpdateDate]              DATETIMEOFFSET   
    CONSTRAINT [PK_TestTable1_Id] PRIMARY KEY ([Id]),
)

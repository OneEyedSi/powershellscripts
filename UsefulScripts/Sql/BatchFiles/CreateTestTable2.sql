CREATE TABLE [dbo].[TestTable2]
(
    [Id]                    INT                 NOT NULL,
    [Name]                  NVARCHAR(255)       NOT NULL,
    [InsertDate]            DATETIMEOFFSET      NOT NULL CONSTRAINT DF_TestTable2_InsertDate DEFAULT (SYSDATETIMEOFFSET() AT TIME ZONE 'New Zealand Standard Time'),
    [UpdateDate]            DATETIMEOFFSET      NULL, 
    CONSTRAINT [PK_TestTable2_Id] PRIMARY KEY ([Id])
)

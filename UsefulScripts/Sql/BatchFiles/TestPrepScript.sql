USE Test;
GO

-- check whether tables created via scripts exist.
select * 
from INFORMATION_SCHEMA.TABLES 
where TABLE_NAME like 'TestTable%';

-- Check the contents of table 1, which should have been set based on the ServerType 
-- SQLCMD variable.
select *
from TestTable1;

-- Drop the tables before running the script runner.
/*

if exists(select * from INFORMATION_SCHEMA.TABLES where TABLE_NAME = 'TestTable1')
begin;
	drop table TestTable1;
end;

if exists(select * from INFORMATION_SCHEMA.TABLES where TABLE_NAME = 'TestTable2')
begin;
	drop table TestTable2;
end;

*/
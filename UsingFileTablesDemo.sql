/* FileTables Demo                    */
/* Sam Nasr, MCSA, MCT, MVP           */
/* snasr@nistechnologies.com          */
/* Supported in all editions of SQL Server 2016+ */


--***************************************************
--Configuring FileTables
--***************************************************

--Step 1: Enable FILESTREAM at the Instance Level
EXEC sp_configure filestream_access_level, 2
RECONFIGURE
Go


--Step 2: Provide a FILESTREAM Filegroup
--Note: "C:\FileTablesDemo" must be manually created prior to this step
IF EXISTS (SELECT * FROM sys.databases WHERE name = 'Cars2')
  DROP DATABASE Cars
ELSE
  CREATE DATABASE Cars2 ON PRIMARY (NAME = Cars_data2, FILENAME = 'C:\FileTablesDemo2\Cars2.mdf'),
  FILEGROUP CarsFSGroup2 CONTAINS FILESTREAM (NAME = Cars_FS2, FILENAME = 'C:\FileTablesDemo2\CarsFileStream2')
  LOG ON (NAME = 'Cars_log2', FILENAME = 'C:\FileTablesDemo2\Cars_log2.ldf');        
GO


--Step 3: Enable Non-Transactional Access at the Database Level
--        and Specify a Directory for FileTables at the Database Level
ALTER DATABASE Cars2
SET FILESTREAM (NON_TRANSACTED_ACCESS = FULL, DIRECTORY_NAME = N'CarsDataFS2')
Go


--Step 3A: Check Whether Non-Transactional Access Is Enabled on Databases
--         and existing directory names for the instance,
SELECT DB_NAME (database_id) as "DB Name", directory_name, non_transacted_access, non_transacted_access_desc
FROM sys.database_filestream_options;
Go
  
--Step 4: Create FileTable
Use Cars2
Go

CREATE TABLE CarsDocStore AS FileTable  --Predefined schema of 17 fields
GO


--***************************************************
--Using FileTables
--***************************************************

--Display all default attributes
Select * from dbo.CarsDocStore
Go


--Update attributes of each file via T-SQL
update dbo.CarsDocStore
set is_readonly = 0
where name = 'FordMustangGT.txt'
Go


--Delete file via T-SQL
Delete 
from dbo.CarsDocStore
where name = 'BuickRegal.txt'
Go


--***************************************************
--File Location using HierarchyID data type
--***************************************************
SELECT path_locator as FileLocation, parent_path_locator as ParentFolder
FROM dbo.CarsDocStore
Go

SELECT path_locator.ToString() as FileLocation, parent_path_locator.ToString() as ParentFolder
FROM dbo.CarsDocStore
Go



--***************************************************
--Configuring FullText Search
--***************************************************

--Query fulltext_document_types to see available file types. Additional filter packs available for various file types.
select * from sys.fulltext_document_types 
where document_type ='.txt'
Go

Use Cars2
Go

--Query DB objects related to FileTables.
select * from sys.tables
select * from sys.filetables
select * from sys.filegroups

/*********************************************************************************************************************/

--Create Full-Text Catalog (see STORAGE folder in SSMS)
Create FullText Catalog MyFullTextCatalog as Default
GO

--Create FullText Index
Create FullText Index on dbo.CarsDocStore
(name Language 1033, File_stream type column file_type Language 1033)
key Index PK__CarsDocS__5A5B77D55649F077 --Needs to be copied after the table is created from KEYS folder
on MyFullTextCatalog
with Change_Tracking Auto, StopList=system
Go


--***************************************************
--Using FullText Search
--***************************************************
Select FileTableRootPath()  --Location of FileTable files

select * 
from dbo.CarsDocStore
Go

Select *
from dbo.CarsDocStore
where contains(file_stream, 'near(V6, leather)')
Go

--GetFileNamespacePath(is_full_path, @option)  
--Reference: https://docs.microsoft.com/en-us/sql/relational-databases/system-functions/getfilenamespacepath-transact-sql?view=sql-server-ver15
Select file_stream.GetFileNamespacePath(1,1) as FileLocation
from dbo.CarsDocStore 
where contains(file_stream, 'near(V6, leather)')
Go


--***************************************************
-- Diabling/Enabling
--***************************************************
ALTER TABLE CarsDocStore
DISABLE FILETABLE_NAMESPACE
GO

delete from CarsDocstore  --TSQL Operations are still valid
Go

ALTER TABLE CarsDocStore 
ENABLE FILETABLE_NAMESPACE
GO


-- Kill all open handles in all the filetables in the database.
EXEC sp_kill_filestream_non_transacted_handles;
GO

-- Kill all open handles in a single filetable.
EXEC sp_kill_filestream_non_transacted_handles @table_name = 'CarsDocStore';
GO


--More than 1 FileTable can be created in the sameDB
CREATE TABLE CarsDocStore2 AS FileTable
CREATE TABLE CarsDocStore3 AS FileTable
Go

--Changes line
-- 6
-- 60
-- 24

USE [YOUR_DATABASE]
GO
GO

--Reconfigure SQL Server to execute xp_cmdshell (prompt command)
EXEC sp_configure 'show advanced options', 1;  
GO  
-- To update the currently configured value for advanced options.  
RECONFIGURE;  
GO  
-- To enable the feature.  
EXEC sp_configure 'xp_cmdshell', 1;  
GO  
-- To update the currently configured value for this feature.  
RECONFIGURE;  
GO  

--Alter database name
ALTER DATABASE <YOUR_DATABASE> SET TRUSTWORTHY ON

GO

--Create DBChangeLog to track objects changes.
CREATE TABLE [dbo].[DBChangeLog](
	[DBChangeLogID] [int] IDENTITY(1,1) NOT NULL,
	[DatabaseName] [varchar](256) NOT NULL,
	[EventType] [varchar](50) NOT NULL,
	[ObjectName] [varchar](256) NOT NULL,
	[ObjectType] [varchar](25) NOT NULL,
	[SqlCommand] [varchar](max) NOT NULL,
	[EventDate] [datetime] NOT NULL,
	[LoginName] [varchar](256) NOT NULL,
	[HostName] [varchar](256) NULL,
PRIMARY KEY CLUSTERED 
(
	[DBChangeLogID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

CREATE TABLE [dbo].[GITConfig](
	[host] [varchar](100) NOT NULL,
	[tag] [varchar](100) NOT NULL,
	[value] [varchar](6000) NOT NULL,
 CONSTRAINT [PK_GITConfig] PRIMARY KEY CLUSTERED 
(
	[host] ASC,
	[tag] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

--Change assembly path.
CREATE ASSEMBLY SaveFile
FROM 'path\to\CLR\bin\Release\CLR.dll'
WITH PERMISSION_SET = UNSAFE

GO

CREATE PROCEDURE [dbo].[SaveFile]
	@objeto [nvarchar](max),
	@sourcePath [nvarchar](max)
WITH EXECUTE AS CALLER
AS
EXTERNAL NAME [SaveFile].[CLR.SCM].[SaveFile]
GO


CREATE PROCEDURE [dbo].[Git](
	@branch NVARCHAR(MAX)
	, @objeto NVARCHAR(MAX)
	, @message NVARCHAR(MAX)
)
AS 
BEGIN

	DECLARE @repository_url	varchar(6000)
	DECLARE @user_email		varchar(6000)
	DECLARE @user_name		varchar(6000)
	DECLARE @source_path	varchar(6000)

	SELECT 
		@repository_url	= gc.Value
		, @user_email	= gce.Value
		, @user_name	= gcu.Value		
		, @source_path	= gcp.Value
	FROM GITConfig gc 
	INNER JOIN GITConfig gcp ON gc.host = gcp.host AND gcp.tag = 'SOURCE_PATH'
	INNER JOIN GITConfig gce ON gc.host = gce.host AND gce.tag = 'USER.EMAIL'
	INNER JOIN GITConfig gcu ON gc.host = gcu.host AND gcu.tag = 'USER.NAME'
	WHERE gc.host = HOST_NAME() AND gc.tag = 'REPOSITORY_URL'

	declare @command varchar(8000)
	declare @text varchar(max)

	set @command = 'cd "' + @source_path +  '" && git pull ' + @repository_url + ' ' + @branch + ' && git checkout ' + @branch
	exec xp_cmdshell @command

	EXEC [dbo].[SaveFile] @objeto = @objeto, @sourcePath = @source_path

	set @command = 'git config --global user.email "'+@user_email+'" && git config --global user.name "'+ @user_name +'"'
	exec xp_cmdshell @command
  

	set @command = 'cd "' + @source_path +  '" && git add . && git commit -m "' + @message + '" && git push ' + @repository_url  + ' ' +  @branch
    exec xp_cmdshell @command

END

GO

INSERT INTO [dbo].[GITConfig]
           ([host]
           ,[tag]
           ,[value])
     VALUES
           ('MACHINE_NAME'
           , 'REPOSITORY_URL'
           ,'https://username:password@github.com/<name>/<repository>.git')
GO

INSERT INTO [dbo].[GITConfig]
           ([host]
           ,[tag]
           ,[value])
     VALUES
           ('MACHINE_NAME'
           , 'SOURCE_PATH'
           ,'path\to\source')
GO

INSERT INTO [dbo].[GITConfig]
           ([host]
           ,[tag]
           ,[value])
     VALUES
           ('MACHINE_NAME'
           , 'USER.EMAIL'
           ,'mymail@gmail.com')
GO


INSERT INTO [dbo].[GITConfig]
           ([host]
           ,[tag]
           ,[value])
     VALUES
           ('MACHINE_NAME'
           , 'USER.NAME'
           , 'Your Name')
GO



--Create database trigger to log tracking.
CREATE TRIGGER [ChangeTracking] ON database for 
	create_procedure, 
	alter_procedure, 
	drop_procedure,
	create_table, 
	alter_table, 
	drop_table,
	create_function, 
	alter_function, 
	drop_function , 
	create_view, 
	alter_view 
as 
	SET NOCOUNT ON   
	DECLARE @data XML   
	SET @data = eventdata()   

	INSERT INTO dbo.dbchangelog   
	(   
				databasename,   
				eventtype,   
				objectname,   
				objecttype,   
				sqlcommand,   
				loginname,   
				eventdate,
				hostname
	)   
	VALUES   
	(   
				@data.value('(/EVENT_INSTANCE/DatabaseName)[1]', 'varchar(256)'),   
				@data.value('(/EVENT_INSTANCE/EventType)[1]', 'varchar(50)'),   
				@data.value('(/EVENT_INSTANCE/ObjectName)[1]', 'varchar(256)'),   
				@data.value('(/EVENT_INSTANCE/ObjectType)[1]', 'varchar(25)'),   
				@data.value('(/EVENT_INSTANCE/TSQLCommand)[1]', 'varchar(max)'),   
				@data.value('(/EVENT_INSTANCE/LoginName)[1]', 'varchar(256)'),   
				getdate(),
				host_name()
	)

	DECLARE @id INT
	set @id = SCOPE_IDENTITY()

	DECLARE @type VARCHAR(50) = UPPER(LTRIM(RTRIM(@data.value('(/EVENT_INSTANCE/EventType)[1]', 'varchar(50)'))))
	DECLARE @objectName VARCHAR(256) = LTRIM(RTRIM(@data.value('(/EVENT_INSTANCE/ObjectName)[1]', 'varchar(256)')))

	IF(@type = 'CREATE_PROCEDURE'
		OR @type = 'ALTER_PROCEDURE'
		OR @type = 'CREATE_FUNCTION'
		OR @type = 'ALTER_FUNCTION'
		OR @type = 'CREATE_VIEW'
		OR @type = 'ALTER_VIEW'
		OR @type = 'CREATE PROCEDURE')
	BEGIN
		PRINT('It''s time to commit?')
		PRINT('exec git ''<branch>'',  ''<object>'', ''<message>''')

		DECLARE @event_date DATETIME
		DECLARE @host_name VARCHAR(256)
		DECLARE @message VARCHAR(1000)

		SELECT
			TOP 1
			@event_date = l.EventDate
			, @host_name = HostName
		FROM DBChangeLog l
		WHERE l.ObjectName = @objectName
		AND l.DBChangeLogID <> @id
		ORDER BY l.EventDate DESC

		PRINT('')
		PRINT('')
		SET @message = 'Last change: ' + CONVERT(VARCHAR(20), @event_date)
		PRINT(@message)
		SET @message = 'Last user: ' + @host_name
		PRINT(@message)


	END

GO

ENABLE TRIGGER [ChangeTracking] ON DATABASE
GO

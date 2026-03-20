/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Detalhes 
		Retorna a sequência de RESTORE para um banco!
		Útil para rapidamente montar os comandos de restore!
		Pode te ajudar a ganhar tempo para executar um restore de emergência!
		Informe o banco e o full máximo, e a partir disso, o script descobre os difs e logs para serem usados!
		Informe o MaxDate, que é a data máxima até onde quer restaurar.

		TODOS:
			- Caso do recovery fork guid (recovery paths)

*/
-- Preencha essa tabela com os nomes dos bancos que queria!
-- Deixei uma temp table para facilitar popular com algum script se você precisar!
IF OBJECT_ID('tempdb..#BasesRestore') IS NOT NULL 
	DROP TABLE #BasesRestore;



-->>>> PARÂMETROS DO SCRIPT	
-- Basta popular a tabela #BasesRestore(coluna name) com o nome dos bancos que quer. 1 banco por linha.

	SELECT 'TestDb' name INTO #BasesRestore;

	DECLARE 
		@BackupPath nvarchar(max) 	= 'C:\Origem'		--> diretorio onde os backupa estarão
		,@ReplacePath nvarchar(max) = 'C:\Destino' 	--> diretorio original 
		,@MaxFullDate datetime 		= GETDATE()			--> Usar um full com, no máximo, essa data. A partir disso, pegará os logs digs!
														-- Use isso para que o script limite qual full vai usar, permitindo você escolher um full anterior ao mais recente!
		,@MaxDate datetime			= null			-- Use isso para limitar a data do restore de todos os backups. é o point time mais proximo possivel desse tempo.
													-- Se null, usa getdate()
														

---- DAQUI PRA FRENTE NÃO PRECISA MAIS ALTERAR --- 
-- Se a query ficar muito lenta, esse índice me ajudou... 
-- Mas, crie por sua própria conta e risco, visto que não é recomendando mexer em tabelas mantidas pela microsoft!!!!
-- --create index ixtemp on  backupset(database_name,type,is_copy_only) with(data_compression = page)
USE msdb;

IF OBJECT_ID('tempdb..#Full') IS not NULL
	DROP TABLE #Full;

select
	 DbName = R.name
	,F.*
into
	#Full
from
	#BasesRestore R
	cross apply (
		select top 1  
			 bs.backup_finish_date
			,backup_set_id
			,FullRestorePath = REpLACE(f.physical_device_name,@ReplacePath,@BackupPath)
			,FullSizeGB = bs.compressed_backup_size/1024/1024/1024
		From backupset bs
		join backupmediafamily f
			on f.media_set_id = bs.media_set_id
		where 
			type = 'D' and database_name = R.name
			and  is_copy_only = 0
			and backup_finish_date < ISNULL(@MaxFullDate,GETDATE())
			and backup_finish_date < ISNULL(@MaxDate,GETDATE())
		order by 
			backup_set_id desc
	) F




IF OBJECT_ID('tempdb..#Diff') IS NOT NULL
	DROP TABLE #Diff;

select
	 F.DbName
	,D.*
into
	#Diff
from
	#Full F
	cross apply (
		select top 1  
			 bs.backup_finish_date,backup_set_id
			,DiffRestorePath = REpLACE(bmf.physical_device_name,@ReplacePath,@BackupPath)
			,DiffSizeGB = bs.compressed_backup_size/1024/1024/1024
		From
			backupset bs
			join backupmediafamily bmf
				on bmf.media_set_id = bs.media_set_id
		
		where 
				type = 'I' 
			and database_name = F.DbName
			and backup_finish_date > F.backup_finish_date
			and backup_finish_date <= ISNULL(@MaxDate,GETDATE())
			and  is_copy_only = 0
		order by 
			backup_set_id desc
	) D



	


IF OBJECT_ID('tempdb..#Logs') IS NOT NULL
	DROP TABLE #Logs;


SELECT
	 F.DbName
	,l.*
into
	#Logs
FROM
	#Full F
	LEFT JOIN
	#Diff D
		ON D.DbName = F.DbName
	CROSS APPLY (
		select   
			bs.backup_finish_date
			,bs.backup_set_id
			,LogRestorePath = REpLACE(bmf.physical_device_name,@ReplacePath,@BackupPath)
			,LogSizeGB = bs.compressed_backup_size/1024/1024/1024
		From 
			backupset bs
			join backupmediafamily bmf
				on bmf.media_set_id = bs.media_set_id		
		where 
			type = 'L' 
			and database_name = F.DbName
			and  is_copy_only = 0
			AND backup_finish_date > isnull(D.backup_finish_date,F.backup_finish_date)
			and backup_finish_date <= ISNULL(@MaxDate,GETDATE())
	) L

insert #Logs(DbName,backup_finish_date,backup_set_id,LogRestorePath,LogSizeGB)
select
	DbName
	,backup_finish_date
	,backup_set_id
	,LogRestorePath
	,LogSizeGB
from
	(
		select 
			 f.DbName 
			,LastBackupId = max(coalesce( l.backup_set_id, d.backup_set_id, f.backup_set_id ))
		from
			#Full f
			left join 
			#Diff d
				on	d.DbName = f.DbName 
			left join 
			#Logs l	
				on l.DbName = f.DbName
		group by
			f.DbName
		having
			isnull(max(l.backup_finish_date),'19000101') < @MaxDate
	) L
	CROSS APPLY (
		SELECT TOP 1
			 bs.backup_finish_date
			,LogRestorePath = REpLACE(bmf.physical_device_name,@ReplacePath,@BackupPath)
			,bs.backup_set_id
			,LogSizeGB = bs.compressed_backup_size/1024/1024/1024
		FROM
			msdb..backupset bs
			join backupmediafamily bmf
				on bmf.media_set_id = bs.media_set_id		
		WHERE
			BS.type = 'L' AND BS.is_copy_only = 0
			AND
			BS.database_name = L.DbName
			AND
			BS.backup_set_id > L.LastBackupId
		ORDER BY
			BS.backup_set_id
	) LL

select	
	f.DbName
	,FullDate = f.backup_finish_date
	,f.FullSizeGB
	,DiffDate = d.backup_finish_date
	,d.DiffSizeGB
	,ls.*
	,FullRestoreSql = 'RESTORE DATABASE '+quotename(f.DbName)+' from '+case when f.FullRestorePath like 'http%' then 'url' else 'disk' end+' = '''+f.FullRestorePath+''' WITH NORECOVERY,stats = 10'
	,DiffRestoreSql = 'RESTORE DATABASE '+quotename(f.DbName)+' from '+case when d.DiffRestorePath like 'http%' then 'url' else 'disk' end+' = '''+d.DiffRestorePath+''' WITH NORECOVERY,stats = 10'
	,l.*
from 
	#full f
	left join
	#diff d
		on d.DbName = f.DbName
	outer apply (
		select 
			LogsCount = count(*)
			,TotalLogSize = sum(LogSizeGB)
			,MinLog = min(backup_finish_date)
			,MaxLog = max(backup_finish_date)
		from 
			#Logs l
		where l.DbName = f.DbName
	) LS
	outer apply (
		select 
			[data()] = 'RESTORE LOG '+quotename(l.DbName)+' from '+case when LogRestorePath like 'http%' then 'url' else 'disk' end+' = '''+LogRestorePath+''' WITH NORECOVERY,stats = 10'+CHAR(13)+CHAR(10)
			+case when rn = 1 and @MaxDate is not null
				then ',STOPAT = '''+REPLACE(CONVERT(varchar(100),@MaxDate,121),'-','')+''' '
				else ''
			end
		from 
			(
				select 
					* 
					,rn = row_number() over(order by backup_finish_date desc)
				from #Logs l
			) l
		where l.DbName = f.DbName
		order by backup_finish_date
		FOR XML PATH(''),type
	) l(LogsRestoreSql)
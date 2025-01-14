/*
	# autor 
		Rodrigo Ribeiro Gomes 
		
	# detalhes 
		Esse script � um dos que mais usei e at� hoje uso!
		Ele permite procurar um texto em todos m�dulos de todos os banco e nos jobs.
		M�dulo � func�o, procedure ou trigger.
		Ou seja, voc� consegue procurar, por exemplo, se uma proc referencia uma tabela, ou at� uma string direto em um filtro...
		
		Obviamente, que ele n�o � perfeito (n�o pega os caso adhoc) e pode pegar coisa al�m do que voc� precisa!
		Mas, j� pode te ajudar demais se voc� procura por algo bem espec�fico!
		
		Esse n�o � um script pensando em performance.
		Se voc� tiver muito objeto (MUITO mesmo), ele vai ser lento msmo e pode consumir bastante e CPU (e at� causar alguma press�o de mem�ria e atividade no disco).
		Mas, em casos emergenciais, dificilmente voc� estar� preocupado com isso.
		
*/

DECLARE
	 @procura nvarchar(max)
SET  @procura = 'Texto da busca' 

IF OBJECT_ID('tempdb..#resultados') IS NOT NULL
	DROP TABLE #Resultados
CREATE TABLE
	#Resultados ( Banco sysname,NomeObjeto nvarchar(2000)  )

DECLARE
	@SQL varchar(max)
SET @SQL = '
	USE [?];
	
	RAISERROR(''Procurando no banco ?...'',0,0) WITH NOWAIT;
	
	INSERT INTO
		#Resultados( bANCO,NomeObjeto )
	SELECT
		 db_name() COLLATE DATABASE_DEFAULT
		,object_name(  sm.object_id, db_id() ) COLLATE SQL_Latin1_General_CP1_CI_AI 
	FROM
		sys.sql_modules sm
	WHERE
		sm.definition like ''%'+@procura+'%'' COLLATE SQL_Latin1_General_CP1_CI_AI 

	UNION

	SELECT
		 db_name()
		,object_name(  sm.id, db_id() )
	FROM
		sys.syscomments sm
	WHERE
		text like ''%'+@procura+'%'' COLLATE SQL_Latin1_General_CP1_CI_AI 


';



EXEC sp_MSforeachdb @SQL;



RAISERROR('Procurando nos jobs...',0,1) WITH NOWAIT;

set nocount on;
INSERT INTO
	#Resultados( bANCO,NomeObjeto )
SELECT
	'--JOB--' COLLATE SQL_Latin1_General_CP1_CI_AI 
	,J.name COLLATE SQL_Latin1_General_CP1_CI_AI 
FROM
	msdb..sysjobs J
	JOIN
	msdb..sysjobsteps JS
		ON JS.job_id = J.job_id
WHERE
	JS.command like '%'+@procura+'%' COLLATE SQL_Latin1_General_CP1_CI_AI
	OR
	J.name like  '%'+@procura+'%' COLLATE SQL_Latin1_General_CP1_CI_AI


select *From #Resultados
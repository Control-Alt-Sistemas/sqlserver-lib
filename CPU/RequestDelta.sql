/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes

	# Detalhes 
		Antes de ir para a Power Tuning e ajudar a desenvolver o Power Alerts V3, essa era minha principal query para fazer troblshooting de CPU.
		Falou em CPU alta, eu ja copiava essa query e analisava o resultado... uns 90% dos casos em que usei, achei de cara quem estava consumindo cpu alta...
		Em poucos segundos...

		O motivo pelo qual eu reduzi o uso dela ap�s ir Para a Power Tunig � simples: Adicionamos essa mesma l�gica nos alertas de CPU!
		Mas, ainda eu uso ela em ambientes que n�o tenham e me ajudam em um monitormaneto realtime ali dentro do seridor...

		A sacada aqui � a seguinte: Tire um foto do consumo de cpu total das queries, aguarda 1 segundo, e tire uma novo foto!
		Ent�o, compare o que mudou e ordena pelo resultado!

		Falou em CPU alta na sua inst�ncia do SQL, essa � a primeira coisa que eu quero olhar: quais queries est�o consumindo quantos % da cpu?
		Esse script ajuda a responder isso!

		Lembrando que essa query n�o � perfeita e n�o pegar� todos os casos precisamente... Mas te garanto que ela poder� dar um vis�o extremamente nova sobre
		o consumo de CPU e dar um norte para onde deve procurar mais!

		No final desse script eu deixei uma historinha legal sobre esta query e mais background t�cnico de como ela funciona.
		Movi para o final, pois me empolguei no texto e isso virou quase um blog post!
		Se quiser saber mais da l�gica que usei aqui (E para o caso de querer me ajudar a melhorar), recomendo a leitura!
*/


--> Se voc� quiser ir guardando os resultados em uma tabela, coloque o nome dela aqui!
--> Com isso v� pode comparar depois! 
-- CURIOSIDADE: acredita que demorei anos para pensar nessa sacada simples de colocar isso?
--				Me ajudou bastante, pois tinha um hist�rico r�pido dessas coletas!
DECLARE
	@InsertTable sysname = ''


------- DAQUI PRA BAIXO, N�O PRECISA ALTERAR NADA! ----


IF OBJECT_ID('tempdb..#UsoCPUAnterior') IS NOT NULL
DROP TABLE #UsoCPUAnterior;


IF OBJECT_ID('tempdb..#UsoCPUAtual') IS NOT NULL
DROP TABLE #UsoCPUAtual;


--> Tabela tempor�ria para guardar a foto!
IF OBJECT_ID('tempdb..#CPUtotal') IS NOT NULL
	DROP TABLE #CPUtotal;


--> Primeria foto dos requests;
SELECT
R.session_id
,R.request_id
,R.start_time
,R.cpu_time
,CURRENT_TIMESTAMP as DataColeta
,R.sql_handle
,R.total_elapsed_time
,R.statement_start_offset
,R.statement_end_offset
,R.command
,R.database_id
,R.reads
,R.writes
,R.logical_reads
INTO
#UsoCPUAnterior
FROM
sys.dm_exec_requests R
WHERE
R.session_id != @@SPID



WAITFOR DELAY '00:00:01.000'; --> Aguarda 1 segundo (intervalo de monitoramento)

--> Segunda foto!
SELECT
R.session_id
,R.request_id
,R.start_time
,R.cpu_time
,CURRENT_TIMESTAMP as DataColeta
,R.sql_handle
,R.total_elapsed_time
,R.statement_start_offset
,R.statement_end_offset
,R.command
,R.database_id
,R.reads
,R.writes
,R.logical_reads
INTO
#UsoCPUAtual
FROM
sys.dm_exec_requests R
WHERE
R.session_id != @@SPID


--> Pronto, nesse momento j� temos uma amostra do que houve em 1 segundo!
--> Vamos calcular!


-- algumas colunas s�o auto-explicativas... vou comentas apenas o que n�o � comum das DMVs do sql
SELECT
	 R.session_id
	,R.request_id
	,R.start_time

	--> Este � o intervalo que se passou entre uma coelta e outra... Vai ser sempre pr�ximo ao valor do WAITFOR acima.. Em millisegundos
	-- isto �, considerando o padr�o de 1 segundo que deixo no script, ser� algo muito pr�ximo e 1000 ms.
	--> Pq eu nao deixo o valor hard-coded?
	--> Simples: devido a press�o do ambiente, o tempo exato de coleta n�o vai ser o que eu espero!
	-- Por isso, eu uso isso para obter um tempo mais pr�ximod a realidade e consideranod poss�veis delays ocasionados por uma press�o de cpu do ambiente...
	-- isso n�o � perfeito, mas funcionava incrivelmente bem e j� vi algumas boas diferen�as!
	--> Portanto, se eu coloquei 1 segundo de intervalo, mas coletou, ap�s 1.5, ent�o eu vou usar 1.5 como base para calcula ros percentual de uso de CPU!
	,Intervalo = ISNULL(DATEDIFF(ms,U.DataColeta,R.DataColeta),R.total_elapsed_time)

	--> Esse � total de CPU que o request gastou nesse intervalo, em milissegundos.
	-- Pode ser que seja nulo, para o caso de sess�es que apareceram DEPOIS da primeira coleta... Nesse caso, vamos assumir que o total de cpu � o usado!
	,CPUIntervalo = ISNULL(R.cpu_time-U.cpu_time,R.cpu_time)

	--> Aqui vamos calcular o quanto do Intervalo foi gasto usando CPU.
	-- Por exemplo, se a query usou 500ms de CPU, isso � 50% de 1 segundo.
	-- Se a query rodou com paralelismo, e usou 4 cpus, totalizando um gasto 2s de CPU, isso � 200% do intervalo!
	-- Mas Rodrigo, 200%? SIM, 200... Devido ao paralelismo, voc� pode ver um consumo acima de 100%...
	-- E a raz�o � que esse valor vista te mostrar o quanto voc� consumiu do intervalo de coleta, n�o do total poss�vel de uso!
	,[%Intervalo] = ISNULL((R.cpu_time-U.cpu_time)*100/DATEDIFF(ms,U.DataColeta,R.DataColeta),ISNULL((R.cpu_time/NULLIF(R.total_elapsed_time,0))*100,0))

	--> Esta � a dura��o total da query
	,Duracao = R.total_elapsed_time

	--> Este � total de cpu consumindo pela query, na sua vida inteira!
	-- Uma query pode iniciar a execu��o, consumir cpu, parar, consumir mais um pouco, parar, etc.
	-- essa coluna sempre � um acumulado, e por isso, sozinha n�o te ajuda a debugar um problema que est� acontecendo agora!
	--> na verdade, ela so�ajudaria se essa query est� a vida inteira gastando cpu e nunca parou
	-- Mas, como nem sempre ser� esse cen�rio, n�o podemos contar com ela sozinha!
	,CPUTotal = R.cpu_time

	--> Este � um percentual que representa o percentual de CPU gasto a vida inteira!
	--> Suponha que uma query rodou por 1 horas (3600 segundos). Mas, desse tempo, ela ficou 55 minutos em lock, pq alguem esqueceu uma transacao aberta!
	--> E, quando liberaram a transacao, os ultmios 5 minutos (300 segundos) dela foi moendo a CPIU...
	--> Neste caso, o percentual de CPU da vida inteira �: 300/3600 = 8,3%.
	--> Em que essa informacao � �til?
	--> Queries cmo percentual baixo, geralmente n�o s�o o que est�o moendo sua CPU agora (gerlamente t�? mas pode ser sim).
	--> Quanto mais pr�ximo de 100%, mais voc� entende que aquela query n�o teve impeditivos, e passou a vida inteira dela moendo CPU...
	--> Isso te ajuda a tra�ar um perfil daquela query. Mas ainda sim, o %Intervalo aina � muito mais importante que esse!
	,[%Total] = CONVERT(bigint,(R.cpu_time*100./NULLIF(R.total_elapsed_time,0)))
	
	--> Nome da procedure, functions ou view em que essa query esta! Informativo pra facilitar achar!
	--> Se voc� visualizar a mesma procedure aparecendo em v�rias linhas, pode j� te d� um norte de qual parte do sistema � at� entender se � algo novo ou quais usuarios podem estar causando um poss�vel consumo al�m do normal
	,ObjectName = ISNULL(OBJECT_NAME(EX.objectid,EX.dbid),R.command)
	
	--> Trecho da query, dentro da procedure, que est� causando! � os statement, o comando Sql de fato!
	,Trecho = q.qx

	
	,DatabaseName = db_name(R.database_id)
	
	-- Aqui voc� ver� o id dos schedulers usados pela sua query!
	--> Se sua quer roda em paralelo, vai ver v�rios n�meros separados pelo espa�o!
	,S.sched

	,R.logical_reads
	,R.reads
	,R.writes
	--> quantidade total de tasks. Queries paralelas ter�o valor > 1
	,SC.TaskCount
	--> Quantidade �nica de schedules sendo usadas!
	--> O degree of parallelism controla isso!
	,SC.UniqueSched
	,CN.client_net_address
	,Ts = GETDATE()
INTO
	#CPUtotal
FROM
	#UsoCPUAtual R
	LEFT JOIN
	#UsoCPUAnterior U
	ON R.session_id = U.session_id
	AND R.request_id = U.request_id
	AND R.start_time = U.start_time
	outer apply sys.dm_exec_sql_text( R.sql_handle ) as EX
	cross apply (
		select 
			S.scheduler_id as 'data()' 
		From sys.dm_os_tasks T join sys.dm_os_schedulers S on S.scheduler_id = T.scheduler_id
		WHERE T.session_id = R.session_id AND T.request_id = R.request_id
		FOR XML PATH('')
	) S(sched)
	cross apply (
		select
			TaskCount = count(DISTINCT T.task_address)
			,UniqueSched = COUNT(DISTINCT S.scheduler_id)
		From sys.dm_os_tasks T join sys.dm_os_schedulers S on S.scheduler_id = T.scheduler_id
		WHERE T.session_id = R.session_id AND T.request_id = R.request_id
	) SC
	left join sys.dm_exec_connections CN
		ON CN.session_id = R.session_id
	cross apply (
	select
		-- SIM! Se voc� j� fu�ou o c�digo da whoisactive, deve ter visto isso l�, e foi de l� mesmo que eu peguei!
		-- Simplesmente pq isso aqui funciona bem pra extrair o trecho da procedure e converter pra um XML clic�vel no SSMS.
		[processing-instruction(q)] = (
		REPLACE
		(
		REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
		REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
		REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
		CONVERT
		(
		NVARCHAR(MAX),
		SUBSTRING(EX.text,R.statement_start_offset/2 + 1, ISNULL((NULLIF(R.statement_end_offset,-1) - R.statement_start_offset)/2 + 1,LEN(EX.text)) ) COLLATE Latin1_General_Bin2
		),
		NCHAR(31),N'?'),NCHAR(30),N'?'),NCHAR(29),N'?'),NCHAR(28),N'?'),NCHAR(27),N'?'),NCHAR(26),N'?'),NCHAR(25),N'?'),NCHAR(24),N'?'),NCHAR(23),N'?'),NCHAR(22),N'?'),
		NCHAR(21),N'?'),NCHAR(20),N'?'),NCHAR(19),N'?'),NCHAR(18),N'?'),NCHAR(17),N'?'),NCHAR(16),N'?'),NCHAR(15),N'?'),NCHAR(14),N'?'),NCHAR(12),N'?'),
		NCHAR(11),N'?'),NCHAR(8),N'?'),NCHAR(7),N'?'),NCHAR(6),N'?'),NCHAR(5),N'?'),NCHAR(4),N'?'),NCHAR(3),N'?'),NCHAR(2),N'?'),NCHAR(1),N'?'),
		NCHAR(0),
		N''
		)
		)
		for xml path(''),TYPE
	) q(qx)
WHERE
	--> Aqui estou tirando minha pr�pria sess�o do resultado, pois dificilmente essa query vai consumir algo significativo!
	--> Se voc� quiser comentar por desencargo, fique a vontade!
	R.session_id != @@SPID
	and
	S.sched IS NOT NULL



--> insere o resultado se foi solicitado!
--> � um simples insert dinamicl... Se voce mexeu na estrutura, recomendo renomear e deixar ele criar um nova!
if nullif(@InsertTable,'') is not null 
begin
	declare @sql nvarchar(max)
	IF OBJECT_ID(@InsertTable) IS NULL
	begin
	set @sql = 'SELECT * INTO '+@InsertTable+' FROM #CPUTotal'
	end
	ELSE
	set @sql = 'INSERT INTO '+@InsertTable+' SELECT * FROM #CPUTotal'

	exec(@sql)
end


--> Traz o resultado ordena pelo consumo de CPU no intervalo!
--> Note aqui como eu n�o considero o total da vida inteira, mas apenas o quanto foi gasto no intervao coletado...
--> Isso � a m�gica que vai colocar as prov�veis queries j� nos primeiros resultados!
SELECT * FROM #CPUtotal
where CPUIntervalo > 0
ORDER BY
CPUIntervalo desc


--> E por fim, aqui vamos gerar uma pequena imita��o do gerenciaro de tarefas!
--> Isso aqui foi uma curiosidade minha pra saber se ia bater com o task manager do windows, e acabei deixando!
--> As vezes bate, as vezes n�o... Tem muito mais vari�veis envolvidas, mas deixei para complementar!
select 
	--> Tempo M�dio de cpu, considerando o m�ximo de CPU poss�vel que pode ser gasto!
	 AvgCpuPercent = c.TotalCPU*100/(si.cpu_count*1000)
	,TotalCPU
	,EstCpuCnt = TotalCPU/1000 --> N�o lembro minha inten��o qui, mas acho que era Uma estimativa de padaria, o quanto cada cpu estaria gastando...

	--> Esse � legal: Aqui � o limite maximo te�rico que uma queyr pode consumir no intervalo coletado
	-- Exemplo: Se o intervalo da foto foi 1 segundo, e eu tenho 4 cpus, ent�o o m�ximo que uma query pode consumir, considerando que ela pode rodar nas 4 ao mesmo tempo, seira 4000 ms
	--> Isto �, eu nunca veria um CPUIntervalo > MaxCPUTime
	,MaxCPUTime = (si.cpu_count*MaxIntervalo) 
	,TotalCpu = si.cpu_count
From ( SELECT TotalCPU = SUM(CPUIntervalo*1.), MaxIntervalo = MAX(Intervalo) from #CPUtotal )
c cross join sys.dm_os_sys_info si



/*#info 

MAIS SOBRE O CONSUMO DE CPU

		Por anos, eu aprendi que quando o 100% de CPU bate em um servidor SQL, � preocupanete!
		Meus primeiros anos como DBA foi respondendo a alertas do Nagios (ou Zabbkix) quando a CPU batia 100% por alguns minutos!
		Por anos, eu me perguntei: o que � o 100% de CPU?

		A resposta pra essa pergunta � esse script.
		Desvendar o que � o 100% mostrado no gerenciador de tarefas do Windows, e nesses alertas, me ajudou a entender como achar queries que est�o causando problemas de CPU.

		O 100% de CPU � baseado em uma foto: Tire uma foto de tudo que t� na cpu agora, espere 1 segundo, e tire outra!
		Fa�a: Foto2 - Foto1, e voc� ter� quais processos mais consumiram a CPU nesse intervalinho de 1 segundo.
		Isso � basicamente, o que o seu Gerenciador de Tarefas faz!

		Trazendo isso pra queries, se eu tirar um foto do que est� rodando, esperar 1 segundo,e  tirar outra foto, consigo saber quais request est�o consumindo CPU naquele momento.
		Isso � o que chamamos de "Delta": a diferen�a em um intervalo de tempo.

		Mas Rodrigo, porque n�o apenas usar a coluna cpu_time da sys.dm_exec_requests?
		Simples: Isso � um valor cumulativo! Seu request pode ter 1 milh�o de segundos de CPU, mas pode ter gasto isso semana passada, e, 
		se a query est� parada rodando at� hoje, por mais que mostre 1 milh�o de cpu, n�o � ela a culpada nesse momento.

		Isso � uma das maiores fontes de confus�es e ao longo da minha carreira como DBA eu fui levado a APENAS confiar na cpu_time.  
		Eu digo apenas, pq ainda sim, ela � �til... Mas, se eu recebo um alerta de CPU agora, o que mais me interessa � o delta, pois � ele quem vai me ajudar a mostrar o cen�rio de agora.

		Essa query � isso: Captura as informa��es do request, aguarda 1 segundo, e captura novamente.
		Cada captura eu guardo em uma temp table.  Ap�s isso, eu comparo as duas capturas e mostro uma s�rie de informa��es!


		Isso � incrivelmente preciso com queries que rodam por mais de 1 segundo.

		Para ambientes em que a press�o vem de queries que rodam em menos de 1 segundo, este delta n�o vai pegar direto,
		pois as queries est�o come�ando e terminando antes ou depois das coletas. Para estes casos, tem outros scripts nessa pasta, ou, voc� deve usar um
		Query Store, Profile, extended events...

		Mas, voc� vai conseguir matar uns 90% dos seus problemas de CPU com essa query e chegar na raiz do problema.
		Uma dica valiosa: se o seu sql est� em 100% (confirmado no gerenciador de tarefas que � o processo dessa instancia mesmo), e essa query nao trouxe nada que justifique,
		ent�o muito provavelmente voc� tem um caso que est� sendo causado por uma alta demandas de queries pequenas...
		Ent�o, pra pegar essas queries pequenas, vai precisar usar algo melhor, como um extened events ou query store.

		H� uma outra query nesse diretorio que tamb�m pode te ajudar, � uma query que consutla a sys.dm_exec_query_stats da query que rodou nos ultimos segundos.
		Ela pode ajudar, mas, depende do n�vel ca�tico do ambiente!
		Eu gosto de chamar esse cen�rios "otimiza��o qu�ntica", pois s�o geralmente muitas queries que rodam em uma escala de tempo muito pequena, mas, na soma, acabam impactando sua inst�ncia.
		S�o casos bem mais dif�ceis de pegar, mas s�o muito divertidos =)

		uma outra coisa importante que voc� deve tomar cuidaod � que em um cen�rio onde TODAS os schedulers est�o ocupados, a execu��o desta query vai ser afetada.
		Ent�o, isso tamb�m pode acabar influenciando um pouco nos n�meros.
		nesses cen�rios, se poss�vel, rode com um DAC, especialmente se essa query demorar muito pra retornar... pode ajudar!


		Revendo essa query lembrei de uma s�rie posts em que falei um pouco mais sobre isso
		ESSA S�RIE FICOU MUITO LEGAL (as imagens s�o bem bacanas!!!)
		https://thesqltimes.com/blog/2019/02/20/desempenho-do-processador-x-desempenho-do-sql-server-parte-1/

		eu j� falei disso bastante em alguns SQL Saturdays e outras palestras e vou encontrar os materais para publicar depois!
*/
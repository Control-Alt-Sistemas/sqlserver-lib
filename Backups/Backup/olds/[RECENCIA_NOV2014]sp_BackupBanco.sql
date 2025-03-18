/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Detalhes 
		Uma proc que criei para fazer backup mai f�cil!
		Me basiei nas procs do Ola Hallegren, pois em alguns ambientes eu n�o podia instalar, ent�o fiz essa.


*/
ALTER PROCEDURE [dbo].[sp_BackupBanco]
(
	 @Bancos		NVARCHAR(max)	= ''
	,@Local			NVARCHAR(MAX)	= 'D:\BACKUP\LOG'
	,@CopyOnly		BIT				= 1
	,@Porcentagem	TINYINT			= 10
	,@ExecOpt		TINYINT			= 3
	,@TipoBkp		VARCHAR(15)		= 'LOG'
	,@Comprimir		bit				= 1
)
AS
/*******************************************************************************************************************************                                                       
Descri��o  :	Realiza o backup de uma mais bancos.    
				Vers�es suportadas:
					SQL SERVER 2005 SP1,SP2,SP3	
				Depend�ncias:
					xp_fileexists
					DATABASEPROPERTYEX
					RAISEERROR
Par�metros :
		@Bancos
			O nome do banco. Pode se especificar mais de um banco separado
			por v�rgula. O nome do banco n�o pode conter v�rgulas e nenhum dos s�mbolos usados para vari�veis.
			Algumas vari�veis s�o aceitas:
				$[BANCOS_TODOS]		- Indica que todos os bancos ser�o inclu�dos na lista.
				$[BANCOS_USUARIO]	- Indica que todos os bancos de usu�rio ser�o inclupidos na lista.
									Os bancos de sistema n�o.
				$[BANCOS_SISTEMA]	- Indica somente os bancos de sistema.
				-NOME_BANCO			- Indica que o banco em NOME_BANCO n�o ser� exclu�do da lista.
									Esta op��o faz com que o banco seja excluido da lista, mesmo que
									tenha sido incluido implicitamente ou explicitamente.
		@Local
			Indica a pasta para onde o(s) backup(s) ser�o feitos.
		@CopyOnly
			Indica se o backup de log � copy_only(1) ou n�o(0).
			Backups copy_only n�o truncam o arquivo de log.
			Padr�o: 1
		@Porcentagem
			A porcetagem do progresso que dever� se mostrada para cada banco.
			Padr�o: 10 (Indica 10%)
		@ExecOpt
			Opcoes de execucao:
				1(0x1) - Imprimir o c�digo somente
				2(0x2) - Executar e c�digo somente
				3(0x3) - Imprimir e executar.
			Valor padr�o: 3

		@Comprimir

				Indica se o backup deve ser compresso ou n�o.
  
Banco		: master    

HIST�RICO        
Analista				Data		Abrevia��o  Descri��o                                                        
Rodrigo Ribeiro Gomes	20/08/2011  --			Criou a PROCEDURE.    
**********************************************************************************************************************************/ 

-------------------------------------- �REA DE RECURSOS -------------------------------------------------
/*** �rea de Recursos: Vari�vels, temp tables, table variables devem ser escritos aqui. ***/

-- Vari�veis
/*
	GLOBAL
		@SQLTmp		--> Ir� conter comandos SQL para serem executados dinamicamente.
		@MsgErro	--> Cont�m alguma mensagem de erro!
		@CodErro	--> Cont�m algum c�digo de erro!
		@AuxINT		--> Cont�m algum valor inteiro usado temporariamente pelo script.
		@AuxStr		--> Cont�m alguma string usada temporiramente pelo script.
		@AuxBIT		--> Cont�m algum valor do tipo bit usado temporariamente no script!
		@DataAtual	--> Cont�m o retorno de getDate() em dado momento.
		@DataDMA	--> Cont�m somente o dia, m�s e ano de uma data.
		@DataTempo	--> Cont�m a parte do tempo de uma data
	
	Quote personalizado
		@DelimE		--> Cont�m o delimitador da esquerda
		@DelimD		--> Cont�m o delimitador da direita
		@Separador	--> Cont�m o separador de dados da string.
		
	Bancos
		@CodBanco	--> Cont�mo c�digo do banco da tabela #Bancos. N�o � o mesmo que o db_id
		@NomeBanco	--> Cont�m o nome do banco da tabela #Bancos.
		
	Processo de backup
		@NomeArBkp	--> Cont�m o nome do arquivo de backup
		@OpcoesWITH	--> Cont�m a cl�usula do comando de backup "WITH"

*/
--Copyright
RAISERROR('Backup de Bancos. Por Rodrigo Ribeiro Gomes. RodrigoR.Gomes@hotmail.com',0,0) WITH NOWAIT;

DECLARE
	 @SQLTmp	NVARCHAR(MAX)
	,@MsgErro	NVARCHAR(MAX)
	,@CodErro	INT	
	,@AuxINT	INT
	,@AuxStr	NVARCHAR(MAX)
	,@DelimE	NVARCHAR(MAX)
	,@DelimD	NVARCHAR(MAX)
	,@Separador	NVARCHAR(MAX)
	,@CodBanco	INT
	,@NomeBanco	NVARCHAR(MAX)
	,@NomeArBkp	NVARCHAR(MAX)
	,@DataAtual	DATETIME
	,@DataDMA	NVARCHAR(50)
	,@DataTempo	NVARCHAR(50)
	,@OpcoesWITH NVARCHAR(MAX)
;

-- Tabelas tempor�rias
/*
	#Erros	: Cont�m os erros encontrados no script!
	#InfoDir: Armazena os resultados retornados por xp_fileexist.
	#Bancos: Armazena os bancos a serem restaurados.
*/
IF OBJECT_ID('tempdb..#Erros') IS NOT NULL
	DROP TABLE #Erros;
CREATE TABLE #Erros( 
	 seq INT NOT NULL IDENTITY PRIMARY KEY 
	,cod INT NOT NULL DEFAULT 0
	,msg NVARCHAR(MAX) DEFAULT 'Erro Desconhecido' 
);

IF OBJECT_ID('tempdb..#InfoDir') IS NOT NULL
	DROP TABLE #InfoDir;
CREATE TABLE #InfoDir( arquivoExiste BIT,eDiretorio BIT,diretorioPaiExiste BIT );

IF OBJECT_ID('tempdb..#Bancos') IS NOT NULL
	DROP TABLE #Bancos;
CREATE TABLE #Bancos( 
	 cod INT NOT NULL IDENTITY PRIMARY KEY
	,nome NVARCHAR(MAX)
);


-------------------------------------- �REA DE SCRIPTS --------------------------------------------------
/*** �rea de Scripts: os scrips devem ser escritos aqui. ***/

SET NOCOUNT ON;
---------------- VALIDANDO Os par�metros

IF @Porcentagem NOT BETWEEN 0 and 100 OR @Porcentagem IS NULL
	SET @Porcentagem = 10
IF @CopyOnly IS NULL
	SET @CopyOnly = 1;

---------------- MONTANDO A TABELA COM OS BANCOS
--> Verificando a vari�vel que cont�m os bancos!
IF @Bancos IS NULL OR LEN(@Bancos) = 0 BEGIN
	SET @MsgErro = N'Nenhum banco informado.';
	INSERT INTO #Erros(msg) VALUES(@MsgErro);
	GOTO MOSTRA_ERROS;
END

--> O script abaixo ir� varrer a string com os bancos, e para cada banco informado, ir� gerar um INSERT INTO. (Usando Quote pernsonalizado)
SET @DelimE = N'INSERT INTO #Bancos(nome) VALUES(N'+NCHAR(0x27);
SET @DelimD = NCHAR(0x27)+N')';
SET @Separador = N','
SET @SQLTmp = @DelimE+REPLACE(@Bancos,@Separador,@DelimD+N';'+@DelimE)+@DelimD 

INSERT INTO
	#Bancos
EXEC(@SQLTmp)

-- Removendo espa�os indesejados.
UPDATE 
	#Bancos
SET
	nome = RTRIM(LTRIM(nome))
	
----- INTERPRETANDO AS VARI�VEIS

--> $(BANCOS_*)
INSERT INTO
	#Bancos(nome)
SELECT
	d.name
FROM
	sys.databases d
WHERE 
(
	EXISTS (SELECT	* FROM #Bancos WHERE nome = '$[BANCOS_TODOS]')
)	
OR (
	EXISTS (SELECT	* FROM #Bancos WHERE nome = '$[BANCOS_USUARIO]')
	AND
	d.database_id > 4
)
OR (
	EXISTS (SELECT	* FROM #Bancos WHERE nome = '$[BANCOS_SISTEMA]')
	AND
	d.database_id <= 4
)
	
-- Removendo nomes duplicados! 
;WITH BancosTmp AS
(
	SELECT DISTINCT
		 b.cod
		 --> Gera uma sequencia. Bancos com o mesmo nome, ter�o mais do que uma linha, e o valor da coluna ser� maior que 1.
		,ROW_NUMBER() OVER( PARTITION BY b.nome ORDER BY b.cod ) as Rn
	FROM
		#bancos b
)
DELETE FROM #Bancos WHERE cod IN ( SELECT cod FROM BancosTmp WHERE Rn > 1 );

--> Removendo os bancos que devem ser ingorados (o nome come�a com um -)
;WITH BancosIngorados AS
(
	SELECT
		RIGHT(nome,LEN(nome)-1) as NomeBanco --> Remove o '-' para poder usar o nome no WHERE do DELETE abaixo
	FROM
		#Bancos
	WHERE
		Nome like '-%'
)
DELETE FROM #Bancos WHERE Nome IN (SELECT NomeBanco FROM BancosIngorados);

--> Removendo os bancos com nomes de vari�vel
DELETE FROM #Bancos WHERE Nome like '$\[BANCOS_%\]' ESCAPE '\'
DELETE FROM #Bancos WHERE Nome like '-%'

---------------- VALIDANDO O DIRET�RIO DOS LOGS
--> Verificando se o diret�rio informado existe!
IF @Local IS NULL OR LEN(@Local) = 0 BEGIN
	SET @MsgErro = N'A vari�vel @Local � nula ou vazia';
	INSERT INTO #Erros(msg) VALUES(@MsgErro);
	GOTO MOSTRA_ERROS;
END
--> Verificando se existe uma barra no final. Se tiver remove-a
IF RIGHT(@Local,1) in ('\','/')
	SET @Local = LEFT(@Local,LEN(@Local)-1)

SET @SQLTmp = 'EXEC xp_fileexist '+QUOTENAME(@Local,NCHAR(0x27))

INSERT INTO
	#InfoDir
EXEC(@SQLTmp)

SELECT
	@AuxINT = eDiretorio
FROM
	#InfoDir
	
IF @AuxINT = 0 BEGIN --> Diret�rio n�o existe.
	SET @MsgErro = N'O diret�rio '+QUOTENAME(@Local,NCHAR(0x27))+' n�o foi encontrado!';
	INSERT INTO #Erros(msg) VALUES(@MsgErro);
	GOTO MOSTRA_ERROS;
END

---------------- PERCORRENDO A TABELA DE BANCOS, MONTANDO O SCRIPT DE BACKUP, E EXECUTANDO OU PRINTANDO.
SELECT 
  @DataAtual	= GETDATE()
 ,@DataDMA		= CONVERT( VARCHAR(10),@DataAtual,103 )
 ,@DataTempo	= CONVERT( VARCHAR(12),@DataAtual,114 )
 ,@AuxStr		= @DataDMA + ' '+@DataTempo
RAISERROR('Iniciando processo de backup. Data: %s',0,0,@AuxStr) WITH NOWAIT;
RAISERROR('',0,0) WITH NOWAIT;

IF EXISTS(
	SELECT * FROM #Bancos
)
BEGIN --> In�cio do script para percorrer os bancos

	SET @CodBanco = 0;
	
	WHILE EXISTS (
			SELECT * FROM #Bancos WHERE cod > @CodBanco
		) OR @CodBanco = 0
	BEGIN --> Inicio Loop para percorrer os bancos
	
		SELECT TOP 1
			 @CodBanco	= b.cod
			,@NomeBanco	= b.nome
		FROM
			#Bancos b
		WHERE
			cod > @CodBanco
			
		RAISERROR('Banco: %s',0,0,@NomeBanco) WITH NOWAIT;
	
		IF DB_ID(@NomeBanco) IS NULL BEGIN
			SET @AuxStr = QUOTENAME(@NomeBanco,CHAR(0x27))
			RAISERROR('O Banco %s n�o existe',0,0,@AuxStr) WITH NOWAIT;
			GOTO CONTINUAR_LOOP;
		END
		

		IF CAST( DATABASEPROPERTYEX(@NomeBanco,'Recovery') AS VARCHAR(MAX)) = 'SIMPLE' AND @TipoBkp = 'LOG' BEGIN
			SET @AuxStr = QUOTENAME(@NomeBanco,CHAR(0x27))
			RAISERROR('O Banco %s est� no modo SIMPLE.',0,0,@AuxStr) WITH NOWAIT;
			GOTO CONTINUAR_LOOP;
		END
		
		--> Determinando a extens�o do backup
		DECLARE
			@Extensao varchar(100)

		SET @Extensao = CASE @TipoBkp
							WHEN 'LOG' THEN 'trn'
							WHEN 'FULL' THEN 'bak'
						END

		--> Montando o nome do arquivo
		SELECT 
		  @DataAtual	= GETDATE()
		 ,@DataDMA		= CONVERT( VARCHAR(10),@DataAtual,103 )
		 ,@DataTempo	= CONVERT( VARCHAR(5),@DataAtual,114 ) --> utilizei varchar(8) para remover a partr de segundo e mil�simos.
		 ,@NomeArBkp	= @NomeBanco+'_'+@TipoBkp+'_'+REPLACE(@DataDMA,'/','')+'_'+REPLACE(@DataTempo,':','')+'.'+@Extensao;
	
		--> Montando as opcoes WITH
		SET @OpcoesWITH = N''+
			 ISNULL('STATS = '+CONVERT(VARCHAR(3),@Porcentagem),'')
				+
			CASE @CopyOnly WHEN 1 THEN ',COPY_ONLY' ELSE '' END
				+
			CASE @Comprimir WHEN 1 THEN ',COMPRESSION' ELSE '' END
			
		DECLARE
			@BackupType varchar(100)

		SET @BackupType = CASE @TipoBkp
							WHEN 'LOG' THEN 'LOG'
							WHEN 'FULL' THEN 'DATABASE'
						END

		IF @BackupType IS NULL
			SET @BackupType = 'LOG'
		

		SET @SQLTmp = N''+
			'BACKUP '+@BackupType+' '+@NomeBanco
				+
			' TO DISK = '+QUOTENAME(@Local+'\'+@NomeArBkp,CHAR(0x27))
				+
			ISNULL(' WITH '+@OpcoesWITH,'')

		
		--> Verificando as op��es de execu��o
		/*
			Cada bit da vari�vel @ExecOpt reprsenta uma op��o.
			Valores dispo�veis:
				Bit 0 | 00000001 | 0x1
					Imprimir somente	
				Bit 1 | 00000010 | 0x2
					Executar somente
		*/
		IF @ExecOpt & 0x1 > 0	--> Bit 0 ativo
			RAISERROR('%s',0,0,@SQLTmp) WITH NOWAIT;
		IF @ExecOpt & 0x2 > 0	--> Bit 1 ativo
			EXEC(@SQLTmp);
		
	
		CONTINUAR_LOOP: --> Este trecho ir� fazer algumas a��es antes de verificar se existe banco...
		RAISERROR('',0,0) WITH NOWAIT;
	END --> Fim do loop para percorrer os bancos

SELECT 
  @DataAtual	= GETDATE()
 ,@DataDMA		= CONVERT( VARCHAR(10),@DataAtual,103 )
 ,@DataTempo	= CONVERT( VARCHAR(12),@DataAtual,114 )
 ,@AuxStr		= @DataDMA + ' '+@DataTempo
RAISERROR('Processo de backup finalizado. Data: %s',0,0,@AuxStr) WITH NOWAIT;
RAISERROR('',0,0) WITH NOWAIT;
RAISERROR('',0,0) WITH NOWAIT;

END --> Fim do script para percorrer os bancos
	

-------------------------------------- �REA DE TRATAMENTO --------------------------------------------------
MOSTRA_ERROS:
	IF EXISTS(
			SELECT * FROM #Erros
		) 
	BEGIN --> Inicio do script para exibir os erros!
		
		SET @AuxINT = 0 --> Representa a chave prim�ria da tabela de erros!!!!!
		
		WHILE EXISTS( --> Ir� pecorrer a tabela. A cada itera��o passa por um "seq" diferente
				SELECT * FROM #Erros e WHERE e.seq > @AuxINT
			)
			BEGIN --> Incio do loop para exibir cada erro na tabela
			
				SELECT TOP 1
					 @AuxINT	= e.seq
					,@MsgErro	= e.msg
					,@CodErro	= e.cod
				FROM
					#Erros e
				WHERE
					e.seq > @AuxINT
			
				RAISERROR('Cod: %d Erro: %s',16,1,@CodErro,@MsgErro) WITH NOWAIT;
				
			
			END --> Fim do loop para exibir cada erro na tabela
		
	END --> Fim do script para exibir erros!

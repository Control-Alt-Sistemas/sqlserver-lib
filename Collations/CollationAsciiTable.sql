/*#info 
	
	# Autor 
		Rodrigo Ribeiro Gomes 

	# Detalhes 
		Gera um tabela ASCII, mostrando todos os caracteres de 1 a 255 em diveres collations (code pages)
		Este � um script simples para voc� visualizar como o collation afeta o caracter. 
		Pro SQL Server (assim como pra qualquer outro softare), caracter � s� um n�mero.

		Quando o SQL envia o dado pra sua aplica��o, ele pode traduzir esse n�mero em outros, conforme o collationa da coluna.
		Esse script demonstra isso...
		O mesmo valor, em diferentes coluna, v�o ter um s�mbolo diferente (a partir do n�mero 128).
*/

if objecT_id('tempdb..#Collate') is not null
	drop table #collate;
go

CREATE TABLE
	#Collate(code tinyint,bin AS CONVERT(binary(1),code))
;

DECLARE @AddColumn nvarchar(4000),@Update nvarchar(4000);
SET @AddColumn = '';
set @Update = '';

SELECT
	--> Esse jeito de concatena nem sempre funcina ok? Pra pouco registro e algo que n�o � prod eu assumo o risco...
	-- mas se voc� for usar isso em prod, pode n�o ter o efeito desejado!
	-- FOR XML (ou STRING_AGG a partir do 2019) s�o op��es melhores!
	@AddColumn = @AddColumn + 'ALTER TABLE #Collate ADD '+CodePage+' char COLLATE '+NAME+';'
	,@Update = @Update + ','+CodePage+' = bin'
FROM
(
	SELECT  
		NAME
		,CodePage
		,ROW_NUMBER() OVER(PARTITION BY CodePage ORDER BY Name)  [Top]
	FROM
	(
		SELECT
			NAME
			,SUBSTRING(NAME,CPStart+1,CHARINDEX('_',Name,CPStart+1)-CPStart-1) as CodePage
		FROM
		(
			select 
				NAME
				,PATINDEX('%[_]CP%[_]%',NAME) as CPStart
			from 
				fn_helpcollations()
			where
				name like 'SQL_Latin1%'
		) C
	) CINF
) CL
WHERE
	CL.[Top] = 1

exec(@AddColumn)
set @Update = 'UPDATE #Collate SET '+stuff(@Update,1,1,'')

;WITH n AS (
	select top 255
		n = row_number() over(order by (select null))
	from
		sys.all_columns a1,sys.all_columns a2 
)
INSERT INTO
	#Collate(code)
SELECT
	n
FROM
	n
exec(@Update);
declare
	@char sql_Variant
SELECT	
	*
FROM
	#Collate



--select * from fn_helpcollations() where name like '%437%'
--SQL_Latin1_General_CP850_BIN	Latin1-General, binary sort for Unicode Data, SQL Server Sort Order 40 on Code Page 850 for non-Unicode Data


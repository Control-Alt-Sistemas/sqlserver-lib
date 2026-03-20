/*#info
	# author 
		Rodrigo Ribeiro Gomes 

	# Descricao 
		Script de exemplo usando a nova procedure sp_invoke_external_rest_endpoint para consumir a API do Wordpress 
		e popular uma tabela com os posts ou outros dados que possam ser retornados pela API do wordpress.

		Funciona somente no SQL 2025 em diante.
*/

DECLARE
	@PageNum int = 1
	,@url nvarchar(1000)
	,@response nvarchar(max)
	,@ResultCode int
	,@BaseUrl nvarchar(1000) = 'https://thesqltimes.com/blog'
	,@PerPage int = 100
	,@MaxPages int = 200

drop table if exists #posts;
create table #posts (
	 PostId int
	,PostJson json
	,PostTitle nvarchar(1000)
	,PostExcerpt varchar(1000)
	,PostUrl nvarchar(1000)
	,PostContent nvarchar(max)
	
)



WHILE @PageNum <= @MaxPages --> Safe!
BEGIN
	set @url = FORMATMESSAGE('%s/wp-json/wp/v2/posts?_fields=id,title,excerpt,tags,link,content&per_page=%d&page=%d'
		,@BaseUrl
		,@PerPage
		,@PageNum
	)

	-- get content output!
	RAISERROR('Loading posts from page %d',0,1,@PageNum) with nowait;
	declare @PostsJson nvarchar(max)
	exec sp_invoke_external_rest_endpoint @url
		,@response = @response output
		,@method = 'GET'


	
	set @ResultCode = JSON_VALUE(@response,'$.response.status.http.code');
	RAISERROR('	Result code: %d',0,1,@ResultCode) with nowait;

	IF @ResultCode != 200 
		BREAK;
		
	SET @PageNum += 1;

	insert into #posts (PostId,PostTitle,PostExcerpt,PostUrl,PostContent,PostJson)
	select 
		 p.*
	from
		openjson(@response,'$.result') with (
			 id int
			,titulo nvarchar(1000)	'$.title.rendered'
			,resumo nvarchar(1000) '$.excerpt.rendered'
			,link varchar(500)
			,content nvarchar(max) '$.content.rendered'
			,RawPost nvarchar(max) '$' AS JSON 
		) p
END

IF @PageNum > @MaxPages
BEGIN
	print 'Limite de páginas atingido. Verifique se a API tem mais páginas ou se houve algum problema.';
	RETURN;
END

select top 3 * from #posts;
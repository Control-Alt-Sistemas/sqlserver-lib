/*#info

	# Autor
		Rodrigo Ribeiro Gomes 
		
	# Detalhes
		Este script cria uma proc que permite simular um OLEDB , para testes.  
		Este script � �til caso voc� precise debugar o wait_type de OLEDB
		Eu usei muito isso para simular o wait e checar como as informa��es se apresentavam na DMV.  
		Com isso eu pode criar alguns scritps de monitoramento
		
	# Instru��es de uso 
	
		- Voc� vai precisar criar um linked server entre as inst�ncia que queria testar (pode ser para a pr�pria inst�ncia)
		- No servidor remoto (pra onde o linked server aponta), crie a proc abaixo.
		- No servidor de origem (onde voc� vai monitorar as requisi��es), execute a proc via Linked Server:
			EXEC('SlowQ') AT NomeLinkedServer 
		
		- Utilize sys.dm_exec_requests  (ou sp_WhoIsActive) para monitorar a requis��o. Voc� deve ver um wait OLEDB.
*/


-- rodar esta proc via linked server no server de origem
-- com isso, o wait deve ficar em oledb
-- devido ao raiserror with nowait, ele for�a entregar meta...

create or alter proc SlowQ(@wait varchar(100) = '01:00:00')
as
select 
	replicate(convert(Varchar(max),'a'),50000)

raiserror('teste...',0,1) with nowait;

waitfor delay @wait
GO


/*
	Exemplo Linked Server de Teste:
	USE [master]
	GO
	EXEC master.dbo.sp_addlinkedserver @server = N'TEST1', @srvproduct=N'', @provider = 'SQLNCLI', @datasrc = 'Server\Instancia'
	GO
	EXEC master.dbo.sp_serveroption @server=N'TEST1', @optname=N'data access', @optvalue=N'true'
	EXEC master.dbo.sp_serveroption @server=N'TEST1', @optname=N'rpc', @optvalue=N'true'
	EXEC master.dbo.sp_serveroption @server=N'TEST1', @optname=N'rpc out', @optvalue=N'true'
	GO
	
	-- crie um login com permissao de execuat a proc acima
	EXEC master.dbo.sp_addlinkedsrvlogin @rmtsrvname = N'TEST1', @locallogin = NULL , @useself = N'False', @rmtuser = N'NomeUser', @rmtpassword = N'PasswordUser'
	GO

*/
/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Detalhes 
		Colocar um login nas roles do CMS. 
		Cria o usu�rio no msdb, se n�o existe!
*/
DECLARE
	@Login sysname
	,@Role sysname
;

SET @Login = '';
SET @Role = ''; -- ServerGroupReaderRole (Leitura) | ServerGroupAdministratorRole  (Leitura/Cria��o/Modifica��o)


--------------------------------------------------------------------------------------------------

IF SUSER_ID(@Login)	IS NULL
BEGIN
	RAISERROR('Login %s n�o encontrado. Crie usando CREATE LOGIN antes...', 16,1,@Login);
	RETURN;
END

IF @Role NOT IN ('ServerGroupReaderRole','ServerGroupAdministratorRole')
BEGIN
	RAISERROR('Role informada inv�lido: %s. As Roles v�lidas s�o: %s (%s) e %s (%s)', 16,1,@Role,'ServerGroupReaderRole','Leitura','ServerGroupAdministratorRole','Leitura/Cria��o/Modifica��o');
	RETURN;
END

DECLARE
	@User sysname
	,@tsql nvarchar(4000)
;


SELECT @User = DP.name FROM msdb.sys.server_principals SP INNER JOIN msdb.sys.database_principals DP ON DP.sid = SP.sid WHERE SP.name = @Login

IF @User IS NULL
BEGIN
	SET @tsql = 'USE msdb; CREATE USER '+QUOTENAME(@Login)+' FROM LOGIN '+QUOTENAME(@Login)+' ;';
	EXEC(@tsql);
END

EXEC msdb..sp_addrolemember @Role,@Login


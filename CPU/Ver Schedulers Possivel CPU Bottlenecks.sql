/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes

	# Detalhes 
		Olha, essa tamb�m � uma das queries que raramente voc� vai usar...
		MAs � bom ter pelo menos para aparecer na pesquisa e lembrar quando mais nada fizer sentido!

		Geralmente esse gargalo vai aparecer em outras m�tricas...

*/
SELECT
	 scheduler_address
	,scheduler_id
	,runnable_tasks_count
	,current_tasks_count
	,status
	,is_online
	,is_idle
FROM 
	sys.dm_os_schedulers os
WHERE
	scheduler_id < 255 -- Sistema
/* http://technet.microsoft.com/en-us/library/cc966540.aspx */


SELECT * FROM sys.dm_os_schedulers;
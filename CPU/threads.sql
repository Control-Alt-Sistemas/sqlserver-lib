/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes

	# Detalhes 
		Lista informa��es das threads de todas as sess�es!
		Na pr�tica mesmo, raramente voc� vai usar isso no dia a dia como DBA SQL!
		
		Deve ter usado algo nesse n�vel em raros casos quando precisei descobrir qual thread no Windows estava rodando uma sess�o!
		E pra qu� eu prciso disso?
		Poderia ser pra matar a thread pelo process explorer e destravar algo!
		Mas isso � extremamente perigoso dependendo do que voc� est� matando... Muito mais seguro reiniciar o SQL...
		Eu usei isso mais para debugar casos relacionados a linked servers (se n�o me falha a mem�ria)
		MAs, de todo modo, � legal ter isso como cart na manga!
		Nunca se sabe quando voc� vai se perguntar algo desse tipo!
*/
SELECT
	 TH.os_thread_id
	,R.command
	,W.worker_address
	,TH.thread_address
	,T.session_id
	,T.task_address
	,T.task_state
	,W.worker_address
	,W.status
	,W.state
	,W.last_wait_type
	,W.return_code
	,W.tasks_processed_count
	,TH.started_by_sqlservr
	,TH.status
	,TH.instruction_address
FROM
	sys.dm_exec_requests R 
	join
	sys.dm_os_tasks T
		ON T.session_id = R.session_id
		AND T.request_id = R.request_id
	JOIN
	SYS.dm_os_workers W 
		ON W.worker_address = T.worker_address
	JOIN
	sys.dm_os_threads TH
		ON TH.thread_address = W.thread_address
WHERE
	R.session_id <> @@SPID
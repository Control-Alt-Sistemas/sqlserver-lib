/*#info 

	# Autor 
		Rodrigo Ribeiro Gomes

	# Detalhes 
		Este � um simple tests pra moer 1 CPU usa!
		A ideia � muito simples: Fa�a um LOOP decrementando um vari�vel e calcule o tempo que isso levou!
		Voc� pode rodar o mesmo teste em outra instancia, copiando e colando e matendo os mesmos resultados!
		E,c om isso, voc� pode comparar e perceber diferen�as!
		Se o mesmo teste, com o mesmo par�metros, apresentar diferen�as no tempo, voc� sabe que tem algo impactando!
		Esse alg pode ser: carga do ambiente, config de hardware, config o seu So, etc.
		A causa exata � outro trabalho.
		O objetivo desse script � testar e ver se h� diferen�a significativas!

		Eu uso sql dinamico com set nocount, devido a um comportamento do sql.
		Sem isso, a cada loop, ele enviaria uma mensagem ao client, fazendo com o que teste n�o consumissse a cpu devido a espera!
*/
exec sp_Executesql  N'
set nocount on;
declare @start_cpu datetime = getdate();
DECLARE @i bigint = 10000000
while @i > 0 set @i -= 1;
select UsedCPU = datediff(ms,@start_cpu, getdate())
'
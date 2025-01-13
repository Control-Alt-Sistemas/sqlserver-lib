/*
	# Autor 
		Rodrigo Ribeiro Gomes 
		
	# Detalhes 
		Criei script enquanto eu estudava alguns funcionamentos b�sicos de Machine Learnin e redes neurais.
		O objetivo era aplicar os conceitos de gradiente descendente e ver se aprend, de fato assuntos como derivadas, etc.

		Eu tenho algumas ideias futuras em mente onde eu poderia usar isso...
		Por enquanto, � s� um exerc�cio simples...

		LEMBRANDO: 
			Esse Script foi usado em car�ter de teste e estudos por algu�m que est� aprendendo MAchine Learning!
			� muito prov�vel que tenham erros de conceitos... Mas meu objetivo aqui � entener os conceitos fundamentais, usando uma linguagem que sou acostumado...

		
*/

-- Criar um banco de testes, caso n�o queria usar o master atual!!
--CREATE DATABASE IA;
--GO
--USE IA;
--GO

set nocount on;

-- Criar uma tabela com dados de treinamento!
IF OBJECT_ID('dbo.Treinamento') IS NULL
	CREATE TABLE Treinamento (
		x decimal(38,10)
		,y decimal(38,10)
		,y_ decimal(38,10)
		,mse as power(y - y_,2)
	)

-- Inserir os dados de treinamento...
-- 2 vari�veis, bem simples!
truncate table Treinamento;
insert into Treinamento(x,y)
values(2104,399.9),(1600,329.9),(2400,369)


-- Aqui � a tabela que irei usar para guardar os dados do treinamento...
drop table if exists #Epochs;
CREATE TABLE #Epochs(
	 epoch bigint PRIMARY KEY		--> N�mero do epoch
	,totalError decimal(38,10)		--> Total de erro gerado nesse epoch
	,lr decimal(38,10)				--. learning rate  usado 
	,w0 decimal(38,10)				--> valor do peso w0 usado nesse epoch
	,w1 decimal(38,10)				--> valor do peso w1 usado nesse epoch
	,dw0 decimal(38,10)				--> valor da derivada do peso w0
	,dw1 decimal(38,10)				--> valor da derivada do peso w1
	,lr0 decimal(38,10)				--> Resultado do Learning rate de w0
	,lr1 decimal(38,10)				--> Resultado do Learning rate de w1
	,nw0 AS w0 - lr0				--> Novo valor do peso w0 (pra ser usado no proximo epoch)
	,nw1 AS w1 - lr1				--> Novo valor do peso w1 (pra ser usado no proximo epoch)
)

/*
	Redes Neurais s�o basicamente fun��es matem�ticas... f(x) = Ax + B... (lemba disso l� do tempo de escola?)
	Reescrevendo: y = Ax + b.  A e b s�o chaamdos de pesos (ou weights). Por usamos o W como nome... 

	Eu usei esse artigo como base para criar esse script. 
	Eu recomendo que voc� de uma lida, pq ele tem uns exemplos interativos...
	Ent�o, fica mais f�cil entender esse script...
	https://iatalk.ing/conceitos-basicos-de-redes-neurais-um-guia-visual-e-interativo/
	
	Vamos reescrever:
	y = W0*X + W1 (normalmente, nas IAs do mund real, s�o bilh�es de W...)

	A ideia � achar o W0 e W1 que fa�a essa fun��o resultar nos Y que jogamos na nossa tabela Treinamento.
	Ou seja, preciso encontrar a fun��o que, quando eu passo X = ??, resulte em Y = ??... isso para todos os exemplos...
	O treinamento de IA � justamente o processo de ficar mudando W0 e W1 at� que encontremos isso...

	Na vida real, dificilmente vamos achar os valores exatos... Mas podemos achar os valores mais pr�ximos... 
	Como medimos o mais pr�ximo?
		Primeiro, escolhemos ai aleatoriamente um valor para W0 e W1... 
		Depois, para cada linha da tabela Treinamento, eu pego X e calculo usando usando os pesos... Isso vai me da um Y...
		Ent�o eu comparo esse Y que calculei com o Y que est� na tabela...  A diferen�a disso � o que chamamos de erro!

		Quanto menor essa diferen�a (quanto mais pr�ximo de zero), melhor a fun��o com estes pessos foi... 
		Ent�o, se eu somar todas as essa diferen�as calculadas pra cada linha de "Treinametno" o resultado deveria ser o mais pr�ximo de zero poss�vel...
		S� que como o erro pode dar negativo, eu preciso tirar o sinal... Um jeito simples � elevar ao quadrado: Isso � chamado Mean Square Error, ou, erro quadr�tico m�dio.

		Ent�o, em cada intera��o, eu to tentando ajutando W0 e W1 para tentar fazer esse erro chegar o mais pr�ximo de 0.  
		Quanto mais pr�ximo de zero, melhor s�o os valores de W0 e W1 que achei...

		E agora, como eu sei como ajustar W0 e W1?
		� aqui que entra derivadas!
		Com o uso de derivadas, eu consigo calcular o quanto eu tenho que incrementar ou decrementar W0 e W1 para que o erro fique pr�ximo de 0.
		Aqui, voc� teria que ler um pouco de derivadas e gr�ficos para entender como as derivadas conseguem fazer isso...
		Mas pra simplificar, � s� vc imaginar isso: J� tem alguns c�lculos prontos de derivadas que me ajudam a acerta W0 e W1...
		Esse c�lculo retorna um valor gigante... E eu quero usar uma parcela dele... O quanto eu vou usar � controlado pela vari�vel @LearningRate.

		S� que esse ajuste, pode ser pouco demais, ou alto demais... 
		� por isso que ficamos repetindo esse v�rias e v�rias vezes... 

		Cada repeti��o desse � chamada de Epoch...
		Geralmente temos um m�ximo de epochs, pro loop n�o fica a vida inteira tentando achar...
*/


DECLARE
	@epoch bigint					= 0
	,@MaxEpoch bigint				= 100000
	,@LearningRate decimal(38,10)	= 0.0000001
	,@LastError decimal(38,10)		= NULL
	,@CurrentError decimal(38,10)	= NULL

-- Inicializa��o de pesos, nao lembro onde escolhi esses valores iniciais, mas assumi aleatorio...
DECLARE
	@W0 decimal(38,10) = 0.180
	,@W1 decimal(38,10)= 0

-- Nosso loop de epoch...
-- ISso aqui � que pode fritar uma das CPUs seu sql...
WHILE @epoch < @MaxEpoch
BEGIN
	SET @epoch += 1;

	--- Esse trecho comentei de prop�sito... Mas vou explicar a ideia dele:
	--- s� entrar aqui se tem um erro calculado previamente...
	--- Isso � um pequena tentativa que eu criei de criar um "Learning Rate" din�mico!
	--- Comparando os ultimos 2 erros, eu consigo saber se oe rro ta aumentando ou diminuindo...
	--- Assim eu decido melhor o meu learning rate...

	--IF @LastError IS NOT NULL 
	--BEGIN
	--
	--	-- Se o erro t� aumentando, ent�o significa que meu learning rate t� muito alto... 
	--	-- vou reduir um pouco...
	--	IF @CurrentError > @LastError
	--	BEGIN
	--		declare @OldLr varchar(100) = convert(varchar(100),@LearningRate);
	--		set @LearningRate *= 0.01
	--		declare @NewLr varchar(100) = convert(varchar(100),@LearningRate);
	--		RAISERROR('Adjusting LR from %s to %s',0,1, @OldLr,@NewLr) WITH NOWAIT;
	--	END
	--
	--
	--	-- Se meu erro for 5% menor do que o anterior, ent�o eu subi um pouco o learning rate pra tentar acelear isso...
	--	ELSE IF @CurrentError < @LastError
	--	BEGIN
	--		declare @ErrDiff decimal(30,20) = (@LastError - @CurrentError);
	--		declare @ErrDiffPerc decimal(38,10) = @ErrDiff  / @LastError;
	--		declare @ErrDiffStr varchar(100) = convert(varchar,@ErrDiff);
	--		declare @ErrDiffPercStr varchar(100) = convert(varchar,@ErrDiffPerc);
	--
	--		if @ErrDiffPerc < 0.05
	--		begin
	--			set @LearningRate *= 1.01
	--		end
	--
	--		-- RAISERROR('ErrorDiff: %s (%s)',0,1, @ErrDiffStr, @ErrDiffPercStr) WITH NOWAIT;
	--	END
	--
	--end

	-- O LastErro vai est� na ultima linha inserida.
	select top 1
		@LastError = totalError
	from #Epochs order by epoch desc

	-- Aqui � onde eu recalculo os pesos e o erro!
	INSERT INTO 
		#Epochs(epoch,totalError,dw0,dw1,lr,w0,w1,lr0,lr1)
	SELECT
		T.*
		,@LearningRate
		,@W0,@W1
		,lr0 = @LearningRate * dw0

		--> Eu n�o devia fazer isso... PRovavelmente est� faltando alguma normaliza��o... o Learning Rate deveria ser o mesmo pra todos os pesos!
		,lr1 = 0.0001 * dw1 
	FROM
	(
		SELECT
			 epoch = @epoch
			,TotalError = AVG(e.mse)								-- Aqui � o Erro quadr�tico m�dio!
			,dw0 = (-2.00/COUNT(*)) * SUM( x*(y - (w0*x + w1)) )	-- derivada do peso W0 ( 2/n * SOMA() )
			,dw1 = (-2.00/COUNT(*)) * SUM( y - (w0*x + w1) )		-- derivada do peso W1
		FROM
			Treinamento
			cross apply (
				select	--> usando os valores atuais dos pesos (no primeiro loop, isso vem do que inicializamos aleatoriamente)
					w0 = @W0
					,w1 = @W1
			) W
			cross apply (
				--> Aqui � nossa fun��o f(x) = W0*x + W1 (ou: Ax + b).
				-- ao inv�s de chaamr de Y, vamos chamar de PY, apenas para n�o confundir...
				-- Ent�o temos: X = valor de entrada, Y = valor esperado, PY = valor calculado no treinamento.
				-- Nosso objetivo � que Y-PY sejam o mais pr�ximo de 0 poss�vel em cada linha do treinamento.
				select 
					py = w0 * x + w1
			) P	
			cross apply (
				-- Eleva a diferen�a ao quadrado... Isso tira o sinal de negativo..
				-- Poderia ser um asb tb... Mas esse � mais comumente usado e n�o sei ainda o porqu�!
				SELECT 
					mse =  power(Y - P.py, 2)
			) E
	) T

	--> Agora � s� atualizarmos o valor dos pesos W0 e W1, com base na derivada!
	-- A tabela #Epochs j� tem uma calcula calculda que vai usar o valor da derivada para gerar os novos valores...
	select top 1 
		@W0 = nw0
		,@W1 = nw1
		,@CurrentError = totalError
	from #Epochs ORDER BY epoch  DESC




END

select * from #Epochs order by epoch





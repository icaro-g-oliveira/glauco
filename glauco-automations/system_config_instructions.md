
# REGRAS PARA TRABALHO COM ARQUIVOS LISTADOS
- Itens retornados por fs_listar e fs_listar_recursivo SEMPRE devem ser filtrados usando item[:caminho], nunca item[:nome].
- Nem todos os itens possuem :nome, mas todos possuem :caminho.
- Para verificar extensão, use:
    File.extname(item[:caminho]).downcase
- Nunca chame métodos como end_with? em item[:nome].

# REGRAS SOBRE USO DE RESULTADOS (res1, res2, res3...)
- Toda lógica Ruby deve acontecer FORA de guard_exec e guard_condition.
- Dentro de guard_exec e guard_condition, só pode existir UMA ÚNICA CHAMADA de função do módulo ApiAutomacoes.
- Nunca escrever loops, blocos, atribuições, Ruby puro, cálculos ou condições dentro de guard_exec ou guard_condition.
- O fluxo correto é sempre:
    res1 = guard_exec("descrição") { funcao() }
    res2 = guard_exec("descrição") { funcao() }
    res3 = `<ruby puro fora>`
    guard_exec("descrição final") { outra_funcao() }
- Variáveis como res1, res2, res3 só podem ser criadas no nível externo da sequence.
- Nunca usar "arquivos.any?" ou "lista.select" dentro de guard_exec/guard_condition.
- guard_condition só aceita chamadas diretas a funções, nunca expressões Ruby.


## **REGRAS SOBRE ASSINATURAS E ARGUMENTOS DAS FUNÇÕES**

- **Todas as funções do módulo `ApiAutomacoes` devem ser chamadas exatamente como aparecem em “Métodos disponíveis”.**
    
- **Nenhuma função aceita argumentos posicionais.**  
    Sempre use **argumentos nomeados**, no formato:
    
    `funcao(arg1: valor, arg2: valor)`
    
- Se a lista exibe:
    
    `fs_listar(path:)`
    
    o agente **deve sempre** chamar:
    
    `fs_listar(path: algum_valor)`
    
- Exemplos corretos:
    
    `fs_listar(path: res1) fs_listar_recursivo(path: res1) ler_arquivo(caminho_arquivo: "arquivo.pdf") criar_xlsx(caminho_arquivo: "...", folhas_e_conteudo: dados)`
    
- Exemplos proibidos:
    
    `fs_listar(res1) fs_listar_recursivo(res1) ler_arquivo("arquivo.pdf")`
    
- Não altere, omita ou renomeie argumentos.  
    Use sempre os **mesmos nomes exibidos em “Métodos disponíveis”**, com o sufixo `:` quando aplicável.
    
- Quando uma função lista múltiplos argumentos nomeados, todos devem ser passados explicitamente, no formato:
    
    `inserir_conteudo_xlsx(caminho_arquivo: res1, celula: "A1", valor: "teste")`


## **REGRAS SOBRE O RETORNO DE UMA SEQUÊNCIA**

A sequência de automação somente produz um valor de saída quando o último comando executado é um `guard_exec` que invoca uma função do módulo `ApiAutomacoes`.  
Não é necessário usar somente funções de determinada categoria de arquivos na sequencia de execução
Qualquer sequência encerrada com operações de Ruby puro, atribuições, cálculos ou manipulações de variáveis resulta obrigatoriamente em um retorno nulo.

Sempre deve existir, ao final da sequência, um `guard_exec` destinado exclusivamente a devolver o valor calculado ou compilado ao longo da execução. Esse `guard_exec` terminal é o responsável por transportar o resultado externo, garantindo que a sequência produza uma saída utilizável.

É necessário uso da função fs_entregar_resultado(valor:) para entregar algum resultado

## 🚫 **Regra Estrita: Nenhum comando pode ficar fora do bloco `sequence do … end`**

O agente **NUNCA** deve gerar `guard_exec`, atribuições, chamadas de funções, verificações, ou qualquer outro comando Ruby **fora do bloco principal de sequência**.

**A estrutura correta é sempre:**

`sequence do   ...   ... end`

### ✔️ Dentro do `sequence do … end`:

- Todas as ações atômicas
    
- Todos os `guard_condition`
    
- Todos os `guard_exec`
    
- Todas as variáveis (`res1`, `res2`, …)
    
- Qualquer criação de planilha, PDF, arquivo, scrap, navegação etc.
    

### ❌ Nunca permitido fora da sequência:

- `guard_exec(...)`
    
- Verificações condicionais
    
- Chamadas de funções
    
- Comentários operacionais
    
- Passos adicionais depois do `end`
    

### EXEMPLO DE PROIBIÇÃO

Isto está **terminantemente proibido**:

`sequence do   res1 = fs_pasta_atual() end  guard_exec("verificar") do   # ❌ proibido   ... end`

### EXEMPLO CORRETO

`sequence do   res1 = abrir_url(url: "https://...")   res2 = capturar_lista(selector: "ytd-video-renderer")    guard_exec("verificar se há resultados") do     fs_entregar_resultado(       valor: res2,       pedido: "buscar vídeos",       instrucao: "analisar resultados"     )   end end`
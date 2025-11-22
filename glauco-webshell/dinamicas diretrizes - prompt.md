## Abaixo, compreensões que devem ser levadas como fundação da compreensão nas interações com o usuário.

- A função listar_arquivos_em_pasta(caminho_base = '.') recebe um único parâmetro que determina de onde a listagem começa. Se nenhum valor for passado, ela usa ".", que significa a pasta atual. Você pode fornecer qualquer caminho relativo ou absoluto, como "./src", "C:/Users/DEV/Desktop", ou "meus_arquivos/". A função garante que o caminho seja normalizado internamente e, a partir dele, percorre tudo recursivamente, identificando corretamente diretórios e arquivos reais. Em resumo, o parâmetro define o ponto inicial da árvore; a partir dele, toda a estrutura abaixo será descoberta e exibida.

## 🧭 1. AÇÕES WEB (NAVEGADOR)

### 🔗 Navegação
**abrir_url(url)**  
→ Abre o endereço especificado.  
> Internamente usa Browser.setUrl.

**voltar()**  
→ Aciona um “back” no histórico do navegador.

**atualizar()**  
→ Recarrega a página atual (reload).

---

#### 🔍 Busca e Input

**digitar(selector, valor)**  
→ Define o valor de um input e dispara evento "input".  
> Equivale a alguém digitando sem errar.

**pressionar_enter(selector?)**  
→ Envia um KeyDown{Enter} para o elemento-alvo.  
→ Se selector não é informado, tenta usar o campo ativo.

**limpar(selector)**  
→ Zera o valor do campo.

---

### 🖱️ Cliques e Interações

**clicar(selector)**  
→ Clica no elemento.  
> Usado para botões, links, thumbnails, vídeos, tabs, filtros.

**clicar_primeiro(selector)**  
→ Seleciona o primeiro elemento da lista e clica.

**clicar_texto(contem_texto)**  
→ Acha elemento cujo texto *inclui* o termo e clica.

**scroll(quantidade_px)**  
→ Rola verticalmente a página.

**scroll_para_baixo() / scroll_para_cima()**  
→ Ações de rolagem inferidas.

---

### 📄 Leitura de Página / Inspect

**ler_html()**  
→ Captura `document.documentElement.outerHTML`.

**capturar_lista(selector)**  
→ Retorna array de texto/atributos dos matches.

**existe(selector)**  
→ Boolean para saber se algo está presente.

**aguardar(selector, timeout)**  
→ Espera elemento aparecer.

**extrair_links(selector)**  
→ Retorna lista de links `href` (e fallback: innerText).

---

### 🎥 YouTube – Ações Operacionais

**abrir_primeiro_video()**  
Usa heurísticas:  
- ytd-video-renderer  
- #thumbnail img  
- #video-title  
- ytd-rich-grid-media

**abrir_canal()**  
→ clique em `ytd-channel-name a`.

**abrir_resultado_pesquisa_texto(texto)**  
→ encontra resultado cujo título inclui o texto.

**rolar_resultados()**  
→ scroll + reavaliação de miniaturas.

---

## 🗂️ 2. AÇÕES DE SISTEMA DE ARQUIVOS (FS)

### 📁 Estrutura de Pastas

**fs_listar(path)**  
→ Lista tudo na pasta.

**fs_listar_recursivo(path)**  
→ Caminha recursivamente.

**fs_buscar(path, padrao)**  
→ Busca por nome (`*.pdf`, `*contrato*`, etc).

**fs_buscar_contextual(path, termos[])**  
→ Usa nome + preview do conteúdo.  
> Ex.: “documento contendo 2024 + orçamento”.

---

### 📄 Leitura de arquivos

**fs_ler_texto(path)**  
→ Lê `.txt`, `.md`, `.csv`, `.json`, `.rb`, `.html`.

**fs_ler_pdf(path)**  
→ Retorna texto usando Docling.

**fs_ler_planilha(path)**  
→ Lê `.xlsx` / `.ods` como tabela.

**fs_ler_imagem(path)**  
→ Retorna OCR (Tesseract / Python).

---

### ✏️ Escrita e Manipulação

**fs_copiar(origem, destino)**

**fs_mover(origem, destino)**

**fs_deletar(path)**

**fs_criar_pasta(path)**

**fs_criar_arquivo(path, conteudo)**

---

### 🧠 Inferência de Tipo de Arquivo

**fs_inferir_tipo(extensão)**  
→ "pdf", "texto", "planilha", "imagem", "json", etc.

Usado para inferir comportamento automático:  
> “abrir arquivo de contrato” → acha pdf/word.  
> “ler planilha de compras” → .xlsx/.csv.

---

## 🗃️ 3. AÇÕES DE DOCUMENTOS (Word, PDF, Planilha)

### 📄 Word (DOCX)

**docx_novo(modelo:nil)**  
→ Cria um docx do zero ou baseado em modelo.

**docx_escrever(path, texto)**

**docx_inserir_tabela(path, dados[][])**

**docx_salvar(path)**

---

### 🧾 PDF

**pdf_extrair_texto(path)**  
→ Usa python/docling.

**pdf_extrair_paginas(path, intervalo)**

**pdf_salvar_novo(path, conteudo_texto)**

---

### 📊 Planilhas

**xls_ler(path)**  
→ retorna matriz.

**xls_escrever(path, linha, coluna, valor)**

**xls_nova(path)**

**xls_salvar(path)**

---

## 🪟 4. AÇÕES DE WINDOWS (OS)

### 🖥️ Janelas

**win_abrir_exe(path)**  
→ abre programa.

**win_focar_janela(titulo_contém)**  
→ ativa janela existente.

**win_fechar_janela(titulo)**

**win_teclar(tecla)**  
→ envia key event global (“Enter”, “Ctrl+C”).

**win_digitar(texto)**  
→ teclado global.

**win_copiar() / win_colar() / win_recortar()**

---

### 📸 Captura e Tela

**win_screenshot(path)**  
→ captura de tela.

**win_capturar_janela(titulo)**  
→ screenshot específico.

---

### 🖱️ Mouse

**win_mouse_click(x, y)**

**win_mouse_mover(x, y)**

**win_mouse_scroll(px)**

---


### Comandos gerais

**cmd_executar("comando")**

**ps_executar("comando")**

### Exemplos inferíveis:

- listar processos → `tasklist`
- matar processo → `taskkill /IM nome`
- listar pastas → `dir`
- copiar → `copy origem destino`
- mover → `move origem destino`

---

## 🔗 6. AÇÕES DE INTEGRAÇÃO (LLM)

### Operações informacionais

**llm_resumir(texto)**  
**llm_extrair_itens(texto)**  
**llm_classificar(tipo)**  
**llm_gerar_json(modelo)**  

Úteis para pipeline:  
> pdf → extrair → resumir → organizar → salvar.

---

## 🧩 7. Ações Atomizadas (Granulares)

Cada comando acima é **atômico**:  
→ o agente só faz UMA coisa por vez.

Exemplos:

- “clicar no ícone”  
- “rolar mais 500px”  
- “pegar o 3º item da lista”  
- “ler arquivo X”  
- “procurar algo contendo Y”  
- “abrir o primeiro resultado”  

O agente constrói *sequências* agrupando essas ações.

---

## 📌 8. Operações Compostas (Construídas a partir das atômicas)

O agente pode inferir:

- “procurar arquivo do cliente João 2024”  
  → fs_buscar_contextual + fs_inferir_tipo

- “abrir o primeiro vídeo do YouTube”  
  → clicar_primeiro + seletor YouTube

- “baixar, mover e renomear”  
  → download + fs_mover + fs_renomear

- “extrair dados da planilha e montar docx”  
  → xls_ler → llm_reescrever → docx_novo

---

## 🧠 9. Heurísticas de Interpretação Comportamental

- “primeiro” = menor índice da lista.  
- “mais relevante” = heurística: topo da página.  
- “resultado da busca” = Google: `a[jsname="UWckNb"]`.  
- “vídeo” = qualquer estrutura `<ytd-video-renderer>` ou `<ytd-rich-grid-media>`.  
- “documento” = pdf/docx/txt/json conforme inferência.  
- “planilha” = xlsx/csv/ods.  
- “imagem” = png/jpg/jpeg.  
- “clicar no que aparece parecido com…” = buscar por substring no texto.


##  🗂️ 10. AÇÕES DE SISTEMA DE ARQUIVOS (FS) — DOCUMENTAÇÃO COMPLETA
### 📁 fs_pasta_atual()

Retorna o caminho absoluto do diretório atual de execução.

Sem argumentos

Retorno: string com o caminho

Ex.: "C:/Users/DEV/Projetos"

### 📁 fs_listar(path)

Lista arquivos e pastas dentro do diretório informado (não recursivo).

path: string (".", "C:/temp", "./src", etc.)

Retorno: array de hashes:
{ nome: "arquivo.txt", tipo: "file" }

### 📁 fs_listar_recursivo(path)

Lista tudo recursivamente.

### 🔍 fs_buscar(path, padrao)

Busca arquivos por padrão de nome.

padrao: "*.pdf", "*contrato*" etc.

### 🔍 fs_buscar_contextual(path, termos[])

Busca por nome + conteúdo (para arquivos leves).

termos: array de strings

Combina nome OU conteúdo.

### 📄 fs_ler_texto(path)

Lê .txt, .md, .rb, .html, .json, .csv
Retorna string.

### 📄 fs_ler_pdf(path)

Retorna { tipo: :texto, conteudo: "texto do pdf" }.

### 📄 fs_ler_planilha(path)

Lê .xlsx, retorna:
{ tipo: :tabela, conteudo: [[linha1], [linha2], ...] }.

### ✏️ fs_copiar(origem, destino)

Copia arquivo/pasta.

### ✏️ fs_mover(origem, destino)

Move arquivo/pasta.

### ✏️ fs_deletar(path)

Remove arquivo ou diretório.

### 📁 fs_criar_pasta(path)

Cria diretórios recursivamente.

### 📝 fs_criar_arquivo(path, conteudo)

Cria arquivo texto com conteúdo inicial.

### 🧠 fs_inferir_tipo(extensão)

Retorna tipos como “texto”, “pdf”, “planilha”, etc.

## 📊 FUNÇÕES DE PLANILHAS (EXPLICITAMENTE DOCUMENTADAS)

### 📊 criar_xlsx(caminho_arquivo:, folhas_e_conteudo:)

Cria um arquivo .xlsx novo.

Argumentos:

	caminho_arquivo:
	Caminho completo do arquivo:
	"C:/temp/minha.xlsx" ou "#{res1}/nova.xlsx"
	
	folhas_e_conteudo:
	Hash onde:
	
	chave = nome da planilha
	
	valor = matriz (array de arrays) representando linhas e colunas

Formato esperado:
	criar_xlsx(
	  caminho_arquivo: "caminho/arquivo.xlsx",
	  folhas_e_conteudo: {
	    "Folha 1" => [
	      ["Nome", "Idade"],
	      ["João", 30],
	      ["Maria", 25]
	    ]
	  }
	)

Retorno:

	Mensagem de confirmação ou erro tratado.

### ✏️ inserir_conteudo_xlsx(caminho_arquivo:, celula:, valor:)

Insere conteúdo em uma célula específica.

Argumentos:

caminho_arquivo: caminho existente

celula: "A1", "B3", ou "Folha 2!C7"

valor: qualquer valor primitivo

Exemplo:
inserir_conteudo_xlsx(
  caminho_arquivo: "#{res1}/nova.xlsx",
  celula: "A1",
  valor: "Título"
)

### 📦 Exemplos reais de uso (para o LLM seguir)
📘 Criar planilha na pasta atual
sequence do
  res1 = fs_pasta_atual()
  res2 = criar_xlsx(
    caminho_arquivo: "#{res1}/nova_planilha.xlsx",
    folhas_e_conteudo: {
      "Folha 1" => [
        ["Nome", "Valor"],
        ["Item 1", 100],
        ["Item 2", 200]
      ]
    }
  )
end


# 📘 **Compreensão Simples e Completa Sobre Arquivos (Visão Humana e Neutra)**



---

## 📁 1. Arquivos têm um “lugar onde vivem”

Todo arquivo tem um caminho completo, como:

`C:/MeusDocumentos/contrato.docx`

Esse caminho é como o “endereço” do arquivo.  
O agente sempre usa esse caminho para:

- achar o arquivo
    
- abrir
    
- mover
    
- copiar
    
- excluir
    
- ou fazer qualquer ação relacionada
    

---

## 🏷️ 2. Arquivos têm um nome

O nome é só a última parte do caminho:

`contrato.docx`

O agente usa isso para:

- mostrar para o usuário
    
- identificar arquivos
    
- filtrar itens
    

Mas o nome nunca substitui o caminho completo.

---

## 📄 3. Arquivos têm um tipo

O tipo de um arquivo é determinado pela **extensão**, assim como para um usuário humano.

Alguns exemplos:

- `.txt` → texto
    
- `.docx` → documento
    
- `.pdf` → PDF
    
- `.csv` → tabela simples
    
- `.mp3` → áudio
    
- `.png` → imagem
    

Nenhum tipo recebe prioridade.  
O agente trata todos igualmente, apenas escolhendo a função certa dependendo da extensão.

---

## 🔍 4. Como o agente encontra arquivos

Da mesma forma que alguém olha para uma pasta no computador e vê o que tem lá dentro.

O agente usa:

- **fs_listar_diretorio** → vê o que há em uma pasta
    
- **fs_listar_recursivo** → vê tudo, inclusive subpastas
    

E cada item é representado assim:

`{   caminho: "C:/pasta/arquivo.ext",   nome: "arquivo.ext",   tipo: "file"  # ou "dir" }`

Isso significa:

- Ele sabe onde está
    
- Ele sabe o nome
    
- Ele sabe se é arquivo ou pasta
    

Nenhuma suposição adicional é feita.

---

## 📂 5. Como o agente identifica tipos

Assim como uma pessoa vê “.pdf” e entende o que é, o agente faz:

`fs_inferir_tipo(File.extname(item[:caminho]))`

E recebe de volta algo como “texto”, “documento”, “imagem”, “planilha”, “pdf”, etc.

Isso evita que o agente precise adivinhar.

---

## 📖 6. Como o agente lê arquivos

A leitura é feita do jeito mais natural para humanos:

- Arquivos de texto → viram texto
    
- Documentos → retornam texto extraído
    
- Tabelas e planilhas → viram tabelas de linhas e colunas
    
- PDFs → viram texto extraído
    
- Outros arquivos → podem ser lidos conforme sua função específica
    

Não importa qual seja o tipo.  
O agente só escolhe como ler com base na extensão.

---

## 📝 7. Como o agente cria arquivos

Criar arquivos funciona como “salvar” ou “criar novo arquivo” para um usuário:

- Criar arquivos de texto
    
- Criar diretórios
    
- Criar documentos de tipos variados
    
- Criar tabelas ou estruturas organizadas
    

Essa criação é sempre **clara, direta e explícita**, com caminho e conteúdo definidos pelo usuário ou pelo sistema.

---

## 🔄 8. Como o agente manipula arquivos

As operações seguem o entendimento natural que qualquer pessoa já tem:

- **copiar** → fazer uma cópia
    
- **mover** → trocar de lugar
    
- **deletar** → remover
    
- **renomear** → mudar o nome
    
- **criar** → gerar arquivo novo
    
- **listar** → ver o que existe em uma pasta
    

Nenhuma operação envolve adivinhação ou tentativas complexas.

---

## ⚙️ 9. Como o agente verifica se um arquivo existe

Do mesmo modo que alguém abre uma pasta e checa:

1. Ele lista os arquivos
    
2. Compara nomes/extensões
    
3. Confirma se algo corresponde ao que está procurando
    

Isso vale para **qualquer extensão**, sem priorizar nenhuma.

---

## ✔️ 10. Resumo humano

O agente deve pensar sobre arquivos como uma pessoa comum pensa:

> “Um arquivo fica em uma pasta, tem um nome, tem um tipo  
> e eu posso abrir, mover, copiar, listar ou criar ele.”

Nenhum formato é favorito, nenhum é especial.  
Todos são tratados igualmente.


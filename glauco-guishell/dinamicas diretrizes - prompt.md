### Estrutura Chave do YouTube

"ytd-rich-grid-renderer" é o seletor principal que contém toda a exibição do feed na página Home. Ela vem com uma lista de videos, dentro do elemento. Ele possui dois seletores filhos diretos cruciais: o #header, que contém os botões/tags de filtro por categoria, e o #contents, que é o contêiner dos itens de vídeo.

Cada vídeo na lista é representado pelo seletor ytd-rich-item-renderer com um elemento "a" nele contendo o título no atributo aria-label. Para abrir nele, é só clicar no link



---

### 📁 1. Arquivos têm um “lugar onde vivem”

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

### 🏷️ 2. Arquivos têm um nome

O nome é só a última parte do caminho:

`contrato.docx`

O agente usa isso para:

- mostrar para o usuário
    
- identificar arquivos
    
- filtrar itens
    

Mas o nome nunca substitui o caminho completo.

---

### 📄 3. Arquivos têm um tipo

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

### 🔍 4. Como o agente encontra arquivos

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

### 📂 5. Como o agente identifica tipos

Assim como uma pessoa vê “.pdf” e entende o que é, o agente faz:

`fs_inferir_tipo(File.extname(item[:caminho]))`

E recebe de volta algo como “texto”, “documento”, “imagem”, “planilha”, “pdf”, etc.

Isso evita que o agente precise adivinhar.

---

### 📖 6. Como o agente lê arquivos

A leitura é feita do jeito mais natural para humanos:

- Arquivos de texto → viram texto
    
- Documentos → retornam texto extraído
    
- Tabelas e planilhas → viram tabelas de linhas e colunas
    
- PDFs → viram texto extraído
    
- Outros arquivos → podem ser lidos conforme sua função específica
    

Não importa qual seja o tipo.  
O agente só escolhe como ler com base na extensão.

---

### 📝 7. Como o agente cria arquivos

Criar arquivos funciona como “salvar” ou “criar novo arquivo” para um usuário:

- Criar arquivos de texto
    
- Criar diretórios
    
- Criar documentos de tipos variados
    
- Criar tabelas ou estruturas organizadas
    

Essa criação é sempre **clara, direta e explícita**, com caminho e conteúdo definidos pelo usuário ou pelo sistema.

---

### 🔄 8. Como o agente manipula arquivos

As operações seguem o entendimento natural que qualquer pessoa já tem:

- **copiar** → fazer uma cópia
    
- **mover** → trocar de lugar
    
- **deletar** → remover
    
- **renomear** → mudar o nome
    
- **criar** → gerar arquivo novo
    
- **listar** → ver o que existe em uma pasta
    

Nenhuma operação envolve adivinhação ou tentativas complexas.

---

### ⚙️ 9. Como o agente verifica se um arquivo existe

Do mesmo modo que alguém abre uma pasta e checa:

1. Ele lista os arquivos
    
2. Compara nomes/extensões
    
3. Confirma se algo corresponde ao que está procurando
    

Isso vale para **qualquer extensão**, sem priorizar nenhuma.

---

### ✔️ 10. Resumo humano

O agente deve pensar sobre arquivos como uma pessoa comum pensa:

> “Um arquivo fica em uma pasta, tem um nome, tem um tipo  
> e eu posso abrir, mover, copiar, listar ou criar ele.”

Nenhum formato é favorito, nenhum é especial.  
Todos são tratados igualmente.

#### 🗃️ Navegação e Busca em Arquivos

O **FsPastaAtualTool** responde a comandos como "Qual meu diretório atual?".

O **ListarArquivosEmPastaTool** é usado para comandos como "Mostre a estrutura desta pasta" ou "Quais arquivos e pastas estão aqui, em formato de árvore?".

O **FsBuscarTool** e o **FsBuscarContextualTool** são cruciais para a comunicação de busca:

- **Padrões de Planilhas de Escritório:** O usuário solicitará "Buscar todos os **`.xlsx`** de contratos" ou "Encontrar planilhas de **`relatórios de vendas`**" (para busca por termo e conteúdo no **FsBuscarContextualTool**).
    
- **Padrões de Nomes Genéricos:** "Buscar arquivos com **`*fatura*`** no nome" (para o **FsBuscarTool**).
    
- **Padrões de Pastas Comuns:** O **`path`** de busca será frequentemente "Desktop", "**`Área de Trabalho`**", "**`Documentos`**" ou "**`Downloads`**".
    

---

#### 📄 Leitura de Conteúdo

O **LerArquivoTool** é o seletor principal aqui, pois abstrai o tipo de arquivo, respondendo a comandos diretos como "Leia o **`contrato.pdf`**" ou "Abra a planilha **`balanço_final.xlsx`**".

O **FsInferirTipoTool** serve para comunicação de metadados, como "Qual o tipo de arquivo de **`.docx`**?".

---

#### ✏️ Manipulação de Arquivos

O **FsMoverTool** e o **FsCopiarTool** atendem a intenções como:

- **Ações:** "**Mova** o arquivo **`proposta.pdf`** para a pasta **`Projetos/Finalizados`**" ou "**Copie** a planilha **`dados.xlsx`** para o **`Desktop`**".
    

O **FsCriarPastaTool** e o **FsDeletarTool** atendem a comandos como:

- **Pastas:** "Crie a pasta **`Backup_2025`** no diretório atual" ou "Apague a pasta **`Lixos`**".
    

---

#### 📊 Manipulação de Planilhas

O **InserirConteudoXlsxTool** traduz a necessidade de edição:

- **Edição:** "Na planilha **`vendas.xlsx`**, folha **`Janeiro`**, coloque o valor **`500`** na célula **`B10`**"


#### 1. 📅 FsMetadataTool (Data e Tamanho)

Este **seletor** fornece informações cruciais para a auditoria e gestão de documentos administrativos: a data da última modificação e o tamanho do arquivo.

- **Necessidade:** Em escritórios, é comum precisar saber "Quando este contrato foi alterado pela última vez?" ou "Qual o tamanho deste arquivo de _backup_?".
    
- **Seletor:** **`FsMetadataTool`**
    
    - **Função:** Retorna o tamanho do arquivo em bytes (e formato legível) e a data/hora da última modificação para um **`path`** fornecido.
        
    - **Uso:** Essencial para rotinas de arquivamento, _backup_ e verificação de integridade.
        

---

#### 2. 🔀 FsCompararTool (Conteúdo)

Este **seletor** é vital para identificar diferenças entre versões de documentos, como contratos ou relatórios financeiros, sem ter que ler o conteúdo inteiro manualmente.

- **Necessidade:** Comparar rapidamente se o "**`Relatório_Final_v1.xlsx`**" e o "**`Relatório_Final_v2.xlsx`**" são diferentes antes de enviá-los.
    
- **Seletor:** **`FsCompararTool`**
    
    - **Função:** Compara dois arquivos ou diretórios (**`path_a`** e **`path_b`**) e retorna se são idênticos (por hash ou conteúdo). Para arquivos de texto, pode retornar uma descrição das linhas diferentes (funcionalidade de _diff_).
        
    - **Uso:** Verificação de versões e garantia de que os dados (como planilhas) não foram alterados acidentalmente.
        

---

#### 3. 📝 FsAnexarTextoTool (Log e Registro)

Em cenários administrativos, é frequente a necessidade de registrar ações (logs) em um arquivo de texto existente, como um histórico de ações em um projeto.

- **Necessidade:** Adicionar uma linha de **`log`** ou um comentário a um arquivo **`Registro_de_Acoes.txt`** sem sobrescrever o conteúdo anterior.
    
- **Seletor:** **`FsAnexarTextoTool`**
    
    - **Função:** Adiciona o **`conteudo`** fornecido ao final de um arquivo de texto existente no **`path`**, com a opção de incluir um _timestamp_ ou quebra de linha.
        
    - **Uso:** Criação e manutenção de arquivos de log, registros de auditoria ou notas rápidas

## 📅 Metadados e Comparação (Ferramentas Administrativas)

O **FsMetadataTool** é o seletor que retorna metadados vitais de um arquivo, como o **`tamanho_bytes`**, o **`tamanho_legivel`** e as datas de **`data_modificacao`** e **`data_criacao`** para o **`path`** fornecido, essencial para auditoria.

O **FsCompararTool** é o seletor usado para verificar se o **`path_a`** e o **`path_b`** são idênticos, comparando o tamanho e o conteúdo para garantir a integridade ou a equivalência de versões de arquivos.

O **FsAnexarTextoTool** atende à função de registro, adicionando **`conteudo`** ao final de um arquivo de texto no **`path`**, com a opção de incluir um **`timestamp`** para rastreabilidade, sendo útil para a criação de _logs_ ou históricos.s
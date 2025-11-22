require 'json'
require 'ruby_llm'

CORE_DIR = File.expand_path(File.dirname(__FILE__))

# Carrega a biblioteca Java de HNSW (certifique-se que o .jar está na pasta)
begin
  require "#{CORE_DIR}/hnswlib-core-1.1.0.jar"
  require "#{CORE_DIR}/eclipse-collections-10.4.0.jar"
  require "#{CORE_DIR}/eclipse-collections-api-10.4.0.jar"
rescue LoadError
  exit
end

# Importa as classes Java necessárias
java_import 'com.github.jelmerk.knn.hnsw.HnswIndex'
java_import 'com.github.jelmerk.knn.DistanceFunctions'
java_import 'com.github.jelmerk.knn.Item'

## Helper class
  # Define um "Item" que o Java consegue entender
  # O HnswIndex Java precisa de objetos que implementem a interface Item<Id, Vector>
class TextItem
  include com.github.jelmerk.knn.Item

  attr_reader :id, :vector 

  def initialize(id, vector_array)
    # Garante que o ID seja uma String Java pura
    @id = java.lang.String.new(id.to_java_bytes, "UTF-8")
    @vector = vector_array.to_java(:float)
  end

  def version; 0; end

  def dimensions
    @vector.length
  end
  
  # 💡 HOOK CRÍTICO DE SERIALIZAÇÃO JRuby/Java: 
  # Garante que APENAS os campos serializáveis (id e vetor) sejam gravados, 
  # eliminando referências internas do Ruby.
  def writeObject(output)
    output.writeObject(@id)
    output.writeObject(@vector)
  end
end

# Classe de armazenamento vetorial local usando HNSW Java
# Removemos o test_index_functionality e os métodos síncronos para simplificar
# e usar apenas a lógica de produção robusta.
# Classe de armazenamento vetorial local usando HNSW Java
class LocalVectorStore
  
  attr_reader :ready

  def initialize(dim: 2560, max_elements: 10_000, index_path: "java_vector_index.bin", metadata_path: "metadata.json")
    @dim = dim
    @max_elements = max_elements
    @index_path = index_path
    @metadata_path = metadata_path # 💡 Caminho para o arquivo JSON
    
    @metadata = {} # 💡 Hash para metadados (Conteúdo e Fonte)
    @ready = false

    java_file = java.io.File.new(@index_path)

    if java_file.exists?
      load_index(java_file) 
    else
      @index = HnswIndex.newBuilder(@dim, DistanceFunctions::FLOAT_COSINE_DISTANCE, @max_elements)
        .withM(16)
        .withEfConstruction(200)
        .build()
      @ready = true
    end
  end

  def ingest(path_or_file)
    return unless path_or_file && File.exist?(path_or_file)

    files = File.directory?(path_or_file) ? Dir.glob("#{path_or_file}/**/*") : [path_or_file]
    files.select! { |f| File.file?(f) && [".txt", ".md", ".rb"].include?(File.extname(f)) }

    puts "[RAG/Java] ☕ Indexando #{files.length} arquivos..."
    count = 0

    files.each do |file|
      content = File.read(file, encoding: 'UTF-8')
      next if content.strip.empty?

      # --- Separação por Tópicos (##) ---
      raw_sections = content.split(/^## /)
      chunks = []

      preamble = raw_sections.shift
      chunks << preamble.strip unless preamble.nil? || preamble.strip.empty?

      raw_sections.each do |section|
        next if section.strip.empty?
        chunks << "## #{section.strip}"
      end

      chunks.each do |chunk|
        begin
          # Tenta gerar embedding
          emb_response = RubyLLM.embed(chunk,
            model: "qwen/qwen3-embedding-4b-q4_k_m",
            provider: :openai,
            assume_model_exists: true
          )

          # --- VERIFICAÇÃO DE INTEGRIDADE ---
          unless emb_response.respond_to?(:vectors)
            raise "API retornou tipo inesperado (#{emb_response.class}). Verifique a conexão com o LM Studio."
          end

          vector_ruby = emb_response.vectors

          if vector_ruby.nil? || vector_ruby.length != @dim
            raise "API retornou um vetor inválido (tamanho: #{vector_ruby.length}, esperado: #{@dim})."
          end
          # ----------------------------------

          id = java.util.UUID.randomUUID.toString
          # Item agora só armazena ID e vetor
          item = TextItem.new(id, vector_ruby) 

          @index.add(item)
          
          # 💡 Armazena metadados no hash Ruby (FORA do objeto Java)
          @metadata[id] = { content: chunk, source: File.basename(file) }

          count += 1
          print "."

        rescue StandardError => e
          # Tratamento de erro explícito para o usuário
          puts "\n❌ Erro chunk (Falha no Embedding): #{e.message}"
        end
      end
    end

    puts "\n[RAG/Java] ✅ Ingestão concluída. #{count} itens adicionados."
    save_index
  end

  def search(query, limit: 3)
    return [] if @index.size == 0

    query_vec = RubyLLM.embed(query).vectors.to_java(:float)
    results = @index.findNearest(query_vec, limit)

    results.map do |result|
      item_id = result.item.id
      metadata = @metadata[item_id] # 💡 Recupera metadados do hash Ruby

      next unless metadata 
      
      {
        content: metadata[:content],
        source: metadata[:source],
        score: (1.0 - result.distance).round(4)
      }
    end.compact
  end

  private

  # Método de carga (síncrono na inicialização)
  def load_index(java_file)
    puts "[RAG/Java] 📂 Carregando índice (Síncrono)...#{java_file.to_string}"
    
    # 1. Carrega o índice HNSW
    @index = HnswIndex.load(java_file)
    
    # 2. Carrega os Metadados (I/O padrão Ruby/JSON)
    if File.exist?(@metadata_path)
      # Assume-se que o JSON está em UTF-8
      @metadata = JSON.parse(File.read(@metadata_path), symbolize_names: true) 
      puts "[RAG/Java] Metadados carregados com sucesso. (#{@metadata.size} itens)"
    else
      puts "[RAG/Java] Metadados não encontrados. Iniciando com hash vazio."
    end
    
    @ready = true 
    puts "[RAG/Java] Índice carregado com #{@index.size} vetores."
  end

  # O save_index (ASSÍNCRONO para a aplicação) - CRÍTICO PARA JRuby
  def save_index
    puts "[RAG/Java] 💾 Salvando índice em uma thread separada (Daemon, CRÍTICO para JRuby)..."
    @ready = false 

    runnable_code = Proc.new do
      begin
        # 1. Cria o File de forma segura (CRÍTICO para JRuby I/O)
        java_path_string = java.lang.String.new(@index_path.to_java_bytes, "UTF-8")
        java_file = java.io.File.new(java_path_string)

        # 2. Salva o índice HNSW (I/O bloqueante)
        @index.save(java_file)
        
        # 3. Salva metadados como JSON (I/O padrão Ruby)
        File.write(@metadata_path, JSON.pretty_generate(@metadata))

        @ready = true 
        puts "[RAG/Java] ✅ Salvamento concluído."
      rescue => e
        @ready = false 
        puts "\n❌ Erro ao salvar índice/metadados: #{e.class} - #{e.message}"
      end
    end

    java_thread = java.lang.Thread.new(runnable_code)
    java_thread.setDaemon(true) # CRÍTICO: Resolve o IllegalThreadStateException
    java_thread.start

    return true 
  end
  
  def ready?
    @ready
  end
end

class RagSearchTool < RubyLLM::Tool
  description "Busca informações na base de conhecimento carregada."
  param :query, desc: "A pergunta ou tópico"

  def initialize(store)
    @store = store
  end

  def execute(query:)
    hits = @store.search(query)
    return "Nenhuma informação relevante encontrada." if hits.empty?
    hits.map { |h| "[Fonte: #{h[:source]}]\n#{h[:content]}" }.join("\n---\n")
  end
end

class GlaucoPlastic
  attr_reader :chat

  LMS_EXE_PATH     = File.expand_path(File.join(Dir.home, ".lmstudio", "bin", "lms.exe"))
  MODEL_PATH       = File.expand_path("vendor/Qwen3-4B-Instruct-2507-Q4_K_M.gguf", __dir__)
  MODEL_IDENTIFIER = "qwen/qwen3-4b-2507"
  SERVER_PORT      = 1234

  def initialize(system_config_instructions:, knowledge_source: nil)
    puts "[Glauco] 🚀 Inicializando Framework..."

    # Inicializa o contexto de automação (que contém o ApiAutomacoes)
    @automation_context = AutomationContext.new

    start_lmstudio

    setup_llm(
      system_config_instructions: system_config_instructions,
      knowledge_source: knowledge_source
    )
    puts "[LLM] ✅ Glauco pronto."
  end

  def setup_llm(system_config_instructions:, knowledge_source:)
    puts "[LLM] ⚙️ Configurando RubyLLM com LM Studio..."

    wait_for_http_ready(SERVER_PORT)

    RubyLLM.configure do |config|
      config.openai_api_key = "lmstudio-local"
      config.openai_api_base = "http://localhost:1234/v1"
    end

    @chat = RubyLLM::Chat.new(
      model: "local-model",
      provider: :openai,
      assume_model_exists: true
    )
    @chat.with_temperature(0.0)


    # Configuração RAG
    if knowledge_source
      puts "[LLM] 🧠 Gerando embeddings..."
      store = LocalVectorStore.new
      store.ingest(knowledge_source)
      @chat.with_tool(RagSearchTool.new(store))
    end

    puts "[LLM] 📜 Carregando instruções do sistema..."

    begin
        instructions = File.read(system_config_instructions)
    rescue => e
        puts "[LLM] ❌ Erro ao ler system_config_instructions: #{e.class} - #{e.message}"
        instructions = ""
    end

    @chat.with_instructions(instructions)
  end

  def start_lmstudio
    puts "[LMStudio] 🚀 Iniciando LM Studio..."
    unless File.exist?(LMS_EXE_PATH)
      raise "LM Studio não encontrado em #{LMS_EXE_PATH}. Por favor, instale-o primeiro."
    end

    puts "[LMStudio] 🚀 Iniciando LM Studio..."
    $lm_mutex ||= Mutex.new
    $lmstudio_started ||= false
    @lmstudio_ready = false

    Thread.new do
      $lm_mutex.synchronize do
        begin
          if !$lmstudio_started
            $lmstudio_started = true

            lmstudio_home = File.expand_path(File.join(Dir.home, ".lmstudio"))
            template_src  = File.expand_path("vendor/.lmstudio", __dir__)

            unless Dir.exist?(lmstudio_home)
              puts "[LMStudio] 🧱 Local .lmstudio não encontrado. Copiando template..."
              FileUtils.cp_r(template_src, lmstudio_home)
            else
              puts "[LMStudio] ⚙️ Ambiente LM Studio já existente."
            end

            puts "[LMStudio] 🚀 Importando modelo..."
            system(LMS_EXE_PATH, "import", MODEL_PATH, "-y", "--hard-link")

            puts "[LMStudio] 🧩 Carregando modelo..."
            gpu_mode = ENV["LMS_GPU_MODE"] || "max" # padrão configurável
            system(LMS_EXE_PATH,
              "load", MODEL_IDENTIFIER,
              "--gpu", gpu_mode,
              "--identifier", MODEL_IDENTIFIER,
              "--context-length", "8192",
              "-y"
            )

            # realizar carregamento de modelo de embeddings Qwen3-Embedding-4B-Q4_K_M.gguf
            system(LMS_EXE_PATH, "import", File.expand_path("vendor/Qwen3-Embedding-4B-Q4_K_M.gguf", __dir__), "-y", "--hard-link")
            system(LMS_EXE_PATH,
              "load", "qwen/qwen3-embedding-4b-q4_k_m",
              "--gpu", gpu_mode,
              "--identifier", "qwen/qwen3-embedding-4b-q4_k_m",
              "--context-length", "8192",
              "-y"
            )

            puts "[LMStudio] 🔌 Iniciando servidor na porta #{SERVER_PORT}..."
            system(LMS_EXE_PATH, "server", "start", "--port", SERVER_PORT.to_s)

            # Espera a porta estar disponível
            wait_for_http_ready(SERVER_PORT)
            @lmstudio_ready = true
            puts "[LMStudio] ✅ Servidor pronto em http://localhost:#{SERVER_PORT}"
          else
            puts "[LMStudio] ⚙️ Reaproveitando servidor existente."
            wait_for_http_ready(SERVER_PORT)
            @lmstudio_ready = true
          end
        rescue => e
          puts "[LMStudio] ❌ Falha ao iniciar servidor: #{e.class} - #{e.message}"
        end
      end
    end

    # Espera sincronamente até LM Studio estar pronto
    start = Time.now
    until @lmstudio_ready
      sleep 0.2
      raise "Timeout ao aguardar LM Studio" if Time.now - start > 60
    end
  end

  def wait_for_http_ready(port, host: "localhost", timeout: 30)
    puts "[LMStudio] ⏳ Aguardando LM Studio na porta #{port}..."
    start = Time.now
    loop do
      puts "[LMStudio] 🔍 Tentando conectar na porta #{port}..."
      begin
        TCPSocket.new(host, port).close
        puts "[LMStudio] 🔗 Porta #{port} está pronta."
        return true
      rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH
        sleep 0.5
        raise "Timeout ao aguardar LM Studio na porta #{port}" if Time.now - start > timeout
      end
    end
  end

end

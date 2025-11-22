Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

require 'json'
require 'fileutils'
require 'open3'
require 'securerandom'

# Garante que o caminho é ABSOLUTO e não relativo.
AUTOMATOR_BASE_DIR = File.expand_path(File.dirname(__FILE__))
puts "[Glauco-Automator] 🚀 Definindo AUTOMATOR_BASE_DIR: #{AUTOMATOR_BASE_DIR.inspect}"

require_relative '../glauco/glauco-framework'

class AutomationAgent < GlaucoPlastic

  # ===========================================================
  # 🧠 Inicialização do LM Studio 
  # ===========================================================
  def initialize(domain_specific_knowledge: nil,visible: true)

    puts "[Glauco-Automator] 🚀 Configurando Glauco Framework..."
    
    require 'ruby_llm'

    puts "[Glauco-Automator] ⚙️ Configuração inicial..."

    @state = { current_url: nil, last_action: nil, context: {} }
    @lmstudio_ready = false

    puts "[Glauco-Automator] 👁️ Visibilidade da UI: #{@visible.inspect}"
    # Só cria UI se a flag permitir
    start_ui_thread if @visible

    puts "[Glauco-Automator] 🚀 Iniciando LM Studio..."
    start_lmstudio

    puts "[Glauco-Automator] 🚀 Configurando LLM e API..."

    setup_llm(domain_specific_knowledge: domain_specific_knowledge)

  end

  def setup_llm(domain_specific_knowledge: nil)
    require "ruby_llm"

    # ===========================================================
    # 1. CARREGAR MÓDULO
    # ===========================================================

    # ===========================================================
    # 2. INICIALIZAR CHAT
    # ===========================================================
    RubyLLM.configure do |config|
      config.openai_api_key  = "lmstudio-local"
      config.openai_api_base = "http://localhost:1234/v1"
    end

    @chat = RubyLLM::Chat.new(
      model: "qwen/qwen3-4b-2507",
      provider: :openai,
      assume_model_exists: true
    ).with_temperature(0.0)


    @chat
  end

  public
  def interpretar(input_text)
    puts "[Interpreter] input_text: #{input_text.inspect}"

    wait_for_http_ready(SERVER_PORT)

    prompt = <<~PROMPT
      Pedido do usuário:
      "#{input_text}"
    PROMPT

    #puts "[Interpreter] Enviando prompt ao LLM:\n#{prompt}"

    result = ""
    @chat.ask(prompt) { |chunk| result << chunk.content.to_s }
    #puts "[Interpreter] Resposta bruta do LLM:\n#{result}"

    result
  end

end
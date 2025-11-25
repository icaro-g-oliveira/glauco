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
  def initialize
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
  end
  
  def setup_llm(domain_specific_knowledge: nil)
    super(system_config_instructions: File.join(AUTOMATOR_BASE_DIR, "system_config_instructions.md"), domain_specific_knowledge:  domain_specific_knowledge)
  end

end
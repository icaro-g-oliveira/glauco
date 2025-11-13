Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

require 'java'
require './jarlibs/swt.jar'

java_import 'org.eclipse.swt.widgets.Display'
java_import 'org.eclipse.swt.widgets.Shell'
java_import 'org.eclipse.swt.layout.FillLayout'
java_import 'org.eclipse.swt.browser.Browser'
java_import 'org.eclipse.swt.browser.BrowserFunction'
java_import "org.eclipse.swt.browser.LocationAdapter"
java_import 'org.eclipse.swt.widgets.FileDialog'
java_import 'org.eclipse.swt.SWT'
java_import 'java.awt.Toolkit'
java_import 'java.awt.datatransfer.DataFlavor'
java_import 'org.eclipse.swt.dnd.Clipboard'
java_import 'org.eclipse.swt.dnd.TextTransfer'

require 'json'
require 'fileutils'
require 'open3'
require 'securerandom'
 class WebAction
    attr_reader :result, :done

    def initialize
      @done = false
      @result = nil
      @callbacks = []
    end

    def then(&block)
      if @done
        block.call(@result)
      else
        @callbacks << block
      end
      self
    end

    def resolve(value)
      @done = true
      @result = value
      @callbacks.each { |cb| cb.call(value) }
    end

    def wait_load(timeout: 30)
      start = Time.now
      until @done || (Time.now - start) > timeout
        sleep 0.05
      end
      @result
    end
  end


module Agents
  
  class BrowserAutoAgent
    
    attr_accessor :display, :shell, :browser, :state
    
    API_PATH = File.expand_path('api_automacoes.rb', __dir__)
    LMS_EXE_PATH     = File.expand_path(File.join(Dir.home, ".lmstudio", "bin", "lms.exe"))
    MODEL_PATH       = File.expand_path("vendor/Qwen3-4B-Instruct-2507-Q4_K_M.gguf", __dir__)
    MODEL_IDENTIFIER = "qwen/qwen3-4b-2507"
    SERVER_PORT      = 1234

    # ===========================================================
    # 🧠 Inicialização do LM Studio + ambiente gráfico
    # ===========================================================
    def initialize
      require 'ruby_llm'

      @visible = false
      @state = { current_url: nil, last_action: nil, context: {} }
      @lmstudio_ready = false

      start_ui_thread
      start_lmstudio
      setup_llm
    end

    def start_lmstudio
      return if @lmstudio_ready
      puts "[LMStudio] 🚀 Iniciando LM Studio..."
      unless File.exist?(LMS_EXE_PATH)
        raise "LM Studio não encontrado em #{LMS_EXE_PATH}. Por favor, instale-o primeiro."
      end
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
                "--y"
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

    def start_ui_thread
      if defined?(@display) && @display && !@display.isDisposed
        puts "[UI] ⚠️ Display ainda ativo, descartando antes de recriar..."
        @display.async_exec { @shell.dispose rescue nil }
        sleep 0.5
        @display.dispose rescue nil
      end

      puts "[UI] 🚀 Criando nova thread de UI..."

      ready = false

      @ui_thread = Thread.new do
        begin
          @display = Display.new
          @shell   = Shell.new(@display)
          @shell.setLayout(FillLayout.new)
          @browser = Browser.new(@shell, 0)
          @shell.setText("Agente de Automação")
          @shell.setSize(1024, 768)
          @shell.open

          ready = true
          puts "[UI] 🧠 Thread de UI iniciada (#{Thread.current.object_id})"

          while !@shell.disposed?
            @display.sleep unless @display.read_and_dispatch
          end

          puts "[UI] 💥 Loop gráfico finalizado. Encerrando display..."
          @display.dispose rescue nil
        rescue => e
          puts "[UI] ❌ Erro crítico no loop de UI: #{e.class} - #{e.message}"
        end
      end

      # espera a UI estar de pé
      start = Time.now
      until ready && @browser && !@browser.isDisposed
        sleep 0.05
        raise "Timeout ao iniciar UI" if Time.now - start > 10
      end
    end

    
    def ensure_ui_alive
      if @ui_thread.nil? || !@ui_thread.alive?
        puts "[UI] 🧩 Thread de UI encerrada — reiniciando..."
        start_ui_thread
        sleep 0.5 # pequeno atraso para garantir criação do Display
      end

      if @display.nil? || @display.isDisposed
        puts "[UI] 🧩 Display inválido — reiniciando..."
        start_ui_thread
      end
    end

    # ===========================================================
    def run_ui(&block)
      ensure_ui_alive

      if Thread.current == @ui_thread
        # já estamos no thread de UI
        block.call
      else
        # executa o bloco dentro do thread da UI
        done = false
        result = nil
        @display.async_exec do
          begin
            result = block.call
          rescue => e
            puts "[UI] 💥 Erro ao executar no thread de UI: #{e.class} - #{e.message}"
          ensure
            done = true
          end
        end

        # espera execução
        sleep 0.05 until done
        result
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


    # ===========================================================
    # 🧩 setup_llm será adicionado abaixo
    # ===========================================================
    def setup_llm
      require 'ruby_llm'

      return @chat if defined?(@chat) && @chat
      RubyLLM.configure do |config|
        # LM Studio não exige chave, mas o campo é obrigatório
        config.openai_api_key = "lmstudio-local"

        # endpoint local do LM Studio (compatível com OpenAI API)
        config.openai_api_base = "http://localhost:1234/v1"
      end

      @chat = RubyLLM::Chat.new(
        model: "#{MODEL_IDENTIFIER}",
        provider: :openai,
        assume_model_exists: true
        )
        
      @chat.with_temperature(0.0)
      @chat.with_instructions <<~SYS
      Você é um agente de automação que gera código Ruby funcional
      usando apenas as funções do módulo `ApiAutomacoes`.
      Sempre feche corretamente aspas simples e duplas em strings Ruby.
      Nunca misture aspas internas sem escapar.
      Sempre utilize a seguinte estrutura para executar ações de automação:

      Use:
        sequence do
          guard_exec("descrição") { open_url(url: "...") }
          guard_wait(segundos)
          guard_condition("descrição") { condição_com_resultado }
        end

      Exemplo:
      sequence do
        guard_exec("abrir site") { open_url(url: "https://google.com", visible: true) }
        guard_wait(2)
        guard_exec("buscar notebooks") { type(selector: "input[name='q']", value: "notebook") }
        guard_exec("enviar busca") { submit(selector: "form") }
      end
      SYS

      @chat
    end

    # ===========================================================
    # 🧩 Listener para ocultar shell ao fechar
    # ===========================================================
    def attach_close_listener
      listener = org.eclipse.swt.widgets.Listener.impl do
        def handleEvent(event)
          event.doit = false
          event.widget.setVisible(false)
          puts "[Automation] 🚫 Shell ocultado (não destruído)"
        end
      end
      @shell.addListener(SWT::Close, listener)
    end



    def read_html
      run_async do
        @browser.evaluate("return document.documentElement.outerHTML;")
      end
    end

    def evaluate(js, label = nil)
      run_async { @browser.evaluate(js) }
    end

    # ===========================================================
    # ⚙️ Execução segura de UI
    # ===========================================================
    def run_async(&block)
      if @display.nil? || @display.isDisposed
        puts "[run_async] ⚠️ Display inexistente — recriando..."
        @display = Display.new
      end

      if Display.get_current
        block.call
      else
        @display.async_exec(&block)
        @display.wake
      end
    end



    # ===========================================================
    # ♻️ Recarrega API dinâmica
    # ===========================================================
    def ensure_api_loaded(force_reload: true)
      puts "[Loader] ♻️ Recarregando ApiAutomacoes..."

      Object.send(:remove_const, :ApiAutomacoes) if Object.const_defined?(:ApiAutomacoes)
      load API_PATH
      puts "[Loader] ✅ ApiAutomacoes recarregado do disco."
      api_mod = Object.const_get(:ApiAutomacoes)
      inject_guard_modules_into(api_mod)
      self.extend(api_mod)

      puts "[Loader] ✅ Instância estendida com ApiAutomacoes"
    end


    # ===========================================================
    # 🧩 Guards e Sequence
    # ===========================================================

    def inject_guard_modules_into(api_mod)
      api_mod.module_eval do
        # registra WebAction no namespace do módulo
        puts "[GuardModule] Registrando WebAction no módulo ApiAutomacoes"
        const_set(:WebAction, WebAction) unless const_defined?(:WebAction)

        # === Guards ===
        def guard_exec(descricao, &block)
          puts "[Guard] ▶️ #{descricao}"
          begin
            result = instance_eval(&block)
            if result.is_a?(WebAction)
              puts "[Guard] ⏳ Aguardando WebAction..."
              result.wait_load
              result = result.result
            end
            key = descricao.downcase.gsub(/[^a-z0-9\s_-]/i, '').gsub(/\s+/, '_').strip.to_sym
            @context[key] = result
            puts "[Guard] ✅ Sucesso: #{descricao} (armazenado como :#{key})"
            @last_result = result
          rescue => e
            puts "[Guard] 💥 Erro em '#{descricao}': #{e.class} - #{e.message}"
            @last_result = nil
          end
        end


        def guard_wait(segundos)
          puts "[Guard] ⏱️ Aguardando #{segundos}s..."
          sleep(segundos)
        end

        def guard_condition(descricao, &block)
          cond = block.call(@last_result)
          puts "[Guard] ⚙️ Condição '#{descricao}' → #{cond.inspect}"
          cond ? @last_result : nil
        end

        def sequence(&block)
          puts "[Sequence] 🚀 Iniciando sequência..."
          @last_result = nil
          instance_eval(&block)
          puts "[Sequence] 🏁 Finalizado com resultado: #{@last_result.inspect}"
          @last_result
        end
      end
    end

    # ===========================================================
    # 🧠 Interpretação e execução
    # ===========================================================
    def funcoes_disponiveis
      ensure_api_loaded
      api_mod = Object.const_get(:ApiAutomacoes)

      api_mod.instance_methods(false).map do |m|
        {
          nome: m,
          args: api_mod.instance_method(m).parameters.map(&:last)
        }
      end
    end

    def interpretar(input_text)
      puts "[Interpreter] input_text: #{input_text.inspect}"
      llm = setup_llm

      wait_for_http_ready(SERVER_PORT)
      
      extra_prompt_path = File.expand_path("dinamicas diretrizes - prompt.md", __dir__)
      extra_prompt = File.exist?(extra_prompt_path) ? File.read(extra_prompt_path, encoding: "UTF-8") : ""

      lista_funcoes = funcoes_disponiveis.map do |f|
        args_sig = f[:args].map { |a| "#{a}:" }.join(", ")
        "#{f[:nome]}(#{args_sig})"
      end.join("\n")

      symbolic_summary = if @context&.any?
        @context.map { |k, v| "- #{k}: #{v.class}" }.join("\n")
      else
        "(sem contexto simbólico ainda)"
      end

      prompt = <<~PROMPT
        Você é um agente Ruby de automação.
        Use apenas funções do módulo `ApiAutomacoes` e estruturas `sequence do ... end`.

        Use variáveis locais (`res1`, `res2`, etc.) para armazenar resultados e reutilizá-los.
        Você pode acessar valores anteriores via:
          recall_context("parte do texto da descrição anterior")

        Estrutura esperada:
        sequence do
          res1 = guard_exec("descrição 1") { open_url(url: "...") }
          guard_wait(3)
          res2 = guard_exec("descrição 2") { type(selector: "...", value: "algo") }
          guard_exec("descrição 3") { hotkey(selector: "...", key: "Enter") }
        end


        Pedido do usuário:
        "#{input_text}"

        Métodos disponíveis:
        #{lista_funcoes}

        Contexto simbólico:
        #{symbolic_summary}


        #{extra_prompt.empty? ? "" : "\n---\n# Instruções adicionais do sistema\n" + extra_prompt + "\n---\n"}
      PROMPT

      #puts "[Interpreter] Enviando prompt ao LLM:\n#{prompt}"

      result = ""
      setup_llm.ask(prompt) { |chunk| result << chunk.content.to_s }
      #puts "[Interpreter] Resposta bruta do LLM:\n#{result}"

      result.strip.gsub(/^```ruby|```$/, "").strip
    end

    def executar(input_text)
      ensure_api_loaded
      code_line = interpretar(input_text)

      return puts "[Executor] ❌ Nenhum comando interpretado." if code_line.nil? || code_line.strip.empty?
      puts "[Executor] 💬 Interpretação limpa:\n#{code_line}"

      begin
        puts "[Executor] 🔍 Executando sequência:"
        @context ||= {}

        result = instance_eval(code_line)

        puts "[Executor] ✅ Execução concluída."
        result
      rescue => e
        puts "[Executor] 💥 Erro: #{e.class} - #{e.message}"
        nil
      end
    end


  end
end

module Frontend
  $callbacks = {}
  def browserFunctionFac(callback_name)
    Class.new(Java::OrgEclipseSwtBrowser::BrowserFunction) do
      define_method(:function) do |*args|
        begin
          arg = args.first
          arg = arg[0] if arg.is_a?(Java::JavaLang::Object[]) && arg.size == 1
          puts "#{callback_name} called with #{arg.inspect}"
          $callbacks[callback_name].call(arg)
        rescue => e
          puts "Error in callback #{callback_name}: #{e.class} - #{e.message}"
        end
      end
    end.new($browser, callback_name)
  end

  def getClipBoardText
    java.awt.Toolkit.getDefaultToolkit.getspawnClipboard.getData(
      java.awt.datatransfer.DataFlavor.stringFlavor
    )
  end

  class RootRenderer
    attr_accessor :browser, :callbacks, :root_component

    def initialize(browser)
      @browser = browser
    end
    
    def bind_callback(event, proc_obj)
      callback_name = "callback_#{rand(1000..9999)}"
      $callbacks[callback_name] = proc_obj
      if @browser
        browserFunctionFac(callback_name)
      end

      # Retorna o atributo HTML correto
      "#{event.to_s.gsub('_', '')}=\"#{callback_name}(this.value)\""
    end
    def render
      puts "calling render"
      return unless @root_component
      puts "passed root_component condition"
      puts "now will call browser.set_text"
      @browser.set_text(@root_component.render_to_html)
    end

    def update_dom(placeholder_id, new_html)
      # garanta string
      html_str = new_html.is_a?(String) ? new_html : Array(new_html).join
      puts "updated dom #{placeholder_id}"
      puts "html_str: #{html_str}"
      js = <<~JS
        (function(){
          var el = document.getElementById("#{placeholder_id}");
          if (el) {
            el.innerHTML = #{html_str.to_json};
          }
        })();
      JS
      @browser.evaluate(js)
    end
  end

  private
  public
  class Component
    attr_accessor :state, :children, :parent_renderer, :attrs

    def initialize(parent_renderer: nil, **attrs)
      puts "initilizing component"
      @state = {}
      @bindings = []
      @children = []
      @parent_renderer = parent_renderer
      @event_listeners = {}
      @attrs = self.class.default_attrs.merge(attrs)
    end

    undef select

    class << self
      def attrs(defaults = {})
        @default_attrs = defaults
        self
      end

      def default_attrs
        @default_attrs || {}
      end
    end

    def add_event_listener(event_name, &callback)
      callback_name = "callback_#{$callbacks.length+1}"
      $callbacks[callback_name] = callback
      if @parent_renderer&.browser
        browserFunctionFac(callback_name)
      end
    end
        
    
    # Define o método _ que inicializa um StatePath a partir de Symbol
    class Symbol
      def >(other)
        sp = StatePath.new(self)
        sp.append_part(other)
      end
    end

    # Classe StatePath
    class StatePath
      def initialize(base)
        @parts = [base.to_s]
      end

      def [](key)
        @parts << key.to_s
        self
      end

      def to_s
        first, *rest = @parts
        rest.reduce(first) { |acc, part| "#{acc}[#{part}]" }
      end
    end


    # --- Bindings avançados ---
    def bind(state_key, node, &block)
      # garante que sempre temos um StatePath
      puts "binding #{state_key} to node #{node}"
      state_path = state_key.is_a?(StatePath) ? state_key : StatePath.new(state_key)

      path_str = state_path.to_s
      puts "path_str: #{path_str}"

      # injeta data-bind no HTML
      node = node.sub(/<(\w+)([^>]*)>/, "<\\1\\2 data-bind=\"#{path_str}\">")
      puts "node after data-bind injection: #{node}"

      # registra o binding
      @bindings << { path: state_path, key: path_str, block: block }
      puts "registered bindings: #{@bindings}"

      # busca valor atual
      value = dig_state_path(state_path)
      puts "current value for #{path_str}: #{value.inspect}"

      begin
        puts "current value for #{path_str}: #{value.inspect}"
        result = block.call(value)

        inner_html =
          case result
          when Array
            result.map { |r| r.is_a?(Component) ? r.render_to_html : r.to_s }.join
          when Component
            result.render_to_html
          else
            result.to_s
          end
      rescue => e
        puts "⚠️ Erro ao executar binding para #{path_str}: #{e.class} - #{e.message}"
        inner_html = ""
      end

      puts "inner_html: #{inner_html}"
      node = node.sub(%r{</\w+>}, inner_html + '\0')
      puts "node after inner_html injection: #{node}"

      node
    end

    def dig_state_path(state_path)
      puts "dig_state_path called with #{state_path}"
      parts = state_path.to_s.scan(/([^\[\]]+)/).flatten
      parts.reduce(@state) do |obj, key|
        break nil if obj.nil?

        if obj.is_a?(Array)
          puts "Accessing array with key #{key}"
          idx = key.to_i rescue nil
          break nil if idx.nil?
          obj[idx]
        elsif obj.is_a?(Hash)
          puts "Accessing hash with key #{key}"
          key_sym = key.to_sym
          if obj.key?(key_sym)
            puts "Found key #{key_sym} in hash"
            obj[key_sym]
          elsif obj.key?(key)
            puts "Found key #{key} in hash"
            obj[key]
          else
            nil
          end
        else
          nil
        end
      end
    end


    # --- Atualização de estado com paths complexos ---
    def set_state(path, new_value)
      path_str = path.is_a?(StatePath) ? path.to_s : path.to_s
      puts "set_state called with path #{path_str} and value #{new_value.inspect}"

      parts = path_str.split(/[:\[\]]/).reject(&:empty?)
      last_key = parts.pop
      target = parts.reduce(@state) do |obj, key|
        if obj[key.to_sym].nil?
          obj[key.to_sym] = {}
        end
        obj[key.to_sym]
      end

      target[last_key.to_sym] = new_value

      notify_bindings(path)
    end

    # --- Notificação de bindings ---
    def notify_bindings(path)
      path_str = path.is_a?(StatePath) ? path.to_s : path.to_s
      puts "notify_bindings called for path #{path_str}"

      @bindings.each do |binding|
        binding_path_str = binding[:path].to_s

        # verifica se binding é afetado: match exato ou prefixo
        if path_str == binding_path_str || binding_path_str.start_with?("#{path_str}:") || binding_path_str.start_with?("#{path_str}[")
          value = dig_state_path(binding[:path])
          puts "Binding found for #{binding_path_str}, updating DOM with value: #{value.inspect}"

          begin
            puts "Calling binding block for #{binding_path_str} with value #{value.inspect}"
            result = binding[:block].call(value)
            puts "Binding block result for #{binding_path_str}: #{result.to_s}"

            # Garante que sempre teremos string
            inner_html =
              case result
              when Array
                result.map { |r| r.is_a?(Component) ? r.render_to_html : r.to_s }.join
              when Component
                result.render_to_html
              else
                result.to_s
              end
          rescue => e
            puts "⚠️ Erro ao renderizar binding #{binding_path_str}: #{e.class} - #{e.message}"
            inner_html = ""
          end

          # puts "Generated inner_html for #{binding_path_str}: #{inner_html.inspect}"

          js = <<~JS
            (() => {
              const el = document.querySelector('[data-bind="#{binding_path_str}"]');
              if (el) el.innerHTML = #{inner_html.to_json};
            })();
          JS

          res = @parent_renderer.browser.execute(js)

          puts "DOM updated for binding #{binding_path_str}"
        end
      end
      path_str
    end



    public
    def add_child(comp)
      comp.parent_renderer = self.parent_renderer
      puts "comp.inspect: #{comp.inspect}"
      @children << comp
    end

    def method_missing(method_name, *args, **kwargs, &block)
      tag(method_name, *args, **kwargs, &block)
    end

    def respond_to_missing?(method_name, include_private = false)
      true
    end

    def tag(name, *args, **attrs, &block)
      puts "tag called with name #{name}, args #{args.inspect}, attrs #{attrs.inspect}"
      content_or_attrs = args.first

      inner_content = if block
        result = instance_eval(&block)

        # Normaliza para array
        components = result.is_a?(Array) ? result : [result]

        # Adiciona cada filho e renderiza
        components.map do |c|
          add_child(c) if c.is_a?(Component)
          c.is_a?(Component) ? c.render_to_html : c.to_s
        end.join
      else
        content_or_attrs.is_a?(Component ) ? content_or_attrs.render_to_html : content_or_attrs.to_s
      end

      html_attrs = attrs.map do |k, v|
        if k.to_s.start_with?("on") && v.is_a?(Proc)
          @parent_renderer.bind_callback(k, v)
        else
          "#{k}=\"#{v}\""
        end
      end.join(" ")

      @event_listeners.each do |event, proc_obj|
        html_attrs += " #{add_event_listener(event, &proc_obj)}"
      end

      @attrs.each do |k, v|
        html_attrs += "#{k}=\"#{v}\""
      end

      res = "<#{name} #{html_attrs}>#{inner_content}</#{name}>"

      # puts "Generated HTML for tag #{name}: #{res}"
      res
    end

    def p(*args, **attrs, &block)
      tag(:p, *args, **attrs, &block)
    end

    def render_to_html
      return "" unless @render_block
      instance_eval(&@render_block).to_s
    end


    def ui(&block)
      @render_block = block
    end

    def define_render(&block)
      @render_block = block
    end

    def render
      instance_eval(&@render_block)
    end

    def run_js(js_code)
      @parent_renderer.browser.evaluate(js_code)
    end

    def rerender
      puts "called"
      @parent_renderer.render
    end
  end

  def +(other)
    self.render_to_html + (other.is_a?(Component) ? other.render_to_html : other.to_s)
  end
end

$display = Display.new
$shell = Shell.new($display)
$shell.setLayout(FillLayout.new)
$browser = Browser.new($shell, 0)
$root = Frontend::RootRenderer.new($browser)

def async(&block)
  $display.async_exec do
    block.call
  end
end

at_exit do
  # Event loop
  while !$shell.disposed?
    $display.sleep unless $display.read_and_dispatch
  end
  $display.dispose  
end
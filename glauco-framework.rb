require 'java'
require './jarlibs/swt.jar'

# SWT imports
java_import 'org.eclipse.swt.widgets.Display'
java_import 'org.eclipse.swt.widgets.Shell'
java_import 'org.eclipse.swt.layout.FillLayout'
java_import 'org.eclipse.swt.browser.Browser'
java_import 'org.eclipse.swt.browser.BrowserFunction'
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

require "observer"


MODEL_ROOT_FOLDER = "vendor"
MODEL_OPTIONS = [
  {
    file: File.join(MODEL_ROOT_FOLDER, "gemma-3n-E4B-it-Q4_K_M.gguf"),
    identifier: "gemma3n",
  }
]


module LMSLLM
  NODE_PATH = "vendor/nodejs/node.exe"
  NODE_SCRIPT_PATH = "./lmstudio_node_script.js"

  LMS_EXE_PATH = File.join(ENV['USERPROFILE'] || ENV['HOME'], ".lmstudio", "bin", "lms.exe")
  LMSTUDIO_EXE = "vendor\\LM Studio\\LM Studio.exe"
  MODEL_PATH = MODEL_OPTIONS[0][:file]
  MODEL_IDENTIFIER = MODEL_OPTIONS[0][:identifier]
  SERVER_PORT = "1234"

  class << self

    
    @tools = []
    @node_process = nil
    @reader_thread = nil

    @node_ready = false
    @node_ready_mutex = Mutex.new
    @node_ready_cond = ConditionVariable.new

    def tools
      @tools ||= []
    end
    def register_tool(name:, docstring:, params:, &impl)
      tool_name = name.to_s
      tool_params = params

      
    # Armazena metadados para gerar JS
      tools << {
        name: tool_name,
        docstring: docstring,
        params: tool_params
      }

      self.singleton_class.send(:define_method, "#{tool_name}_impl") do |args, impl_block = impl|
        tool_params.each_key do |k|
          raise ArgumentError, "Missing argument: #{k}" unless args.key?(k.to_s)
        end
        impl_block.call(args)
      end
    end


    def init_llm!
      @node_ready_mutex ||= Mutex.new
      @node_ready_cond ||= ConditionVariable.new
      prepare_lmstudio
      generate_node_script
      start_node_process
      start_reader_thread
    end



    # Envia prompt para Node (se precisar)
    def act(prompt)
      puts 'chegou '+prompt
      raise "Node process not started" unless @stdin
      sanitized_prompt = sanitize_prompt(prompt)
      final_message = nil
      call_id = SecureRandom.uuid

      mutex = Mutex.new
      cond  = ConditionVariable.new

      # Listener temporário
      handler = Proc.new do |msg|
        if msg['type'] == 'act_message'
          # Podemos filtrar apenas mensagens do assistente
          final_message = msg['message']
        elsif msg['type'] == 'act_response'
          # Node sinaliza que o act terminou
          mutex.synchronize { cond.signal }
        end
      end

      @temp_handlers ||= []
      @temp_handlers << handler

      cmd = { type: "act", prompt: sanitized_prompt, call_id: call_id }
      puts "[Ruby DEBUG] Sending ACT command to Node: #{cmd}"
      @stdin.puts(cmd.to_json)
      @stdin.flush

      # Espera Node finalizar
      mutex.synchronize { cond.wait(mutex) }

      @temp_handlers.delete(handler)

      # Retorna a última mensagem do assistente
      final_message
    end


    private
    def sanitize_prompt(prompt)
      # garante UTF-8 válido
      prompt = prompt.encode('UTF-8', invalid: :replace, undef: :replace, replace: '?')
      # opcional: remove ou substitui caracteres de controle que podem quebrar JSON
      prompt.gsub(/[\u0000-\u001F]/, '')
    end

    # Fecha Node
    public
    def stop!
      if @node_process
        begin
          @node_process.puts({ type: "shutdown" }.to_json) # opcional, se você implementar shutdown no Node
          @node_process.flush
        rescue IOError
          # ignora erros se o processo já morreu
        end
      end

      @reader_thread&.join
      @stdin&.close
      @stdout_and_stderr&.close
      @wait_thr&.kill
    end

    private
    # Checa e inicializa LM Studio, importa e carrega modelo
    def prepare_lmstudio
      unless File.exist?(LMS_EXE_PATH)
        puts "Starting LM Studio headless..."
        system("#{LMSTUDIO_EXE} --headless")
      end

      puts "Importing model..."
      system("#{LMS_EXE_PATH} import #{MODEL_PATH} -y --hard-link")
      puts "Loading model..."
      system("#{LMS_EXE_PATH} load #{MODEL_IDENTIFIER} -y --identifier #{MODEL_IDENTIFIER}")
      puts "Starting LM Studio server..."
      spawn(LMS_EXE_PATH, "server", "start", "--port", SERVER_PORT, out: $stdout, err: $stderr)
      sleep 3 # aguarda servidor iniciar
    end

    private
    # Cria script Node.js com bind das funções Ruby
    def generate_node_script
      puts "generate_node_script"
      FileUtils.mkdir_p(File.dirname(NODE_SCRIPT_PATH))
      puts NODE_SCRIPT_PATH

      puts tools
      
      js_tools_code = tools.map do |t|
          params_schema = t[:params].map { |k,v| "#{k}: z.#{v}()" }.join(", ")

          <<~JS
            const #{t[:name]} = tool({
              name: "#{t[:name]}",
              description: "#{t[:docstring]}",
              parameters: { #{params_schema} },
              implementation: async ({ #{t[:params].keys.join(", ")} }) => {
                const callId = crypto.randomUUID();
                process.stdout.write(JSON.stringify({
                  type: "tool_call",
                  tool: "#{t[:name]}",
                  args: { #{t[:params].keys.join(", ")} },
                  call_id: callId
                }) + "\\n");

                return new Promise(resolve => {
                  const listener = (data) => {
                    try {
                      const msg = JSON.parse(data.toString());
                      if (msg.type === "tool_response" && msg.call_id === callId) {
                        resolve(msg.result);
                        process.stdin.off("data", listener); // remove listener após resposta
                      }
                    } catch(e) {}
                  };
                  process.stdin.on("data", listener);
                });
              }
            });
          JS
      end.join("\n")
      
      node_script = <<~JS
        import { LMStudioClient, tool } from "@lmstudio/sdk";
        import { z } from "zod";
        import crypto from "crypto";
        import readline from "readline";

        const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
        const client = new LMStudioClient();
        const model = await client.llm.model("#{MODEL_IDENTIFIER}");

        
        #{js_tools_code}
        // Indica ao Ruby que Node está pronto
        console.log(JSON.stringify({ type: "node_ready" }));

        rl.on("line", async (line) => {
          try {
            const cmd = JSON.parse(line);
            if (cmd.type === "act") {
              const result = await model.act(cmd.prompt, [#{tools.map { |t| t[:name] }.join(", ")}], {
                onMessage: (msg) => {
                  console.log(JSON.stringify({ type: "act_message", message: msg.toString() }));
                }
              });
              console.log(JSON.stringify({ type: "act_response", result }));
            }
          } catch(e) {
            console.error(JSON.stringify({ type: "act_error", error: `${e.message}: ${line}` }));
          }
        });
      JS
      puts "written"
      File.write(NODE_SCRIPT_PATH, node_script)
    end

    private
    def start_node_process
      @stdin, @stdout_and_stderr, @wait_thr = Open3.popen2e(LMSLLM::NODE_PATH, LMSLLM::NODE_SCRIPT_PATH)
      puts "Node started, PID: #{@wait_thr.pid}"
    end

    
    # Thread para ler respostas Node → Ruby
    private
    def start_reader_thread
      @reader_thread = Thread.new do
        loop do
          line = @stdout_and_stderr.gets
          break if line.nil?

          begin
            msg = JSON.parse(line.chomp)
            @temp_handlers&.each { |h| h.call(msg) }

            case msg['type']
            when 'tool_call'
              tool_name = msg['tool']
              args = msg['args']
              call_id = msg['call_id']
              puts "[Ruby DEBUG] Tool call received: #{tool_name} with args: #{args}"
              result = send("#{tool_name}_impl", args)
              response = { type: 'tool_response', call_id: call_id, result: result }
              @stdin.puts(response.to_json)
              @stdin.flush
            when 'act_message'
              puts "[Ruby DEBUG] LLM message: #{msg['message']}"
            when "act_response"
              puts "[Ruby DEBUG] ACT finished: #{msg["result"].inspect}"
              @node_ready_mutex.synchronize do
                @pending_act_result = msg["result"]
                @pending_act_cond&.signal
              end
            when 'act_error'
              puts "[Ruby DEBUG] ACT error from Node: #{msg['error']}"
            when 'node_ready'
              puts "[Ruby DEBUG] Node ready handshake received"
              @node_ready_mutex.synchronize do
                @node_ready = true
                @node_ready_cond.signal
              end
            else
              puts "[Ruby DEBUG] Unknown JSON from Node: #{msg}"
            end
          rescue JSON::ParserError
            puts "[Ruby DEBUG] Non-JSON output from Node: #{line}"
          rescue StandardError => e
            puts "[Ruby DEBUG] Tool execution error: #{e.message}"
          end
        end
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
          puts callback_name+" called with args "+ args.to_a[0].to_s
          $callbacks[callback_name].call(args.to_a[0])
        rescue => e
          puts "Error in callback #{callback_name}: #{e.class} - #{e.message}"
        end 
      end
    end.new($browser, callback_name)
  end

  def getClipBoardText
    java.awt.Toolkit.getDefaultToolkit.getSystemClipboard.getData(
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
        inner_html = Array(block.call(value)).join
      rescue => e
        puts "⚠️ Erro ao executar binding para #{path_str}: #{e.class} - #{e.message}"
        inner_html = ""
      end

      puts "inner_html: #{inner_html}"
      node = node.sub(%r{</\w+>}, inner_html + '\0')
      puts "node after inner_html injection: #{node}"

      node
    end

    # --- Navegação de paths complexos ---
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
          # obj não é Array nem Hash, não dá pra descer mais
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
                result.map(&:to_s).join
              else
                result.to_s
              end
          rescue => e
            puts "⚠️ Erro ao renderizar binding #{binding_path_str}: #{e.class} - #{e.message}"
            inner_html = ""
          end

          puts "Generated inner_html for #{binding_path_str}: #{inner_html.inspect}"

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
        add_child(result) if result.is_a?(Component)
        result.is_a?(Component) ? "" : result.to_s
      else
        content_or_attrs.is_a?(Component) ? (add_child(content_or_attrs); "") : content_or_attrs.to_s

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

      puts "Generated HTML for tag #{name}: #{res}"
      res
    end

    def render_to_html
      return "" unless @render_block
      puts "render_to_html called : #{@render_block}"

      content = instance_eval(&@render_block)
      add_child(content) if content.is_a?(Component)

      children_html = children.map(&:render_to_html).join
      content_html = content.is_a?(Component) ? "" : content.to_s
      puts "content_html: #{content_html}"
      "<div>#{content_html}#{children_html}</div>"
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
  LMSLLM.stop!
  $display.dispose  
end

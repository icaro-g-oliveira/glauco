
$callbacks = {}
$browser_functions = {}

class RootRenderer
  attr_accessor :browser, :callbacks, :root_component

  def initialize(browser)
    @browser = browser
  end

  def bind_callback(event, proc_obj)
    callback_name = "callback_#{rand(1000..9999)}"
    $callbacks[callback_name] = proc_obj

    puts event, callback_name, proc_obj

    if @browser
      puts "esta passando por aqui pelo menos?"
      
      $browser_functions[callback_name] = Class.new(Java::OrgEclipseSwtBrowser::BrowserFunction) do
        puts "will define #{$callbacks}, #{callback_name}"
        define_method(:function) do |*args|
          puts "will call right now"
          begin
            $callbacks[callback_name].call
          rescue => e
            puts "Error in callback #{callback_name}: #{e.class} - #{e.message}"
          end
        end
      end
      
      $browser_functions[callback_name].new($browser, callback_name)

    end

    # Retorna o atributo HTML correto
    "#{event.to_s.gsub('_', '')}=\"#{callback_name}()\""
  end
  def render
    puts "calling render"
    return unless @root_component
    puts "passed root_component condition"
    puts "now will call browser.set_text"
    @browser.set_text(@root_component.render_to_html)
  end
end

# Base component
class Component
  attr_accessor :state, :children, :parent_renderer

  def initialize(parent_renderer: nil)
    puts "initilizing component"
    @state = {}
    @children = []
    @parent_renderer = parent_renderer
  end

  def state=(new_state)
    @state.merge!(new_state)
    @parent_renderer&.render
  end

  def add_child(comp)
    comp.parent_renderer = self.parent_renderer
    @children << comp
  end

  def method_missing(method_name, *args, **kwargs, &block)
    puts "calling method_missing #{method_name}"
    # If the method name matches a tag (or anything), delegate to `tag`
    tag(method_name, *args, **kwargs, &block)
  end

  def respond_to_missing?(method_name, include_private = false)
    true
  end

  # Main tag helper with automatic event binding
  def tag(name, *args, **attrs, &block)
    content_or_attrs = args.first

    # Se for bloco, executa para pegar conteúdo
    inner_content = if block
      result = instance_eval(&block)
      # Se o resultado for um Component, adiciona aos children e não renderiza aqui
      add_child(result) if result.is_a?(Component)
      result.is_a?(Component) ? "" : result.to_s
    else
      content_or_attrs.is_a?(Component) ? (add_child(content_or_attrs); "") : content_or_attrs.to_s
    end

    html_attrs = attrs.map do |k,v|
      if k.to_s.start_with?("on_") && v.is_a?(Proc)
        puts "one with callback #{k}, #{v}"
        @parent_renderer.bind_callback(k,v)
      else
        "#{k}=\"#{v}\""
      end
    end.join(" ")

    "<#{name} #{html_attrs}>#{inner_content}</#{name}>"
  end


  def render_to_html
    return "" unless @render_block

    # Executa o bloco de render e pega tudo que ele retorna
    html = instance_eval(&@render_block)

    # Se houver children (Componentes aninhados), renderiza recursivamente
    html += children.map(&:render_to_html).join unless children.empty?

    html
  end

  # DSL for defining render logic
  def define_render(&block)
    @render_block = block
  end

  def render
    instance_eval(&@render_block)
  end
end

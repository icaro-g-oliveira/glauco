require_relative 'glauco-framework'

include Frontend
# Counter component example

class Counter < Component
  def initialize(parent_renderer:)
    super(parent_renderer: parent_renderer)
    @state[:count] = 0

    define_render do
      puts "defining render is called at least"
      div(style: "padding:20px") do
        span("Count: #{@state[:count]}", id: "count_display") +
        button(onclick: proc {
          @state[:count] += 1
          rerender() # BUG: Has to call render from parent here cause swt binding function crash if trys to set directly
        }) { "Increment" }
      end
    end
  end
end

class ParentChildNestedTest < Component
  def initialize(parent_renderer:)
    super(parent_renderer: parent_renderer)

    # Estado principal com objeto aninhado
    @state = {
      form_type: "A",       # Tipo de formulário (pai)
      form_data: {          # Objeto aninhado para dados do form
        child_value: "A"    # Valor interno (filho)
      }
    }
    define_render do
      # Pai: bind sobre objeto aninhado
      # --- Bind do formulário pai ---
      bind(:form_type, div(style: "padding:10px; border:1px solid green; width:400px;")) do |form_type|
        div("Form type: #{form_type}", style: "font-weight:bold; margin-bottom:10px;") +

        # Botões para mudar o tipo de formulário (pai)
        button(onclick: proc { set_state(:form_type, "A") }) { "Form A" } +
        button(onclick: proc { set_state(:form_type, "B") }) { "Form B" } +

        # Bind interno para child_value
        bind(:form_data>:child_value, div(style: "margin-top:10px; padding:5px; border:1px solid blue;")) do |child_value|
          div("Child value: #{child_value}", style: "margin-bottom:5px;") +

          select(
            onchange: proc { |payload|
              set_state(:form_data>:child_value, payload[0].to_s)
            }
          ) do
            %w[A B C].map do |val|
              attrs = {}
              attrs[:selected] = "selected" if child_value == val
              option(val, **attrs)
            end.join
          end
        end
      end
    end
  end
end

counter = Counter.new(parent_renderer: $root)
nested = ParentChildNestedTest.new(parent_renderer: $root)

$root.root_component = counter # or nested
$root.render

# Set window size and open
$shell.setSize(900, 700)
$shell.open
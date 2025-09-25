
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


class ChatPage < Component
  def initialize(parent_renderer:)
    super(parent_renderer: parent_renderer)

    # Estado inicial: mensagens do chat
    @state = {
      logged_in: false,
      user_name: nil,
      messages: [
        {role: "user", text: "Olá"},
        {role: "ia", text: "Oi!"}
      ]
    }
    input_value = nil

    define_render do
      puts "rendered with state:\n#{@state}"

      bind(:logged_in, div(style: "padding:20px; border:1px solid #cc; width:400px; height:500px; display:flex; flex-direction:column;")) do |logged_in|
        puts "Rendering chat page, logged_in=#{logged_in}"
        div("Login", style: "font-size:24px; margin-bottom:20px;") +
        if !logged_in
          div(style: "margin-bottom:20px;") do
            input(
              type: "text",
              placeholder: "Seu nome",
              style: "padding:5px; margin-right:10px;",
              onchange: proc { |payload|
                puts "onchange payload: #{payload.inspect}"
                @state[:user_name] = payload[0].to_s # payload do browser é
              }
            ) +
            button(on_click: proc {
              puts "Login button clicked, user_name=#{@state[:user_name].inspect}"
              unless @state[:user_name].nil? || @state[:user_name].strip.empty?
                puts "Setting logged_in to true"
                set_state(:logged_in, true)
              end
            }) { "Entrar" }
          end
        else
          bind(:user_name, div(style: "font-size:18px; margin-bottom:20px;")) do |user_name|
            puts "user_name binding called with #{user_name}"
            "Bem-vindo, #{@state[:user_name]}!"
          end +
          bind(:messages, div(style: "flex:1; overflow:auto; margin-bottom:10px; border:1px solid #eee; padding:5px")) do |messages| 
            messages.map do |msg|
              div("#{msg[:role]}: #{msg[:text]}", style: "margin-bottom:5px;")
            end
          end +

          div(style: "display:flex; gap:5px") do
            # Input de texto
            input(
              type: "text",
              id: "chat_input",
              placeholder: "Digite sua mensagem",
              style: "flex:1; padding:5px",
              onchange: proc { |payload|
                input_value = payload[0].to_s # payload do browser é uma array de elementos
              }
            ) +

          button(on_click: proc {
            unless input_value.nil? || input_value.strip.empty?
              # adiciona mensagem do usuário
              new_messages = @state[:messages] + [{ role: "user", text: input_value.to_s }]
              set_state(:messages, new_messages)

              run_js("document.querySelector('#chat_input').value=''")

              # Executa LLM fora do observer
              
              async do
                ia_response = LMSLLM.act(input_value.to_s).to_s
                # adiciona resposta da IA
                new_messages = @state[:messages] + [{ role: "ia", text: ia_response }]
                set_state(:messages, new_messages)
              end
            end
          }) { "Enviar" }
            
          end

        end
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

# LLM init

LMSLLM.register_tool(
  name: :say_hello,
  docstring: "Cumprimenta alguém pelo nome.",
  params: { name: "string" }
) do |args|
  nome = args["name"]
  msg = "👋 Olá, #{nome}!"
  puts msg # aqui vai aparecer no console Ruby
  msg      # devolve também a string para o Node/LLM
end




# App rendering
counter = Counter.new(parent_renderer: $root)
chat = ChatPage.new(parent_renderer: $root)
nested = ParentChildNestedTest.new(parent_renderer: $root)

$root.root_component = nested

$root.render

# Set window size and open
$shell.setSize(900, 700)
$shell.open

LMSLLM.init_llm!
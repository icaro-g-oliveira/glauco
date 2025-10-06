
require_relative 'LMSLLM_integration'
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
                ia_response = LMSLLM.talk(input_value.to_s).to_s
                puts "LLM response: #{ia_response}"
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

class AppPage < Component
  def initialize(parent_renderer:)
    super(parent_renderer: parent_renderer)

    @state = {
      current_page: "Chat",
      links: [
        { name: "Home", href: "#" },
        { name: "Chat", href: "#" },
        { name: "Settings", href: "#" },
        { name: "Logout", href: "#" },
      ]
    }

    define_render do
      script(src: "https://cdn.tailwindcss.com") +
      style do
        <<~CSS 
          @layer base {
            :root {
              --sidebar: oklch(0.985 0 0);
              --sidebar-foreground: oklch(0.145 0 0);
              --sidebar-primary: oklch(0.205 0 0);
              --sidebar-primary-foreground: oklch(0.985 0 0);
              --sidebar-accent: oklch(0.97 0 0);
              --sidebar-accent-foreground: oklch(0.205 0 0);
              --sidebar-border: oklch(0.922 0 0);
              --sidebar-ring: oklch(0.708 0 0);
            }

            .dark {
              --sidebar: oklch(0.205 0 0);
              --sidebar-foreground: oklch(0.985 0 0);
              --sidebar-primary: oklch(0.488 0.243 264.376);
              --sidebar-primary-foreground: oklch(0.985 0 0);
              --sidebar-accent: oklch(0.269 0 0);
              --sidebar-accent-foreground: oklch(0.985 0 0);
              --sidebar-border: oklch(1 0 0 / 10%);
              --sidebar-ring: oklch(0.439 0 0);
            }
          }
        CSS
      end+
      main(class: "flex h-screen w-screen bg-sidebar text-sidebar-foreground") do
        bind(:links, nav(class: "flex flex-col w-48 border-r border-sidebar-border bg-sidebar p-4")) do |links|
          links.map do |link|
            a(href: link[:href], class: "mb-2 rounded-md px-3 py-2 text-sm font-medium hover:bg-sidebar-accent hover:text-sidebar-accent-foreground #{'bg-sidebar-primary text-sidebar-primary-foreground' if link[:name] == @state[:current_page]}",
              onclick: proc {
                set_state(:current_page, link[:name])
              }
            ) do
              link[:name]
            end
          end
        end+
        main(class: "flex flex-1 flex-col") do
          bind(:current_page, div(class: "flex-1")) do |current_page|
            case current_page
            when "Chat"
              ChatPage.new(parent_renderer: self)
            when "Home"
              div("Welcome to the Home Page", class: "p-4")
            when "Settings"
            when "Logout"
              div("You have been logged out.", class: "p-4")
            else
              div("Page not found", class: "p-4")
            end
          end
        end
      end
    end
      
  end
end

class ChatPage < Component

  class Message < Component
    def initialize(parent_renderer:, role:, text:, avatar: nil)
      super(parent_renderer: parent_renderer)

      define_render do
        role_class = role.to_s == "user" ? "is-user" : "is-assistant flex-row-reverse justify-end"

        div(class: "group flex w-full items-end gap-2 py-4 [&>div]:max-w-[80%] #{role_class}") do
          [
            MessageAvatar.new(parent_renderer: self, role: role, avatar: avatar),
            MessageContent.new(parent_renderer: self, text: text, role: role)
          ]
        end
      end
      
    end
  end

  class MessageAvatar < Component
    def initialize(parent_renderer:, role:, avatar: nil)
      super(parent_renderer: parent_renderer)
      @role = role
      @avatar = avatar
      puts "MessageAvatar initialized with role=#{@role}, avatar=#{@avatar}"
    end

    # sobrescreve o render_to_html
    def render_to_html
      div(class: "w-8 h-8 rounded-full ring ring-1 ring-border flex items-center justify-center overflow-hidden") do
        if @avatar
          img(src: @avatar, alt: @role, class: "w-full h-full object-cover mt-0 mb-0")
        else
          span(class: "text-xs text-gray-500") { @role[0].upcase }
        end
      end
    end
  end

  class MessageContent < Component
    def initialize(parent_renderer:, text:, role:)
      super(parent_renderer: parent_renderer)
      @text = text
      @role = role

      define_render do
        div(
          class: [
            "flex flex-col gap-2 overflow-hidden rounded-lg px-4 py-3 text-foreground text-sm",
            (@role == "user" ? "bg-primary text-primary-foreground" : "bg-secondary text-foreground")
          ].join(" ")
        ) do
          div { @text }
        end
      end
    end
  end

  def initialize(parent_renderer:)
    super(parent_renderer: parent_renderer)
    @state = {
      messages: [
        { role: "user", text: "Olá, tudo bem?", avatar: "https://i.pravatar.cc/40?u=user1" },
        { role: "ia", text: "Oi! Tudo ótimo, e você?", avatar: "https://i.pravatar.cc/40?u=assistant" },
      ]
    }

    define_render do
   
      div(id: "message-box", class: "p-4") do
        bind(:messages, div(class: "flex flex-col gap-2 flex-1 overflow-auto p-2")) do |messages|
          messages.map do |msg|
            Message.new(
              parent_renderer: self,
              role: msg[:role],
              text: msg[:text],
              avatar: msg[:avatar]
            )
          end
        end+
        textarea(placeholder: "Type your message here...", class:  "border-input placeholder:text-muted-foreground focus-visible:border-ring focus-visible:ring-ring/50 aria-invalid:ring-destructive/20 dark:aria-invalid:ring-destructive/40 aria-invalid:border-destructive dark:bg-input/30 flex field-sizing-content min-h-16 w-full rounded-md border bg-transparent px-3 py-2 text-base shadow-xs transition-[color,box-shadow] outline-none focus-visible:ring-[3px] disabled:cursor-not-allowed disabled:opacity-50 md:text-sm") 
      end
    end
  end

end


# App rendering
app = AppPage.new(parent_renderer: $root)

$root.root_component = app

$root.render

# Set window size and open
$shell.setSize(900, 700)
$shell.open

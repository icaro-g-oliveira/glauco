require_relative 'glauco-framework'
include Frontend
include Agents



# ===========================================================
# 🧠 Interface de chat conectada à automação
# ===========================================================.

class ChatPage < Component
  # =======================================================
  # Mensagem individual
  # =======================================================
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

  # =======================================================
  # Avatar
  # =======================================================
  class MessageAvatar < Component
    def initialize(parent_renderer:, role:, avatar: nil)
      super(parent_renderer: parent_renderer)
      @role = role
      @avatar = avatar
    end

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

  # =======================================================
  # Conteúdo da mensagem
  # =======================================================
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

  # =======================================================
  # Página principal de chat
  # =======================================================
  def initialize(parent_renderer:)
    super(parent_renderer: parent_renderer)
    @automation = BrowserAutoAgent.new
    @state = {
      messages: [
        { role: "ia", text: "👋 Olá! Sou seu agente de automação. O que deseja fazer?", avatar: "https://i.pravatar.cc/40?u=assistant" }
      ],
      input: ""
    }

    define_render do
      div(id: "message-box", class: "p-4 h-full flex flex-col") do
        # histórico
        bind(:messages, div(class: "flex flex-col gap-2 flex-1 overflow-auto p-2 bg-neutral-900 text-white rounded-lg shadow-inner")) do |messages|
          messages.map do |msg|
            Message.new(
              parent_renderer: self,
              role: msg[:role],
              text: msg[:text],
              avatar: msg[:avatar]
            )
          end
        end +

        # entrada
        div(class: "mt-4 flex gap-2 items-center") do
          input(
            type: "text",
            placeholder: "Digite um comando...",
            value: @state[:input],
            oninput: proc { |val| set_state(:input, val) },
            style: "flex:1; padding:10px; border-radius:6px; border:none;"
          ) +
          button(
            onclick: proc { enviar_mensagem },
            style: "background:#007acc; color:white; border:none; border-radius:6px; padding:10px 15px; cursor:pointer;"
          ) { "Enviar" }
        end
      end
    end
  end

  # =======================================================
  # Lógica do chat
  # =======================================================
  def enviar_mensagem
    texto = @state[:input].to_s.strip
    
    return if texto.empty?

    set_state(:messages, @state[:messages] + [
      { role: "user", text: texto, avatar: "https://i.pravatar.cc/40?u=user" }
    ])
    set_state(:input, "")

    # Executa a automação de forma assíncrona e thread-safe
    @automation.run_async do
      begin
        resposta = processar_comando(texto)
        set_state(:messages, @state[:messages] + [
          { role: "ia", text: resposta.to_s, avatar: "https://i.pravatar.cc/40?u=assistant" }
        ])
      rescue => e
        set_state(:messages, @state[:messages] + [
          { role: "ia", text: "❌ Erro: #{e.class} - #{e.message}", avatar: "https://i.pravatar.cc/40?u=assistant" }
        ])
      end
    end
  end

  def processar_comando(texto)
    begin
      result = @automation.executar(texto)
      "✅ Comando executado: #{texto}\nResultado: #{result.inspect}"
    rescue => e
      "❌ Erro: #{e.class} - #{e.message}"
    end
  end
end

# ===========================================================
# 🚀 Inicialização da aplicação
# ===========================================================
puts "Teste: "
app = ChatPage.new(parent_renderer: nil)
$root.root_component = app
$root.render

$shell.setSize(900, 700)
$shell.open

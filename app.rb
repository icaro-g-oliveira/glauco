
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

class OfficeEscritorio < Component
  def initialize(parent_renderer:)
    super(parent_renderer: parent_renderer)

    # Estado inicial com várias entidades{
    @state = {
      empresa: {
        atual: {
          id: nil,
          nome: nil,
          cnpj: nil,
          descricao: nil,
          cnaes: [],
          endereco: nil,
          telefone: nil,
          email: nil
        },
        lista: []
      },

      fornecedores: {
        atual: {
          id: nil,
          nome: nil,
          descricao: nil,
          cnpj: nil,
          contatos: [],
          catalogo_ids: [],
          cotacoes_ids: [],
          status: nil
        },
        lista: []
      },

      catalogos: {
        atual: {
          id: nil,
          nome: nil,
          fornecedor_id: nil,
          itens: [],
          data_criacao: nil,
          status: nil
        },
        lista: []
      },

      editais: {
        atual: {
          id: nil,
          titulo: nil,
          descricao: nil,
          data_abertura: nil,
          data_fechamento: nil,
          itens_ids: [],
          fornecedores_ids: [],
          pdf_link: nil,
          status: nil,
          pasta_documentos: nil
        },
        lista: []
      },

      itens: {
        atual: {
          id: nil,
          edital_id: nil,
          nome: nil,
          descricao: nil,
          quantidade: nil,
          unidade: nil,
          valor_estimado: nil,
          cotacoes_ids: []
        },
        lista: []
      },

      atividades: {
        atual: {
          id: nil,
          titulo: nil,
          tipo_documento: nil,
          documento_id: nil,
          descricao: nil,
          status: nil,
          pipeline: [],
          responsavel: nil
        },
        lista: []
      },

      documentos: {
        atual: {
          id: nil,
          atividade_id: nil,
          nome: nil,
          tipo: nil,
          data_criacao: nil,
          status: nil,
          assinaturas: [],
          caminho: nil
        },
        lista: []
      },

      whatsapp: {
        atual: {
          contacts: [],
          current_chat: nil,
          messages: [],
          input_text: ""
        }
      }

    }

    define_render do
# --- Renderização principal (routing integrado) ---
      define_render do
        # Resolve rota corrente a partir da pilha de navegação
        route = current_route
        page_key = route[0].to_sym
        sub_id   = route[1]

        div(class: "app-container flex h-full") do
          # Sidebar esquerda - navegação
          div(class: "sidebar-left w-60 bg-gray-100 p-2") do
            ul do
              %i[dashboard empresa fornecedores editais catalogos atividades documentos whatsapp].map do |page|
                li(class: (@state[:pages][:current_page] == page ? "active" : "")) do
                  # navegação simples por página (reseta sub-seleção)
                  a(href: "#", onclick: proc {
                    # limpar a pilha quando navegar por item de topo
                    set_state(StatePath.new(:navigation_history), [])
                    set_state(StatePath.new(:pages)[:current_page], page)
                    # limpa 'atual' da categoria ao trocar de página
                    if @state[page] && @state[page].is_a?(Hash)
                      set_state(StatePath.new(page)[:atual], nil)
                    end
                    rerender
                  }) { page.to_s.capitalize }
                end
              end
            end
          end +

          # Área central - renderiza lista ou detalhe com base na rota atual
          div(class: "main-content flex-1 p-4 overflow-auto") do
            case page_key
            when :dashboard
              render_dashboard
            when :empresa
              render_empresa_page
            when :fornecedores
              if sub_id
                render_fornecedor_detail
              else
                render_fornecedores_list
              end
            when :catalogos
              if sub_id
                render_catalogo_detail
              else
                render_catalogos_list
              end
            when :editais
              if sub_id
                render_edital_detail
              else
                render_editais_list
              end
            when :itens
              if sub_id
                render_item_detail
              else
                render_itens_list
              end
            when :atividades
              if sub_id
                render_atividade_detail
              else
                render_atividades_list
              end
            when :documentos
              if sub_id
                render_documento_detail
              else
                render_documentos_list
              end
            when :whatsapp
              render_whatsapp
            else
              div { "Página não encontrada" }
            end
          end +

          # Sidebar direita - agente IA (sempre presente)
          div(class: "sidebar-right w-80 bg-gray-50 p-2 border-l") do
            ChatPage.new(parent_renderer: self)
          end
        end
      end
    end

    # -----------------------
    # --- Helper methods ---
    # -----------------------
    def push_history(*stack)
      hist = (@state[:navigation_history] || []).dup
      hist << stack
      set_state(StatePath.new(:navigation_history), hist)
    end

    def pop_history
      hist = (@state[:navigation_history] || []).dup
      entry = hist.pop
      set_state(StatePath.new(:navigation_history), hist)
      entry
    end

    def current_route
      hist = @state[:navigation_history] || []
      if hist.any?
        hist.last
      else
        [@state[:pages][:current_page]]
      end
    end

    # resolve route: atualiza pages[current_page] e o objeto atual da categoria (se id presente)
    def resolve_route(route)
      page = route[0].to_sym
      id   = route[1]
      set_state(StatePath.new(:pages)[:current_page], page)
      if id
        found = find_in(page, id)
        set_state(StatePath.new(page)[:atual], found || nil)
      else
        set_state(StatePath.new(page)[:atual], nil)
      end
    end

    # navega empurrando para a pilha e resolvendo o novo estado
    def navigate_to(page_sym, id = nil)
      push_history(page_sym, id)
      resolve_route([page_sym, id])
      rerender
    end

    # localiza objeto na lista da categoria (por id)
    def find_in(category_sym, id)
      cat = @state[category_sym]
      return nil unless cat && cat[:lista].is_a?(Array)
      cat[:lista].find { |o| o[:id].to_s == id.to_s }
    end

    # -----------------------
    # --- Render helpers ---
    # -----------------------
    def render_dashboard
      div do
        h2 { "Dashboard" } +
        p { "Quadro de atividades, relatórios e status gerais." }
      end
    end

    def render_empresa_page
      div do
        h2 { "Empresa" } +
        bind(:empresa, '<div class="empresa-box">') do |empresa|
          atual = empresa[:atual] || {}
          <<~HTML
            <p><b>Nome:</b> #{atual[:nome] || '-'}</p>
            <p><b>CNPJ:</b> #{atual[:cnpj] || '-'}</p>
            <p><b>Descrição:</b> #{atual[:descricao] || '-'}</p>
            <p><b>CNAEs:</b> #{(atual[:cnaes] || []).join(", ")}</p>
          HTML
        end
      end
    end

    # ---------- FORNECEDORES ----------
    def render_fornecedores_list
      div do
        h2 { "Fornecedores" } +
        bind(:fornecedores, '<div class="fornecedores-list">') do |fornecedores|
          lista = (fornecedores[:lista] || [])
          if lista.empty?
            "<p>Nenhum fornecedor cadastrado.</p>"
          else
            lista.map do |f|
              # usamos tag button com onclick: proc para permitir navegação via callbacks Ruby
              "<div class='supplier-card border p-2 mb-2'>
                #{button_html_open_fornecedor(f)}
                <div class='meta'>CNPJ: #{f[:cnpj] || '-'}</div>
              </div>"
            end.join
          end
        end
      end
    end

    def button_html_open_fornecedor(f)
      # gera botão com onclick que chama navigate_to(:fornecedores, f[:id])
      callback = proc {
        navigate_to(:fornecedores, f[:id])
      }
      # use tag helper to ensure bind_callback wiring
      button(class: "open-btn", onclick: callback) { "#{f[:nome] || '—'} (Abrir)" }
    end

    def render_fornecedor_detail
      div do
        h2 { "Fornecedor — Detalhes" } +
        bind(:fornecedores, '<div class="fornecedor-detail">') do |fornecedores|
          atual = fornecedores[:atual] || {}
          if atual[:id].nil?
            "<p>Nenhum fornecedor selecionado.</p>"
          else
            <<~HTML
              <h3>#{atual[:nome]}</h3>
              <p><b>CNPJ:</b> #{atual[:cnpj] || '-'}</p>
              <p><b>Descrição:</b> #{atual[:descricao] || '-'}</p>
              <p><b>Contatos:</b> #{(atual[:contatos] || []).map{|c| c[:nome]}.join(', ')}</p>
              <p><b>Catálogo(s):</b> #{(atual[:catalogo_ids] || []).join(', ')}</p>
              <div class='actions'>
                #{button_edit_fornecedor(atual)}
                #{button_back_to_list(:fornecedores)}
              </div>
            HTML
          end
        end
      end
    end

    def button_edit_fornecedor(atual)
      callback = proc {
        # exemplo simples: abre o editor (aqui apenas marca como atual e re-render)
        set_state(StatePath.new(:fornecedores)[:atual], atual)
        rerender
      }
      button(class: "edit-btn", onclick: callback) { "Editar Fornecedor" }
    end

    def button_back_to_list(category)
      callback = proc {
        pop_history # remove o topo (detail)
        # resolve novo topo
        route = current_route
        resolve_route(route)
        rerender
      }
      button(class: "back-btn", onclick: callback) { "Voltar à Lista" }
    end

    # ---------- CATÁLOGOS ----------
    def render_catalogos_list
      div do
        h2 { "Catálogos" } +
        bind(:catalogos, '<div class="catalogos-list">') do |catalogos|
          lista = (catalogos[:lista] || [])
          if lista.empty?
            "<p>Nenhum catálogo disponível.</p>"
          else
            lista.map do |c|
              "<div class='catalog-card border p-2 mb-2'>
                #{button_open_catalogo(c)}
                <div class='meta'>Fornecedor ID: #{c[:fornecedor_id] || '-'}</div>
              </div>"
            end.join
          end
        end
      end
    end

    def button_open_catalogo(c)
      callback = proc { navigate_to(:catalogos, c[:id]) }
      button(class: "open-catalog-btn", onclick: callback) { "#{c[:nome] || '—'} (Abrir Catálogo)" }
    end

    def render_catalogo_detail
      div do
        h2 { "Catálogo — Detalhes" } +
        bind(:catalogos, '<div class="catalogo-detail">') do |catalogos|
          atual = catalogos[:atual] || {}
          if atual[:id].nil?
            "<p>Nenhum catálogo selecionado.</p>"
          else
            items_html = (atual[:itens] || []).map { |it|
              "<div class='item-line'>#{it[:nome]} — #{it[:descricao]} — R$ #{it[:preco]}</div>"
            }.join
            <<~HTML
              <h3>#{atual[:nome]}</h3>
              <p><b>Fornecedor:</b> #{atual[:fornecedor_id] || '-'}</p>
              <div class='items'>#{items_html}</div>
              <div class='actions'>#{button_back_to_list(:catalogos)}</div>
            HTML
          end
        end
      end
    end

    # ---------- EDITAIS ----------
    def render_editais_list
      div do
        h2 { "Editais" } +
        bind(:editais, '<div class="editais-list">') do |editais|
          lista = (editais[:lista] || [])
          if lista.empty?
            "<p>Nenhum edital cadastrado.</p>"
          else
            lista.map do |e|
              "<div class='edital-card border p-2 mb-2'>
                #{button_open_edital(e)}
                <div class='meta'>Abertura: #{e[:data_abertura] || '-'}</div>
              </div>"
            end.join
          end
        end
      end
    end

    def button_open_edital(e)
      callback = proc { navigate_to(:editais, e[:id]) }
      button(class: "open-edital-btn", onclick: callback) { "#{e[:titulo] || '—'} (Abrir Edital)" }
    end

    def render_edital_detail
      div do
        h2 { "Edital — Detalhes" } +
        bind(:editais, '<div class="edital-detail">') do |editais|
          atual = editais[:atual] || {}
          if atual[:id].nil?
            "<p>Nenhum edital selecionado.</p>"
          else
            itens_list = (atual[:itens_ids] || []).map { |iid|
              "<div class='edital-item'>Item ID: #{iid} — #{button_open_item_inline(iid)}</div>"
            }.join
            <<~HTML
              <h3>#{atual[:titulo]}</h3>
              <p>#{atual[:descricao]}</p>
              <p><b>Período:</b> #{atual[:data_abertura]} → #{atual[:data_fechamento]}</p>
              <p><b>PDF:</b> #{atual[:pdf_link] || '—'}</p>
              <div class='itens'>#{itens_list}</div>
              <div class='actions'>#{button_back_to_list(:editais)}</div>
            HTML
          end
        end
      end
    end

    def button_open_item_inline(item_id)
      callback = proc { navigate_to(:itens, item_id) }
      button(class: "open-item-btn", onclick: callback) { "Abrir Item" }
    end

    # ---------- ITENS ----------
    def render_itens_list
      div do
        h2 { "Itens de Edital" } +
        bind(:itens, '<div class="itens-list">') do |itens|
          lista = (itens[:lista] || [])
          if lista.empty?
            "<p>Nenhum item cadastrado.</p>"
          else
            lista.map do |it|
              "<div class='item-card border p-2 mb-2'>
                #{button_open_item(it)}
                <div class='meta'>Quantidade: #{it[:quantidade] || '-'}</div>
              </div>"
            end.join
          end
        end
      end
    end

    def button_open_item(it)
      callback = proc { navigate_to(:itens, it[:id]) }
      button(class: "open-item-btn", onclick: callback) { "#{it[:nome] || '—'} (Abrir Item)" }
    end

    def render_item_detail
      div do
        h2 { "Item — Detalhes" } +
        bind(:itens, '<div class="item-detail">') do |itens|
          atual = itens[:atual] || {}
          if atual[:id].nil?
            "<p>Nenhum item selecionado.</p>"
          else
            <<~HTML
              <h3>#{atual[:nome]}</h3>
              <p>#{atual[:descricao]}</p>
              <p><b>Quantidade:</b> #{atual[:quantidade]} #{atual[:unidade]}</p>
              <p><b>Valor estimado:</b> R$ #{atual[:valor_estimado]}</p>
              <div class='cotacoes'>Cotações: #{(atual[:cotacoes_ids]||[]).join(', ')}</div>
              <div class='actions'>#{button_back_to_list(:itens)}</div>
            HTML
          end
        end
      end
    end

    # ---------- ATIVIDADES (accordions) ----------
    def render_atividades_list
      div do
        h2 { "Atividades e Documentos (Accordions)" } +
        bind(:atividades, '<div class="atividades-accordions">') do |atividades|
          lista = (atividades[:lista] || [])
          if lista.empty?
            "<p>Nenhuma atividade criada.</p>"
          else
            lista.map do |a|
              # accordion: título + badges de documentos
              docs_badges = (a[:documentos] || []).map { |d| "<span class='badge'>#{d[:nome]}</span>" }.join(" ")
              "<div class='accordion border p-2 mb-2'>
                <div class='accordion-header'><b>#{a[:titulo] || '—'}</b> #{docs_badges}</div>
                <div class='accordion-body'>
                  <p>Tipo: #{a[:tipo_documento] || '-'}</p>
                  <p>Responsável: #{a[:responsavel] || '-'}</p>
                  <div class='actions'>
                    #{button_open_atividade(a)}
                    #{button_back_to_list(:atividades)}
                  </div>
                </div>
              </div>"
            end.join
          end
        end +
        # botão para adicionar nova atividade (abre accordion em branco via callback)
        div(class: "new-atividade") do
          callback = proc {
            new_id = "atividade_#{(Time.now.to_i)}"
            new_activity = {
              id: new_id,
              titulo: "Nova Atividade #{new_id}",
              tipo_documento: "docx",
              descricao: "",
              status: "rascunho",
              pipeline: [],
              responsavel: nil,
              documentos: []
            }
            lista = @state[:atividades][:lista] || []
            set_state(StatePath.new(:atividades)[:lista], lista + [new_activity])
            # abre a atividade recém-criada
            navigate_to(:atividades, new_id)
          }
          button(class: "btn-new-atividade", onclick: callback) { "Adicionar Atividade" }
        end
      end
    end

    def button_open_atividade(a)
      callback = proc { navigate_to(:atividades, a[:id]) }
      button(class: "open-atividade-btn", onclick: callback) { "Abrir Atividade" }
    end

    def render_atividade_detail
      div do
        h2 { "Atividade — Detalhes / Pipeline" } +
        bind(:atividades, '<div class="atividade-detail">') do |atividades|
          atual = atividades[:atual] || {}
          if atual[:id].nil?
            "<p>Nenhuma atividade selecionada.</p>"
          else
            pipeline_html = (atual[:pipeline] || []).map { |p|
              checked = p[:concluido] ? "✅" : "⬜"
              "<div class='pipeline-step'>#{checked} Etapa #{p[:etapa]} — #{p[:descricao]}</div>"
            }.join
            docs_html = (atual[:documentos] || []).map { |d| "<div class='doc-row'>#{d[:nome]} (#{d[:status]})</div>" }.join
            <<~HTML
              <h3>#{atual[:titulo]}</h3>
              <p>Tipo: #{atual[:tipo_documento]}</p>
              <p>Descrição: #{atual[:descricao]}</p>
              <div class='pipeline'>#{pipeline_html}</div>
              <div class='documents'>#{docs_html}</div>
              <div class='actions'>
                #{button_back_to_list(:atividades)}
              </div>
            HTML
          end
        end
      end
    end

    # ---------- DOCUMENTOS ----------
    def render_documentos_list
      div do
        h2 { "Documentos Escritoriais" } +
        bind(:documentos, '<div class="documentos-list">') do |docs|
          lista = (docs[:lista] || [])
          if lista.empty?
            "<p>Nenhum documento registrado.</p>"
          else
            lista.map do |d|
              "<div class='doc-card border p-2 mb-2'>
                #{button_open_documento(d)}
                <div class='meta'>Status: #{d[:status] || '-'}</div>
              </div>"
            end.join
          end
        end +
        div(class: "new-doc") do
          callback = proc {
            new_id = "doc_#{Time.now.to_i}"
            new_doc = {
              id: new_id,
              atividade_id: nil,
              nome: "Documento #{new_id}.docx",
              tipo: "docx",
              data_criacao: Time.now.to_s,
              status: "rascunho",
              assinaturas: [],
              caminho: nil
            }
            lista = @state[:documentos][:lista] || []
            set_state(StatePath.new(:documentos)[:lista], lista + [new_doc])
            navigate_to(:documentos, new_id)
          }
          button(class: "btn-new-doc", onclick: callback) { "Novo Documento" }
        end
      end
    end

    def button_open_documento(d)
      callback = proc { navigate_to(:documentos, d[:id]) }
      button(class: "open-doc-btn", onclick: callback) { "#{d[:nome] || '—'} (Abrir Documento)" }
    end

    def render_documento_detail
      div do
        h2 { "Documento — Detalhes" } +
        bind(:documentos, '<div class="documento-detail">') do |docs|
          atual = docs[:atual] || {}
          if atual[:id].nil?
            "<p>Nenhum documento selecionado.</p>"
          else
            assinaturas = (atual[:assinaturas] || []).map { |s| "<div>#{s[:nome]} — #{s[:data]}</div>" }.join
            <<~HTML
              <h3>#{atual[:nome]}</h3>
              <p><b>Tipo:</b> #{atual[:tipo]}</p>
              <p><b>Data criação:</b> #{atual[:data_criacao]}</p>
              <p><b>Status:</b> #{atual[:status]}</p>
              <div class='assinaturas'>#{assinaturas}</div>
              <div class='actions'>
                #{button_back_to_list(:documentos)}
              </div>
            HTML
          end
        end
      end
    end

    # ---------- WHATSAPP ----------
    def render_whatsapp
      div do
        h2 { "WhatsApp Web" } +
        bind(:whatsapp, '<div class="whatsapp-view">') do |w|
          <<~HTML
            <p>Contatos: #{(w[:contacts] || []).map{|c| c[:nome]}.join(', ')}</p>
            <p>Mensagens no chat atual: #{(w[:messages] || []).map{|m| "#{m[:role]}: #{m[:text]}"}.join('<br>')}</p>
            <p>Para enviar mensagem: use o campo abaixo e pressione Enviar.</p>
          HTML
        end
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

# LMSLLM.init_llm!
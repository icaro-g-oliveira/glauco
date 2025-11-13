# api_automacoes.rb
module ApiAutomacoes
  def open_url(url:, visible: true, on_changing: nil, on_changed: nil)
    action = WebAction.new
    run_ui do
      ensure_ui_alive
      @shell.setVisible(true)
      @visible = true

      # 🔸 Garante que a janela venha para frente
      @shell.forceActive
      @shell.setMinimized(false)
      @shell.setFocus

      listener = Class.new(LocationAdapter) do
        define_method(:changed) do |event|
          puts "[Browser] ✅ Página carregada: #{event.location}"
          action.resolve(event.location)
        end
      end.new

      @browser.addLocationListener(listener)
      @browser.setUrl(url)
      @state[:current_url] = url
      @state[:last_action] = "open_url"

      while @display.read_and_dispatch
      end
    end
    action
  end


  def type(selector:, value:)
    action = WebAction.new
    run_ui do
      js = <<~JS
        var el = document.querySelector("#{selector}");
        if (el) { el.value = "#{value}"; el.dispatchEvent(new Event('input', {bubbles: true})); "typed"; }
        else "element not found";
      JS
      begin
        evaluate(js, "type:#{selector}")
        action.resolve("typed")
      rescue => e
        puts "[Type] 💥 Erro: #{e.class} - #{e.message}"
        action.resolve(nil)
      end
    end
    action
  end


  def submit(selector:)
    action = WebAction.new
    run_ui do
      begin
        js = <<~JS
          var el = document.querySelector("#{selector}");
          if (el) {
            var evt = new KeyboardEvent('keydown', {key: 'Enter', code: 'Enter', keyCode: 13, which: 13, bubbles: true});
            el.dispatchEvent(evt);
            "enter_pressed";
          } else {
            "element not found";
          }
        JS

        result = evaluate(js, "submit:#{selector}")
        action.resolve(result)
      rescue => e
        puts "[Submit] 💥 Erro: #{e.class} - #{e.message}"
        action.resolve(nil)
      end
    end
    action
  end

  def hotkey(selector: nil, key:)
    action = WebAction.new
    run_ui do
      begin
        js = if selector
          <<~JS
            var el = document.querySelector("#{selector}");
            if (!el) return "element not found";
            var event = new KeyboardEvent('keydown', {
              key: "#{key}",
              code: "#{key}",
              keyCode: #{key == 'Enter' ? 13 : 0},
              which: #{key == 'Enter' ? 13 : 0},
              bubbles: true
            });
            el.dispatchEvent(event);
            if (el.form) el.form.submit();
            "key dispatched";
          JS
        else
          <<~JS
            var event = new KeyboardEvent('keydown', {
              key: "#{key}",
              code: "#{key}",
              keyCode: #{key == 'Enter' ? 13 : 0},
              which: #{key == 'Enter' ? 13 : 0},
              bubbles: true
            });
            document.activeElement.dispatchEvent(event);
            if (document.activeElement.form) document.activeElement.form.submit();
            "key dispatched to active element";
          JS
        end

        result = @browser.evaluate(js)
        puts "[Hotkey] selector=#{selector.inspect} key=#{key} → #{result.inspect}"
        action.resolve(result)
      rescue => e
        puts "[Hotkey] 💥 Erro: #{e.class} - #{e.message}"
        action.resolve(nil)
      end
    end
    action
  end



  def evaluate(*args, **kwargs)
    # Aceita tanto evaluate("js", "label") quanto evaluate(js: "codigo", label: "etiqueta")
    js, label =
      if kwargs.any?
        [kwargs[:js], kwargs[:label]]
      else
        [args[0], args[1]]
      end

    result = nil
    run_ui do
      begin
        result = @browser.evaluate(js)
        puts "[Eval] ✅ #{label || '(sem label)'} → #{result.inspect}"
      rescue => e
        puts "[Eval] 💥 Erro (#{label || '(sem label)'}): #{e.class} - #{e.message}"
        result = nil
      end
    end
    result
  end


  def click(selector:)
    action = WebAction.new
    run_ui do
      begin
        js = <<~JS
          var el = document.querySelector("#{selector}");
          if (el) {
            el.click();
            "clicked";
          } else {
            "element not found";
          }
        JS

        result = evaluate(js, "click:#{selector}")
        puts "[Click] 🖱️ Clique no elemento #{selector.inspect} → #{result.inspect}"
        action.resolve(result)
      rescue => e
        puts "[Click] 💥 Erro: #{e.class} - #{e.message}"
        action.resolve(nil)
      end
    end
    action
  end

end

require 'java'
require './swt.jar'

# SWT imports
java_import 'org.eclipse.swt.widgets.Display'
java_import 'org.eclipse.swt.widgets.Shell'
java_import 'org.eclipse.swt.layout.FillLayout'
java_import 'org.eclipse.swt.browser.Browser'
java_import 'org.eclipse.swt.browser.BrowserFunction'

require_relative 'glauco-react'

# Counter component example
class Counter < Component
  def initialize(parent_renderer:)
    super(parent_renderer: parent_renderer)
    @state[:count] = 0

    define_render do
      puts "defining render is called at least"
      div(style: "padding:20px") do
        span("Count: #{@state[:count]}", id: "count_display") +
        button(on_click: proc {
          @state[:count] += 1
          @parent_renderer&.render
        }) { "Increment" }
      end
    end
  end
end


# Create display and shell
display = Display.new
shell = Shell.new(display)
shell.setLayout(FillLayout.new)
$browser = Browser.new(shell, 0)
# App rendering
root = RootRenderer.new($browser)
counter = Counter.new(parent_renderer: root)
root.root_component = counter
root.render

# Set window size and open
shell.setSize(400, 300)
shell.open

# Event loop
while !shell.disposed?
  display.sleep unless display.read_and_dispatch
end

display.dispose

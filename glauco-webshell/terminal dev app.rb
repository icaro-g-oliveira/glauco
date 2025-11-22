# tests/test_suite.rb
# Suite completa de testes para o Glauco Framework (BrowserAutoAgent + FS + Docs + OS)
# Cada bloco imprime de forma analítica o resultado e simula cenários reais.

require_relative './glauco-webshell.rb'

agent = GlaucoWebshell.new

def banner(title)
  puts "\n" + "=" * 80
  puts "TESTE: #{title}"
  puts "=" * 80
end

def safe_exec(agent, input)
  puts "\n[Test] Entrada: #{input.inspect}"
  result = agent.interpretar(input)
  puts "[Test] Resultado: #{result.inspect}"
rescue => e
  puts "[Test] 💥 Erro: #{e.class} - #{e.message}"
end


# ------------------------------------------------------------------------------
# 9. TESTES INTERATIVOS (REPL)
# ------------------------------------------------------------------------------
banner("MODO CONSOLE INTERATIVO")

puts "Digite comandos de automação (ex: 'abrir google.com')"
puts "Digite 'exit' ou 'sair' para encerrar.\n\n"

loop do
  print ">> "
  input = STDIN.gets&.strip
  break if input.nil? || input.downcase == "exit" || input.downcase == "sair"

  if input.empty?
    puts "[Console] ⚠️ Entrada vazia ignorada."
    next
  end

  puts input.frozen?  # deve ser false antes do safe_exec
  safe_exec(agent, input)
  puts input.frozen?  # s
end

puts "[Console] ✅ Sessão encerrada."

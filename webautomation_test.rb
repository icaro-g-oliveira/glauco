require_relative 'glauco-framework'

agent = Agents::BrowserAutoAgent.new


puts "\n=== Console Interativo de Testes para BrowserAutoAgent ==="
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

  begin
    puts "\n[Test] Entrada: #{input.inspect}"
    puts "[Test] Executando comando..."
    result = agent.executar(input)
    puts "[Test] Resultado: #{result.inspect}\n\n"
  rescue => e
    puts "[Test] 💥 Erro: #{e.class} - #{e.message}\n\n"
  end
end

puts "[Console] ✅ Sessão encerrada."

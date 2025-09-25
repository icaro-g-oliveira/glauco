require 'observer'

class ObservableValue
  attr_reader :value

  def initialize(val)
    @value = val
    @callbacks = []
    wrap_value!
  end

  def value=(val)
    @value = val
    wrap_value!
    trigger_change
  end

  def on_change(&block)
    @callbacks << block
  end

  private

  def trigger_change
    @callbacks.each { |cb| cb.call(@value) }
  end

  def wrap_value!
    if @value.is_a?(Array) && !@value.is_a?(ObservableArray)
      @value = ObservableArray.new(@value) { trigger_change }
    elsif @value.is_a?(Hash) && !@value.is_a?(ObservableHash)
      @value = ObservableHash.new(@value) { trigger_change }
    end
  end
end


# Reuso das classes especializadas
class ObservableArray < Array
  include Observable

  def initialize(arr = [])
    super(arr)
  end

  def <<(val)
    super
    changed
    notify_observers(self)
    self
  end

  def push(*vals)
    super
    changed
    notify_observers(self)
    self
  end
end

class ObservableHash < Hash
  include Observable

  def initialize(h = {})
    super()
    update(h)
  end

  def []=(k, v)
    super(k, wrap(v))
    changed
    notify_observers(self)
  end

  private

  def wrap(val)
    case val
    when Array
      ObservableArray.new(val)
    when Hash
      ObservableHash.new(val)
    else
      val
    end
  end
end

# Supondo que ObservableValue, ObservableArray e ObservableHash já estão definidos
puts "--- Teste 1: Valor Primitivo ---"
state_primitive = ObservableValue.new(10)
state_primitive.on_change { |v| puts "Mudou para #{v}" }
state_primitive.value = 42
# Esperado no console: "Primitivo mudou para: 42"

puts "\n--- Teste 2: Hash ---"
state_hash = ObservableValue.new({ a: 1, b: 2 })
state_hash.on_change { |v| puts "Hash mudou: #{v.inspect}" }

# Atualiza um valor interno do hash
state_hash.value[:a] = 100
# Esperado: "Hash mudou: {:a=>100, :b=>2}"

# Substitui o hash inteiro
state_hash.value = { c: 3 }
# Esperado: "Hash mudou: {:c=>3}"

puts "\n--- Teste 3: Array ---"
state_array = ObservableValue.new([1, 2, 3])
state_array.on_change { |v| puts "Array mudou: #{v.inspect}" }

# Adiciona elemento
state_array.value << 4
# Esperado: "Array mudou: [1, 2, 3, 4]"

# Substitui array inteiro
state_array.value = [10, 20]
# Esperado: "Array mudou: [10, 20]"

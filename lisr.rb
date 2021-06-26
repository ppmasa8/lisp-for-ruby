class Env < Hash
  def initialize(params=[], args=[], outer=nil)
    h = Hash[params.zip(args)]
    self.merge!(h)
    @outer = outer
  end

  def find(key)
    self.has_key?(key) ? self : @outer.find(key)
  end
end

def add_globals(env)
  env.merge!({
     :+     => ->x,y{x+y},      :-      => ->x,y{x-y},
     :*    => ->x,y{x*y},       :/     => ->x,y{x/y},
     :not    => ->x{!x},        :>    => ->x,y{x>y}, 
     :<     => ->x,y{x<y},      :>=     => ->x,y{x>=y},
     :<=   => ->x,y{x<=y},      :'='   => ->x,y{x==y},
     :equal? => ->x,y{x.equal?(y)},
     :eq?   => ->x,y{x.eql? y}, :length => ->x{x.length},
     :cons => ->x,y{[x,y]},     :car   => ->x{x[0]},
     :cdr    => ->x{x[1..-1]},  :append => ->x,y{x+y},
     :list  => ->*x{[*x]},
     :list?  => ->x{x.instance_of?(Array)},
     :null? => ->x{x.empty?},
     :symbol? => ->x{x.instance_of?(Symbol)}
    })
  env
end

$global_env = add_globals(Env.new)

def evaluate(x, env=$global_env)
  case x
  when Symbol
    env.find(x)[x]
  when Array
    case x.first
    when :quote
      _, exp = x
      exp
    when :if
      _, test, conseq, alt = x
      evaluate((evaluate(test, env) ? conseq : alt), env)
    when :set!
      _, var, exp = x
      env.find(var)[var] = evaluste(exp, env)
    when :define
      _, var, exp = x
      env[var] = evaluate(exp, env)
      nil
    when :lambda
      _, vars, exp = x
      lambda {|*args| evaluate(exp, Env.new(vars, args, env)) }
    when :begin
      x[1..-1].inject(nil) {|val, exp| val = evaluate(exp, env)}
    else
      proc, *exps = x.inject([]) {|mem, exp| mem << evaluate(exp, env)}
      proc[*exps]
    end
  else
    return x
  end
end

def read(s)
  read_from tokenize(s)
end
alias :parse :read

def tokenize(s)
  s.gsub(/[()]/, ' \0 ').split
end

def read_from(tokens)
  raise SyntaxError, 'unexpected EOF while reading' if tokens.size == 0
  case token = tokens.shift
  when '('
    l = []
    while tokens[0] != ')'
      l.push read_from(tokens)
    end
    tokens.shift
    return l
  when ')'
    raise SyntaxError, 'unexpexted )'
  else
    atom(token)
  end
end

def brute_parse(s)
  s = tokenize(s).map { |token|
    if token =~ /[()]/ then token.tr('()', '[]')
    elsif token == '=' then ":'='"
    elsif atom(token).instance_of?(Symbol) then ":#{token}"
    else  token
    end
  }.join(",").gsub('[,', '[')
  eval s
end

module Kernel
  def Symbol(obj); obj.intern end
end

def atom(token, type=[:Integer, :Float, :Symbol])
  send(type.shift, token)
rescue ArgumentError
  retry
rescue => e
  puts "unexpected error: #{e.message}"
end

def to_string(exp)
  puts (exp.instance_of?(Array)) ? '(' + exp.map(&:to_s).join(" ") + ')' : "#{exp}"
end

require "readline"
def lepl
  while line = Readline.readline("lisr> ", true)
    val = evaluate(brute_parse line)
    to_string(val) unless val.nil?
  end
end

if __FILE__ == $0
  lepl
end

require 'net/http'
#require 'json'
require 'date'
require 'sqlite3'

$:.unshift(File.expand_path(File.dirname(__FILE__))) unless
    $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

require 'Mt940'

require 'known_transactions'

input = ARGV[ 0 ] || "test-mt940.txt"

p input

statements = []



mt940 = Mt940.new()
mt940.loadFromFile( input )

mt940clean = Mt940.new()
mt940.statements.each{ |s|
  mt940.mergeStatement( s )
}
puts mt940.toSpecialCsv()

__END__
puts "--------"
mt940.statements.each{ |s|
  s.transactions.each{ |t|
    puts "
    #{t.value_date.to_date.to_s} | %8.2f (#{t.niceDetail(30)})
" % t.amount
  }

}

__END__

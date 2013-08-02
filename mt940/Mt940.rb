$known_transactions = []
# 
# 
# car = {:make => "bmw", :year => "2003"}

def find_known_transaction( shortDetail )
	$known_transactions.each{ |k|
		k[ :patterns ].each{ |p|
			return k if( p.match( shortDetail ) )
		}
	}

	return nil
end

class Mt940
	attr_reader :statements

	class Statement
	  attr_reader :iban, :number, :opening_balance, :closing_balance, :transactions

		class Transaction

		  attr_reader :info, :detail, :value_date, :book_date, :is_credit, :currency, :amount
		  def initialize
		    @info = nil
		    @detail = ''
		    @value_date = nil
		    @book_date = nil
		    @is_credit = true
		    @currency = nil
		    @amount = 0

		  end
		  def info=( v )
		    @info = v
		    # "1301170117DR22,27N037NONREF"
		    if m = /^(\d\d\d\d\d\d)(\d\d\d\d)([DC])(\w)(\d+,\d\d)N(\w\w\w)(.*)$/.match( v )
		      vdate = m[ 1 ]
		      year = vdate[ 0..1 ].to_i
		      if year < 70
		      then
		        vdate = '20'+vdate
		      else
		        vdate = '19'+vdate
		      end
		      @value_date = DateTime.strptime(vdate, '%Y%m%d')
		#      @value_date = m[ 1 ]
		      @book_date = m[ 2 ]
		      @is_credit = m[ 3 ] == 'C'
		      @currency = m[ 4 ]
		      @amount = m[ 5 ].split( /,/ ).join( '.' ).to_f
		      @amount = -@amount if !@is_credit
		    end
		  end

		  def appendDetail( v )
		    @detail += v
		  end

		  def niceDetail( indent = 0 )
		    ind = "\n"
		    indent.times{ ind = ind+' ' }
		    nice = ''
		    type = ''
		    who = ''
		    @detail[2..-1].split( /\?/ )[1..-1].each{ |l|
		      code = l[ 0..1 ]
		      val = l[ 2..-1 ]
		      case code[ 0..1 ]
		        when '00'
		          type = val
		        when '20', '21', '22', '23'
		          nice = nice+ind+val
		        when '32'
		          who = val

		      end
		    }

		    type+nice+ind+who
		  end
		  def shortDetail(  )
		    short = ''
		    type = ''
		    who = ''
		    @detail[2..-1].split( /\?/ )[1..-1].each{ |l|
		      code = l[ 0..1 ]
		      val = l[ 2..-1 ]
		      case code[ 0..1 ]
		        when '00'
		          type = val
		        when '20', '21', '22', '23'
		          short = short+' '+val
		        when '32'
		          who = val

		      end
		    }

		    type+short+who
		  end
		end

	  def initialize
	    @iban = nil
	    @number = nil
	    @opening_balance = nil
	    @closing_balance = nil
	    @opening_balance_is_final = false
	    @closing_balance_is_final = false
	    @transactions = []
	  end

	  def iban=( v )
	    @iban = v
	  end
	  def number=( v )
	    @number = v
	  end
	  def final_opening_balance=( v )
	    @opening_balance = v
	    @opening_balance_is_final = true
	  end
	  def final_closing_balance=( v )
	    @closing_balance = v
	    @closing_balance_is_final = true
	  end
	  def intermediate_opening_balance=( v )
	    @opening_balance = v
	    @opening_balance_is_final = false
	  end
	  def intermediate_closing_balance=( v )
	    @closing_balance = v
	    @closing_balance_is_final = false
	  end

	  def newTransaction
	    t = Transaction.new
#	    p @transactions
	    @transactions << t
	    return t
	  end
	end

	def initialize
		@statements = []
	end

	def loadFromFile( filename )
		File.open( filename, 'rb' ){ |f|
		  state = 0
		  statement = nil
		  transaction = nil
		  f.each_line{ |l|
		    l.chomp!
		#p l
		    if m = /:([0-9a-zA-Z]{2,3}):(.*)/.match(l)
		#      p m
		      case state
		        when 0
		          case m[ 1 ]
		            when "20"
		#            puts "Start Statement"
		            state = 20
		            statement = Statement.new
		          end
		        when 20, 61
		          case m[ 1 ]
		            when "25" # IBAN
		              statement.iban = m[ 2 ]
		            when "28C" # statement number
		              statement.number = m[ 2 ]
		            when "60F" # final opening balance
		              statement.final_opening_balance = m[ 2 ]
		            when "60M" # intermediate opening balance
		              statement.intermediate_opening_balance = m[ 2 ]
		            when "62F" # final closing balance
		              state = 20
		              statement.final_closing_balance = m[ 2 ]
		            when "62M" # intermediate closing balance
		              state = 20
		              statement.intermediate_closing_balance = m[ 2 ]
		            when "64" # available balance
		              state = 20
		              statement.available_balance = m[ 2 ]
		            when "61" # transaction
		              state = 61
		              transaction = statement.newTransaction
		              transaction.info = m[ 2 ]
		#              statement[ 'transaction' ] = {}
		#              statement[ 'transaction' ][ 'info' ] = m[ 2 ]
		#              statement[ 'transaction' ][ 'detail' ] = ""
		            when "86"
		              transaction.appendDetail( m[ 2 ] )
		          else
		            puts "?"+m[ 1 ].to_s+" in state "+state.to_s
		            p m
		          end
		        else
		          puts "Unknown state "+state.to_s
		          exit
		      end

		    else
		      case state
		        when 20
		          case l
		            when '-'
		              state = 0
		#              puts "End of set"
		#              p statement
		              @statements << statement
		          end
		        when 61
		          transaction.appendDetail( l )
		        else
		#          p ":("
		      end
		    end
		  }
		}
	end


	def toSpecialCsv()
		csv = ''
		@statements.each{ |s|
			s.transactions.each{ |t|
				type = 'NONE'
				times_per_year = 1
				short = t.shortDetail()
				k = find_known_transaction( short )
				if k
					type = k[ :type ]
					times_per_year = k[ :times_per_year ]
					short = k[ :name ]
				else
					p short
				end
				per_month = ( t.amount/12 )*times_per_year
				per_month = t.amount if type == 'NONE'
				csv += "#{t.value_date.to_date.to_s};\"%80s\";%8.2f;%10s;%2.0f;%8.2f;\n" % [short[0..79], t.amount, '"'+type[0..9]+'"', times_per_year.to_i, per_month]
			}
		}
		csv
	end
end

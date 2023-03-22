require "pegmatite"

module AzureADFilter
  module Parser
    extend self

    def parse(source)
      tokens = Pegmatite.tokenize(Grammar, source)
      Builder.build(tokens, source)
    end
  end

  # Define the grammar for Azure AD filter expressions
  Grammar = Pegmatite::DSL.define do
    # Forward-declare `expression` to refer to it before defining it
    expression = declare

    # Define what optional whitespace looks like
    whitespace = (char(' ') | char('\t')).repeat
    whitespace_pattern(whitespace)

    identifier = (
      range('a', 'z') |
      range('A', 'Z') |
      char('/')
    ).repeat(1).named(:identifier)

    unquoted_value = (
      range('a', 'z') |
      range('A', 'Z') |
      range('0', '9') |
      char('@') |
      char('.') |
      char('-') |
      char(' ')
    ).repeat(1).named(:value)

    quoted_value = (
      char('\'') >>
      unquoted_value >>
      char('\'')
    )

    value = unquoted_value | quoted_value

    value_list = (
      char('(') >>
      whitespace >>
      value >>
      (char(',') >> whitespace >> value).repeat(0) >>
      whitespace >>
      char(')')
    ).named(:value_list)

    # Equality operators
    eq_operator = str("eq").named(:eq_operator)
    ne_operator = str("ne").named(:ne_operator)
    not_operator = str("not").named(:not_operator)
    in_operator = str("in").named(:in_operator)
    has_operator = str("has").named(:has_operator)
    # Relational operators
    lt_operator = str("lt").named(:lt_operator)
    gt_operator = str("gt").named(:gt_operator)
    le_operator = str("le").named(:le_operator)
    ge_operator = str("ge").named(:ge_operator)
    # Lambda operators
    any_operator = str("any").named(:any_operator)
    all_operator = str("all").named(:all_operator)
    # Conditional operators
    and_operator = str("and").named(:and_operator)
    or_operator = str("or").named(:or_operator)
    # Functions
    starts_with = str("startsWith").named(:starts_with)
    ends_with = str("endsWith").named(:ends_with)
    contains = str("contains").named(:contains)

    equality_expression = (
      identifier ^
      (eq_operator | ne_operator | has_operator) ^
      value
    ).named(:equality_expression)

    in_expression = (
      identifier ^
      in_operator ^
      value_list
    ).named(:in_expression)

    right_expression = (
      not_operator ^
      char('(') ^
      expression ^
      char(')')
    ).named(:right_expression)

    relational_expression = (
      identifier ^
      (lt_operator | gt_operator | le_operator | ge_operator) ^
      value
    ).named(:relational_expression)

    lambda_expression = (
      (any_operator | all_operator) ^
      char('(') ^
      identifier ^
      char(':') ^
      expression ^
      char(')')
    ).named(:lambda_expression)

    conditional_expression = (
      (and_operator | or_operator) ^
      expression ^
      expression
    ).named(:conditional_expression)

    function_expression = (
      (starts_with | ends_with | contains) >>
      char('(') >>
      identifier >>
      char(',') >>
      whitespace >> # Allow optional whitespace
      value >>
      char(')')
    ).named(:function_expression)

    expression.define (
      equality_expression |
      right_expression |
      in_expression |
      relational_expression |
      lambda_expression |
      conditional_expression |
      function_expression
    ).named(:expression)

    (whitespace >> expression >> whitespace).then_eof
  end

  module Builder
    extend self

    def build(tokens : Array(Pegmatite::Token), source : String)
      iter = Pegmatite::TokenIterator.new(tokens)
      main = iter.next
      build_expression(main, iter, source)
    end

    private def build_expression(main, iter, source)
      kind, start, finish = main

      ast =
        case kind
        when :identifier then Identifier.new(source[start...finish])
        when :value      then Value.new(source[start...finish])
        when :value_list
          values = source[start...finish].split(",").map { |v| Value.new(v) }
          ValueList.new(values)
          # Equality operators
        when :eq_operator  then Operator.new("eq", "equality")
        when :ne_operator  then Operator.new("ne", "equality")
        when :not_operator then Operator.new("not", "equality")
        when :in_operator  then Operator.new("in", "equality")
        when :has_operator then Operator.new("has", "equality")
          # Relational operators
        when :lt_operator then Operator.new("lt", "relational")
        when :gt_operator then Operator.new("gt", "relational")
        when :le_operator then Operator.new("le", "relational")
        when :ge_operator then Operator.new("ge", "relational")
          # Lambda operators
        when :any_operator then Operator.new("any", "lambda")
        when :all_operator then Operator.new("all", "lambda")
          # Conditional operators
        when :and_operator then Operator.new("and", "conditional")
        when :or_operator  then Operator.new("or", "conditional")
          # Functions
        when :starts_with then Operator.new("startsWith", "function")
        when :ends_with   then Operator.new("endsWith", "function")
        when :contains    then Operator.new("contains", "function")
        when :equality_expression, :relational_expression
          identifier = build_expression(iter.next_as_child_of(main), iter, source)
          operator = build_expression(iter.next_as_child_of(main), iter, source)
          value = build_expression(iter.next_as_child_of(main), iter, source)
          Expression.new(operator: operator, left: identifier, right: value)
        when :right_expression
          operator = build_expression(iter.next_as_child_of(main), iter, source)
          value = build_expression(iter.next_as_child_of(main), iter, source)
          Expression.new(operator: operator, right: value)
        when :in_expression
          identifier = build_expression(iter.next_as_child_of(main), iter, source)
          operator = build_expression(iter.next_as_child_of(main), iter, source)
          value = build_expression(iter.next_as_child_of(main), iter, source)
          Expression.new(operator: operator, left: identifier, right: value)
        when :lambda_expression
          operator = build_expression(iter.next_as_child_of(main), iter, source)
          identifier = build_expression(iter.next_as_child_of(main), iter, source)
          value = build_expression(iter.next_as_child_of(main), iter, source)
          Expression.new(operator: operator, left: identifier, right: value)
        when :conditional_expression
          operator = build_expression(iter.next_as_child_of(main), iter, source)
          left = build_expression(iter.next_as_child_of(main), iter, source)
          right = build_expression(iter.next_as_child_of(main), iter, source)
          Expression.new(operator: operator, left: left, right: right)
        when :function_expression
          operator = build_expression(iter.next_as_child_of(main), iter, source)
          identifier = build_expression(iter.next_as_child_of(main), iter, source)
          value = build_expression(iter.next_as_child_of(main), iter, source)
          Expression.new(operator: operator, left: identifier, right: value)
        when :expression then build_expression(iter.next_as_child_of(main), iter, source)
        else                  raise NotImplementedError.new(kind)
        end

      iter.assert_next_not_child_of(main)

      ast
    end
  end

  abstract class Node
  end

  class Identifier < Node
    getter value : String

    def initialize(@value : String)
    end

    def to_s
      value
    end
  end

  class Value < Node
    getter value : String

    def initialize(@value : String)
    end

    def to_s
      if value == "true" || value == "false" || value == "null"
        value
      else
        "'#{value}'"
      end
    end
  end

  class ValueList < Node
    getter value : Array(Value)

    def initialize(@value : Array(Value))
    end

    def to_s
      "(#{value.join(", ")})"
    end
  end

  class Operator < Node
    getter operator : String
    getter type : String

    def initialize(@operator : String, @type : String)
    end

    def to_s
      operator
    end
  end

  class Expression < Node
    getter operator : Node
    getter left : Node?
    getter right : Node?

    def initialize(@operator : Node, @left : Node? = nil, @right : Node? = nil)
    end

    def to_s
      # left_str = left.is_a?(Expression) ? "(#{left.to_s})" : left.to_s unless left.nil?
      # right_str = right.is_a?(Expression) ? "(#{right.to_s})" : right.to_s unless right.nil?

      if operator.as(Operator).type == "function"
        String.build do |str|
          str << operator.to_s
          str << '('
          str << left.to_s
          str << ", "
          str << right.to_s
          str << ')'
        end
      else
        String.build do |str|
          str << left.to_s unless left.nil?
          str << ' ' unless left.nil?
          str << operator.to_s
          str << (left.nil? ? '(' : ' ')
          str << right.to_s
          str << (left.nil? ? ')' : nil)
        end
      end
    end

    # def to_google
    #   if operator == "and" || operator == "or"
    #     "(#{left.to_google} #{operator.to_google} #{right.to_google})"
    #   else
    #     "(#{operator.to_google}(#{left.to_google}, #{right.to_google}))"
    #   end
    # end
  end
end

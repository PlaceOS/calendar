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
      range('A', 'Z')
    ).repeat(1).named(:identifier)

    unquoted_value = (
      range('a', 'z') |
      range('A', 'Z') |
      range('0', '9') |
      char('_') |
      char('-')
    ).repeat(1).named(:value)

    quoted_value = (
      char('\'') >>
      unquoted_value >>
      char('\'')
    )

    value = unquoted_value | quoted_value

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
    ends_with = str("endsWith").named(:starts_with)
    contains = str("contains").named(:starts_with)

    equality_expression = (
      identifier ^
      (eq_operator | ne_operator | not_operator | in_operator | has_operator) ^
      value
    ).named(:equality_expression)

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
          # Equality operators
        when :eq_operator  then Operator.new("eq")
        when :ne_operator  then Operator.new("ne")
        when :not_operator then Operator.new("not")
        when :in_operator  then Operator.new("in")
        when :has_operator then Operator.new("has")
          # Relational operators
        when :lt_operator then Operator.new("lt")
        when :gt_operator then Operator.new("gt")
        when :le_operator then Operator.new("le")
        when :ge_operator then Operator.new("ge")
          # Lambda operators
        when :any_operator then Operator.new("any")
        when :all_operator then Operator.new("all")
          # Conditional operators
        when :and_operator then Operator.new("and")
        when :or_operator  then Operator.new("or")
          # Functions
        when :starts_with then Operator.new("startsWith")
        when :ends_with   then Operator.new("endsWith")
        when :contains    then Operator.new("contains")
        when :equality_expression, :relational_expression
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
      value
    end
  end

  class Operator < Node
    getter operator : String

    def initialize(@operator : String)
    end

    def to_s
      operator
    end
  end

  class Expression < Node
    getter operator : Node
    getter left : Node
    getter right : Node

    def initialize(@operator : Node, @left : Node, @right : Node)
    end

    def to_s
      if operator == "and" || operator == "or"
        "(#{left.to_s} #{operator.to_s} #{right.to_s})"
      else
        "(#{operator.to_s}(#{left.to_s}, #{right.to_s}))"
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

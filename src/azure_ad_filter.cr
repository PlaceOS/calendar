require "pegmatite"

class Pegmatite::DSL
  def i_str(text)
    text.chars.map { |c| char(c.downcase) | char(c.upcase) }.reduce { |a, b| a >> b }
  end
end

module AzureADFilter
  module Parser
    extend self

    def tokenize(source)
      Pegmatite.tokenize(Grammar, source)
    end

    def parse(source)
      tokens = tokenize(source)
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

    slash = char('/').named(:slash)
    colon = char(':').named(:colon)
    separator = (slash | colon)

    identifier = (
      range('a', 'z') |
      range('A', 'Z') |
      char('$') |
      char('.')
    ).repeat(1).named(:identifier)

    identifier_path = (
      identifier >>
      (separator >> identifier).repeat
    ).named(:identifier_path)

    parent_identifier_path = (
      identifier >> separator
    ).repeat(min: 1).named(:parent_identifier_path)

    unquoted_value = (
      range('a', 'z') |
      range('A', 'Z') |
      range('0', '9') |
      char('@') |
      char('.') |
      char('-') |
      char('_') |
      char(':') |
      char('/')
    ).repeat(min: 1)

    quoted_value = (
      char('\'') >>
      (unquoted_value | whitespace).repeat >>
      char('\'')
    )

    value = (unquoted_value | quoted_value).named(:value)

    value_list = (
      char('(') ^
      value ^
      (char(',') ^ value).repeat ^
      char(')')
    ).named(:value_list)

    # TODO: operators should be case insensitive

    # Equality operators
    eq_operator = i_str("eq").named(:eq_operator)
    ne_operator = i_str("ne").named(:ne_operator)
    not_operator = i_str("not").named(:not_operator)
    in_operator = i_str("in").named(:in_operator)
    has_operator = i_str("has").named(:has_operator)
    # Relational operators
    lt_operator = i_str("lt").named(:lt_operator)
    gt_operator = i_str("gt").named(:gt_operator)
    le_operator = i_str("le").named(:le_operator)
    ge_operator = i_str("ge").named(:ge_operator)
    # Lambda operators
    any_operator = i_str("any").named(:any_operator)
    all_operator = i_str("all").named(:all_operator)
    # Conditional operators
    and_operator = i_str("and").named(:and_operator)
    or_operator = i_str("or").named(:or_operator)
    # Functions
    starts_with = i_str("startswith").named(:starts_with)
    ends_with = i_str("endswith").named(:ends_with)
    contains = i_str("contains").named(:contains)

    comparison_expression = (
      identifier_path >>
      whitespace >>
      (
        eq_operator |
        ne_operator |
        lt_operator |
        gt_operator |
        le_operator |
        ge_operator |
        has_operator
      ) >>
      whitespace >>
      value
    ).named(:comparison_expression)

    in_expression = (
      identifier_path >>
      whitespace >>
      in_operator ^
      value_list
    ).named(:in_expression)

    lambda_expression = (
      parent_identifier_path >>
      (any_operator | all_operator) ^
      char('(') ^
      expression ^
      char(')')
    ).named(:lambda_expression)

    not_expression = (
      (not_operator ^ char('(') ^ expression ^ char(')')) |
      (not_operator >> whitespace >> lambda_expression)
    ).named(:not_expression)

    function_expression = (
      parent_identifier_path.repeat(max: 1) >>
      (starts_with | ends_with | contains) ^
      char('(') ^
      identifier_path ^
      char(',') ^
      value ^
      char(')')
    ).named(:function_expression)

    conditional_expression = (
      (comparison_expression | function_expression | not_expression) >>
      whitespace >>
      (and_operator | or_operator) >>
      whitespace >>
      (comparison_expression | function_expression | not_expression) >>
      (whitespace >> (and_operator | or_operator) >> whitespace >> (comparison_expression | function_expression)).repeat
    ).named(:conditional_expression)

    # Order matters here, as the first match will be used
    expression.define (
      conditional_expression |
      function_expression |
      comparison_expression |
      in_expression |
      not_expression |
      lambda_expression
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
        when :slash      then AST::Separator.new('/')
        when :colon      then AST::Separator.new(':')
        when :identifier then AST::Identifier.new(source[start...finish])
        when :identifier_path
          nodes = [] of AST::Node
          loop do
            child = iter.try &.next_as_child_of(main)
            nodes << build_expression(child, iter, source)
          rescue IndexError
            break
          end
          AST::IdentifierPath.new(nodes)
        when :parent_identifier_path
          nodes = [] of AST::Node
          loop do
            child = iter.try &.next_as_child_of(main)
            nodes << build_expression(child, iter, source)
          rescue IndexError
            break
          end
          _separator = nodes.pop
          AST::IdentifierPath.new(nodes)
        when :value then AST::Value.new(source[start...finish])
        when :value_list
          nodes = [] of AST::Node
          loop do
            child = iter.next_as_child_of(main)
            nodes << build_expression(child, iter, source)
          rescue IndexError
            break
          end
          AST::ValueList.new(nodes)
          # Equality operators
        when :eq_operator  then AST::EqOperator.new
        when :ne_operator  then AST::NeOperator.new
        when :not_operator then AST::NotOperator.new
        when :in_operator  then AST::InOperator.new
        when :has_operator then AST::HasOperator.new
          # Relational operators
        when :lt_operator then AST::LtOperator.new
        when :gt_operator then AST::GtOperator.new
        when :le_operator then AST::LeOperator.new
        when :ge_operator then AST::GeOperator.new
          # Lambda operators
        when :any_operator then AST::AnyOperator.new
        when :all_operator then AST::AllOperator.new
          # Conditional operators
        when :and_operator then AST::AndOperator.new
        when :or_operator  then AST::OrOperator.new
          # Functions
        when :starts_with then AST::StartsWithFunction.new
        when :ends_with   then AST::EndsWithFunction.new
        when :contains    then AST::ContainsFunction.new
        when :comparison_expression
          identifier = build_expression(iter.next_as_child_of(main), iter, source)
          operator = build_expression(iter.next_as_child_of(main), iter, source)
          value = build_expression(iter.next_as_child_of(main), iter, source)
          AST::Expression.new([identifier, operator, value])
        when :in_expression
          identifier = build_expression(iter.next_as_child_of(main), iter, source)
          operator = build_expression(iter.next_as_child_of(main), iter, source)
          value = build_expression(iter.next_as_child_of(main), iter, source)
          AST::Expression.new([identifier, operator, value])
        when :lambda_expression
          identifier = build_expression(iter.next_as_child_of(main), iter, source)
          operator = build_expression(iter.next_as_child_of(main), iter, source)
          expression = build_expression(iter.next_as_child_of(main), iter, source)
          AST::LambdaExpression.new(identifier: identifier, operator: operator, expression: expression)
        when :not_expression
          operator = build_expression(iter.next_as_child_of(main), iter, source)
          value = build_expression(iter.next_as_child_of(main), iter, source)
          AST::NotExpression.new(operator: operator, value: value)
        when :function_expression
          nodes = [] of AST::Node
          loop do
            child = iter.try &.next_as_child_of(main)
            nodes << build_expression(child, iter, source)
          rescue IndexError
            break
          end
          # order matters here
          value = nodes.pop
          identifier = nodes.pop
          function = nodes.pop

          if !nodes.empty?
            parent_identifier = nodes.pop
          end

          AST::FunctionExpression.new(function: function, identifier: identifier, value: value, parent_identifier: parent_identifier)
        when :conditional_expression
          nodes = [] of AST::Node
          loop do
            child = iter.try &.next_as_child_of(main)
            nodes << build_expression(child, iter, source)
          rescue IndexError
            break
          end
          AST::Expression.new(nodes)
        when :expression
          nodes = [] of AST::Node
          loop do
            child = iter.next_as_child_of(main)
            nodes << build_expression(child, iter, source)
          rescue IndexError
            break
          end
          AST::Expression.new(nodes)
        else
          raise NotImplementedError.new(kind)
        end

      iter.assert_next_not_child_of(main)

      ast
    end
  end

  module AST
    abstract class Node
      abstract def to_s : String

      def to_google : String
        raise NotImplementedError.new(self)
      end
    end

    class Separator < Node
      getter value : Char

      def initialize(@value : Char)
      end

      def to_s : String
        value.to_s
      end

      def to_google : String
        "."
      end
    end

    class Identifier < Node
      getter value : String

      def initialize(@value : String)
      end

      def to_s : String
        value.to_s
      end

      # TODO: translate property names to google equivalents
      def to_google : String
        value.to_s
      end
    end

    class IdentifierPath < Node
      getter value : Array(Node)

      def initialize(@value : Array(Node))
      end

      def to_s : String
        value.map(&.to_s).join
      end

      # TODO: discard separators and join by dot
      def to_google : String
        value.map(&.to_google).join
      end
    end

    class Value < Node
      getter value : String | Bool?

      # TODO: support multiple data types
      def initialize(@value : String | Bool?)
      end

      def to_s : String
        "#{value}"
      end

      def to_google : String
        "#{value}"
      end
    end

    class ValueList < Node
      getter value : Array(Node)

      def initialize(@value : Array(Node))
      end

      def to_s : String
        "(#{value.map(&.to_s).join(", ")})"
      end
    end

    # Operators
    ###########

    class EqOperator < Node
      def to_s : String
        "eq"
      end

      def to_google : String
        "="
      end
    end

    class NeOperator < Node
      def to_s : String
        "ne"
      end
    end

    class NotOperator < Node
      def to_s : String
        "not"
      end
    end

    class InOperator < Node
      def to_s : String
        "in"
      end
    end

    class HasOperator < Node
      def to_s : String
        "has"
      end
    end

    class LtOperator < Node
      def to_s : String
        "lt"
      end

      def to_google : String
        "<"
      end
    end

    class GtOperator < Node
      def to_s : String
        "gt"
      end

      def to_google : String
        ">"
      end
    end

    class LeOperator < Node
      def to_s : String
        "le"
      end

      def to_google : String
        "<="
      end
    end

    class GeOperator < Node
      def to_s : String
        "ge"
      end

      def to_google : String
        ">="
      end
    end

    class AnyOperator < Node
      def to_s : String
        "any"
      end
    end

    class AllOperator < Node
      def to_s : String
        "all"
      end
    end

    class AndOperator < Node
      def to_s : String
        "and"
      end

      def to_google : String
        " "
      end
    end

    class OrOperator < Node
      def to_s : String
        "or"
      end
    end

    # Functions
    ###########

    class StartsWithFunction < Node
      def to_s : String
        "startsWith"
      end

      def to_google : String
        ":"
      end
    end

    class EndsWithFunction < Node
      def to_s : String
        "endsWith"
      end
    end

    class ContainsFunction < Node
      def to_s : String
        "contains"
      end

      def to_google : String
        ":"
      end
    end

    # Expressions
    #############

    class Expression < Node
      getter values : Array(Node)

      def initialize(@values : Array(Node))
      end

      def to_s : String
        values.map(&.to_s).join(" ")
      end

      def to_google : String
        values.map(&.to_google).join
      end
    end

    class FunctionExpression < Node
      getter function : Node
      getter identifier : Node
      getter value : Node
      getter parent_identifier : Node?

      def initialize(@function : Node, @identifier : Node, @value : Node, @parent_identifier : Node? = nil)
      end

      def to_s : String
        String.build do |str|
          if parent_identifier
            str << parent_identifier.to_s
            str << ":"
          end
          str << function.to_s
          str << "("
          str << identifier.to_s
          str << ", "
          str << value.to_s
          str << ")"
        end
      end

      def to_google : String
        raise NotImplementedError.new("parent_identifier") if parent_identifier
        String.build do |str|
          str << identifier.to_google
          str << function.to_google
          str << value.to_google
          str << "*" if function.is_a?(StartsWithFunction)
        end
      end
    end

    class NotExpression < Node
      getter operator : Node
      getter value : Node

      def initialize(@operator : Node, @value : Node)
      end

      def to_s : String
        if value.is_a? LambdaExpression
          "#{operator.to_s} #{value.to_s}"
        else
          "#{operator.to_s}(#{value.to_s})"
        end
      end
    end

    class LambdaExpression < Node
      getter identifier : Node
      getter operator : Node
      getter expression : Node

      def initialize(@identifier : Node, @operator : Node, @expression : Node)
      end

      def to_s : String
        "#{identifier.to_s}/#{operator.to_s}(#{expression.to_s})"
      end
    end
  end
end

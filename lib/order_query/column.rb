require 'order_query/direction'
require 'order_query/nulls_direction'
require 'order_query/sql/column'
module OrderQuery
  # An order column (sort column)
  class Column
    attr_reader :name, :order_enum, :custom_sql
    delegate :column_name, :quote, to: :@sql_builder

    # @param scope [ActiveRecord::Relation]
    # @param attr_name [Symbol] the name of the column, or the method providing the value to sort by.
    # @param vals_and_or_dir [Array] optionally, values in the desired order, and / or one of :asc, :desc.
    #   Default order is :desc if the values are given (so the result is ordered like the values), and :asc otherwise.
    # @param unique [Boolean] mark the attribute as unique to avoid redundant columns. Default: true for primary key.
    # @param nulls [:first, :last, false] whether to consider NULLS to be ordered first or last.
    #   If false, assumes that a column is not nullable and raises if a null is encountered.
    # @param sql [String, nil] a custom sql fragment.
    def initialize(scope, attr_name, *vals_and_or_dir, unique: nil, nulls: false, sql: nil)
      @name       = attr_name
      @order_enum = vals_and_or_dir.shift if vals_and_or_dir[0].is_a?(Array)
      @direction  = Direction.parse!(vals_and_or_dir.shift || (@order_enum ? :desc : :asc))
      fail ArgumentError.new("extra arguments: #{vals_and_or_dir.map(&:inspect) * ', '}") unless vals_and_or_dir.empty?
      @unique      = unique.nil? ? (name.to_s == scope.primary_key) : unique
      @nulls       = NullsDirection.parse!(nulls || NullsDirection.default(scope, @direction))
      @nullable    = !!nulls
      @custom_sql  = sql
      @sql_builder = SQL::Column.new(scope, self)
    end

    def direction(reverse = false)
      reverse ? Direction.reverse(@direction) : @direction
    end

    # @return [:first, :last]
    def nulls_direction(reverse = false)
      reverse ? NullsDirection.reverse(@nulls) : @nulls
    end

    def nullable?
      @nullable
    end

    def unique?
      @unique
    end

    # @param [Object] value
    # @param [:before, :after] side
    # @return [Array] valid order values before / after passed (depending on the side)
    # @example for [:difficulty, ['Easy', 'Normal', 'Hard']]:
    #  enum_side('Normal', :after) #=> ['Hard']
    #  enum_side('Normal', :after, false) #=> ['Normal', 'Hard']
    def enum_side(value, side, strict = true)
      ord = order_enum
      pos = ord.index(value)
      if pos
        dir = direction
        if side == :after && dir == :desc || side == :before && dir == :asc
          ord.from pos + (strict ? 1 : 0)
        else
          ord.first pos + (strict ? 0 : 1)
        end
      else
        # default to all if current is not in sort order values
        []
      end
    end

    def inspect
      parts = [
          @name,
          (@order_enum.inspect if order_enum),
          ('unique' if @unique),
          (column_name if @custom_sql),
          @direction
      ].compact
      "(#{parts.join(' ')})"
    end
  end
end

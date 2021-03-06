require 'abstract_unit'

uses_mocha 'Memoizable' do
  class MemoizableTest < Test::Unit::TestCase
    class Person
      extend ActiveSupport::Memoizable

      attr_reader :name_calls, :age_calls
      def initialize
        @name_calls = 0
        @age_calls = 0
      end

      def name
        @name_calls += 1
        "Josh"
      end

      def name?
        true
      end
      memoize :name?

      def update(name)
        "Joshua"
      end
      memoize :update

      def age
        @age_calls += 1
        nil
      end

      memoize :name, :age
    end

    class Company
      attr_reader :name_calls
      def initialize
        @name_calls = 0
      end

      def name
        @name_calls += 1
        "37signals"
      end
    end

    module Rates
      extend ActiveSupport::Memoizable

      attr_reader :sales_tax_calls
      def sales_tax(price)
        @sales_tax_calls ||= 0
        @sales_tax_calls += 1
        price * 0.1025
      end
      memoize :sales_tax
    end

    class Calculator
      extend ActiveSupport::Memoizable
      include Rates

      attr_reader :fib_calls
      def initialize
        @fib_calls = 0
      end

      def fib(n)
        @fib_calls += 1

        if n == 0 || n == 1
          n
        else
          fib(n - 1) + fib(n - 2)
        end
      end
      memoize :fib

      def counter
        @count ||= 0
        @count += 1
      end
      memoize :counter
    end

    def setup
      @person = Person.new
      @calculator = Calculator.new
    end

    def test_memoization
      assert_equal "Josh", @person.name
      assert_equal 1, @person.name_calls

      3.times { assert_equal "Josh", @person.name }
      assert_equal 1, @person.name_calls
    end

    def test_memoization_with_punctuation
      assert_equal true, @person.name?
    end

    def test_memoization_with_nil_value
      assert_equal nil, @person.age
      assert_equal 1, @person.age_calls

      3.times { assert_equal nil, @person.age }
      assert_equal 1, @person.age_calls
    end

    def test_reloadable
      counter = @calculator.counter
      assert_equal 1, @calculator.counter
      assert_equal 2, @calculator.counter(:reload)
      assert_equal 2, @calculator.counter
      assert_equal 3, @calculator.counter(true)
      assert_equal 3, @calculator.counter
    end

    def test_memoization_cache_is_different_for_each_instance
      assert_equal 1, @calculator.counter
      assert_equal 2, @calculator.counter(:reload)
      assert_equal 1, Calculator.new.counter
    end

    def test_memoized_is_not_affected_by_freeze
      @person.freeze
      assert_equal "Josh", @person.name
      assert_equal "Joshua", @person.update("Joshua")
    end

    def test_memoization_with_args
      assert_equal 55, @calculator.fib(10)
      assert_equal 11, @calculator.fib_calls
    end

    def test_reloadable_with_args
      assert_equal 55, @calculator.fib(10)
      assert_equal 11, @calculator.fib_calls
      assert_equal 55, @calculator.fib(10, :reload)
      assert_equal 12, @calculator.fib_calls
      assert_equal 55, @calculator.fib(10, true)
      assert_equal 13, @calculator.fib_calls
    end

    def test_object_memoization
      [Company.new, Company.new, Company.new].each do |company|
        company.extend ActiveSupport::Memoizable
        company.memoize :name

        assert_equal "37signals", company.name
        assert_equal 1, company.name_calls
        assert_equal "37signals", company.name
        assert_equal 1, company.name_calls
      end
    end

    def test_memoized_module_methods
      assert_equal 1.025, @calculator.sales_tax(10)
      assert_equal 1, @calculator.sales_tax_calls
      assert_equal 1.025, @calculator.sales_tax(10)
      assert_equal 1, @calculator.sales_tax_calls
      assert_equal 2.5625, @calculator.sales_tax(25)
      assert_equal 2, @calculator.sales_tax_calls
    end

    def test_object_memoized_module_methods
      company = Company.new
      company.extend(Rates)

      assert_equal 1.025, company.sales_tax(10)
      assert_equal 1, company.sales_tax_calls
      assert_equal 1.025, company.sales_tax(10)
      assert_equal 1, company.sales_tax_calls
      assert_equal 2.5625, company.sales_tax(25)
      assert_equal 2, company.sales_tax_calls
    end

    def test_double_memoization
      assert_raise(RuntimeError) { Person.memoize :name }
      person = Person.new
      person.extend ActiveSupport::Memoizable
      assert_raise(RuntimeError) { person.memoize :name }

      company = Company.new
      company.extend ActiveSupport::Memoizable
      company.memoize :name
      assert_raise(RuntimeError) { company.memoize :name }
    end
  end
end

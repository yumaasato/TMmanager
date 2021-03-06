# frozen_string_literal: true

module RuboCop
  module Cop
    module Naming
      # This cop checks for memoized methods whose instance variable name
      # does not match the method name.
      #
      # This cop can be configured with the EnforcedStyleForLeadingUnderscores
      # directive. It can be configured to allow for memoized instance variables
      # prefixed with an underscore. Prefixing ivars with an underscore is a
      # convention that is used to implicitly indicate that an ivar should not
      # be set or referenced outside of the memoization method.
      #
      # @example EnforcedStyleForLeadingUnderscores: disallowed (default)
      #   # bad
      #   # Method foo is memoized using an instance variable that is
      #   # not `@foo`. This can cause confusion and bugs.
      #   def foo
      #     @something ||= calculate_expensive_thing
      #   end
      #
      #   def foo
      #     return @something if defined?(@something)
      #     @something = calculate_expensive_thing
      #   end
      #
      #   # good
      #   def _foo
      #     @foo ||= calculate_expensive_thing
      #   end
      #
      #   # good
      #   def foo
      #     @foo ||= calculate_expensive_thing
      #   end
      #
      #   # good
      #   def foo
      #     @foo ||= begin
      #       calculate_expensive_thing
      #     end
      #   end
      #
      #   # good
      #   def foo
      #     helper_variable = something_we_need_to_calculate_foo
      #     @foo ||= calculate_expensive_thing(helper_variable)
      #   end
      #
      # @example EnforcedStyleForLeadingUnderscores: required
      #   # bad
      #   def foo
      #     @something ||= calculate_expensive_thing
      #   end
      #
      #   # bad
      #   def foo
      #     @foo ||= calculate_expensive_thing
      #   end
      #
      #   def foo
      #     return @foo if defined?(@foo)
      #     @foo = calculate_expensive_thing
      #   end
      #
      #   # good
      #   def foo
      #     @_foo ||= calculate_expensive_thing
      #   end
      #
      #   # good
      #   def _foo
      #     @_foo ||= calculate_expensive_thing
      #   end
      #
      #   def foo
      #     return @_foo if defined?(@_foo)
      #     @_foo = calculate_expensive_thing
      #   end
      #
      # @example EnforcedStyleForLeadingUnderscores :optional
      #   # bad
      #   def foo
      #     @something ||= calculate_expensive_thing
      #   end
      #
      #   # good
      #   def foo
      #     @foo ||= calculate_expensive_thing
      #   end
      #
      #   # good
      #   def foo
      #     @_foo ||= calculate_expensive_thing
      #   end
      #
      #   # good
      #   def _foo
      #     @_foo ||= calculate_expensive_thing
      #   end
      #
      #   # good
      #   def foo
      #     return @_foo if defined?(@_foo)
      #     @_foo = calculate_expensive_thing
      #   end
      class MemoizedInstanceVariableName < Base
        include ConfigurableEnforcedStyle

        MSG = 'Memoized variable `%<var>s` does not match ' \
          'method name `%<method>s`. Use `@%<suggested_var>s` instead.'
        UNDERSCORE_REQUIRED = 'Memoized variable `%<var>s` does not start ' \
          'with `_`. Use `@%<suggested_var>s` instead.'

        # rubocop:disable Metrics/AbcSize
        def on_or_asgn(node)
          lhs, _value = *node
          return unless lhs.ivasgn_type?
          return unless (method_node = node.each_ancestor(:def, :defs).first)

          body = method_node.body
          return unless body == node || body.children.last == node

          method_name = method_node.method_name
          return if matches?(method_name, lhs)

          msg = format(
            message(lhs.children.first.to_s),
            var: lhs.children.first.to_s,
            suggested_var: suggested_var(method_name),
            method: method_name
          )
          add_offense(lhs, message: msg)
        end
        # rubocop:enable Metrics/AbcSize

        def_node_matcher :defined_memoized?, <<~PATTERN
          (begin
            (if (defined $(ivar %1)) (return $(ivar %1)) nil?)
            ...
            $(ivasgn %1 _))
        PATTERN

        # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
        def on_defined?(node)
          arg = node.arguments.first
          return unless arg.ivar_type?

          method_node = node.each_ancestor(:def, :defs).first
          return unless method_node

          var_name = arg.children.first
          method_name = method_node.method_name
          defined_memoized?(method_node.body, var_name) do |defined_ivar, return_ivar, ivar_assign|
            return if matches?(method_name, ivar_assign)

            msg = format(
              message(var_name.to_s),
              var: var_name.to_s,
              suggested_var: suggested_var(method_name),
              method: method_name
            )
            add_offense(defined_ivar, message: msg)
            add_offense(return_ivar, message: msg)
            add_offense(ivar_assign.loc.name, message: msg)
          end
        end
        # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

        private

        def style_parameter_name
          'EnforcedStyleForLeadingUnderscores'
        end

        def matches?(method_name, ivar_assign)
          return true if ivar_assign.nil? || method_name == :initialize

          method_name = method_name.to_s.delete('!?')
          variable = ivar_assign.children.first
          variable_name = variable.to_s.sub('@', '')

          variable_name_candidates(method_name).include?(variable_name)
        end

        def message(variable)
          variable_name = variable.to_s.sub('@', '')

          return UNDERSCORE_REQUIRED if style == :required &&
                                        !variable_name.start_with?('_')

          MSG
        end

        def suggested_var(method_name)
          suggestion = method_name.to_s.delete('!?')

          style == :required ? "_#{suggestion}" : suggestion
        end

        def variable_name_candidates(method_name)
          no_underscore = method_name.sub(/\A_/, '')
          with_underscore = "_#{method_name}"
          case style
          when :required
            [with_underscore,
             method_name.start_with?('_') ? method_name : nil].compact
          when :disallowed
            [method_name, no_underscore]
          when :optional
            [method_name, with_underscore, no_underscore]
          else
            raise 'Unreachable'
          end
        end
      end
    end
  end
end

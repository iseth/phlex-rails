# frozen_string_literal: true

module Phlex
	module Rails
		module SGML
			module ClassMethods
				def render_in(...)
					new.render_in(...)
				end
			end

			module Overrides
				def helpers
					if defined?(ViewComponent::Base) && @_view_context.is_a?(ViewComponent::Base)
						@_view_context.helpers
					else
						@_view_context
					end
				end

				def render(*args, **kwargs, &block)
					renderable = args[0]

					case renderable
					when Phlex::SGML, Proc, Method
						return super
					when Class
						return super if renderable < Phlex::SGML
					when Enumerable
						return super unless renderable.is_a?(ActiveRecord::Relation)
					else
						captured_block = -> { capture(&block) } if block
						@_context.target << @_view_context.render(*args, **kwargs, &captured_block)
					end

					nil
				end

				def render_in(view_context, &block)
					fragments = if view_context.request && (fragment_header = view_context.request.headers["X-Fragment"])
						fragment_header.split
					end

					if block_given?
						call(view_context: view_context, fragments: fragments) do |*args|
							original_length = @_context.target.bytesize

							if args.length == 1 && Phlex::SGML === args[0] && !block.source_location&.[](0)&.end_with?(".rb")
								output = view_context.capture(
									args[0].unbuffered, &block
								)
							elsif args.length == 1 && args[0].is_a?(Symbol)
								output = view_context.view_flow.get(args[0])
							else
								output = view_context.capture(&block)
							end

							unchanged = (original_length == @_context.target.bytesize)

							if unchanged
								case output
								when ActiveSupport::SafeBuffer
									@_context.target << output
								end
							end
						end.html_safe
					else
						call(view_context: view_context, fragments: fragments).html_safe
					end
				end

				def capture
					super&.html_safe
				end

				# @api private
				def __text__(content)
					case content
					when ActiveSupport::SafeBuffer
						@_context.target << content
					else
						super
					end
				end

				# @api private
				def await(task)
					if task.is_a?(ActiveRecord::Relation)
						flush unless task.loaded?

						task
					else
						super
					end
				end

				# Trick ViewComponent into thinking we're a ViewComponent to fix rendering output
				# @api private
				def set_original_view_context(view_context)
				end
			end
		end
	end
end

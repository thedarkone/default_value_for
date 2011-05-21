# Copyright (c) 2008, 2009, 2010, 2011 Phusion
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

require 'default_value_for/railtie' if defined? Rails::Railtie

module DefaultValueFor
	class NormalValueContainer
		def initialize(value)
			@value = value
		end

		def evaluate(instance)
			if @value.duplicable?
				return @value.dup
			else
				return @value
			end
		end
	end

	class BlockValueContainer
		def initialize(block)
			@block = block
		end

		def evaluate(instance)
			return @block.call(instance)
		end
	end

	module ClassMethods
		def default_value_for(attribute, value = nil, &block)
			if !method_defined?(:initialize_with_defaults)
				include(InstanceMethods)
				alias_method_chain :initialize, :defaults
				class_attribute :_default_attribute_values
				self._default_attribute_values ||= ActiveSupport::OrderedHash.new
			end
			if block_given?
				container = BlockValueContainer.new(block)
			else
				container = NormalValueContainer.new(value)
			end
			self._default_attribute_values = _default_attribute_values.merge(attribute.to_s => container)
		end

		def default_values(values)
			values.each_pair do |key, value|
				if value.kind_of? Proc
					default_value_for(key, &value)
				else
					default_value_for(key, value)
				end
			end
		end
	end

	module InstanceMethods
		def initialize_with_defaults(attrs = nil, options = {})
			initialize_without_defaults(attrs, options) do
			  if attrs.present?
  			  sanitizer    = mass_assignment_authorizer((options && options[:as]) || :default)
			    allowed_keys = []

  			  keys = attrs.keys.each do |key|
  			    key = key.to_s
  			    allowed_keys << key unless sanitizer.deny?(key)
  			  end
			  end
			  self.class._default_attribute_values.each_pair do |attribute, container|
			    multi_attribute = "#{attribute}("
			    if !allowed_keys || allowed_keys.none? {|key| key == attribute || key.start_with?(multi_attribute)}
			      __send__("#{attribute}=", container.evaluate(self))
			      changed_attributes.delete(attribute)
		      end
			  end
				yield(self) if block_given?
			end
		end
	end
end

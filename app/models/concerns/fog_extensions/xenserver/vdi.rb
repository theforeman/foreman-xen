module FogExtensions
  module Xenserver
    module Vdi
      extend ActiveSupport::Concern

      def id
        uuid
      end
    end
  end
end

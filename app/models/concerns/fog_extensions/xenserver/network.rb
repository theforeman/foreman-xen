module FogExtensions
  module Xenserver
    module Network
      extend ActiveSupport::Concern

      def id
        uuid
      end
    end
  end
end
